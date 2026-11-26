#!/usr/bin/bash
set -ouex pipefail
# Rebuild the initramfs so it includes the TPM2 + LUKS modules from
# /usr/lib/dracut/dracut.conf.d/90-magic-luks.conf. We run Aurora's own script
# (Apache-2.0) so its reproducibility fixes reach us automatically.
bash /ctx/upstream/aurora/build_scripts/base/19-initramfs.sh
