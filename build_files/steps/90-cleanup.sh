#!/usr/bin/bash
set -ouex pipefail
dnf5 clean all || true
rm -rf /var/cache/* /var/log/* /var/tmp/* 2>/dev/null || true
