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

## Releases

A release goes out automatically every **Saturday at 12:00 UK time**, but only if every check passes: file checks, the image build, `bootc container lint`, and a smoke test that starts the built image. If anything fails, nothing is published and everyone stays on the previous version.

- Pushes and pull requests build and test but never publish.
- To release early: Actions, "Build container image", Run workflow, tick "publish".
- GitHub can start scheduled runs late. The gate only publishes when the run starts during the 12:00 hour in London, so a run delayed past 13:00 skips that week. Run it by hand if that happens.

Aurora is a git submodule. Dependabot opens a bump PR on Fridays; merge it (once its checks are green) and it ships on Saturday. Clone with `git clone --recurse-submodules`, or run `git submodule update --init`.

## One-time setup for signing

```
cosign generate-key-pair
```

1. Keep `cosign.key` private. It is git-ignored. Never commit it.
2. Commit `cosign.pub`.
3. In GitHub: Settings, Secrets and variables, Actions, new secret `SIGNING_SECRET`, paste the contents of `cosign.key`.

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
