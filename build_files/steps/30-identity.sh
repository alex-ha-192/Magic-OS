#!/usr/bin/bash
set -ouex pipefail
# Adapted from Aurora's 18-image-info.sh (Apache-2.0).

NAME="Magic OS"
VERSION_STR="${MAGIC_VERSION:-dev}"

sed -i "s|^NAME=.*|NAME=\"${NAME}\"|" /usr/lib/os-release
sed -i "s|^PRETTY_NAME=.*|PRETTY_NAME=\"${NAME} ${VERSION_STR}\"|" /usr/lib/os-release
sed -i "s|^VERSION=.*|VERSION=\"${VERSION_STR}\"|" /usr/lib/os-release
sed -i "s|^VARIANT_ID=.*|VARIANT_ID=magic-os|" /usr/lib/os-release
sed -i "s|^ID=fedora|ID=magic\nID_LIKE=\"fedora\"|" /usr/lib/os-release
sed -i "s|^DEFAULT_HOSTNAME=.*|DEFAULT_HOSTNAME=\"magic\"|" /usr/lib/os-release
sed -i "s|^HOME_URL=.*|HOME_URL=\"https://github.com/alex-ha-192/Magic-OS\"|" /usr/lib/os-release
sed -i "s|^BUG_REPORT_URL=.*|BUG_REPORT_URL=\"https://github.com/alex-ha-192/Magic-OS/issues\"|" /usr/lib/os-release
sed -i "/^SUPPORT_URL=/d; /^DOCUMENTATION_URL=/d" /usr/lib/os-release
sed -i "/^REDHAT_/d" /usr/lib/os-release
sed -i "s|^OSTREE_VERSION=.*|OSTREE_VERSION='${VERSION_STR}'|" /usr/lib/os-release || true

mkdir -p /usr/share/magic
cat > /usr/share/magic/image-info.json <<EOF
{
  "image-name": "magic-os",
  "version": "${VERSION_STR}",
  "fedora-version": "${FEDORA_VERSION:-unknown}"
}
EOF
