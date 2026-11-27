#!/usr/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Magic's desktop: Settings app, App Store, boot screen, names and icons.
set -ouex pipefail

# ---- Magic Settings needs Qt for Python (system Qt, so it follows the theme)
dnf5 install -y python3-pyside6
python3 -c "import PySide6.QtQuick, PySide6.QtQml"

# ---- KDE's System Settings stays, renamed "Advanced Settings"
f=/usr/share/applications/systemsettings.desktop
if [[ -f "$f" ]]; then
    sed -i -E '/^(Name|GenericName|X-KDE-Keywords|Comment)(\[[^]]+\])?=/d' "$f"
    sed -i '/^\[Desktop Entry\]/a Name=Advanced Settings\nGenericName=Advanced Settings\nComment=Every KDE setting, for when Settings does not have it' "$f"
fi

# ---- Discover is the App Store: apps only. Magic updates itself, so no
# system updates in Discover and no update nagging in the tray.
for p in plasma-discover-rpm-ostree plasma-discover-packagekit; do
    rpm -q "$p" >/dev/null 2>&1 && dnf5 remove -y "$p" || true
done
f=/usr/share/applications/org.kde.discover.desktop
if [[ -f "$f" ]]; then
    sed -i -E '/^(Name|GenericName|Comment)(\[[^]]+\])?=/d' "$f"
    sed -i '/^\[Desktop Entry\]/a Name=App Store\nGenericName=App Store\nComment=Get apps for Magic' "$f"
fi
mkdir -p /etc/xdg/autostart
printf '[Desktop Entry]\nType=Application\nName=Discover notifier\nHidden=true\n' > /etc/xdg/autostart/org.kde.discover.notifier.desktop

# ---- No KDE Welcome Center after the first sign-in: the installer did that.
printf '[Desktop Entry]\nType=Application\nName=Welcome Center\nHidden=true\n' > /etc/xdg/autostart/org.kde.plasma-welcome.desktop
printf '[General]\nShouldShow=false\nLastSeenVersion=99.0.0\n' > /etc/xdg/plasma-welcomerc

# ---- Start-up screen (Plymouth). The initramfs step after this picks it up.
dnf5 install -y plymouth-plugin-script plymouth-plugin-label
plymouth-set-default-theme magic

# ---- Logo for "About this system"
sed -i '/^LOGO=/d' /usr/lib/os-release
echo 'LOGO=magic-start' >> /usr/lib/os-release
gtk-update-icon-cache -f /usr/share/icons/hicolor 2>/dev/null || true

# ---- Sign-in screen: Magic wallpaper (magic-firstboot swaps in the chosen accent)
/usr/libexec/magic-os/signin-wallpaper /var/lib/magic-os/signin.jpg

# ---- Check Magic Settings loads every page without errors.
QT_QPA_PLATFORM=offscreen MAGIC_SETTINGS_DEMO=1 timeout 120 /usr/bin/magic-settings --check
