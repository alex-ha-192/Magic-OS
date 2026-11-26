#!/usr/bin/bash
set -ouex pipefail
# Rebuild the initramfs so it includes the TPM2 + LUKS modules we ask for in
# /usr/lib/dracut/dracut.conf.d/90-magic-luks.conf. Adapted from Aurora's
# 19-initramfs.sh (Apache-2.0), including the os-release dance that keeps the
# initramfs reproducible.
KERNEL_VERSION=$(rpm -q --queryformat="%{evr}.%{arch}" kernel-core)
INITRAMFS="/usr/lib/modules/${KERNEL_VERSION}/initramfs.img"

TMP_OS_RELEASE=$(mktemp --tmpdir 'os-release-XXXXXXXXXX')
OS_RELEASE=/usr/lib/os-release
cp "${OS_RELEASE}" "${TMP_OS_RELEASE}"
sed -Ei -e '/^((OSTREE_)?(IMAGE_)?VERSION|PRETTY_NAME|BUILD_ID)=/d' "${OS_RELEASE}"

DRACUT_NO_XATTR=1 /usr/bin/dracut --kver "${KERNEL_VERSION}" --reproducible --verbose --force "${INITRAMFS}"

cp "${TMP_OS_RELEASE}" "${OS_RELEASE}"
rm "${TMP_OS_RELEASE}"
chmod 0600 "${INITRAMFS}"
sha256sum "${INITRAMFS}"
