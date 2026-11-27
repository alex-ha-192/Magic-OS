#!/usr/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Builds the installer environment. Live-ISO parts follow Titanoboa's examples.
set -exo pipefail

PKGS=(
    # the installer itself
    python3 curl jq openssl skopeo podman flatpak
    cryptsetup tpm2-tss tpm2-tools btrfs-progs e2fsprogs dosfstools gdisk parted util-linux
    ntfsprogs ntfs-3g efibootmgr mokutil
    # screen: a kiosk (cage) showing the installer in Firefox
    cage firefox mesa-dri-drivers mesa-libEGL mesa-libgbm
    open-sans-fonts google-noto-sans-fonts google-droid-sans-fonts google-noto-sans-mono-fonts
    xkeyboard-config kbd tzdata glibc-langpack-en
    # network and Wi-Fi
    NetworkManager NetworkManager-wifi wpa_supplicant
    linux-firmware iwlwifi-mvm-firmware iwlwifi-dvm-firmware iwlegacy-firmware atheros-firmware
    brcmfmac-firmware realtek-firmware mt7xxx-firmware libertas-firmware
    amd-gpu-firmware intel-gpu-firmware
    # start-up screen
    plymouth plymouth-scripts plymouth-plugin-script plymouth-plugin-label
    # live boot
    dracut-live grub2-efi-x64-cdboot
)
dnf -y install --skip-unavailable "${PKGS[@]}"

# Never update or change itself; this system only lives in memory.
systemctl disable bootc-fetch-apply-updates.timer 2>/dev/null || true
systemctl mask bootc-fetch-apply-updates.timer bootc-fetch-apply-updates.service 2>/dev/null || true
systemctl disable sshd.service 2>/dev/null || true

# The kiosk user comes from /usr/lib/sysusers.d/magic-installer.conf; create it
# now too so file ownership below resolves.
systemd-sysusers

systemctl enable NetworkManager.service magic-installer-backend.service magic-installer-ui.service var-tmp.mount
systemctl set-default graphical.target
systemctl mask getty@tty1.service

# Start-up screen: stays up until the installer's screen takes over
# (magic-installer-ui.service quits it with --retain-splash).
plymouth-set-default-theme magic
systemctl mask plymouth-quit.service plymouth-quit-wait.service

# Live-boot initramfs (dmsquash-live). The splash uses the kernel's simple
# display driver, so leave the big GPU drivers and firmware out (they load later).
# /root is a symlink in bootc images; dracut needs its target to exist.
mkdir -p "$(realpath /root)"
kernel=$(ls /usr/lib/modules | head -1)
DRACUT_NO_XATTR=1 dracut -v --force --zstd --reproducible --no-hostonly \
    --add "dmsquash-live dmsquash-live-autooverlay plymouth" \
    --omit-drivers "amdgpu radeon nouveau i915 xe nvidia" \
    "/usr/lib/modules/${kernel}/initramfs.img" "${kernel}"
ls -la "/usr/lib/modules/${kernel}/initramfs.img"

# Titanoboa expects the EFI binaries in /boot/efi.
mkdir -p /boot/efi
cp -av /usr/lib/efi/*/*/EFI /boot/efi/
cp -v /boot/efi/EFI/fedora/grubx64.efi /boot/efi/EFI/BOOT/fbx64.efi || true

rm -f /etc/localtime
systemd-firstboot --timezone UTC || true

mkdir -p /usr/lib/bootc-image-builder
cp /tmp/build/iso.yaml /usr/lib/bootc-image-builder/iso.yaml

chmod 0755 /usr/libexec/magic-installer/*.py
dnf clean all
