#!/usr/bin/python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Magic OS install engine.

Prepares the disk (whole disk, next to Windows, or free space), sets up
full-disk encryption (TPM2 + Secure Boot auto-unlock, or a start-up
password, always with a recovery key), installs the Magic image with
`bootc install to-filesystem`, installs the chosen apps from Flathub, and
leaves a one-time setup file that Magic's first boot uses to create the
user, set the clock, language and keyboard, and apply the accent colour.

Used by the installer UI (server.py) and directly from the command line
for automated tests:   magic_install.py --config install.json
"""
import json
import os
import re
import secrets
import shutil
import subprocess
import sys
import threading
import time

LOG_PATH = "/var/log/magic-installer.log"
RUN_DIR = "/run/magic-installer"
TOP = "/mnt/magic-top"        # btrfs top level (holds the root subvolume + a temporary cache)
TARGET = "/mnt/magic-target"  # the new system's root, as bootc sees it
DEFAULT_IMAGE = "ghcr.io/alex-ha-192/magic-os:latest"
ESP_TYPE = "c12a7328-f81f-11d2-ba4b-00a0c93ec93b"
MSR_TYPE = "e3c9e316-0b5c-4db8-817d-f92df00215ae"
MIN_MAGIC_GB = 40
WINDOWS_HEADROOM_GB = 20      # always leave Windows at least this much free space
GIB = 1024 ** 3


class InstallError(Exception):
    """An error with a message meant for the person installing."""

    def __init__(self, message, details=""):
        super().__init__(message)
        self.message = message
        self.details = details


# --------------------------------------------------------------------------
# logging and commands
# --------------------------------------------------------------------------
_log_lock = threading.Lock()
_log_tail = []


def log(msg):
    line = time.strftime("%H:%M:%S ") + msg
    with _log_lock:
        _log_tail.append(line)
        del _log_tail[:-200]
        try:
            with open(LOG_PATH, "a") as f:
                f.write(line + "\n")
        except OSError:
            pass
    # Visible on a serial console during automated tests.
    for dev in ("/dev/ttyS0",):
        if os.path.exists(dev) and os.environ.get("MAGIC_SERIAL_LOG") == "1":
            try:
                with open(dev, "w") as f:
                    f.write("[magic-installer] " + msg + "\r\n")
            except OSError:
                pass
    print(line, file=sys.stderr, flush=True)


def log_tail(n=40):
    with _log_lock:
        return list(_log_tail[-n:])


def run(cmd, input=None, check=True, quiet=False, env=None):
    if not quiet:
        log("$ " + " ".join(cmd))
    p = subprocess.run(cmd, input=input, capture_output=True, text=True, env=env)
    out = (p.stdout or "") + (p.stderr or "")
    if out.strip() and not quiet:
        for l in out.strip().splitlines()[-25:]:
            log("  " + l)
    if check and p.returncode != 0:
        raise InstallError("A step of the installation failed.", f"{' '.join(cmd)} exited {p.returncode}:\n{out[-2000:]}")
    return p


def stream(cmd, on_line=None, env=None):
    """Run a long command, logging its output line by line."""
    log("$ " + " ".join(cmd))
    p = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, env=env, bufsize=1)
    tail = []
    for line in p.stdout:
        line = line.rstrip()
        if not line:
            continue
        tail.append(line)
        del tail[:-60]
        log("  " + line[:300])
        if on_line:
            on_line(line)
    rc = p.wait()
    if rc != 0:
        raise InstallError("A step of the installation failed.", f"{' '.join(cmd)} exited {rc}:\n" + "\n".join(tail[-30:]))


def settle():
    run(["udevadm", "settle", "--timeout=30"], check=False, quiet=True)


# --------------------------------------------------------------------------
# hardware detection (also used by the UI)
# --------------------------------------------------------------------------
def lsblk(dev=None):
    cmd = ["lsblk", "-J", "-b", "-o", "NAME,PATH,SIZE,TYPE,TRAN,RM,RO,MODEL,FSTYPE,LABEL,PARTLABEL,PARTTYPE,PARTN,MOUNTPOINTS,UUID"]
    if dev:
        cmd.append(dev)
    p = run(cmd, quiet=True)
    return json.loads(p.stdout).get("blockdevices", [])


def _boot_medium_disks():
    """Disks we must never offer: the one we booted from."""
    out = set()
    for d in lsblk():
        for part in [d] + d.get("children", []):
            label = part.get("label") or ""
            mps = [m for m in (part.get("mountpoints") or []) if m]
            if label.startswith("MagicOS") or any(m.startswith("/run/initramfs") for m in mps):
                out.add(d["path"])
    return out


def tpm_status():
    present = os.path.exists("/sys/class/tpm/tpm0")
    tpm2 = False
    if present:
        try:
            tpm2 = open("/sys/class/tpm/tpm0/tpm_version_major").read().strip() == "2"
        except OSError:
            p = run(["systemd-cryptenroll", "--tpm2-device=list"], check=False, quiet=True)
            tpm2 = p.returncode == 0 and "/dev/tpm" in p.stdout
    return tpm2


def secure_boot_enabled():
    try:
        for name in os.listdir("/sys/firmware/efi/efivars"):
            if name.startswith("SecureBoot-"):
                data = open(os.path.join("/sys/firmware/efi/efivars", name), "rb").read()
                return len(data) >= 5 and data[4] == 1
    except OSError:
        pass
    return False


def uefi_boot():
    return os.path.isdir("/sys/firmware/efi")


def _partitions(disk):
    devs = lsblk(disk)
    return devs[0].get("children", []) if devs else []


def _mount_ro_and_check(part, relpath):
    mp = os.path.join(RUN_DIR, "probe")
    os.makedirs(mp, exist_ok=True)
    if run(["mount", "-o", "ro", part, mp], check=False, quiet=True).returncode != 0:
        return False, 0
    try:
        found = os.path.exists(os.path.join(mp, relpath))
        st = os.statvfs(mp)
        return found, st.f_bavail * st.f_frsize
    finally:
        run(["umount", mp], check=False, quiet=True)


def free_regions(disk):
    """Unpartitioned gaps on a GPT disk, in bytes: [(start, end, size)]."""
    p = run(["parted", "-m", "-s", disk, "unit", "B", "print", "free"], check=False, quiet=True)
    out = []
    for line in p.stdout.splitlines():
        f = line.rstrip(";").split(":")
        if len(f) >= 5 and f[-1] == "free":
            s, e, z = (int(x.rstrip("B")) for x in f[1:4])
            out.append((s, e, z))
    return out


def partition_table(disk):
    p = run(["parted", "-m", "-s", disk, "print"], check=False, quiet=True)
    for line in p.stdout.splitlines():
        f = line.rstrip(";").split(":")
        if len(f) >= 6 and f[0] == disk:
            return f[5]
    return "unknown"


def ntfs_shrink_info(part):
    """How small can this NTFS partition go? Also catches hibernation/Fast Startup."""
    p = run(["ntfsresize", "--info", "--force", "--no-progress-bar", part], check=False, quiet=True)
    text = p.stdout + p.stderr
    info = {"min_bytes": None, "hibernated": False, "dirty": False}
    if re.search(r"hibernat|Windows is hibernated|fast restart", text, re.I):
        info["hibernated"] = True
    if re.search(r"unclean|inconsistent|chkdsk", text, re.I):
        info["dirty"] = True
    m = re.search(r"You might resize at (\d+) bytes", text)
    if m:
        info["min_bytes"] = int(m.group(1))
    return info


def describe_disk(d):
    disk = d["path"]
    parts = d.get("children", [])
    info = {
        "path": disk,
        "name": (d.get("model") or "").strip() or d["name"],
        "size": d["size"],
        "usb": d.get("tran") == "usb" or d.get("rm") in (True, "1", 1),
        "table": partition_table(disk),
        "windows": False, "bitlocker": False, "hibernated": False,
        "ntfs": None, "esp": None, "esp_free": 0,
        "largest_free": max([r[2] for r in free_regions(disk)] or [0]),
        "alongside_max_gb": 0, "alongside_default_gb": 0,
        "has_data": bool(parts),
    }
    ntfs = [p for p in parts if (p.get("fstype") or "") == "ntfs" and (p.get("parttype") or "").lower() != MSR_TYPE]
    info["bitlocker"] = any((p.get("fstype") or "").lower() == "bitlocker" for p in parts)
    for p in parts:
        if (p.get("parttype") or "").lower() == ESP_TYPE:
            has_ms, free = _mount_ro_and_check(p["path"], "EFI/Microsoft/Boot/bootmgfw.efi")
            info["esp"], info["esp_free"] = p["path"], free
            info["windows"] = info["windows"] or has_ms
    if ntfs:
        big = max(ntfs, key=lambda p: p["size"])
        info["ntfs"] = {"path": big["path"], "size": big["size"]}
        info["windows"] = True
        si = ntfs_shrink_info(big["path"])
        info["hibernated"] = si["hibernated"]
        if si["min_bytes"]:
            max_free = big["size"] - si["min_bytes"] - WINDOWS_HEADROOM_GB * GIB
            info["alongside_max_gb"] = max(0, int(max_free // GIB))
            info["alongside_default_gb"] = max(MIN_MAGIC_GB, min(info["alongside_max_gb"], int(info["alongside_max_gb"] * 0.5)))
    if info["bitlocker"]:
        info["windows"] = True
    return info


def list_disks():
    skip = _boot_medium_disks()
    out = []
    for d in lsblk():
        if d.get("type") != "disk" or d.get("ro") in (True, "1", 1):
            continue
        if d["path"] in skip or d["name"].startswith(("zram", "loop", "sr")):
            continue
        if d["size"] < 32 * GIB:
            continue
        out.append(describe_disk(d))
    return out


# --------------------------------------------------------------------------
# recovery key
# --------------------------------------------------------------------------
def new_recovery_key():
    """Six groups of six digits (about 119 bits). Shown to the user once."""
    return "-".join("%06d" % secrets.randbelow(10 ** 6) for _ in range(6))


# --------------------------------------------------------------------------
# installation
# --------------------------------------------------------------------------
class Progress:
    def __init__(self, cb=None):
        self.cb = cb
        self.stage = "starting"
        self.percent = 0

    def set(self, stage, percent):
        self.stage, self.percent = stage, int(percent)
        log(f"== {stage} ({self.percent}%)")
        if self.cb:
            self.cb(stage, self.percent)


def _part_by_label(disk, label):
    settle()
    for p in _partitions(disk):
        if p.get("partlabel") == label:
            return p["path"]
    raise InstallError("The new disk layout could not be found.", f"no partition labelled {label} on {disk}")


def _uuid(dev):
    return run(["blkid", "-s", "UUID", "-o", "value", dev], quiet=True).stdout.strip()


def _write_secret(name, value):
    os.makedirs(RUN_DIR, mode=0o700, exist_ok=True)
    path = os.path.join(RUN_DIR, name)
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, "w") as f:
        f.write(value)
    return path


def _cleanup_mounts():
    for mp in (TARGET + "/boot/efi", TARGET + "/boot", TARGET, TOP, "/var/lib/flatpak"):
        run(["umount", "-R", mp], check=False, quiet=True)
    if os.path.exists("/dev/mapper/magicroot"):
        run(["cryptsetup", "close", "magicroot"], check=False, quiet=True)


def check_network(image):
    p = run(["curl", "-sS", "-o", "/dev/null", "-w", "%{http_code}", "--max-time", "15", "https://ghcr.io/v2/"], check=False, quiet=True)
    if p.stdout.strip() not in ("200", "401"):
        raise InstallError("Magic needs the internet to install. Check your Wi-Fi or cable and try again.", p.stdout + p.stderr)


def prepare_disk(cfg, prog):
    disk, mode = cfg["disk"], cfg["mode"]
    info = describe_disk(lsblk(disk)[0])
    run(["swapoff", "-a"], check=False, quiet=True)
    if mode == "erase":
        prog.set("Preparing the disk", 6)
        run(["wipefs", "-a", "-f", disk])
        run(["sgdisk", "--zap-all", disk])
        run(["sgdisk", "-n", "1:0:+600M", "-t", "1:ef00", "-c", "1:EFI System", disk])
        run(["sgdisk", "-n", "2:0:+1G", "-t", "2:8300", "-c", "2:magic-boot", disk])
        run(["sgdisk", "-n", "3:0:0", "-t", "3:8309", "-c", "3:magic-root", disk])
        run(["partprobe", disk], check=False)
        settle()
        esp = None
        for p in _partitions(disk):
            if (p.get("parttype") or "").lower() == ESP_TYPE:
                esp = p["path"]
        run(["mkfs.fat", "-F", "32", "-n", "EFI", esp])
        return esp

    # Next to Windows, or in free space: keep everything that is there.
    if info["table"] != "gpt" or not info["esp"]:
        raise InstallError("Windows on this computer starts in an older way (legacy BIOS). Magic can only go next to Windows on computers that use UEFI.")
    if info["esp_free"] < 40 * 1024 * 1024:
        raise InstallError("The disk's start-up partition is full, so Magic can't be added next to Windows.")

    if mode == "alongside":
        if info["bitlocker"]:
            raise InstallError("Windows disk protection (BitLocker) is on. Turn it off in Windows first, then try again.")
        if info["hibernated"]:
            raise InstallError("Windows didn't fully shut down (Fast Startup). In Windows, hold Shift while you press Shut down, then try again.")
        size_gb = int(cfg.get("magic_size_gb") or 0)
        if size_gb < MIN_MAGIC_GB or size_gb > info["alongside_max_gb"]:
            raise InstallError(f"Pick a size between {MIN_MAGIC_GB} and {info['alongside_max_gb']} GB for Magic.")
        prog.set("Making room next to Windows", 6)
        part = info["ntfs"]["path"]
        new_bytes = info["ntfs"]["size"] - size_gb * GIB - 4 * 1024 * 1024
        new_bytes -= new_bytes % (1024 * 1024)
        run(["ntfsresize", "--force", "--no-action", "--size", str(new_bytes), part])
        run(["ntfsresize", "--force", "--no-progress-bar", "--size", str(new_bytes), part], input="y\n")
        # Shrink the partition itself (keeping its start) to just above the new filesystem size.
        sector = int(run(["blockdev", "--getss", disk], quiet=True).stdout.strip() or 512)
        partn = next(p["partn"] for p in _partitions(disk) if p["path"] == part)
        new_sectors = (new_bytes + 2 * 1024 * 1024) // sector
        run(["sfdisk", "--no-reread", "--no-tell-kernel", "-N", str(partn), disk], input=f",{new_sectors}\n")
        run(["partprobe", disk], check=False)
        settle()
    else:
        prog.set("Using the free space", 6)
        if info["largest_free"] < MIN_MAGIC_GB * GIB:
            raise InstallError(f"There isn't {MIN_MAGIC_GB} GB of free space on this disk.")

    # sgdisk's 0:0 means "the largest free block", which is the space we just made.
    run(["sgdisk", "-n", "0:0:+1G", "-t", "0:8300", "-c", "0:magic-boot", disk])
    run(["sgdisk", "-n", "0:0:0", "-t", "0:8309", "-c", "0:magic-root", disk])
    run(["partprobe", disk], check=False)
    settle()
    return info["esp"]


def setup_encryption(cfg, prog, root_part):
    enc = cfg.get("encryption", "tpm")
    if enc == "none":
        return root_part, None, []
    prog.set("Setting up encryption", 12)
    tmpkey = _write_secret("tmpkey", secrets.token_hex(32))
    run(["cryptsetup", "luksFormat", "--type", "luks2", "--batch-mode", "--label", "magic-root",
         "--key-file", tmpkey, root_part])
    # Recovery key: accepted with or without the dashes.
    rk = cfg["recovery_key"].strip()
    for variant in {rk, rk.replace("-", "")}:
        run(["cryptsetup", "luksAddKey", "--batch-mode", "--key-file", tmpkey, root_part, _write_secret("rk", variant)])
    if enc == "password":
        run(["cryptsetup", "luksAddKey", "--batch-mode", "--key-file", tmpkey, root_part,
             _write_secret("startup", cfg["startup_password"])])
    elif enc == "tpm":
        # PCR 7 = Secure Boot state and keys. If someone changes the start-up
        # software, the TPM won't release the key and the recovery key is needed.
        run(["systemd-cryptenroll", "--tpm2-device=auto", "--tpm2-pcrs=7", f"--unlock-key-file={tmpkey}", root_part])
    run(["cryptsetup", "open", "--key-file", tmpkey, "--allow-discards", root_part, "magicroot"])
    run(["cryptsetup", "luksRemoveKey", "--batch-mode", root_part, tmpkey])
    for f in ("tmpkey", "rk", "startup"):
        try:
            os.unlink(os.path.join(RUN_DIR, f))
        except FileNotFoundError:
            pass
    uuid = _uuid(root_part)
    opts = "discard" + (",tpm2-device=auto" if enc == "tpm" else "")
    kargs = [f"rd.luks.uuid={uuid}", f"rd.luks.options={uuid}={opts}"]
    return "/dev/mapper/magicroot", uuid, kargs


def make_filesystems(cfg, prog, rootdev, boot_part, esp):
    prog.set("Preparing the new system", 15)
    run(["mkfs.ext4", "-F", "-q", "-L", "magic-boot", boot_part])
    run(["mkfs.btrfs", "-f", "-q", "-L", "magic", rootdev])
    os.makedirs(TOP, exist_ok=True)
    run(["mount", "-o", "compress=zstd:1", rootdev, TOP])
    run(["btrfs", "subvolume", "create", TOP + "/root"])
    run(["btrfs", "subvolume", "create", TOP + "/install-cache"])
    os.makedirs(TARGET, exist_ok=True)
    run(["mount", "-o", "subvol=root,compress=zstd:1", rootdev, TARGET])
    os.makedirs(TARGET + "/boot", exist_ok=True)
    run(["mount", boot_part, TARGET + "/boot"])
    os.makedirs(TARGET + "/boot/efi", exist_ok=True)
    run(["mount", esp, TARGET + "/boot/efi"])


def _rx_bytes():
    total = 0
    try:
        for line in open("/proc/net/dev").read().splitlines()[2:]:
            name, data = line.split(":", 1)
            if name.strip() != "lo":
                total += int(data.split()[0])
    except OSError:
        pass
    return total


def _authfile(cfg):
    """Registry login, only used by automated tests while the image is private."""
    auth = cfg.get("registry_auth")
    if not auth:
        return []
    import base64
    tok = base64.b64encode(f"{auth['user']}:{auth['token']}".encode()).decode()
    path = _write_secret("auth.json", json.dumps({"auths": {"ghcr.io": {"auth": tok}}}))
    return ["--authfile", path]


def _image_download_size(image, authargs=()):
    try:
        raw = json.loads(run(["skopeo", "inspect", *authargs, "--raw", "docker://" + image], quiet=True).stdout)
        if "manifests" in raw:
            m = next(m for m in raw["manifests"] if m.get("platform", {}).get("architecture") == "amd64")
            repo = image.rsplit(":", 1)[0] if "@" not in image else image.split("@")[0]
            raw = json.loads(run(["skopeo", "inspect", *authargs, "--raw", f"docker://{repo}@{m['digest']}"], quiet=True).stdout)
        return sum(l.get("size", 0) for l in raw.get("layers", []))
    except Exception as e:  # progress is cosmetic
        log(f"could not size image: {e}")
        return 0


def download_and_install(cfg, prog, kargs):
    image = cfg.get("image", DEFAULT_IMAGE)
    target_ref = cfg.get("target_imgref", DEFAULT_IMAGE)
    storage = TOP + "/install-cache/storage"
    os.makedirs(storage, exist_ok=True)
    os.makedirs(TOP + "/install-cache/tmp", exist_ok=True)
    podman = ["podman", "--root", storage, "--runroot", RUN_DIR + "/podman"]

    prog.set("Downloading Magic", 18)
    authargs = _authfile(cfg)
    total = _image_download_size(image, authargs)
    start = _rx_bytes()
    done = threading.Event()

    def watch():
        while not done.wait(2):
            if total:
                frac = min(0.99, (_rx_bytes() - start) / total)
                prog.set("Downloading Magic", 18 + frac * 40)

    t = threading.Thread(target=watch, daemon=True)
    t.start()
    try:
        for attempt in range(3):
            try:
                stream(podman + ["pull", "--retry", "3", *authargs, image])
                break
            except InstallError:
                if attempt == 2:
                    raise InstallError("Magic couldn't be downloaded. Check the internet connection and try again.")
                log("download failed, retrying in 10 seconds")
                time.sleep(10)
    finally:
        done.set()

    prog.set("Installing Magic", 60)
    cmd = podman + ["run", "--rm", "--privileged", "--pid=host",
                    "--security-opt", "label=type:unconfined_t",
                    "-v", "/dev:/dev", "-v", f"{storage}:/var/lib/containers/storage",
                    "-v", f"{TARGET}:{TARGET}", "-v", f"{TOP}/install-cache/tmp:/var/tmp",
                    image, "bootc", "install", "to-filesystem",
                    "--target-imgref", target_ref, "--skip-fetch-check", "--skip-finalize"]
    for k in kargs + list(cfg.get("extra_kargs", [])):
        cmd += ["--karg", k]
    cmd.append(TARGET)
    stream(cmd)


def deployment_paths():
    base = TARGET + "/ostree/deploy/default"
    deps = [d for d in os.listdir(base + "/deploy") if d.endswith(".0") or re.match(r"^[0-9a-f]+\.\d+$", d)]
    if not deps:
        raise InstallError("The new system was not set up correctly.", "no ostree deployment found")
    return base + "/deploy/" + sorted(deps)[0], base + "/var"


def install_apps(cfg, prog, var_dir, deploy_dir=None):
    apps = [a for a in cfg.get("apps", []) if re.match(r"^[A-Za-z0-9_.-]+$", a)]
    if deploy_dir:
        # Skip apps the Magic image already ships as part of the system.
        apps = [a for a in apps if not os.path.exists(f"{deploy_dir}/usr/share/applications/{a}.desktop")]
    pending = os.path.join(var_dir, "lib/magic-os/apps.pending")
    os.makedirs(os.path.dirname(pending), exist_ok=True)
    with open(pending, "w") as f:
        f.write("\n".join(apps) + ("\n" if apps else ""))
    if not apps:
        return
    prog.set("Installing your apps", 76)
    fp = os.path.join(var_dir, "lib/flatpak")
    os.makedirs(fp, exist_ok=True)
    os.makedirs("/var/lib/flatpak", exist_ok=True)
    run(["mount", "--bind", fp, "/var/lib/flatpak"])
    try:
        run(["flatpak", "remote-add", "--system", "--if-not-exists", "flathub", "https://dl.flathub.org/repo/flathub.flatpakrepo"])
        n = len(apps)
        remaining = []
        for i, app in enumerate(apps):
            prog.set(f"Installing your apps ({i + 1} of {n})", 76 + 18 * i / n)
            try:
                stream(["flatpak", "install", "--system", "--noninteractive", "-y", "flathub", app])
            except InstallError:
                log(f"{app} failed now; Magic will retry after it starts")
                remaining.append(app)
        with open(pending, "w") as f:
            f.write("\n".join(remaining) + ("\n" if remaining else ""))
    finally:
        run(["umount", "/var/lib/flatpak"], check=False)


def write_first_boot(cfg, var_dir):
    setup = {k: cfg.get(k) for k in ("hostname", "pretty_hostname", "timezone", "locale", "keyboard", "clock", "accent")}
    setup["user"] = {k: cfg["user"].get(k) for k in ("full_name", "username", "password_hash")}
    path = os.path.join(var_dir, "lib/magic-os/setup.json")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, "w") as f:
        json.dump(setup, f)


def setup_boot_menu(cfg, info, esp):
    """Windows entry in the boot menu, and Magic first in the firmware's boot order."""
    disk = cfg["disk"]
    if cfg["mode"] in ("alongside", "free") and info.get("windows"):
        esp_uuid = _uuid(esp)
        custom = f"""# Added by the Magic installer
set timeout=5
set timeout_style=menu
menuentry 'Windows' --class windows {{
  insmod part_gpt
  insmod fat
  insmod chain
  search --no-floppy --fs-uuid --set=root {esp_uuid}
  chainloader /EFI/Microsoft/Boot/bootmgfw.efi
}}
"""
        os.makedirs(TARGET + "/boot/grub2", exist_ok=True)
        with open(TARGET + "/boot/grub2/custom.cfg", "w") as f:
            f.write(custom)
    if not uefi_boot():
        return
    shim = None
    for vendor in ("fedora",):
        cand = f"{TARGET}/boot/efi/EFI/{vendor}/shimx64.efi"
        if os.path.exists(cand):
            shim = f"\\EFI\\{vendor}\\shimx64.efi"
    if not shim:
        return
    p = run(["efibootmgr"], check=False, quiet=True)
    for line in p.stdout.splitlines():
        m = re.match(r"Boot([0-9A-Fa-f]{4})\*?\s+(Magic OS|Fedora)\b", line)
        if m:
            run(["efibootmgr", "-b", m.group(1), "-B"], check=False, quiet=True)
    partn = next(p["partn"] for p in _partitions(disk) if p["path"] == esp)
    run(["efibootmgr", "--create", "--disk", disk, "--part", str(partn), "--label", "Magic OS", "--loader", shim], check=False)


def install(cfg, progress_cb=None):
    prog = Progress(progress_cb)
    os.makedirs(RUN_DIR, mode=0o700, exist_ok=True)
    _cleanup_mounts()
    try:
        prog.set("Checking", 2)
        if cfg.get("mode") not in ("erase", "alongside", "free"):
            raise InstallError("Choose how to install Magic.")
        if not os.path.exists(cfg.get("disk", "")):
            raise InstallError("The chosen disk isn't there any more.")
        if cfg.get("encryption", "tpm") == "tpm":
            if not tpm_status():
                raise InstallError("This computer has no TPM 2 security chip, so choose a start-up password instead.")
            if cfg.get("require_secure_boot", True) and not secure_boot_enabled():
                raise InstallError("Secure Boot is off, so automatic unlocking isn't safe. Choose a start-up password instead.")
        check_network(cfg.get("image", DEFAULT_IMAGE))
        info = describe_disk(lsblk(cfg["disk"])[0])

        esp = prepare_disk(cfg, prog)
        boot_part = _part_by_label(cfg["disk"], "magic-boot")
        root_part = _part_by_label(cfg["disk"], "magic-root")
        rootdev, _, kargs = setup_encryption(cfg, prog, root_part)
        make_filesystems(cfg, prog, rootdev, boot_part, esp)
        download_and_install(cfg, prog, kargs)

        deploy_dir, var_dir = deployment_paths()
        install_apps(cfg, prog, var_dir, deploy_dir)
        prog.set("Finishing", 96)
        write_first_boot(cfg, var_dir)
        setup_boot_menu(cfg, info, esp)
        shutil.rmtree(TOP + "/install-cache", ignore_errors=True)
        run(["btrfs", "subvolume", "delete", TOP + "/install-cache"], check=False)
        run(["fstrim", "-v", TARGET], check=False)
        run(["sync"])
        _cleanup_mounts()
        prog.set("Done", 100)
        log("MAGIC-INSTALL-OK")
        return True
    except InstallError:
        _cleanup_mounts()
        raise
    except Exception as e:
        _cleanup_mounts()
        raise InstallError("Something unexpected went wrong.", repr(e))


def main():
    import argparse
    ap = argparse.ArgumentParser()
    ap.add_argument("--config", required=True)
    ap.add_argument("--list-disks", action="store_true")
    a = ap.parse_args()
    cfg = json.load(open(a.config))
    try:
        install(cfg)
    except InstallError as e:
        log("MAGIC-INSTALL-FAILED: " + e.message)
        log(e.details)
        sys.exit(1)


if __name__ == "__main__":
    main()
