#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# End-to-end test: boot the installer ISO in a VM with a TPM, install Magic
# unattended (encrypted, TPM unlock), then boot the installed system and wait
# for first-boot setup to finish. Screenshots and serial logs go to OUTDIR.
#   e2e-vm.sh ISO IMAGE_REF OUTDIR
set -euo pipefail
ISO=$(realpath "$1"); IMAGE=$2; OUT=$(realpath -m "$3")
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
  "encryption": "tpm", "require_secure_boot": false,
  "full_name": "Test User", "computer_name": "CI test machine", "password": "magic-test",
  "locale": "en_GB.UTF-8", "kb_layout": "gb", "kb_variant": "", "clock": "24",
  "timezone": "Europe/London", "accent": "teal",
  "software": "own", "browser": "firefox", "office": "none", "email": "none", "extras": [],
  "extra_kargs": ["console=tty0", "console=ttyS0,115200", "systemd.show_status=1"]
}
JSON
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
grep -a "magic-installer" "$OUT/install-serial.log" | tail -40 || true
if ! grep -aq "MAGIC-INSTALL-OK" "$OUT/install-serial.log"; then
    echo "::error::Install failed"; exit 1
fi

echo "::group::Phase 2: first boot of the installed system"
SECONDS=0
start_tpm
"${QEMU[@]}" -serial file:"$OUT/boot-serial.log" -qmp unix:"$WORK/qmp2",server,nowait &
QPID=$!
ok=0
while (( SECONDS < 900 )); do
    if grep -aq "MAGIC-FIRSTBOOT-OK" "$OUT/boot-serial.log" 2>/dev/null; then ok=1; break; fi
    if grep -aqi "enter passphrase\|recovery key" "$OUT/boot-serial.log" 2>/dev/null; then
        sleep 20; shot "$WORK/qmp2" "boot-passphrase-prompt"; echo "::error::TPM did not unlock the disk"; break
    fi
    kill -0 $QPID 2>/dev/null || break
    sleep 5
done
if (( ok )); then
    sleep 90   # let the sign-in screen come up
    shot "$WORK/qmp2" "boot-signin-screen"
    grep -a -E "sddm|display-manager|Reached target.*[Gg]raphical" "$OUT/boot-serial.log" | tail -5 || true
fi
(( ok )) || shot "$WORK/qmp2" "boot-failed"
python3 "$HERE/qmp.py" "$WORK/qmp2" quit >/dev/null 2>&1 || kill $QPID 2>/dev/null || true
echo "::endgroup::"
if (( ! ok )); then
    tail -80 "$OUT/boot-serial.log" || true
    echo "::error::First boot did not finish"; exit 1
fi
echo "End-to-end test passed: installed, TPM unlocked, first-boot setup done."
