# Building and testing the ARM RetroDECK prototype on Arch Linux ARM

This guide records the working local workflow used on an AArch64 Chromebook
running Arch Linux ARM. The prototype currently packages RetroArch and three
ARM64 Libretro cores in a Flatpak based on KDE Platform 6.11.

> **Scope:** RetroArch has been launched inside the Flatpak, Gambatte loaded a
> Game Boy Color ROM, and both video and audio worked. This is not yet a full
> RetroDECK launch: ARM `framework` and ES-DE components are still outstanding.

## 1. Check the machine and GPU

Confirm that the host is AArch64 and that Mesa sees the Chromebook GPU:

```bash
uname -m
ls -l /dev/dri
eglinfo -B
vulkaninfo --summary
```

On the test Chromebook, `uname -m` reports `aarch64`; EGL reports Mali-G72 MC3
through Panfrost with desktop OpenGL 3.1 and OpenGL ES 3.1. Vulkan reports no
driver. The ARM RetroArch config therefore selects OpenGL (`video_driver =
"gl"`), not Vulkan.

## 2. Install host build tools

Install Flatpak Builder and the utilities required by the component builder:

```bash
sudo pacman -S --needed flatpak flatpak-builder jq git curl wget 7zip unzip tar gettext mesa-utils vulkan-tools
```

`gettext` provides `envsubst`; Arch's `7zip` package provides `7z`. Confirm the
main commands are available. `mesa-utils` and `vulkan-tools` provide the GPU
inspection tools used above:

```bash
flatpak-builder --version
jq --version
7z | head -n 2
envsubst --version | head -n 1
```

## 3. Configure Flathub and check the AArch64 KDE runtime

Add Flathub if it is not already configured:

```bash
sudo flatpak remote-add --system --if-not-exists flathub \
  https://flathub.org/repo/flathub.flatpakrepo
```

Query the exact AArch64 refs. Including the full ref avoids the “multiple
branches available” error:

```bash
flatpak remote-info --system flathub org.kde.Platform/aarch64/6.11
flatpak remote-info --system flathub org.kde.Sdk/aarch64/6.11
```

The successful Flatpak build used `--install-deps-from=flathub`, which installs
the required runtime and SDK when they are missing.

## 4. Use the two ARM prototype worktrees

The checked-out directories are siblings under `/home/duet/dev/retrodeck`:

- `components-arm-prototype` — ARM RetroArch component recipe and build script.
- `RetroDECK-arm-prototype` — ARM Flatpak manifest and this guide.
- `RetroDECK` — standard RetroDECK checkout; the component build uses this
  checkout for its disk-backed temporary work directory.

Keep the two prototype worktrees on their `arm-prototype` branches. The ARM
manifest expects the generated component archive at:

```text
../components-arm-prototype/linux-arm64/retroarch/artifacts/retroarch.tar.gz
```

## 5. Build the ARM RetroArch component

Run the component builder from its repository:

```bash
cd /home/duet/dev/retrodeck/components-arm-prototype
./linux-arm64/retroarch/build-component.sh
```

The wrapper places Alchemist's work directory at:

```text
/home/duet/dev/retrodeck/RetroDECK/.tmp-arm-retroarch-build
```

This location is on the main disk. On the Chromebook, `/tmp` is a 1.9 GiB
tmpfs; the first build attempt ran out of space while checking out and copying
the full Libretro database there. The wrapper now uses the disk-backed path.
The generated archive is about 424 MiB and contains RetroArch, assets, database
data, and the Gambatte, Snes9x, and Genesis Plus GX cores. The artifacts
directory is Git-ignored.

## 6. Build the AArch64 Flatpak

The ARM manifest derives its version from the metainfo file because the normal
`retrodeck_builder.sh` step that creates the Git-ignored `version` file is not
run when invoking Flatpak Builder directly.

```bash
cd /home/duet/dev/retrodeck/RetroDECK-arm-prototype
flatpak-builder --force-clean --arch=aarch64 --install-deps-from=flathub \
  build-arm64 net.retrodeck.retrodeck.arm64.yml
```

The build completed successfully on the Chromebook. Its output directory is
`build-arm64/`; the installed RetroArch binary is at:

```text
build-arm64/files/retrodeck/components/retroarch/bin/retroarch
```

The build took several minutes. A successful build does not mean RetroDECK's
launcher flow is ready: only the RetroArch component is currently provided for
ARM.

## 7. Export and install without rebuilding

The first Flatpak Builder command creates the finalized app directory, but
does not install it. Export that existing directory to a local OSTree repo,
make a bundle, and install the bundle:

```bash
cd /home/duet/dev/retrodeck/RetroDECK-arm-prototype

flatpak build-export --arch=aarch64 \
  .flatpak-builder/repo-arm64 build-arm64 stable

flatpak build-bundle --arch=aarch64 \
  --runtime-repo=https://dl.flathub.org/repo/flathub.flatpakrepo \
  .flatpak-builder/repo-arm64 /tmp/retrodeck-arm64.flatpak \
  net.retrodeck.retrodeck stable

flatpak install --user /tmp/retrodeck-arm64.flatpak
```

If Flatpak asks to add the Flathub remote recorded in the bundle, accept the
prompt; then confirm installation. Exporting the already-finalized app with
`flatpak-builder --finish-only` is not the right step and failed with “already
finalized.” Use `flatpak build-export` as above. The export and bundle steps do
not rebuild the app.

## 8. Run RetroArch and test a Game Boy Color ROM

Check that the installed RetroArch binary starts in the Flatpak runtime:

```bash
flatpak run --user \
  --command=/app/retrodeck/components/retroarch/bin/retroarch \
  net.retrodeck.retrodeck --version
```

The tested output reported RetroArch 1.22.2, built for 64-bit ARM. Start its UI
by omitting `--version`:

```bash
flatpak run --user \
  --command=/app/retrodeck/components/retroarch/bin/retroarch \
  net.retrodeck.retrodeck
```

Because this directly launches RetroArch, it bypasses RetroDECK's component
preparation script. Set the core directory manually in **Settings → Directory
→ Core** to:

```text
/app/retrodeck/components/retroarch/rd_extras/cores
```

Then choose **Load Core → Gambatte**. To load a ROM, choose **Load Content** and
browse to its host location, for example `/home/duet/Downloads`. This manifest
grants host filesystem access. The tested `.gbc` ROM loaded and had both video
and audio.

Bundled cores and supported systems in this prototype:

- Gambatte: Game Boy and Game Boy Color.
- Snes9x: Super Nintendo / Super Famicom.
- Genesis Plus GX: Genesis / Mega Drive, Master System, Game Gear, and Sega CD.

## 9. Known limitations and next work

- ARM `framework` and ES-DE component artifacts have not been built or
  integrated. The RetroDECK → ES-DE → RetroArch launch flow is not tested.
- ES-DE compatibility with this Chromebook's Panfrost OpenGL 3.1 stack still
  needs to be verified.
- The RetroArch artifact is built from a dated AArch64 nightly executable and
  current AArch64 core nightlies; the component recipe should be pinned and
  updated deliberately for reproducible builds.
- Do not place x86_64 component archives in the ARM manifest's `components/`
  input.
- For a fresh clean build, use the command in section 6. For an already-built
  finalized app directory, export it as in section 7 instead of rebuilding.
