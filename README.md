# Magic OS

A calm, stable KDE Plasma desktop for people who are used to Windows.

- **Looks familiar:** classic taskbar, Start button on the left, a Windows 10 style Start menu in a Zune/Metro look (thin lowercase headings, square tiles), dark charcoal with a lime accent you can change (six colours).
- **Simple settings:** Magic Settings covers what most people change (Wi-Fi, Bluetooth, display, sound, colours, updates and going back, apps, account, time, power, printers). KDE's full settings stay available as Advanced Settings. Apps come from the App Store (Discover, Flathub only).
- **Updates itself:** new versions download quietly in the background. Magic never restarts on its own. Any restart or shutdown installs the waiting update.
- **Easy to undo:** if something is wrong, go back to the previous version. Files and settings are untouched.
- **Encrypted by default:** full-disk encryption, unlocked by the TPM with Secure Boot, with a recovery key.
- **Friendly installer:** a small ISO that connects to Wi-Fi, asks a few plain questions (in the Magic look), and installs the newest Magic next to Windows or on the whole disk.
- **Versions are dates:** a release is named for the day it was built, `YYYY-MM-DD`.

Magic is an image-based system (bootc / rpm-ostree) built from [Universal Blue](https://universal-blue.org)'s plain Kinoite image, using ideas and files from [Aurora](https://github.com/ublue-os/aurora). Everything is built and signed by GitHub Actions.

## Install

Download **[MagicOS.iso](https://github.com/alex-ha-192/Magic-OS/releases/latest/download/MagicOS.iso)**, write it to a USB stick (for example with Fedora Media Writer or balenaEtcher), and start the computer from it. The installer needs an internet connection (Wi-Fi or cable): it downloads the newest Magic while it installs.

It asks, in order: get online, where you are, about you, how to install (next to Windows, empty space, or the whole disk), protect your files (encryption, unlocked by the TPM or a start-up password, plus a recovery key), your software, and a final check before anything changes.

## Status

Early. Every release is installed and booted in a VM by CI before it goes out (see Releases). Real hardware, Wi-Fi chips and dual-boot with a real Windows install have not been tested yet. See [docs/DESIGN.md](docs/DESIGN.md).

## How it is built

| Path | What it does |
|------|--------------|
| `Containerfile` | Starts from `ghcr.io/ublue-os/kinoite-main:44`, runs `build_files/build.sh` |
| `build_files/steps/` | Numbered steps: copy files, packages, identity, services, initramfs, cleanup |
| `system_files/` | Copied onto `/`: update service, presets, look-and-feel `org.magicos.desktop`, colour schemes and wallpapers (from `tools/gen-theme.py`), Magic Settings (`usr/share/magic-settings`), Start menu (`usr/share/plasma/plasmoids/org.magicos.start`), boot screen |
| `tools/gen-theme.py` | Regenerates the six accent colour schemes, wallpapers and system `kdeglobals` |
| `upstream/aurora` | Git submodule: pinned Aurora, source of a few reused files and scripts |
| `.github/workflows/build.yml` | Checks, build, smoke test; releases **Saturdays 12:00 UK time**, signed with cosign |
| `installer/` | The installer: a small Fedora live system (`Containerfile`) that boots into the Magic installer UI (`files/usr/share/magic-installer/ui`) and engine (`files/usr/libexec/magic-installer`) |
| `.github/workflows/installer.yml` | Builds `MagicOS.iso` with Titanoboa and tests it end to end in a VM (`tests/e2e-vm.sh`) |
| `.github/workflows/build-disk.yml` | By hand only: a ready-made VM disk (login `magic` / `magic`) |
| `Justfile` | Local builds: `just build`, `just build-iso` |

The release version is set at build time from the date (`MAGIC_VERSION`).

## Releases (fully automatic)

Nobody has to do anything weekly.

- **Schedule:** a check runs every 3 hours. It releases if this week's release (Saturday 12:00 UK time) has not gone out yet. If GitHub is late, or skips a run, the next check does it. Once the week's release exists, the checks do nothing.
- **Only if it works:** file checks, the image build, `bootc container lint`, a smoke test, and a full VM test must all pass. The VM test boots the new installer ISO, installs the new version (encrypted, TPM unlock), boots it and waits for first-boot setup. Only then does `latest` move to the new version and the release appear with `MagicOS.iso` attached. If anything fails, nothing is published, everyone stays on the previous version, and the next 3-hourly check tries again.
- **Versions:** the release date, `2026-11-28`. A second release the same day is `2026-11-28-2`, then `-3`. Each release is a git tag and a GitHub Release.
- **Snapshots kept:** the newest release image and the three before it stay in the registry. Older ones are deleted automatically. `magic-rollback --list` shows what is kept.
- **Dependabot:** it bumps the Aurora submodule and workflow actions on Fridays. Each PR is built and tested, and merged automatically if it passes.
- **Pushes and pull requests** build and test but never publish. To release early: Actions, "Build container image", Run workflow, tick "publish".
- **Clone** with `git clone --recurse-submodules` (or `git submodule update --init`).

## Signing (optional until you add a key)

Releases work without a key; they are just unsigned. Add one and every release after it is signed automatically:

```
cosign generate-key-pair          # leave the password empty
```

Commit `cosign.pub`, and save the contents of `cosign.key` as the repository secret `SIGNING_SECRET` (Settings, Secrets and variables, Actions). Keep `cosign.key` private. It is git-ignored.

## Try it in a VM

Use the ISO above with UEFI firmware, 4 GB RAM or more, a 64 GB disk and (for automatic unlocking) a virtual TPM 2.0. Or switch an existing Fedora atomic desktop:

```
sudo bootc switch ghcr.io/alex-ha-192/magic-os:latest
```

## Licence

Magic's own files are GPL-3.0-or-later (`LICENSE-GPL-3.0`). Files adapted from Universal Blue's image-template and Aurora are Apache-2.0 (`LICENSE-APACHE-2.0`); see `NOTICE`.
