# Magic OS design notes

## Decisions

| Topic | Decision | Why |
|-------|----------|-----|
| Base | `ghcr.io/ublue-os/kinoite-main:44` | Plain KDE from ublue: signed kernel, codecs, flatpak setup. Aurora's extras left out. 44 is ublue's "gts" tag, one behind the newest. |
| Updates | `rpm-ostreed-automatic` with `AutomaticUpdatePolicy=stage`, daily | Downloads and stages silently. No automatic reboot. |
| Restart gating | Comes with ostree: a staged update is applied on any reboot or shutdown | "Update and restart" and "update and shut down" are the only paths, as designed. The tray indicator reads `magic-update-status`. |
| Rollback | `magic-rollback` (`rpm-ostree rollback`) | The only update control shown to the user. |
| Build cadence | Release every Saturday 12:00 UK time if all checks pass; manual early release available | Calm, predictable, and nothing broken ships. |
| Upstream Aurora | Git submodule (`upstream/aurora`), bumped weekly by Dependabot | Upstream fixes arrive as reviewed bumps instead of manual copies. |
| Version | Build date, `YYYY-MM-DD` | Requested. Two builds on one day share a version. |
| Apps | Flathub only; Vivaldi default, Firefox alternative | Flatpaks update on their own timer, away from the OS image. |
| Look | `org.magicos.ember` look-and-feel, `MagicEmber` colours, Open Sans | Matches the mockups. |
| Filesystem | btrfs | Cheap snapshots for "see earlier versions" later. |

## Not verified yet (nothing has been built or booted)

1. The image builds in CI. Base tag `kinoite-main:44` and package names are from reading ublue's repos; GHCR was not reachable from the authoring sandbox.
2. The Plasma layout script and look-and-feel apply on first login (panel height, Start button icon, task manager launchers).
3. Vivaldi from Flathub (`com.vivaldi.Vivaldi`): exists, plays Netflix/Prime (Widevine), works with Google Docs, can start with a simple layout.
4. `flatpak-preinstall` installs the default apps on a fresh install without network trouble.
5. TPM2 + Secure Boot auto-unlock on a custom image: Secure Boot signing and key enrolment for our own kernel/shim chain, and re-binding after firmware updates.
6. Installer. The template's Anaconda ISO is only a stopgap. We need a friendly front end for: language, name, time zone, sign-in password, encryption + recovery key, next-to-Windows or whole disk, and software choice.
7. Windows disk in Files: read-only by default, safe with Fast Startup/hibernation, BitLocker detection.
8. `bootc-image-builder` was merged into `image-builder` (June 2026); the workflows still use the old action.
9. Whether a failed first CI run is only the `ARG` bug (fixed) or hides more.
10. Pinning the base image by digest (Renovate) so upstream changes never arrive unreviewed.

## Next

- First CI build; fix what breaks.
- Boot it in a VM and check the desktop.
- First-run "make it yours" (accent colour) and the tray update indicator.
- App Store front end, Files/Settings tweaks, installer.
