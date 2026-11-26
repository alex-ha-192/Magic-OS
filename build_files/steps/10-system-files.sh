#!/usr/bin/bash
set -ouex pipefail
# Everything under system_files/ lands on / (usr/, etc/).
cp -avf /ctx/system_files/. /
# Make the Plasma defaults executable where they need to be.
chmod 0755 /usr/bin/magic-rollback /usr/bin/magic-update-status
