#!/usr/bin/bash
set -ouex pipefail

# Keep this list SHORT. Every package here is something that can break an
# update for someone who never asked for it.
ADD=(
    open-sans-fonts        # the Magic look uses Open Sans
    ntfs-3g
    jq
    exfatprogs
    tpm2-tools             # TPM2 unlock tooling for full-disk encryption
)

# Things we do not want on a Windows-switcher's desktop.
# Only remove packages that are known to be safe to drop; ignore absent ones.
REMOVE=(
    toolbox
)

dnf5 install -y --skip-unavailable "${ADD[@]}"
for p in "${REMOVE[@]}"; do
    rpm -q "$p" >/dev/null 2>&1 && dnf5 remove -y "$p" || true
done
