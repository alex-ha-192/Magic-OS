#!/usr/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Image build entry point. Runs inside the Containerfile; keep it boring.
set -ouex pipefail

CTX=/ctx/build_files
for step in 10-system-files 15-upstream 20-packages 30-identity 40-services 50-initramfs 90-cleanup; do
    echo "::group:: === ${step} ==="
    bash "${CTX}/steps/${step}.sh"
    echo "::endgroup::"
done
