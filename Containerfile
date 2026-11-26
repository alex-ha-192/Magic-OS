# Magic OS: a calm, stable KDE desktop for people coming from Windows.
# SPDX-License-Identifier: GPL-3.0-or-later

# Base: Universal Blue's plain Fedora Kinoite (KDE Plasma) image.
# It carries ublue's signed kernel, multimedia codecs, flatpak setup and
# signing policy, which is the part of Aurora we want without Aurora's extras.
# Stability: track Fedora's "gts" release (44), not the newest one.
# Bump FEDORA_VERSION deliberately, never by accident.
# (Declared before the first FROM so it can be used in the FROM line.)
ARG FEDORA_VERSION=44

# Build scripts and system files are mounted, not copied into the final image.
FROM scratch AS ctx
COPY build_files /build_files
COPY system_files /system_files
# Pinned upstream Aurora (git submodule). We reuse a few of its files and scripts.
COPY upstream/aurora /upstream/aurora

FROM ghcr.io/ublue-os/kinoite-main:${FEDORA_VERSION}

# Magic's version is the release date, YYYY-MM-DD. CI sets it.
ARG MAGIC_VERSION=dev
ARG FEDORA_VERSION

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    MAGIC_VERSION="${MAGIC_VERSION}" FEDORA_VERSION="${FEDORA_VERSION}" \
    /ctx/build_files/build.sh

RUN bootc container lint
