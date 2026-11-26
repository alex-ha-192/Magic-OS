#!/usr/bin/bash
set -ouex pipefail
# Files we take straight from upstream Aurora (submodule at upstream/aurora).
# A new Aurora commit arrives as a reviewed submodule bump, not a manual copy.
A=/ctx/upstream/aurora/system_files/shared

# Never use Fedora's own flatpak remotes (Flathub only).
install -Dm0644 "$A/usr/lib/systemd/system/flatpak-nuke-fedora.service" \
    /usr/lib/systemd/system/flatpak-nuke-fedora.service
# Quiet boot with the Plymouth splash.
install -Dm0644 "$A/usr/lib/bootc/kargs.d/10-aurora-plymouth.toml" \
    /usr/lib/bootc/kargs.d/10-aurora-plymouth.toml
