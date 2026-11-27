#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# End-to-end test: boot the installer ISO in a VM with a TPM, install Magic
# unattended (encrypted, TPM unlock), then boot the installed system and wait
# for first-boot setup to finish. Screenshots and serial logs go to OUTDIR.
#   e2e-vm.sh ISO IMAGE_REF OUTDIR [tpm|password]
# Then it signs in and photographs the desktop, Start menu and Magic's apps.
set -euo pipefail
ISO=$(realpath "$1"); IMAGE=$2; OUT=$(realpath -m "$3"); UNLOCK=${4:-tpm}
STARTUP_PW="magic-start"
HERE=$(cd "$(dirname "$0")" && pwd)
mkdir -p "$OUT"
WORK=$(mktemp -d)
OVMF_CODE=/usr/share/OVMF/OVMF_CODE_4M.fd
cp /usr/share/OVMF/OVMF_VARS_4M.fd "$WORK/vars.fd"
qemu-img create -q -f qcow2 "$WORK/disk.qcow2" 64G

cat > "$WORK/autoinstall.json" <<JSON
{
  "image": "$IMAGE",
  "target_imgref": "ghcr.io/alex-ha-192/magic-os:latest",
  "disk": "auto", "mode": "erase",
  "encryption": "$UNLOCK", "startup_password": "$STARTUP_PW", "require_secure_boot": false, "test_mode": true,
  "full_name": "Test User", "computer_name": "CI test machine", "password": "magic-test",
  "locale": "en_GB.UTF-8", "kb_layout": "gb", "kb_variant": "", "clock": "24",
  "timezone": "Europe/London", "accent": "teal",
  "software": "own", "browser": "firefox", "office": "none", "email": "none", "extras": [],
  "extra_kargs": ["console=ttyS0,115200", "console=tty0"]
}
JSON
# While the image package is private, let the test VM log in (short-lived CI token).
if [[ -n "${REGISTRY_TOKEN:-}" ]]; then
    python3 - "$WORK/autoinstall.json" <<PY
import json, os, sys
p = sys.argv[1]; d = json.load(open(p))
d["registry_auth"] = {"user": os.environ.get("REGISTRY_USER", "ci"), "token": os.environ["REGISTRY_TOKEN"]}
json.dump(d, open(p, "w"))
PY
fi
mkfs.fat -C -n MAGICAUTO "$WORK/auto.img" 2048 >/dev/null
mcopy -i "$WORK/auto.img" "$WORK/autoinstall.json" ::

start_tpm() {
    mkdir -p "$WORK/tpm"
    swtpm socket --tpmstate dir="$WORK/tpm" --ctrl type=unixio,path="$WORK/tpm/sock" \
        --tpm2 --daemon --log file="$OUT/swtpm.log"
    sleep 1
}
QEMU=(qemu-system-x86_64 -enable-kvm -machine q35 -cpu host -smp 4 -m 6144
      -drive if=pflash,format=raw,readonly=on,file="$OVMF_CODE"
      -drive if=pflash,format=raw,file="$WORK/vars.fd"
      -drive file="$WORK/disk.qcow2",if=virtio,format=qcow2
      -netdev user,id=n0 -device virtio-net-pci,netdev=n0
      -chardev socket,id=chrtpm,path="$WORK/tpm/sock"
      -tpmdev emulator,id=tpm0,chardev=chrtpm -device tpm-tis,tpmdev=tpm0
      -vga virtio -display none)
shot() { python3 "$HERE/qmp.py" "$1" screendump "$OUT/$2.png" >/dev/null 2>&1 || true; }
# Print a small JPEG of a screenshot into the log, base64, between markers.
logshot() {
    [[ -f "$OUT/$1.png" ]] || return 0
    python3 - "$OUT/$1.png" "$1" <<'PY' || true
import base64, io, sys
try:
    from PIL import Image
    im = Image.open(sys.argv[1]).convert("RGB"); im.thumbnail((720, 450))
    b = io.BytesIO(); im.save(b, "JPEG", quality=55); data = b.getvalue()
except Exception:
    data = open(sys.argv[1], "rb").read()
enc = base64.b64encode(data).decode()
print("SCREENSHOT-BEGIN " + sys.argv[2])
for i in range(0, len(enc), 800):
    print("B64 " + enc[i:i + 800])
print("SCREENSHOT-END")
PY
}

echo "::group::Phase 1: install from the ISO"
start_tpm
"${QEMU[@]}" -drive file="$WORK/auto.img",if=virtio,format=raw -cdrom "$ISO" \
    -serial file:"$OUT/install-serial.log" -qmp unix:"$WORK/qmp1",server,nowait &
QPID=$!
for t in 60 150 300 600 900 1200 1800 2400 3000 3600 4200; do
    while (( SECONDS < t )); do
        kill -0 $QPID 2>/dev/null || break 2
        sleep 5
    done
    shot "$WORK/qmp1" "install-$(printf %04d $t)s"
done
if kill -0 $QPID 2>/dev/null; then
    echo "Install did not finish in time"; kill $QPID || true; tail -50 "$OUT/install-serial.log" || true; exit 1
fi
wait $QPID || true
echo "::endgroup::"
logshot install-0150s; logshot install-0600s
grep -a "magic-installer" "$OUT/install-serial.log" | tail -60 || true
if ! grep -aq "MAGIC-UI-OK" "$OUT/install-serial.log"; then
    echo "::error::The installer's screen did not start"; exit 1
fi
if ! grep -aq "MAGIC-INSTALL-OK" "$OUT/install-serial.log"; then
    echo "::error::Install failed"; exit 1
fi

echo "::group::Phase 2: first boot, sign in, look around"
SECONDS=0
start_tpm
"${QEMU[@]}" -serial file:"$OUT/boot-serial.log" -qmp unix:"$WORK/qmp2",server,nowait &
QPID=$!
Q() { python3 "$HERE/qmp.py" "$WORK/qmp2" "$@" >/dev/null 2>&1 || true; }
serial() { grep -aq "$1" "$OUT/boot-serial.log" 2>/dev/null; }
ok=0; typed=0; booted_shot=0
while (( SECONDS < 900 )); do
    if serial "MAGIC-FIRSTBOOT-OK"; then ok=1; break; fi
    if (( ! booted_shot && SECONDS > 12 )); then shot "$WORK/qmp2" "boot-splash"; booted_shot=1; fi
    # Start-up password: the prompt is on the screen (Plymouth), so go by time.
    if [[ "$UNLOCK" == "password" ]] && { (( typed == 0 && SECONDS > 30 )) || (( typed == 1 && SECONDS > 120 )); }; then
        shot "$WORK/qmp2" "boot-password-prompt"
        Q type "$STARTUP_PW"; sleep 1; shot "$WORK/qmp2" "boot-password-typed"; Q key ret; typed=$((typed + 1))
    fi
    if [[ "$UNLOCK" == "tpm" ]] && serial "Please enter passphrase\|Enter passphrase"; then
        sleep 20; shot "$WORK/qmp2" "boot-passphrase-prompt"; echo "::error::TPM did not unlock the disk"; break
    fi
    kill -0 $QPID 2>/dev/null || break
    sleep 3
done
signed_in=0
if (( ok )); then
    sleep 75   # sign-in screen
    shot "$WORK/qmp2" "signin-screen"
    Q key shift; sleep 3
    Q type "magic-test"; sleep 1; Q key ret
    # The installed system prints a report once the desktop is up.
    for _ in $(seq 160); do serial "MAGIC-REPORT-END" && { signed_in=1; break; }; sleep 5; done
    shot "$WORK/qmp2" "desktop"
    Q key meta_l; sleep 5; shot "$WORK/qmp2" "start-menu"; Q key esc; sleep 2
    open_app() {   # $1 command, $2 screenshot name, $3 seconds to wait
        Q key alt+f2; sleep 3; Q type "$1"; sleep 3; Q key ret; sleep "$3"
        shot "$WORK/qmp2" "$2"; Q key alt+f4; sleep 3
    }
    open_app "magic-settings" "app-settings" 15
    open_app "magic-settings updates" "app-settings-updates" 15
    open_app "dolphin" "app-files" 12
    open_app "plasma-discover" "app-store" 30
    open_app "systemsettings" "app-advanced-settings" 15
    Q key meta_l; sleep 4; Q type "sett"; sleep 3; shot "$WORK/qmp2" "start-search"; Q key esc
fi
echo "::endgroup::"
echo "----- installed system report -----"
sed 's/\x1b\[[0-9;]*[a-zA-Z]//g' "$OUT/boot-serial.log" | tr -d '\r' | sed -n '/MAGIC-REPORT-BEGIN/,/MAGIC-REPORT-END/p'
echo "-----"
for n in boot-splash boot-password-prompt boot-password-typed signin-screen desktop start-menu start-search app-settings app-settings-updates app-files app-store app-advanced-settings; do logshot "$n"; done
if (( ! ok )); then
    echo "----- last lines of the installed system's serial console -----"
    sed 's/\x1b\[[0-9;]*[a-zA-Z]//g' "$OUT/boot-serial.log" | tr -d '\r' | grep -av '^\s*$' | tail -150 || true
    echo "-----"
    shot "$WORK/qmp2" "boot-failed"; logshot boot-failed; logshot boot-passphrase-prompt
fi
python3 "$HERE/qmp.py" "$WORK/qmp2" quit >/dev/null 2>&1 || kill $QPID 2>/dev/null || true
if (( ! ok )); then
    echo "::error::First boot did not finish"; exit 1
fi
# The installer made the account, so KDE's own setup wizard must not appear.
if grep -aE "(Starting|Started|Finished) plasma-setup\.service" "$OUT/boot-serial.log"; then
    echo "::error::KDE's first-run wizard ran instead of the sign-in screen"; exit 1
fi
if (( ! signed_in )); then
    echo "::error::Could not sign in to the desktop (no report from the installed system)"; exit 1
fi
report=$(sed -n '/MAGIC-REPORT-BEGIN/,/MAGIC-REPORT-END/p' "$OUT/boot-serial.log" | tr -d '\r')
if ! grep -q "ColorScheme = Magic" <<<"$report"; then
    echo "::error::Magic's colour scheme is not in effect on the desktop"; exit 1
fi
if ! grep -q "LookAndFeelPackage = org.magicos.desktop" <<<"$report"; then
    echo "::error::Magic's desktop layout package is not in effect"; exit 1
fi
echo "End-to-end test passed ($UNLOCK): installed, unlocked, set up, signed in, Magic theme in effect."
