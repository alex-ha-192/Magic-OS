#!/usr/bin/python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Magic installer backend: serves the installer UI and a small JSON API on
127.0.0.1:8080. Runs as root; the UI (Firefox in a kiosk) runs as a normal user.

If a disk labelled MAGICAUTO holding autoinstall.json is attached, the install
runs on its own with those answers and the machine powers off afterwards
(used by the automated VM test)."""
import json
import os
import re
import subprocess
import sys
import threading
import time
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import magic_install as mi  # noqa: E402

UI_DIR = "/usr/share/magic-installer/ui"
XKB_ENV = "/run/magic-installer/xkb.env"

# Flathub IDs for every choice the installer offers.
APPS = {
    "vivaldi": "com.vivaldi.Vivaldi", "firefox": "org.mozilla.firefox",
    "libreoffice": "org.libreoffice.LibreOffice", "onlyoffice": "org.onlyoffice.desktopeditors",
    "thunderbird": "org.mozilla.Thunderbird", "evolution": "org.gnome.Evolution",
    "gwenview": "org.kde.gwenview", "okular": "org.kde.okular",
    "vlc": "org.videolan.VLC", "zotero": "org.zotero.Zotero", "zoom": "us.zoom.Zoom",
    "spotify": "com.spotify.Client", "signal": "org.signal.Signal", "discord": "com.discordapp.Discord",
    "bitwarden": "com.bitwarden.desktop", "steam": "com.valvesoftware.Steam", "gimp": "org.gimp.GIMP",
    "kdenlive": "org.kde.kdenlive", "audacity": "org.audacityteam.Audacity", "obs": "com.obsproject.Studio",
    "calibre": "com.calibre_ebook.calibre",
}
RECOMMENDED = ["vivaldi", "libreoffice", "thunderbird", "gwenview", "okular", "vlc"]
ACCENTS = {"ember", "magenta", "teal", "blue", "violet", "green"}

STATE = {
    "recovery_key": mi.new_recovery_key(),
    "install": {"running": False, "done": False, "stage": "", "percent": 0, "error": None, "details": ""},
    "autoinstall": False,
}
_disk_cache = {"t": 0, "v": None}


def sh(cmd, timeout=30):
    try:
        p = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
        return p.returncode, p.stdout, p.stderr
    except Exception as e:
        return 1, "", str(e)


# --------------------------------------------------------------------- network
def online():
    rc, out, _ = sh(["curl", "-sS", "-o", "/dev/null", "-w", "%{http_code}", "--max-time", "6", "https://ghcr.io/v2/"], 10)
    return out.strip() in ("200", "401")


def net_status():
    rc, out, _ = sh(["nmcli", "-t", "-f", "TYPE,STATE,CONNECTION", "device"])
    wired = wifi_conn = None
    has_wifi = False
    for line in out.splitlines():
        f = re.split(r"(?<!\\):", line)
        if len(f) < 3:
            continue
        if f[0] == "wifi":
            has_wifi = True
            if f[1] == "connected":
                wifi_conn = f[2].replace("\\:", ":")
        if f[0] == "ethernet" and f[1] == "connected":
            wired = True
    return {"online": online(), "wired": bool(wired), "wifi": wifi_conn, "has_wifi": has_wifi}


def wifi_list():
    rc, out, _ = sh(["nmcli", "-t", "-f", "IN-USE,SSID,SIGNAL,SECURITY", "device", "wifi", "list", "--rescan", "yes"], 25)
    seen = {}
    for line in out.splitlines():
        f = [x.replace("\\:", ":") for x in re.split(r"(?<!\\):", line)]
        if len(f) < 4 or not f[1]:
            continue
        ssid = f[1]
        sig = int(f[2] or 0)
        if ssid not in seen or seen[ssid]["signal"] < sig:
            seen[ssid] = {"ssid": ssid, "signal": sig, "secure": bool(f[3].strip() and f[3] != "--"), "active": f[0] == "*"}
    return sorted(seen.values(), key=lambda n: -n["signal"])


def wifi_connect(ssid, password):
    cmd = ["nmcli", "device", "wifi", "connect", ssid]
    if password:
        cmd += ["password", password]
    rc, out, err = sh(cmd, 45)
    if rc != 0:
        msg = "That didn't work. Check the password and try again." if "Secrets were required" in err or "802-1x" in err or "password" in err.lower() else "Couldn't connect to that network."
        return {"ok": False, "message": msg}
    return {"ok": True}


# ------------------------------------------------------------------ time zones
def timezones():
    names = {}
    try:
        for line in open("/usr/share/zoneinfo/iso3166.tab"):
            if line.startswith("#") or not line.strip():
                continue
            code, name = line.rstrip("\n").split("\t", 1)
            names[code] = name
    except OSError:
        pass
    out = []
    try:
        for line in open("/usr/share/zoneinfo/zone.tab"):
            if line.startswith("#"):
                continue
            f = line.rstrip("\n").split("\t")
            if len(f) >= 3:
                tz = f[2]
                city = tz.split("/")[-1].replace("_", " ")
                out.append({"tz": tz, "city": city, "country": names.get(f[0], f[0])})
    except OSError:
        pass
    out.append({"tz": "UTC", "city": "UTC", "country": "Coordinated Universal Time"})
    return sorted(out, key=lambda z: (z["city"], z["country"]))


def geo_guess():
    try:
        with urllib.request.urlopen("https://geoip.fedoraproject.org/city", timeout=5) as r:
            d = json.load(r)
            return {"timezone": d.get("time_zone"), "country": d.get("country_code")}
    except Exception:
        return {"timezone": None}


# ----------------------------------------------------------------- keyboard
def set_keyboard(layout, variant):
    if not re.match(r"^[a-z]{2,8}$", layout or "") or not re.match(r"^[a-z0-9_-]{0,20}$", variant or ""):
        return {"ok": False}
    os.makedirs(os.path.dirname(XKB_ENV), exist_ok=True)
    with open(XKB_ENV, "w") as f:
        f.write(f"XKB_DEFAULT_LAYOUT={layout}\nXKB_DEFAULT_VARIANT={variant}\n")
    # cage reads the layout when it starts; restart it (the page restores where you were).
    subprocess.Popen(["systemctl", "restart", "magic-installer-ui.service"])
    return {"ok": True}


# ----------------------------------------------------------------- install
def username_from(name):
    base = re.sub(r"[^a-z0-9]", "", (name or "").strip().split(" ")[0].lower()) or "user"
    if not re.match(r"^[a-z]", base):
        base = "u" + base
    if base in ("root", "bin", "daemon", "adm", "nobody", "wheel", "admin", "magic"):
        base += "1"
    return base[:30]


def hostname_from(pretty):
    h = re.sub(r"[^a-z0-9-]+", "-", (pretty or "").lower().replace("'", "")).strip("-")
    return (h or "magic")[:60]


def build_config(ui):
    """Turn the installer's answers into the engine's config."""
    name = (ui.get("full_name") or "").strip()
    pw = ui.get("password") or ""
    if not name or len(pw) < 1:
        raise mi.InstallError("Your name and a password are needed.")
    p = subprocess.run(["openssl", "passwd", "-6", "-stdin"], input=pw, capture_output=True, text=True)
    if p.returncode != 0:
        raise mi.InstallError("Couldn't prepare your password.", p.stderr)
    username = ui.get("username") or username_from(name)
    if not re.match(r"^[a-z_][a-z0-9_-]{0,30}$", username):
        raise mi.InstallError("Usernames can use lowercase letters, numbers, - and _.")
    if ui.get("software") == "recommended":
        picks = list(RECOMMENDED)
    else:
        picks = [ui.get("browser") or "vivaldi"]
        for k in ("office", "email"):
            if ui.get(k) and ui[k] != "none":
                picks.append(ui[k])
        picks += [x for x in ui.get("extras", []) if x in APPS]
    apps = []
    for k in picks:
        if k in APPS and APPS[k] not in apps:
            apps.append(APPS[k])
    enc = ui.get("encryption", "tpm")
    cfg = {
        "image": ui.get("image") or mi.DEFAULT_IMAGE,
        "target_imgref": ui.get("target_imgref") or mi.DEFAULT_IMAGE,
        "disk": ui["disk"], "mode": ui["mode"], "magic_size_gb": int(ui.get("magic_size_gb") or 0),
        "encryption": enc,
        "startup_password": ui.get("startup_password") or "",
        "recovery_key": STATE["recovery_key"],
        "require_secure_boot": bool(ui.get("require_secure_boot", True)),
        "user": {"full_name": name, "username": username, "password_hash": p.stdout.strip()},
        "hostname": hostname_from(ui.get("computer_name") or name + "-pc"),
        "pretty_hostname": (ui.get("computer_name") or "").strip() or None,
        "timezone": ui.get("timezone") or "UTC",
        "locale": ui.get("locale") or "en_GB.UTF-8",
        "keyboard": {"layout": ui.get("kb_layout") or "gb", "variant": ui.get("kb_variant") or ""},
        "clock": "12" if str(ui.get("clock")) == "12" else "24",
        "accent": ui.get("accent") if ui.get("accent") in ACCENTS else "ember",
        "apps": apps,
        "extra_kargs": ui.get("extra_kargs", []),
        "registry_auth": ui.get("registry_auth"),
    }
    if enc == "password" and len(cfg["startup_password"]) < 4:
        raise mi.InstallError("Choose a start-up password of at least 4 characters.")
    return cfg


def start_install(ui):
    st = STATE["install"]
    if st["running"]:
        return {"ok": False, "message": "Already installing."}
    try:
        cfg = build_config(ui)
    except mi.InstallError as e:
        return {"ok": False, "message": e.message}
    st.update(running=True, done=False, error=None, details="", stage="Starting", percent=0)

    def cb(stage, pct):
        st["stage"], st["percent"] = stage, pct

    def work():
        try:
            mi.install(cfg, cb)
            st.update(done=True)
        except mi.InstallError as e:
            st.update(error=e.message, details=e.details)
            mi.log("MAGIC-INSTALL-FAILED: " + e.message)
            mi.log(e.details or "")
        finally:
            st["running"] = False
            if STATE["autoinstall"]:
                time.sleep(3)
                subprocess.run(["systemctl", "poweroff"])

    threading.Thread(target=work, daemon=True).start()
    return {"ok": True}


def disks(force=False):
    if force or not _disk_cache["v"] or time.time() - _disk_cache["t"] > 20:
        _disk_cache["v"], _disk_cache["t"] = mi.list_disks(), time.time()
    return _disk_cache["v"]


def autoinstall_check():
    rc, out, _ = sh(["blkid", "-L", "MAGICAUTO"])
    dev = out.strip()
    if rc != 0 or not dev:
        return
    os.environ["MAGIC_SERIAL_LOG"] = "1"
    STATE["autoinstall"] = True
    mp = "/run/magic-installer/auto"
    os.makedirs(mp, exist_ok=True)
    sh(["mount", "-o", "ro", dev, mp])
    try:
        ui = json.load(open(os.path.join(mp, "autoinstall.json")))
    finally:
        sh(["umount", mp])
    if ui.get("disk") == "auto":
        ds = disks(True)
        ui["disk"] = ds[0]["path"] if ds else ""
    mi.log("autoinstall: starting with disk " + ui.get("disk", "?"))
    for _ in range(60):  # wait for the network
        if online():
            break
        time.sleep(2)
    r = start_install(ui)
    if not r["ok"]:
        mi.log("MAGIC-INSTALL-FAILED: " + r.get("message", ""))


# ------------------------------------------------------------------ http
class H(BaseHTTPRequestHandler):
    def log_message(self, fmt, *a):
        pass

    def _json(self, obj, code=200):
        b = json.dumps(obj).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Length", str(len(b)))
        self.end_headers()
        self.wfile.write(b)

    def _body(self):
        n = int(self.headers.get("Content-Length") or 0)
        return json.loads(self.rfile.read(n) or b"{}")

    def do_GET(self):
        path = self.path.split("?")[0]
        try:
            if path == "/api/status":
                return self._json({
                    "net": net_status(), "tpm": mi.tpm_status(), "secure_boot": mi.secure_boot_enabled(),
                    "uefi": mi.uefi_boot(), "recovery_key": STATE["recovery_key"],
                    "install": STATE["install"], "autoinstall": STATE["autoinstall"],
                })
            if path == "/api/disks":
                return self._json(disks("force" in self.path))
            if path == "/api/wifi":
                return self._json(wifi_list())
            if path == "/api/timezones":
                return self._json(timezones())
            if path == "/api/geo":
                return self._json(geo_guess())
            if path == "/api/progress":
                return self._json({**STATE["install"], "log": mi.log_tail(12)})
            return self._static(path)
        except Exception as e:
            return self._json({"error": repr(e)}, 500)

    def do_POST(self):
        path = self.path.split("?")[0]
        try:
            b = self._body()
            if path == "/api/wifi":
                return self._json(wifi_connect(b.get("ssid", ""), b.get("password", "")))
            if path == "/api/keyboard":
                return self._json(set_keyboard(b.get("layout"), b.get("variant", "")))
            if path == "/api/install":
                return self._json(start_install(b))
            if path == "/api/restart":
                subprocess.Popen(["systemctl", "reboot"])
                return self._json({"ok": True})
            if path == "/api/poweroff":
                subprocess.Popen(["systemctl", "poweroff"])
                return self._json({"ok": True})
            return self._json({"error": "not found"}, 404)
        except Exception as e:
            return self._json({"error": repr(e)}, 500)

    def _static(self, path):
        if path in ("", "/"):
            path = "/index.html"
        full = os.path.realpath(os.path.join(UI_DIR, path.lstrip("/")))
        if not full.startswith(UI_DIR) or not os.path.isfile(full):
            self.send_response(404)
            self.end_headers()
            return
        ctype = {".html": "text/html; charset=utf-8", ".css": "text/css", ".js": "application/javascript",
                 ".svg": "image/svg+xml", ".png": "image/png"}.get(os.path.splitext(full)[1], "application/octet-stream")
        data = open(full, "rb").read()
        self.send_response(200)
        self.send_header("Content-Type", ctype)
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)


def main():
    global UI_DIR
    if len(sys.argv) > 1:
        UI_DIR = os.path.realpath(sys.argv[1])  # for previewing the UI
    srv = ThreadingHTTPServer(("127.0.0.1", int(os.environ.get("MAGIC_INSTALLER_PORT", "8080"))), H)
    threading.Thread(target=autoinstall_check, daemon=True).start()
    srv.serve_forever()


if __name__ == "__main__":
    main()
