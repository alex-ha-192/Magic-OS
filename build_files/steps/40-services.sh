#!/usr/bin/bash
set -ouex pipefail
# Presets in /usr/lib/systemd/system-preset/89-magic.preset decide what is on.
systemctl preset-all
systemctl --global preset-all
