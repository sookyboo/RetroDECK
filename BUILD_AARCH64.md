# Build RetroDECK 0.11 for AArch64

This guide checks out the ARM 0.11 branches of RetroDECK and Components, builds
the AArch64 component archives, builds the Flatpak, and installs it from the
local OSTree repository. Building on a native AArch64 Linux host is required.

## Requirements

Confirm that the machine and Flatpak target AArch64:

```bash
uname -m
flatpak --default-arch
```

Both should report `aarch64` (some `uname` implementations report `arm64`).

Install the build tools for your distribution.

Arch Linux / Arch Linux ARM:

```bash
sudo pacman -Syu --needed \
  flatpak flatpak-builder gettext jq 7zip unzip curl git python
```

Fedora:

```bash
sudo dnf install -y \
  flatpak flatpak-builder gettext jq 7zip unzip curl git python3
```

Debian:

```bash
sudo apt-get update
sudo apt-get install -y \
  flatpak flatpak-builder gettext-base jq p7zip-full unzip curl git python3
```

Add Flathub for the current user and install build dependencies when prompted:

```bash
flatpak remote-add --user --if-not-exists flathub \
  https://flathub.org/repo/flathub.flatpakrepo
```

Allow at least 35 GB of free disk space for component scratch files,
Flatpak build directories, and the OSTree repository. Use
`ARM_BUILD_JOBS=1` on low-memory devices; the default below is one job.

## Check out the branches

The two worktrees must be siblings because the ARM manifest uses relative paths
from RetroDECK to the Components worktree. These commands use the `sookyboo`
forks, where the `arm-0.11.0` branches are maintained:

```bash
mkdir -p "$HOME/dev/retrodeck"
cd "$HOME/dev/retrodeck"

git clone --branch arm-0.11.0 --single-branch \
  https://github.com/sookyboo/components.git components-arm-0.11.0
git clone --branch arm-0.11.0 --single-branch \
  https://github.com/sookyboo/RetroDECK.git RetroDECK-arm-0.11.0
```

Expected layout:

```text
retrodeck/
├── components-arm-0.11.0/
└── RetroDECK-arm-0.11.0/
```

## Build the components

Set the build-job limit and scratch directory from the workspace root. `TMPDIR`
redirects temporary component builds away from a small `/tmp` filesystem.

```bash
cd "$HOME/dev/retrodeck"
export ARM_BUILD_JOBS="${ARM_BUILD_JOBS:-1}"
export BUILD_TMPDIR="${BUILD_TMPDIR:-$PWD/.build-tmp}"
mkdir -p "$BUILD_TMPDIR"
export TMPDIR="$BUILD_TMPDIR"
export ESDE_BUILD_JOBS="$ARM_BUILD_JOBS"

cd components-arm-0.11.0
for component in \
  retroarch framework pico-8 ppsspp ruffle scummvm \
  azahar dolphin melonds mame xemu portmaster \
  duckstation vita3k rpcs3 cemu steam-rom-manager es-de; do
  printf '\nBuilding %s for AArch64\n' "$component"
  bash "linux-arm64/$component/build-component.sh" || exit 1
done
```

ES-DE is last because it prepares the frontend integration and system
definitions for the other components. Each successful build writes an archive
and checksum under that component's `artifacts/` directory.

## Build the AArch64 Flatpak

From the Components worktree, change to the sibling RetroDECK worktree and build
from the ARM manifest. `--default-branch=arm-0.11.0` sets the app ref branch in
the local OSTree repository. `--force-clean` is useful for a fresh build; omit
it on a retry to let Flatpak Builder reuse completed modules.

```bash
cd ../RetroDECK-arm-0.11.0

flatpak-builder \
  --user \
  --force-clean \
  --disable-rofiles-fuse \
  --jobs="$ARM_BUILD_JOBS" \
  --arch=aarch64 \
  --default-branch=arm-0.11.0 \
  --install-deps-from=flathub \
  --repo=repo-arm64 \
  build-arm64 \
  net.retrodeck.retrodeck.arm64.yml
```

This produces the app ref in `repo-arm64`. Building does not launch RetroDECK.

## Install from the local OSTree repository

Installing from the local repo avoids importing the single-file bundle, which
can use substantial memory on low-memory devices:

```bash
flatpak remote-add --user --no-gpg-verify --if-not-exists \
  retrodeck-arm-0.11.0-local "$PWD/repo-arm64"

flatpak install --user --arch=aarch64 \
  retrodeck-arm-0.11.0-local \
  net.retrodeck.retrodeck//arm-0.11.0
```

Launch it with:

```bash
flatpak run --user net.retrodeck.retrodeck//arm-0.11.0
```

## Optional: create and install a single-file bundle

Skip this section when installing directly from the local OSTree repository.
The bundle is portable, but packaging and importing it can take longer and use
more memory and disk space.

Create the bundle with the same branch name:

```bash
mkdir -p output
flatpak build-bundle \
  --arch=aarch64 \
  repo-arm64 \
  output/RetroDECK-0.11.0-aarch64.flatpak \
  net.retrodeck.retrodeck \
  arm-0.11.0
```

Install the bundle with:

```bash
flatpak install --user --bundle \
  output/RetroDECK-0.11.0-aarch64.flatpak
```
