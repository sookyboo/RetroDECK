# Building and testing the ARM RetroDECK prototype on Arch Linux ARM

This guide records the working local workflow used on an AArch64 Chromebook
running Arch Linux ARM. The ARM RetroDECK prototype packages RetroArch and
three ARM64 Libretro cores in KDE Platform 6.11. A separate ES-DE test app
builds the frontend with GLES and validates launching a bundled core.

> **Scope:** RetroArch and ES-DE have each been tested inside Flatpak apps, and
> ES-DE successfully launched a Game Boy Color ROM through bundled RetroArch
> and Gambatte. This does not yet validate the integrated RetroDECK framework,
> first-run setup, theme, or configuration flow; ARM `framework` and integrated
> ES-DE component artifacts remain outstanding.

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

## 6. Build the ARM component archives

The ARM Flatpak manifest expects RetroArch, framework, and ES-DE archives in
the sibling components worktree. Generate them before building the full app:

```bash
cd /home/duet/dev/retrodeck/components-arm-prototype
./linux-arm64/framework/build-component.sh
./linux-arm64/retroarch/build-component.sh
./linux-arm64/es-de/build-component.sh
```

The ES-DE builder uses the successful GLES smoke-test manifest and requires
the RetroArch archive first. It builds ES-DE with `FLATPAK_BUILD=off`, stages
the RetroDECK theme and component config, and creates
`linux-arm64/es-de/artifacts/es-de.tar.gz`. It does not install the standalone
test app. The framework and ES-DE archive outputs, like the RetroArch archive,
are Git-ignored. The ES-DE builder uses a disk-backed appdir at
`RetroDECK-arm-prototype/.build-esde-arm64-component`.

The ES-DE build fetches the RetroDECK theme from its `main` branch, matching
the existing component recipe. Pin the theme revision for a reproducible
release build.

## 7. Build the AArch64 Flatpak

The ARM manifest derives its version from the metainfo file because the normal
`retrodeck_builder.sh` step that creates the Git-ignored `version` file is not
run when invoking Flatpak Builder directly.

```bash
cd /home/duet/dev/retrodeck/RetroDECK-arm-prototype
flatpak-builder --force-clean --arch=aarch64 --install-deps-from=flathub \
  build-arm64 net.retrodeck.retrodeck.arm64.yml
```

The full manifest has now built successfully with the RetroArch, framework,
and ES-DE archives generated in section 6. Its output directory is
`build-arm64/`; the components are under `build-arm64/files/retrodeck/components/`.
The RetroArch binary is at:

```text
build-arm64/files/retrodeck/components/retroarch/bin/retroarch
```

The build took several minutes. The integrated `flatpak-builder --run` path
collides with the manifest's Discord `xdg-run/app` permission on this host.
Use the local `arm-prototype` branch below to launch the built app.

## 8. Export and install without rebuilding

The first Flatpak Builder command creates the app directory, but does not
install it. Export that existing directory to a local OSTree repo, then install
its `arm-prototype` branch:

```bash
cd /home/duet/dev/retrodeck/RetroDECK-arm-prototype

flatpak build-export --arch=aarch64 \
  .flatpak-builder/repo-arm64 build-arm64 arm-prototype
flatpak remote-add --user --no-gpg-verify --if-not-exists \
  retrodeck-arm-prototype .flatpak-builder/repo-arm64
flatpak install --user retrodeck-arm-prototype \
  net.retrodeck.retrodeck//arm-prototype
flatpak run --user net.retrodeck.retrodeck//arm-prototype
```

If `flatpak build-export` reports that the app directory is not finalized, run
`flatpak build-finish --no-exports build-arm64` and retry the export. If it
reports that the directory is already finalized, skip `build-finish`.

For later rebuilds, rerun the build command in section 7, export to the same
branch, then update it with
`flatpak update --user net.retrodeck.retrodeck//arm-prototype`. Exporting and
installing the branch do not rebuild the app.

## 9. Run RetroArch and test a Game Boy Color ROM

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

## 10. Known limitations and next work

- Framework and ES-DE component archives were built, and the full ARM manifest
  completed with all three components staged. The integrated `arm-prototype`
  branch has launched successfully: the first-run Zenity wizard completed,
  ES-DE's scraper ran, and a Game Boy game launched. The separate ES-DE
  smoke-test app also rendered through Panfrost and launched a GBC game using
  bundled ARM RetroArch and Gambatte.
- A Bluetooth Xbox controller works in the integrated app. Pressing LS and RS
  together opens the RetroArch menu, where the save option is accessible.
- Game Boy game saves were confirmed working.
- The integrated ES-DE launch path also works with Snes9x for SNES games and
  Genesis Plus GX for Mega Drive/Genesis, Master System, and Game Gear games.
- The ARM manifest exposes ES-DE component data at `/app/share/es-de`, the
  path expected by the binary built with `/app` as its install prefix.
- ES-DE 3.5.0 has now compiled for AArch64 with its GLES renderer enabled in
  the KDE 6.11 SDK. Its help and version commands run in the Flatpak build
  sandbox. Visible rendering has been confirmed on the Chromebook's Panfrost
  driver through the smoke-test app.
- The standalone test manifest omits ES-DE's PDF conversion helper because the
  KDE SDK does not include Poppler. It applies small compatibility edits to
  ES-DE's SDL/GLES includes and the upstream FreeImage 3.18 module. This is a
  graphics smoke test, not the finished RetroDECK component build.
- The RetroArch artifact is built from a dated AArch64 nightly executable and
  current AArch64 core nightlies; the component recipe should be pinned and
  updated deliberately for reproducible builds.
- Do not place x86_64 component archives in the ARM manifest's `components/`
  input.
- For a fresh clean build, use the command in section 7. For an already-built
  finalized app directory, export it as in section 8 instead of rebuilding.

### SRM and PortMaster integration status

The ARM prototype does not currently bundle Steam ROM Manager (SRM) or
PortMaster. Their absent shell helpers cause startup messages, but neither
integration blocked the verified setup, scraping, or game launches. These
integrations are deferred to separate work.

- **SRM:** RetroDECK uses SRM to add RetroDECK and ES-DE favorites to Steam,
  including artwork and shortcut management. The current Flatpak recipe
  downloads an x86_64-only Flathub app whose manifest uses an AMD64 Debian
  package. Upstream publishes an ARM64 AppImage, so a custom ARM component
  appears possible. It is useful only where a compatible Steam installation
  is accessible. See the [Flathub architecture listing](https://flathub.org/apps/details/com.steamgriddb.steam-rom-manager),
  [Flathub manifest](https://raw.githubusercontent.com/flathub/com.steamgriddb.steam-rom-manager/master/com.steamgriddb.steam-rom-manager.json),
  and [upstream releases](https://github.com/SteamGridDB/steam-rom-manager/releases).
- **PortMaster:** PortMaster publishes AArch64 runtimes, but its supported
  device list documents RetroDECK on Steam Deck and does not list this
  Chromebook. The existing RetroDECK component prepares files under
  `$XDG_DATA_HOME/PortMaster`, while its launcher executes
  `/var/data/PortMaster/PortMaster.sh`; resolve this path difference before
  packaging it. Test GUI/input/display compatibility and individual ARM ports
  on Panfrost/KDE. See the [supported devices](https://portmaster.games/installation/supported-handhelds/)
  and [runtime architectures](https://portmaster.games/installation/runtimes/).
- For clean startup without pretending either full integration is available,
  guard optional helper calls or package only the architecture-independent
  helper scripts and keep unavailable UI actions disabled. Neither full SRM
  nor full PortMaster support has been tested on the Chromebook.

### ES-DE GLES smoke test

The test manifest is `net.retrodeck.esde-gles-test.yml`. Build it with two
parallel jobs to stay within the Chromebook's memory limit:

```bash
cd /home/duet/dev/retrodeck/RetroDECK-arm-prototype
flatpak-builder --force-clean --jobs=2 --arch=aarch64 \
  --user --install \
  --install-deps-from=flathub \
  .build-esde-arm64-gles net.retrodeck.esde-gles-test.yml
```

From a terminal in the Chromebook desktop session, launch the built frontend
to verify actual GLES rendering on Panfrost:

```bash
flatpak-builder --run --arch=aarch64 \
  .build-esde-arm64-gles net.retrodeck.esde-gles-test.yml es-de
```

To launch the installed test app and try the game from the ES-DE UI:

```bash
flatpak run --user net.retrodeck.esde.gles.test
```

The test manifest also bundles the ARM RetroArch component and selected cores,
and adds their `/app/retrodeck/components/retroarch` paths to ES-DE's ARM find
rules. ES-DE is compiled with `FLATPAK_BUILD=off` for this test: that upstream
define prefixes emulator launches with `flatpak-spawn --host`, which cannot see
emulators bundled inside this app's `/app` tree. The app itself remains a
Flatpak; this setting makes ES-DE launch bundled emulators inside its sandbox.
This separate test app validates the ES-DE-to-RetroArch launch path, not the
full RetroDECK launcher, component preparation, theme, or configuration flow.

Troubleshooting notes:

- If ES-DE says the emulator or core is missing, check that the ARM RetroArch
  artifact exists and that both find-rule paths above match the installed
  app's `/app/retrodeck/components/retroarch/` layout.
- If the log shows a launch through `flatpak-spawn --host` followed by
  `No such file or directory` for an `/app/...` binary, check that the ES-DE
  test was built with `-DFLATPAK_BUILD=off`; a clean rebuild is needed after
  changing this CMake option.
- The `Tried to write to log file before it was open` messages were emitted in
  the successful launch as well; they were not the cause of the earlier
  emulator launch failures.
