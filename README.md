# Magic OS

A calm, stable KDE Plasma desktop for people who are used to Windows.

- **Looks familiar:** classic taskbar, Start button on the left, Windows 10 style Start menu, an original dark charcoal and orange look ("Ember") with a customisable accent colour.
- **Updates itself:** new versions download quietly in the background. Magic never restarts on its own. Any restart or shutdown installs the waiting update.
- **Easy to undo:** if something is wrong, go back to the previous version. Files and settings are untouched.
- **Encrypted by default:** full-disk encryption, unlocked by the TPM with Secure Boot, with a recovery key. (Installer work, see below.)
- **Versions are dates:** a release is named for the day it was built, `YYYY-MM-DD`.

Magic is an image-based system (bootc / rpm-ostree) built from [Universal Blue](https://universal-blue.org)'s plain Kinoite image, using ideas and files from [Aurora](https://github.com/ublue-os/aurora). Everything is built and signed by GitHub Actions.

## Status

Early. The image definition, update policy and Plasma defaults are written but **not yet built or booted**. See [docs/DESIGN.md](docs/DESIGN.md) for decisions and the list of things still to verify.

## How it is built

| Path | What it does |
|------|--------------|
| `Containerfile` | Starts from `ghcr.io/ublue-os/kinoite-main:44`, runs `build_files/build.sh` |
| `build_files/steps/` | Numbered steps: copy files, packages, identity, services, initramfs, cleanup |
| `system_files/` | Copied onto `/`: update policy, presets, Plasma look-and-feel, colour scheme, app list |
| `upstream/aurora` | Git submodule: pinned Aurora, source of a few reused files and scripts |
| `.github/workflows/build.yml` | Checks, build, smoke test; releases **Saturdays 12:00 UK time**, signed with cosign |
| `.github/workflows/build-disk.yml` | Builds a test disk image and an installer ISO |
| `Justfile` | Local builds: `just build`, `just build-iso` |

The release version is set at build time from the date (`MAGIC_VERSION`).

## Releases (fully automatic)

Nobody has to do anything weekly.

- **Schedule:** a check runs every 3 hours. It releases if this week's release (Saturday 12:00 UK time) has not gone out yet. If GitHub is late, or skips a run, the next check does it. Once the week's release exists, the checks do nothing.
- **Only if it works:** file checks, the image build, `bootc container lint` and a smoke test must all pass. If one fails, nothing is published, everyone stays on the previous version, and the next 3-hourly check tries again.
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

## Try it

```
git submodule update --init
just build         # build the image locally with podman
just build-iso     # installer ISO (uses disk_config/iso.toml)
```

To switch an existing Fedora atomic desktop to Magic once an image is published:

```
sudo bootc switch ghcr.io/alex-ha-192/magic-os:latest
```

## Licence

Magic's own files are GPL-3.0-or-later (`LICENSE-GPL-3.0`). Files adapted from Universal Blue's image-template and Aurora are Apache-2.0 (`LICENSE-APACHE-2.0`); see `NOTICE`.
