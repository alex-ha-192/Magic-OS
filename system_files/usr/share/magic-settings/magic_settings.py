#!/usr/bin/python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Magic Settings: the everyday settings, in plain language.

The Python side reads and changes the system (NetworkManager, PipeWire,
KWin, rpm-ostree, ...). The QML side (qml/) is the Metro interface.
KDE's full System Settings stays available as "Advanced Settings".

    magic-settings [page]        open, optionally on a page (e.g. updates)
    magic-settings --check       load every page off-screen; exit 1 on QML errors
    MAGIC_SETTINGS_DEMO=1        sample data, for previews and screenshots
"""
import getpass
import json
import os
import re
import shutil
import subprocess
import sys
import threading

from PySide6.QtCore import QObject, Property, QTimer, QUrl, Signal, Slot
from PySide6.QtGui import QGuiApplication, QIcon, QFontDatabase, QFont
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtQuick import QQuickImageProvider

HERE = os.path.dirname(os.path.abspath(__file__))
DEMO = os.environ.get("MAGIC_SETTINGS_DEMO") == "1"
ACCENTS_FILE = "/usr/share/magic-os/accents.json"
FALLBACK_ACCENTS = {"default": "lime", "order": ["lime", "ember", "magenta", "teal", "blue", "violet"], "accents": {
    "lime": {"name": "Lime", "fill": "#4d7c0f", "text": "#bef264", "wallpaper": "#26390d"},
    "ember": {"name": "Ember", "fill": "#c2410c", "text": "#ff8a4c", "wallpaper": "#4b2412"},
    "magenta": {"name": "Magenta", "fill": "#c4125f", "text": "#ff5fa2", "wallpaper": "#4a1236"},
    "teal": {"name": "Teal", "fill": "#0f766e", "text": "#5eead4", "wallpaper": "#0c3b3a"},
    "blue": {"name": "Blue", "fill": "#1d5fc4", "text": "#7db3ff", "wallpaper": "#10305f"},
    "violet": {"name": "Violet", "fill": "#6d3fc0", "text": "#b79cff", "wallpaper": "#2d1a58"}}}
IMAGE_REF = "ghcr.io/alex-ha-192/magic-os:latest"


def sh(cmd, timeout=8, input=None):
    try:
        p = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout, input=input)
        return p.returncode, p.stdout, p.stderr
    except Exception as e:  # missing tool, timeout
        return 127, "", str(e)


def spawn(cmd):
    try:
        subprocess.Popen(cmd, start_new_session=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        return True
    except Exception:
        return False


def load_accents():
    try:
        return json.load(open(ACCENTS_FILE))
    except Exception:
        return FALLBACK_ACCENTS


def kread(file, group, key, default=""):
    rc, out, _ = sh(["kreadconfig6", "--file", file, "--group", group, "--key", key, "--default", default])
    return out.strip() if rc == 0 else default


def kwrite(file, groups, key, value, typ=None):
    cmd = ["kwriteconfig6", "--file", file]
    for g in groups:
        cmd += ["--group", g]
    cmd += ["--key", key]
    if typ:
        cmd += ["--type", typ]
    cmd.append(str(value))
    return sh(cmd)[0] == 0


# --------------------------------------------------------------------------- readers
def read_network():
    if DEMO:
        return {"wifi_enabled": True, "connection": "HomeNetwork", "kind": "wifi", "has_wifi": True}
    rc, out, _ = sh(["nmcli", "-t", "-f", "WIFI", "general"])
    wifi_on = out.strip() == "enabled"
    rc, out, _ = sh(["nmcli", "-t", "-f", "TYPE,STATE,CONNECTION", "device"])
    conn, kind, has_wifi = None, None, False
    for line in out.splitlines():
        f = re.split(r"(?<!\\):", line)
        if len(f) < 3:
            continue
        if f[0] == "wifi":
            has_wifi = True
        if f[1] == "connected" and f[0] in ("wifi", "ethernet") and not conn:
            conn, kind = f[2].replace("\\:", ":"), ("wifi" if f[0] == "wifi" else "wired")
    return {"wifi_enabled": wifi_on, "connection": conn, "kind": kind, "has_wifi": has_wifi}


def read_bluetooth():
    if DEMO:
        return {"available": True, "powered": True}
    rc, out, _ = sh(["bluetoothctl", "show"], 4)
    if rc != 0 or "Controller" not in out:
        return {"available": False, "powered": False}
    return {"available": True, "powered": "Powered: yes" in out}


def read_sound():
    if DEMO:
        return {"volume": 40, "muted": False, "available": True}
    rc, out, _ = sh(["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"])
    m = re.search(r"Volume:\s*([\d.]+)", out)
    if rc != 0 or not m:
        return {"volume": 0, "muted": False, "available": False}
    return {"volume": round(float(m.group(1)) * 100), "muted": "MUTED" in out, "available": True}


def _brightness():
    path = "/org/kde/ScreenBrightness/display0"
    def get(prop):
        rc, out, _ = sh(["busctl", "--user", "call", "org.kde.ScreenBrightness", path,
                         "org.freedesktop.DBus.Properties", "Get", "ss", "org.kde.ScreenBrightness.Display", prop], 3)
        m = re.search(r"(-?\d+)\s*$", out.strip())
        return int(m.group(1)) if rc == 0 and m else None
    cur, mx = get("Brightness"), get("MaxBrightness")
    if cur is None or not mx:
        return -1
    return round(cur * 100 / mx)


def _outputs():
    rc, out, _ = sh(["kscreen-doctor", "-j"], 5)
    try:
        return [o for o in json.loads(out).get("outputs", []) if o.get("enabled")]
    except Exception:
        return []


def read_display():
    if DEMO:
        return {"brightness": 70, "night_light": False, "scale": 100}
    outs = _outputs()
    scale = round((outs[0].get("scale", 1) if outs else 1) * 100)
    return {"brightness": _brightness(), "night_light": kread("kwinrc", "NightColor", "Active", "false") == "true",
            "scale": scale}


def read_accent():
    acc = load_accents()
    key = acc["default"] if DEMO else kread("kdeglobals", "General", "MagicAccent", acc["default"])
    return key if key in acc["accents"] else acc["default"]


def read_updates():
    if DEMO:
        return {"booted": "2026-11-21", "staged": "2026-11-28", "previous": "2026-11-14", "rolled_back": False}
    rc, out, _ = sh(["rpm-ostree", "status", "--json"], 15)
    res = {"booted": None, "staged": None, "previous": None, "rolled_back": False}
    try:
        deps = json.loads(out)["deployments"]
    except Exception:
        return res
    booted_i = next((i for i, d in enumerate(deps) if d.get("booted")), None)
    for i, d in enumerate(deps):
        v = d.get("version") or (d.get("checksum", "")[:8])
        if d.get("booted"):
            res["booted"] = v
        elif d.get("staged") or (booted_i is not None and i < booted_i):
            res["staged"] = v       # will be used on the next restart
        elif res["previous"] is None:
            res["previous"] = v
    res["rolled_back"] = os.path.exists("/var/lib/magic-os/skip-version")
    return res


def read_security():
    if DEMO:
        return {"encrypted": True}
    rc, out, _ = sh(["lsblk", "-J", "-o", "TYPE"])
    return {"encrypted": '"crypt"' in out}


def read_you():
    user = getpass.getuser()
    name = user
    try:
        import pwd
        name = (pwd.getpwnam(user).pw_gecos.split(",")[0] or user)
    except Exception:
        pass
    if DEMO:
        name, user = "Alex Morgan", "alex"
    return {"name": name, "username": user}


def read_time():
    if DEMO:
        return {"timezone": "Europe/London", "auto": True, "language": "English (United Kingdom)"}
    rc, out, _ = sh(["timedatectl", "show"])
    d = dict(l.split("=", 1) for l in out.splitlines() if "=" in l)
    lang = os.environ.get("LANG", "")
    names = {"en_GB": "English (United Kingdom)", "en_US": "English (United States)", "de_DE": "Deutsch",
             "fr_FR": "Français", "es_ES": "Español", "it_IT": "Italiano", "nl_NL": "Nederlands"}
    return {"timezone": d.get("Timezone", ""), "auto": d.get("NTP") == "yes",
            "language": names.get(lang.split(".")[0], lang.split(".")[0] or "English")}


def read_power():
    if DEMO:
        return {"battery": 82, "charging": False, "has_battery": True, "profile": "balanced", "profiles": ["power-saver", "balanced", "performance"]}
    bat = None
    base = "/sys/class/power_supply"
    try:
        for n in sorted(os.listdir(base)):
            if n.startswith("BAT"):
                bat = n
                break
    except OSError:
        pass
    res = {"has_battery": bool(bat), "battery": 0, "charging": False, "profile": "", "profiles": []}
    if bat:
        try:
            res["battery"] = int(open(f"{base}/{bat}/capacity").read())
            res["charging"] = open(f"{base}/{bat}/status").read().strip() in ("Charging", "Full")
        except OSError:
            pass
    rc, out, _ = sh(["powerprofilesctl", "get"])
    if rc == 0:
        res["profile"] = out.strip()
        rc, out, _ = sh(["powerprofilesctl", "list"])
        res["profiles"] = [p for p in ("power-saver", "balanced", "performance") if p in out]
    return res


def read_about():
    osr = {}
    try:
        for l in open("/etc/os-release"):
            k, _, v = l.strip().partition("=")
            osr[k] = v.strip('"')
    except OSError:
        pass
    cpu = ""
    try:
        cpu = next(l.split(":", 1)[1].strip() for l in open("/proc/cpuinfo") if l.startswith("model name"))
    except Exception:
        pass
    mem = 0
    try:
        mem = int(next(l.split()[1] for l in open("/proc/meminfo") if l.startswith("MemTotal"))) // (1024 * 1024)
    except Exception:
        pass
    du = shutil.disk_usage("/var/home" if os.path.isdir("/var/home") else "/")
    host = os.uname().nodename
    rc, out, _ = sh(["hostnamectl", "--pretty"])
    if DEMO:
        return {"version": "2026-11-21", "name": "Magic OS", "computer": "Alex's laptop", "cpu": "Intel Core i5-1235U",
                "memory_gb": 16, "disk_free_gb": 312, "disk_total_gb": 476}
    return {"version": osr.get("VERSION", ""), "name": osr.get("NAME", "Magic OS"), "computer": out.strip() or host,
            "cpu": cpu, "memory_gb": max(1, round(mem)), "disk_free_gb": du.free // 10 ** 9, "disk_total_gb": du.total // 10 ** 9}


READERS = {"network": read_network, "bluetooth": read_bluetooth, "sound": read_sound, "display": read_display,
           "updates": read_updates, "security": read_security, "you": read_you, "time": read_time,
           "power": read_power, "about": read_about}


class IconProvider(QQuickImageProvider):
    def __init__(self):
        super().__init__(QQuickImageProvider.ImageType.Pixmap)

    def requestPixmap(self, id, size, requested):
        w = requested.width() if requested.width() > 0 else 32
        h = requested.height() if requested.height() > 0 else 32
        name, _, tint = id.partition("?")
        own = os.path.join(HERE, "icons", name.replace("-symbolic", "") + ".svg")
        icon = QIcon(own) if os.path.exists(own) else QIcon.fromTheme(name)
        if icon.isNull() and name.endswith("-symbolic"):
            icon = QIcon.fromTheme(name[:-9])
        pm = icon.pixmap(w, h)
        if not pm.isNull() and tint:
            # Draw the icon flat in one colour (the Metro look).
            from PySide6.QtGui import QPainter, QColor
            p = QPainter(pm)
            p.setCompositionMode(QPainter.CompositionMode.CompositionMode_SourceIn)
            p.fillRect(pm.rect(), QColor(tint))
            p.end()
        if pm.isNull():
            from PySide6.QtGui import QPixmap
            from PySide6.QtCore import Qt
            pm = QPixmap(w, h)
            pm.fill(Qt.GlobalColor.transparent)
        if size is not None:
            size.setWidth(pm.width())
            size.setHeight(pm.height())
        return pm


class Backend(QObject):
    changed = Signal()
    accentChanged = Signal()
    message = Signal(str)
    busyChanged = Signal()

    def __init__(self):
        super().__init__()
        self._state = {}
        self._accents = load_accents()
        self._accent = read_accent()
        self._busy = False
        self.refresh()
        t = QTimer(self)
        t.timeout.connect(self.refresh)
        t.start(5000)
        self._timer = t

    # ---------------------------------------------------------------- state
    def _get_state(self):
        return self._state
    state = Property("QVariantMap", _get_state, notify=changed)

    def _get_accents(self):
        return self._accents
    accents = Property("QVariantMap", _get_accents, constant=True)

    def _get_accent(self):
        return self._accent
    accent = Property(str, _get_accent, notify=accentChanged)

    def _get_busy(self):
        return self._busy
    busy = Property(bool, _get_busy, notify=busyChanged)

    def _get_demo(self):
        return DEMO
    demo = Property(bool, _get_demo, constant=True)

    @Slot()
    def refresh(self):
        def work():
            st = {}
            for k, f in READERS.items():
                try:
                    st[k] = f()
                except Exception as e:
                    st[k] = {"error": str(e)}
            self._state = st
            self.changed.emit()
        threading.Thread(target=work, daemon=True).start()

    def _bg(self, fn, done_msg=None):
        def work():
            try:
                fn()
                if done_msg:
                    self.message.emit(done_msg)
            finally:
                self.refresh()
        threading.Thread(target=work, daemon=True).start()

    # ---------------------------------------------------------------- actions
    @Slot(bool)
    def setWifi(self, on):
        self._bg(lambda: sh(["nmcli", "radio", "wifi", "on" if on else "off"]))

    @Slot(bool)
    def setBluetooth(self, on):
        self._bg(lambda: sh(["bluetoothctl", "power", "on" if on else "off"]))

    @Slot(int)
    def setVolume(self, v):
        self._bg(lambda: sh(["wpctl", "set-volume", "-l", "1.0", "@DEFAULT_AUDIO_SINK@", f"{max(0, min(100, v)) / 100:.2f}"]))

    @Slot(bool)
    def setMuted(self, m):
        self._bg(lambda: sh(["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "1" if m else "0"]))

    @Slot(int)
    def setBrightness(self, pct):
        def f():
            path = "/org/kde/ScreenBrightness/display0"
            rc, out, _ = sh(["busctl", "--user", "call", "org.kde.ScreenBrightness", path, "org.freedesktop.DBus.Properties",
                             "Get", "ss", "org.kde.ScreenBrightness.Display", "MaxBrightness"])
            m = re.search(r"(\d+)\s*$", out.strip())
            if m:
                val = max(1, round(int(m.group(1)) * pct / 100))
                sh(["busctl", "--user", "call", "org.kde.ScreenBrightness", path, "org.kde.ScreenBrightness.Display",
                    "SetBrightness", "iu", str(val), "0"])
        self._bg(f)

    @Slot(bool)
    def setNightLight(self, on):
        def f():
            kwrite("kwinrc", ["NightColor"], "Active", "true" if on else "false")
            sh(["busctl", "--user", "call", "org.kde.KWin", "/KWin", "org.kde.KWin", "reconfigure"])
        self._bg(f)

    @Slot(int)
    def setScale(self, pct):
        def f():
            for o in _outputs():
                sh(["kscreen-doctor", f"output.{o['name']}.scale.{pct / 100:g}"], 15)
        self._bg(f, "Text and app size changed.")

    @Slot(str)
    def setAccent(self, key):
        acc = self._accents["accents"].get(key)
        if not acc:
            return
        self._accent = key
        self.accentChanged.emit()
        name = acc["name"]

        def f():
            kwrite("kdeglobals", ["General"], "MagicAccent", key)
            sh(["plasma-apply-colorscheme", f"Magic{name}"], 20)
            sh(["plasma-apply-wallpaperimage", f"/usr/share/wallpapers/Magic{name}"], 20)
            kwrite("kscreenlockerrc", ["Greeter", "Wallpaper", "org.kde.image", "General"], "Image",
                   f"file:///usr/share/wallpapers/Magic{name}/contents/images/3840x2160.jpg")
        if not DEMO:
            self._bg(f)

    @Slot(str)
    def setPowerProfile(self, p):
        self._bg(lambda: sh(["powerprofilesctl", "set", p]))

    @Slot(bool)
    def setAutoTime(self, on):
        self._bg(lambda: sh(["timedatectl", "set-ntp", "true" if on else "false"], 60))

    @Slot(str)
    def openKcm(self, kcm):
        spawn(["systemsettings", kcm])

    @Slot()
    def openAdvanced(self):
        spawn(["systemsettings"])

    @Slot(str)
    def openStore(self, mode):
        spawn(["plasma-discover"] + (["--mode", mode] if mode else []))

    @Slot()
    def restartNow(self):
        if not spawn(["busctl", "--user", "call", "org.kde.Shutdown", "/Shutdown", "org.kde.Shutdown", "logoutAndReboot"]):
            spawn(["systemctl", "reboot"])

    @Slot()
    def goBack(self):
        def f():
            self._busy = True
            self.busyChanged.emit()
            rc, out, err = sh(["pkexec", "/usr/bin/magic-rollback"], 600)
            self._busy = False
            self.busyChanged.emit()
            self.message.emit("Done. Restart to go back to the earlier version." if rc == 0
                              else "That didn't work, so nothing changed.")
        self._bg(f)

    @Slot(result=str)
    def aboutText(self):
        a = self._state.get("about", {})
        u = self._state.get("updates", {})
        return (f"{a.get('name', 'Magic OS')} {a.get('version', '')}\nComputer: {a.get('computer', '')}\n"
                f"Processor: {a.get('cpu', '')}\nMemory: {a.get('memory_gb', '')} GB\n"
                f"Storage: {a.get('disk_free_gb', '')} GB free of {a.get('disk_total_gb', '')} GB\n"
                f"Update waiting: {u.get('staged') or 'no'}")

    @Slot(str)
    def copy(self, text):
        QGuiApplication.clipboard().setText(text)
        self.message.emit("Copied.")


def main():
    check = "--check" in sys.argv
    if check:
        os.environ["QT_QPA_PLATFORM"] = "offscreen"
    os.environ.setdefault("QT_QUICK_CONTROLS_STYLE", "Basic")
    app = QGuiApplication(sys.argv)
    app.setApplicationName("Magic Settings")
    app.setDesktopFileName("org.magicos.Settings")
    app.setWindowIcon(QIcon.fromTheme("preferences-system"))
    if "Open Sans" in QFontDatabase.families():
        app.setFont(QFont("Open Sans", 10))
    paths = QIcon.themeSearchPaths()
    for p in ("/usr/share/icons", os.path.expanduser("~/.local/share/icons")):
        if p not in paths:
            paths.append(p)
    QIcon.setThemeSearchPaths(paths)
    if DEMO and QIcon.fromTheme("audio-volume-high").isNull():
        QIcon.setThemeName("Adwaita")   # previews on machines without Breeze
    engine = QQmlApplicationEngine()
    engine.addImageProvider("icon", IconProvider())
    backend = Backend()
    errors = []
    engine.warnings.connect(lambda ws: errors.extend(w.toString() for w in ws))
    engine.rootContext().setContextProperty("sys", backend)
    args = [a for a in sys.argv[1:] if not a.startswith("-")]
    engine.rootContext().setContextProperty("startPage", args[0] if args else "")
    engine.rootContext().setContextProperty("checkMode", check)
    engine.load(QUrl.fromLocalFile(os.path.join(HERE, "qml", "Main.qml")))
    if not engine.rootObjects():
        print("\n".join(errors) or "Main.qml failed to load", file=sys.stderr)
        sys.exit(1)
    if check:
        # Main.qml walks through every page, then quits. Report any QML problems.
        def finish():
            for e in errors:
                print(e, file=sys.stderr)
            app.exit(1 if errors else 0)
        engine.rootObjects()[0].checkDone.connect(finish)
        QTimer.singleShot(30000, lambda: (print("check timed out", file=sys.stderr), app.exit(1)))
    sys.exit(app.exec())


if __name__ == "__main__":
    main()
