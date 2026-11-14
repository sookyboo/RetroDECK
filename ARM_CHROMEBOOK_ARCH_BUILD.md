# Building and testing the ARM RetroDECK prototype on Arch Linux ARM

This guide records the working local workflow used on an AArch64 Chromebook
running Arch Linux ARM. The ARM RetroDECK prototype packages RetroArch and
194 ARM64 Libretro cores in KDE Platform 6.11. A separate ES-DE test app
builds the frontend with GLES and validates launching a bundled core.

> **Verified on the Chromebook:** The integrated ARM Flatpak completes first-run
> setup, runs ES-DE scraping, and launches Game Boy, SNES, Mega Drive, Master
> System, Game Gear, Sega CD, NES through Mesen, and PICO-8 games. An Xbox
> Bluetooth controller works, and RetroArch save states and Game Boy saves were
> confirmed. The ARM manifest also packages standalone emulator components and
> PortMaster; see the inventory below for individual test coverage and remaining
> integration work.

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
Ruffle, ScummVM, Azahar, Dolphin, melonDS, MAME, xemu, DuckStation, Vita3K,
RPCS3, Cemu, Steam ROM Manager, and PortMaster component archives in the
sibling components worktree.
Generate them before building the full app:

```bash
cd /home/duet/dev/retrodeck/components-arm-prototype
./linux-arm64/framework/build-component.sh
./linux-arm64/retroarch/build-component.sh
./linux-arm64/pico-8/build-component.sh
./linux-arm64/ppsspp/build-component.sh
./linux-arm64/ruffle/build-component.sh
./linux-arm64/scummvm/build-component.sh
./linux-arm64/azahar/build-component.sh
./linux-arm64/dolphin/build-component.sh
./linux-arm64/melonds/build-component.sh
./linux-arm64/mame/build-component.sh
./linux-arm64/xemu/build-component.sh
./linux-arm64/duckstation/build-component.sh
./linux-arm64/vita3k/build-component.sh
./linux-arm64/rpcs3/build-component.sh
./linux-arm64/cemu/build-component.sh
./linux-arm64/steam-rom-manager/build-component.sh
PORTMASTER_ARCHIVE_PATH=/home/duet/dev/retrodeck/.tmp-retroarch-arm-inspect/retrodeck.portmaster.zip \
  ./linux-arm64/portmaster/build-component.sh
./linux-arm64/es-de/build-component.sh
```

The PortMaster builder pins release `2026.11.12-1059`. The optional
`PORTMASTER_ARCHIVE_PATH` uses the archive already downloaded from the official
release URL, which avoids re-downloading that 24 MiB archive. It still gathers
SDL libraries from KDE SDK/Platform 6.7 and liblzma from Freedesktop 25.08.
Those runtimes must be available to Flatpak when building. PortMaster's reset
refreshes bundled files in place, keeps the user's PortMaster config/data, and
uses Flatpak's `XDG_DATA_HOME` for its control files and launcher.

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
ScummVM component archive includes `sky.cpt` under `scummvm/`, and its launcher
passes that directory as `--extrapath` for engine data such as Beneath a Steel
Sky's required file. On a Configurator reset, the ScummVM component copies its
bundled `scummvm.ini` defaults into the user's config and substitutes the
current RetroDECK saves, ROMs, and bundled soundfont paths. This includes
`fullscreen=true`; reset ScummVM once after rebuilding to apply these defaults
to an existing profile. The reset replaces that ScummVM config file, so save a
copy first if you have custom ScummVM settings to keep.
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

### AArch64 Flathub emulators and GLIBC checks

The standalone ARM components Azahar, Dolphin, melonDS, and MAME are extracted
from native AArch64 Flathub builds. Their app commits and inspected maximum
GLIBC symbol versions are:

| Component | AArch64 app commit | Runtime branch | Maximum GLIBC | Configuration vs x86 | Configurator reset wiring |
| --- | --- | --- | --- | --- | --- |
| Azahar | `39d1b884780a727499b59de097ef09aa507b23bd4340205ded4ba2c3b44020c6` | KDE 6.11 | 2.42 | Same component config, manifest, and scripts | Hook and defaults bundled; ARM reset not yet run |
| Dolphin | `a22e93a81ac2898f9a4cd69bbcbaa7b8de52262f7b6f5cc4eb18211a3bd25d7e` | KDE 6.11 | 2.38 | Same component config, manifest, and scripts | Hook and defaults bundled; ARM reset not yet run |
| melonDS | `7d673f2d9516adb6f959b0a71449007725eff7781c6f7ce6c1064c39f6b0c18e` | KDE 6.10 | 2.38 | Same component config, manifest, and scripts | Hook and defaults bundled; ARM reset not yet run |
| MAME | `7e0da1bbaea5667b53c6bb7c1e84c2705304d19a8dbb7ec3dcf69967d1d31043` | KDE 6.11 | 2.38 | Same component config, manifest, and scripts | Hook and defaults bundled; ARM reset not yet run |
| xemu | `56e940a8b2ec81291df431867bf082f94068f1856beb231e4ee2225a4bb1274c` | Freedesktop 25.08 | 2.42 (executable) | Same component config, manifest, and scripts | Hook and defaults bundled; ARM reset not yet run |

“Same component config, manifest, and scripts” means the component source
directories were compared directly with the x86 `components` checkout; no
differences were found for these five components. Each ARM packaging recipe
includes its `component_prepare.sh` and `rd_config` defaults. This confirms
the reset path is packaged, but the Configurator reset itself still needs an
ARM runtime check for each emulator.

The current xemu AArch64 app uses Freedesktop 26.08 and requires GLIBC 2.44,
newer than RetroDECK's KDE 6.11 runtime (GLIBC 2.42). The ARM recipe therefore
pins an earlier Flathub commit on Freedesktop 25.08. Its executable was
inspected at GLIBC 2.42. The other four pins are at or below the KDE 6.11
baseline. Cemu currently has no AArch64 Flathub app, so it is not part of these
standalone component builds. These components are packaged for AArch64 targets;
their inclusion does not claim every game or graphics backend will work on the
Chromebook's Mali GPU.

To check which runtime a particular historical Flatpak commit needs, inspect
the app's AArch64 history and query a commit from that history:

```bash
flatpak remote-info --user --arch=aarch64 --log flathub APP_ID/aarch64/stable
flatpak remote-info --user --commit=COMMIT_HASH --show-runtime \
  flathub APP_ID/aarch64/stable
```

To inspect the GLIBC symbol versions actually required by an installed app,
first install its AArch64 ref (or install its required historical app commit
with `flatpak update --user --commit=COMMIT_HASH APP_ID`), then scan the app's
executables and shared libraries. Set `APP_ID` to the app ID, for example
`org.DolphinEmu.dolphin-emu`:

```bash
app_location="$(flatpak info --show-location --user "$APP_ID")"
find "$app_location/files" -type f \
  \( -perm /111 -o -name '*.so' -o -name '*.so.*' \) -print0 |
  while IFS= read -r -d '' elf; do
    readelf --version-info "$elf" 2>/dev/null || true
  done |
  grep -o 'GLIBC_[0-9.]*' | sort -Vu | tail
```

For an archived component executable, unpack the archive and run `readelf`
directly. For example:

```bash
mkdir -p .tmp-component-inspect
tar -xzf linux-arm64/scummvm/artifacts/scummvm.tar.gz \
  -C .tmp-component-inspect
readelf --version-info .tmp-component-inspect/bin/scummvm |
  grep -o 'GLIBC_[0-9.]*' | sort -Vu | tail
```

Compare the maximum against the runtime available in the app. The Chromebook's
KDE 6.11 runtime baseline was checked with:

```bash
flatpak run --user --command=sh org.kde.Platform//6.11 \
  -c 'ldd --version | head -n 1'
```

If a current app commit exceeds that baseline, check older commits in the
history and their runtime branches before pinning one. Keep pins and measured
GLIBC versions updated together when upgrading components or the application
runtime. Remove the temporary inspection directory when finished.

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

### Complete rebuild and run example

This is the full command sequence for rebuilding all ARM components, rebuilding
the RetroDECK Flatpak, exporting it, updating the installed branch, and
launching it:

```bash
cd /home/duet/dev/retrodeck/components-arm-prototype

./linux-arm64/framework/build-component.sh
./linux-arm64/retroarch/build-component.sh
./linux-arm64/pico-8/build-component.sh
./linux-arm64/ppsspp/build-component.sh
./linux-arm64/ruffle/build-component.sh
./linux-arm64/scummvm/build-component.sh
./linux-arm64/azahar/build-component.sh
./linux-arm64/dolphin/build-component.sh
./linux-arm64/melonds/build-component.sh
./linux-arm64/mame/build-component.sh
./linux-arm64/xemu/build-component.sh
./linux-arm64/duckstation/build-component.sh
./linux-arm64/vita3k/build-component.sh
./linux-arm64/rpcs3/build-component.sh
./linux-arm64/cemu/build-component.sh
./linux-arm64/steam-rom-manager/build-component.sh
PORTMASTER_ARCHIVE_PATH=/home/duet/dev/retrodeck/.tmp-retroarch-arm-inspect/retrodeck.portmaster.zip \
  ./linux-arm64/portmaster/build-component.sh
./linux-arm64/es-de/build-component.sh

cd /home/duet/dev/retrodeck/RetroDECK-arm-prototype

flatpak-builder --user --force-clean --arch=aarch64 --jobs=2 \
  --disable-updates --disable-rofiles-fuse --install-deps-from=flathub \
  build-arm64 net.retrodeck.retrodeck.arm64.yml

flatpak build-export --arch=aarch64 \
  .flatpak-builder/repo-arm64 build-arm64 arm-prototype

flatpak update --user net.retrodeck.retrodeck//arm-prototype

flatpak run --user net.retrodeck.retrodeck//arm-prototype
```

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

## 10. Engine and emulator porting inventory

This is the ARM Chromebook prototype inventory for the engines and emulators
listed in RetroDECK's component catalog. It records the packaging approach
identified for the x86 RetroDECK build, whether an ARM route was identified,
and the prototype's current status. ARM availability is an initial assessment,
not a guarantee that a component will build or run well on this Chromebook.

### Engine components

| Component | ARM prototype status |
|---|---|
| IkemenGO / M.U.G.E.N | Not ported; Ikemen GO and legacy M.U.G.E.N need separate feasibility checks |
| OpenBOR | Not ported |
| PICO-8 | Packaged; Chromebook game launch confirmed using the user's licensed AArch64 files |
| ScummVM | Packaged; standalone launch tested |
| Solarus | Not ported |
| UZDoom (GZDoom component) | Not ported |

### Emulator and utility components

| Component | ARM prototype status |
|---|---|
| Azahar | Packaged in the manifest; Chromebook game launch not recorded |
| Cemu | ARM64 CI AppImage archive built and manifest entry added; Chromebook launch testing pending |
| Dolphin | Packaged in the manifest; Chromebook game launch not recorded |
| DuckStation (Legacy) | ARM64 AppImage archive built and manifest entry added; Chromebook launch testing pending |
| Flips | Not ported |
| melonDS | Packaged in the manifest; Chromebook game launch not recorded |
| MAME | Packaged in the manifest; Chromebook game launch not recorded |
| PCSX2 | Not ported; ARM64 compatibility and Chromebook performance need investigation |
| PPSSPP | Packaged; standalone game launch confirmed; reset was needed to apply defaults |
| PrimeHack | Not ported; ARM support and dependencies need investigation |
| RetroArch | Packaged; multiple cores and game launches confirmed; 194 matching ARM64 cores are bundled |
| RPCS3 | ARM64 AppImage archive built and manifest entry added; Chromebook launch testing pending; graphics support and practical performance are uncertain |
| Ruffle | Packaged; Flash game launch confirmed. Controller mapping remains unverified |
| Steam ROM Manager | ARM64 AppImage archive built and manifest entry added; Chromebook launch testing pending |
| Vita3K | AArch64 AppImage archive built and manifest entry added; Chromebook launch testing pending |
| xemu | Packaged in the manifest; Chromebook game launch not recorded |
| XRoar | Not ported; native ARM source build appears feasible |

`Framework`, ES-DE, and PortMaster are also packaged in the manifest. ES-DE's
frontend and PortMaster's basic launch path have been exercised; PortMaster's
full GUI and broad port compatibility remain unverified. “Packaged” means an
ARM component recipe/archive is staged by the manifest; it does not claim that
every emulator has launched or that every game works on the Chromebook.

The components marked “Not ported” are candidates for future work. Validate
upstream architecture support, runtime requirements, graphics backend, and
performance before adding one to the ARM manifest.

### ARM upstream builds and packaging matches

Checked 2026-11-14 against upstream release/build pages. “Same method” here
means an upstream Linux ARM64 artifact in the same package form that the x86
RetroDECK component currently consumes; it does not mean the component is
already integrated or tested in the ARM prototype.

| Component | x86 RetroDECK input | ARM64 availability | Same-method match? |
|---|---|---|---|
| DuckStation (Legacy) | AppImage | Upstream publishes an ARM64 AppImage | Yes |
| Vita3K | AppImage | Upstream publishes an AArch64 AppImage | Yes |
| RPCS3 | AppImage | Upstream publishes a Linux ARM64 AppImage from its separate ARM64 builds repository | Yes |
| Steam ROM Manager | Flathub Flatpak, extracted into the component | Upstream publishes an ARM64 AppImage | No; packaged using an ARM AppImage recipe |
| Cemu | Flathub Flatpak, extracted into the component | ARM AppImage is available from upstream CI; no matching ARM Flatpak or stable release was identified | No; packaged using a moving CI AppImage artifact |
| OpenBOR | AppImage | Upstream documents building a native ARM64 Linux binary from source | No matching ARM AppImage identified |
| Flips | RetroDECK-provided Linux binary zip | An AArch64 Arch Linux ARM package exists; no matching RetroDECK binary zip identified | No |
| Solarus | AppImage | No upstream Linux ARM64 AppImage was identified; source builds are the likely route | No matching artifact identified |
| XRoar | RetroDECK-provided binary tarball | Native ARM source build appears feasible; no matching upstream ARM64 binary tarball was identified | No matching artifact identified |
| UZDoom (GZDoom component) | Linux x86_64 AppImage | No Linux ARM64 artifact was identified | No |
| PCSX2 | x86_64 AppImage | Upstream says ARM builds are unsupported | No |
| PrimeHack | x86_64 release build | No upstream ARM64 release artifact was identified | No |

ARM-specific recipes now package upstream AppImages for DuckStation, Vita3K,
RPCS3, Cemu, and Steam ROM Manager. All five component archives are built, but
Chromebook launch tests are pending. Cemu uses the current AppImage artifact
from its CI workflow, distributed through nightly.link; this is a moving,
largely untested CI build rather than a stable release. Artifact availability
does not establish performance or compatibility on the Chromebook.

The Chromebook's Panfrost stack exposes OpenGL ES 3.1 and has no Vulkan driver.
DuckStation lists OpenGL ES 3.1 as supported, so it is the most plausible of
these five to run here. Vita3K requires OpenGL 4.4, while RPCS3 requires Vulkan
1.2. Cemu requires OpenGL 4.5 or Vulkan 1.2. Those requirements exceed the
graphics APIs available on this host, so these three are unlikely to run here
without a suitable graphics backend. The ARM archives still provide packaging
and launch integration for devices with compatible graphics support. See the
upstream [DuckStation requirements](https://github.com/stenzek/duckstation),
[Vita3K quickstart](https://vita3k.org/quickstart.html),
[RPCS3 requirements](https://rpcs3.io/faq.html), and
[Cemu requirements](https://cemu.info/).

Sources: [DuckStation releases](https://github.com/stenzek/duckstation/releases),
[Vita3K releases](https://github.com/Vita3K/Vita3K/releases),
[RPCS3 ARM64 builds](https://github.com/RPCS3/rpcs3-binaries-linux-arm64),
[Steam ROM Manager releases](https://github.com/SteamGridDB/steam-rom-manager/releases),
[Cemu CI builds](https://github.com/cemu-project/Cemu/actions/runs/31884801588),
[OpenBOR build instructions](https://github.com/DCurrent/openbor/wiki/Compiling-Overview),
[Flips for Arch Linux ARM](https://archlinuxarm.org/packages/aarch64/flips),
[UZDoom releases](https://github.com/UZDoom/UZDoom/releases), and
[PCSX2 build requirements](https://pcsx2.net/docs/advanced/building/).

## 11. Known limitations and next work

- The ARM manifest is configured to stage 18 components: framework, ES-DE,
  RetroArch, PICO-8, PPSSPP, Ruffle, ScummVM, Azahar, Dolphin, melonDS, MAME,
  xemu, DuckStation, Vita3K, RPCS3, Cemu, Steam ROM Manager, and PortMaster.
  DuckStation, Vita3K, RPCS3, Cemu, and Steam ROM Manager archives are built;
  their runtime behavior has not been tested on the Chromebook.
  A PSP game launched successfully through standalone PPSSPP after
  pinning the compatible AArch64 Flathub commit and rebuilding its archive.
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

SRM's ARM AppImage archive is now staged in the manifest; launching it and
testing Steam integration remain pending. PortMaster packaging work has been
added to the ARM branch and built into the Flatpak. An individual ARM port was
confirmed to launch; controller-to-keyboard and mouse emulation needs host
`/dev/uinput` access as described below. Full GUI, display, networking, and
broader port compatibility remain to be verified.

- **SRM:** RetroDECK uses SRM to add RetroDECK and ES-DE favorites to Steam,
  including artwork and shortcut management. The ARM component uses the
  upstream ARM64 AppImage because the Flathub app is x86_64-only. It is useful
  only where a compatible Steam installation is accessible. See the [Flathub architecture listing](https://flathub.org/apps/details/com.steamgriddb.steam-rom-manager),
  [Flathub manifest](https://raw.githubusercontent.com/flathub/com.steamgriddb.steam-rom-manager/master/com.steamgriddb.steam-rom-manager.json),
  and [upstream releases](https://github.com/SteamGridDB/steam-rom-manager/releases).
- **PortMaster:** Release `2026.11.12-1059` includes AArch64 helpers, with a
  maximum observed GLIBC requirement of 2.38. The ARM component patches its
  launcher/control paths to use Flatpak's `XDG_DATA_HOME` and preserves the
  user's PortMaster data on reset. Its SDL libraries come from KDE 6.7 and
  liblzma from Freedesktop 25.08. The component build currently needs those
  runtimes from Flathub; the attempt in this environment stopped because DNS
  could not resolve `flathub.org`. Continue testing the GUI, controller,
  display, networking, and more ARM ports on Panfrost/KDE. PortMaster's
  [supported devices](https://portmaster.games/installation/supported-handhelds/)
  page focuses on handheld custom firmware, so it does not establish Chromebook
  compatibility; see also [runtime architectures](https://portmaster.games/installation/runtimes/).
  Controller-to-keyboard and mouse emulation also needs host access to
  `/dev/uinput`; Flatpak `--device=all` does not override host node permissions.
  Temporary ACL and persistent udev-rule setup (independent of Steam), plus
  optional distro `steam-devices` packages, are documented in
  [ARM_PROTOTYPE.md](ARM_PROTOTYPE.md#portmaster-controller-to-keyboard-and-mouse-input).
- SRM and PortMaster remain unverified as complete Chromebook integrations.

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
