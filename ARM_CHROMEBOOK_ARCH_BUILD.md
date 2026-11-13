# Building and testing the ARM RetroDECK prototype on Arch Linux ARM

This guide records the working local workflow used on an AArch64 Chromebook
running Arch Linux ARM. The ARM RetroDECK prototype packages RetroArch and
194 ARM64 Libretro cores in KDE Platform 6.11. A separate ES-DE test app
builds the frontend with GLES and validates launching a bundled core.

> **Verified on the Chromebook:** The integrated ARM Flatpak completes first-run
> setup, runs ES-DE scraping, and launches Game Boy, SNES, Mega Drive, Master
> System, Game Gear, Sega CD, NES through Mesen, and PICO-8 games. An Xbox
> Bluetooth controller works, and RetroArch save states and Game Boy saves were
> confirmed. Steam ROM Manager and PortMaster remain deferred.

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
The archive contains RetroArch, assets, database data, core metadata, and all
194 AArch64 cores whose names match cores in the x86 RetroDECK package. Fourteen
x86 cores without a matching AArch64 nightly are omitted. The artifacts
directory is Git-ignored; its size depends on the selected cores and upstream
nightly builds. The current core-expanded archive is about 822 MiB; the
installed Flatpak is about 2.4 GiB.
The omitted x86 core names are `ardens`, `boom3_xp`, `bsnes_hd_beta`,
`doukutsu_rs`, `fbalpha`, `genesis_plus_gx_paprium`, `mcsoftserve`, `noods`,
`panda3ds`, `qemu`, `romcleaner`, `sameboy`, `vice_xcbm2`, and `vice_xcbm5x0`.

## 6. Build the ARM component archives

The ARM Flatpak manifest expects RetroArch, framework, ES-DE, PICO-8, PPSSPP,
Ruffle, and ScummVM component archives in the sibling components worktree.
Generate them before building the full app:

```bash
cd /home/duet/dev/retrodeck/components-arm-prototype
./linux-arm64/framework/build-component.sh
./linux-arm64/retroarch/build-component.sh
./linux-arm64/pico-8/build-component.sh
./linux-arm64/ppsspp/build-component.sh
./linux-arm64/ruffle/build-component.sh
./linux-arm64/scummvm/build-component.sh
./linux-arm64/es-de/build-component.sh
```

The ES-DE builder uses the successful GLES smoke-test manifest and requires
the RetroArch archive first. It builds ES-DE with `FLATPAK_BUILD=off`, stages
the RetroDECK theme and component config, and creates
`linux-arm64/es-de/artifacts/es-de.tar.gz`. It does not install the standalone
test app. The framework and ES-DE archive outputs, like the RetroArch archive,
are Git-ignored. The ES-DE builder uses a disk-backed appdir at
`RetroDECK-arm-prototype/.build-esde-arm64-component`.
The PICO-8 archive contains only its component scripts and configuration; it
does not contain proprietary PICO-8 files. The ES-DE package adds a static
lookup path for the PICO-8 component launcher.

The PPSSPP builder extracts the AArch64 Flathub app into a component archive.
Flatpak commit IDs differ by architecture, so the ARM builder pins the
AArch64-specific commit `678bf845ac9679ddf5d2be24ed39bc21b269a573b7ba07a1795175aaf4a57040`.
The newer stable commit uses Freedesktop 26.08 and requires GLIBC 2.43/2.44,
which is too new for RetroDECK's KDE 6.11 runtime (GLIBC 2.42). The pinned
commit uses Freedesktop 25.08 and its PPSSPP executable requires GLIBC up to
2.38, so it launches in the KDE 6.11 runtime. Recheck this pin when updating
PPSSPP or RetroDECK's runtime.
The archive is written to
`linux-arm64/ppsspp/artifacts/ppsspp.tar.gz`; the Alchemist library collector
uses Flatpak's native architecture when collecting runtime libraries.
The ES-DE ARM system definition defaults PSP launches to this standalone
component and keeps the PPSSPP RetroArch core as an alternate emulator.

Fresh RetroDECK setup calls `prepare_component "reset" "all"`, which copies
the bundled PPSSPP defaults into the user's config directory. If PPSSPP is
added to an already initialized profile, that initial reset has already passed;
reset PPSSPP once in the Configurator to apply its defaults. This replaces its
current `ppsspp.ini` and `controls.ini`, so back them up first if they contain
settings to keep.

The ScummVM builder extracts the native AArch64 Flathub app, currently using
the candidate commit
`a742f597c46657508a03bd65f26349b427a14a3dbe9adfcc7ed9eb5a5dde2bad`.
This historical app ref uses Freedesktop 25.08. A newer app binary was found
to require GLIBC 2.43 and 2.44, above the KDE 6.11 runtime's GLIBC 2.42. The
pinned binary and all bundled ELF libraries were checked; their highest GLIBC
requirement is 2.38. The component builder checks that the installed app
commit matches the requested pin and fails if the pinned update cannot be
downloaded. The component keeps the upstream
Linux ARM ScummVM system definition: RetroArch's ScummVM core remains the
default, and standalone ScummVM is available as an alternate emulator. The
ES-DE build adds the bundled launcher to the `SCUMMVM` static-path lookup. The
ARM standalone command auto-detects a game in `%GAMEDIR%`; the ScummVM
descriptor target ID is not necessarily the folder's display name. Leave
`%GAMEDIR%` unquoted because ES-DE already escapes spaces for the shell. The x86
Linux ES-DE definition leaves standalone ScummVM commented out, so this ARM
standalone path is a new integration and is not confirmed by the x86 behavior.
Launch testing exposed both the display-name/target-ID mismatch and the extra
quoting; rebuild ES-DE to include the corrected auto-detect command. The
archive is written to
`linux-arm64/scummvm/artifacts/scummvm.tar.gz`. After building, extract it and
inspect the AArch64 binary before rebuilding RetroDECK:

```bash
mkdir -p .tmp-scummvm-inspect
tar -xzf linux-arm64/scummvm/artifacts/scummvm.tar.gz \
  -C .tmp-scummvm-inspect
readelf --version-info .tmp-scummvm-inspect/bin/scummvm |
  grep -o 'GLIBC_[0-9.]*' | sort -Vu | tail
```

Accept a future replacement binary only if its highest GLIBC requirement is
no newer than 2.42. The pinned component archive was built and its GLIBC
compatibility was verified. Retest standalone ScummVM by launching a game
directory containing a `.scummvm` descriptor after rebuilding ES-DE and the
full Flatpak.

The ES-DE build fetches the RetroDECK theme from its `main` branch, matching
the existing component recipe. Pin the theme revision for a reproducible
release build.

## 7. Build the AArch64 Flatpak

The ARM manifest derives its version from the metainfo file because the normal
`retrodeck_builder.sh` step that creates the Git-ignored `version` file is not
run when invoking Flatpak Builder directly.

```bash
cd /home/duet/dev/retrodeck/RetroDECK-arm-prototype
flatpak-builder --user --force-clean --arch=aarch64 --jobs=2 \
  --disable-updates --disable-rofiles-fuse --install-deps-from=flathub \
  build-arm64 net.retrodeck.retrodeck.arm64.yml
```

The full manifest has previously built successfully with the RetroArch,
framework, and ES-DE archives generated in section 6. Rebuild the PPSSPP
archive before building with the updated manifest. Its output directory is
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
installing the branch do not rebuild the app. On this host, `build-export`
requires host network access for icon validation; if a sandbox reports
`NETLINK_ROUTE` permission errors, rerun that export command with the required
host permissions.

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

The ARM recipe bundles 194 cores with AArch64 builds from the x86 RetroDECK
core set. Some of the system defaults and prior launch checks are:

- Gambatte: Game Boy and Game Boy Color.
- Snes9x: Super Nintendo / Super Famicom.
- Genesis Plus GX: Genesis / Mega Drive, Master System, Game Gear, and Sega CD.
- Mesen: Nintendo Entertainment System (NES) and Famicom. This matches the
  default NES core in the x86 and ARM ES-DE system definitions. NES game launch
  through Mesen was confirmed on the Chromebook.
- GearColeco: ColecoVision. The ARM ES-DE default is set to GearColeco.
- DOSBox Pure: DOS.
- mGBA: Game Boy Advance.
- DeSmuME: Nintendo DS. The ARM ES-DE default is set to DeSmuME to match the
  x86 default.
- Mupen64Plus-Next: Nintendo 64. The ARM ES-DE default is set to
  Mupen64Plus-Next to match the x86 default.
- SwanStation: PlayStation. The ARM ES-DE default is set to SwanStation to
  match the x86 default, but it freezes at the PlayStation logo on this
  Chromebook. PCSX-ReARMed and Beetle PSX are bundled alternatives that have
  not yet been tested here.

The additional cores are packaged but have not yet been individually tested
with games on the Chromebook. A matching AArch64 build does not guarantee that
every core runs well on this device.

## 10. Known limitations and next work

- Framework, ES-DE, PICO-8, PPSSPP, and RetroArch component archives were built,
  and the full ARM manifest completed with all five components staged. A PSP
  game launched successfully through standalone PPSSPP after pinning the
  compatible AArch64 Flathub commit and rebuilding the component archive.
  The integrated `arm-prototype`
  branch has launched successfully: the first-run Zenity wizard completed,
  ES-DE's scraper ran, and a Game Boy game launched. The separate ES-DE
  smoke-test app also rendered through Panfrost and launched a GBC game using
  bundled ARM RetroArch and Gambatte.
- A Bluetooth Xbox controller works in the integrated app. Pressing LS and RS
  together opens the RetroArch menu, where the save option is accessible.
- Game Boy game saves were confirmed working.
- The integrated ES-DE launch path also works with Snes9x for SNES games and
  Genesis Plus GX for Mega Drive/Genesis, Master System, Game Gear, and Sega CD
  games. Sega CD required its BIOS files in RetroDECK's configured BIOS
  directory.
- NES launch through the bundled Mesen RetroArch core and PICO-8 launch through
  the user's licensed AArch64 `pico8_64` executable were also confirmed in the
  integrated app. PICO-8's own files remain outside the Flatpak component
  archive.
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

### PICO-8 user-owned ARM64 copy

PICO-8 is proprietary, so the ARM component packages only RetroDECK's launcher,
configuration template, and component scripts. It does not package PICO-8's
executable or data files. Place the user's licensed Linux copy in
`$bios_path/pico-8` (on this Chromebook, `/home/duet/retrodeck/bios/pico-8`).
The ARM64 distribution includes `pico8_64`; its bundled `pico8` is a 32-bit
ARM executable and is not selected on AArch64.

The PICO-8 component setup links its carts directory to
`$roms_path/pico8` and its `cdata` save directory to `$saves_path/pico-8`.
It keeps PICO-8's config under RetroDECK's XDG config directory and sets those
paths there. The launcher passes that config home and selects `pico8_64` on
AArch64. ES-DE's PICO-8 static-path rule resolves the component launcher, and
ES-DE continues to pass each cartridge path to PICO-8.

Build the component archive before building the full Flatpak:

```bash
cd /home/duet/dev/retrodeck/components-arm-prototype
./linux-arm64/pico-8/build-component.sh
```

The ES-DE component packaging script also adds the PICO-8 launcher to the
Linux ARM emulator discovery rules. Rebuild that archive when rebuilding
ES-DE. Then build and install RetroDECK with the clean-build command in
section 7, export it as in section 8, and run the `arm-prototype` branch.
PICO-8 launch was confirmed on the Chromebook with a cartridge from
`$roms_path/pico8`. Its save path is configured under `$saves_path/pico-8`, but
PICO-8 save-file persistence has not been separately verified.
