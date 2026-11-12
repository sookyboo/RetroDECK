# ARM64 RetroDECK prototype handoff

This is the working handoff for continuing the ARM port. The host-specific
setup and command transcripts are in
[ARM_CHROMEBOOK_ARCH_BUILD.md](ARM_CHROMEBOOK_ARCH_BUILD.md).

## Goal and current boundary

Target a full local RetroDECK Flatpak on the AArch64 Arch Linux Chromebook:

- Mali-G72 MC3 GPU using Panfrost; desktop OpenGL 3.1 and GLES 3.1 work.
- Vulkan has no driver on this host. Use RetroArch's OpenGL video driver.
- KDE Flatpak Platform and SDK 6.11, AArch64.
- Initial emulation scope: RetroArch plus Gambatte, Snes9x, and Genesis Plus GX.

There are two separate prototypes. The ARM RetroDECK Flatpak currently proves
that the bundled ARM RetroArch executable runs and plays a GBC ROM when launched
directly. A separate ES-DE GLES test app now proves ES-DE can discover a ROM,
launch the bundled RetroArch/Gambatte, and render a game. The full RetroDECK
framework → ES-DE → RetroArch flow has not yet been integrated or validated.
Do not describe either prototype as a complete ARM RetroDECK build.

## Repositories and branch state

The work is isolated from the standard x86_64 checkouts:

| Worktree | Purpose | Branch | Fork (`origin`) | Upstream |
| --- | --- | --- | --- | --- |
| `/home/duet/dev/retrodeck/RetroDECK-arm-prototype` | Flatpak manifests and this documentation | `arm-prototype` | `sookyboo/RetroDECK` | `RetroDECK/RetroDECK` |
| `/home/duet/dev/retrodeck/components-arm-prototype` | Component recipes and ARM RetroArch build | `arm-prototype` | `sookyboo/components` | `RetroDECK/components` |

The current functional prototype includes these implementation commits:

- RetroDECK: `310f4e4d` — `Add ARM ES-DE GLES launch smoke test`
- components: `395f538a` — `Use ARM ES-DE system definitions`

The generated RetroArch archive is intentionally ignored by Git, so a new
builder must create it locally using section 5 in the Chromebook guide before
building the ARM Flatpak or ES-DE test app. Both branches track
`origin/arm-prototype`; do not push ARM changes to `upstream`.

## How the packaging is intended to work

RetroDECK's Flatpak manifest stages component archives under
`/app/retrodeck/components/`. The component installer expects a component
archive in its `components/` input. Keep architecture-specific recipes and
artifacts under `components/linux-arm64/` and never feed an x86_64 archive to
the ARM manifest.

The ARM RetroArch build currently packages a dated AArch64 RetroArch nightly,
architecture-neutral assets/config/database data, and three AArch64
libretro cores. Its output is:

```text
components-arm-prototype/linux-arm64/retroarch/artifacts/retroarch.tar.gz
```

The main ARM manifest is `net.retrodeck.retrodeck.arm64.yml`. It selects the
AArch64 rclone release, omits unused yq, and removes x86/i386 codec and
GStreamer paths. The direct RetroArch smoke test is not equivalent to
initializing the framework through RetroDECK's normal first-run flow.

## Confirmed ES-DE and emulator launch behavior

The reproducible ES-DE test manifest is
`net.retrodeck.esde-gles-test.yml`. It builds ES-DE from the RetroDECK fork at
commit `15e1b236eafd2864bd99ffcc9853d2efa2a3916c`, uses GLES, and bundles the
ARM RetroArch component archive. It adds these paths to the ARM ES-DE find
rules:

```text
/app/retrodeck/components/retroarch/bin/retroarch
/app/retrodeck/components/retroarch/rd_extras/cores
```

The key launch finding: ES-DE's CMake option `FLATPAK_BUILD=on` defines
`FLATPAK_BUILD` in `FileData.cpp`, which prefixes every emulator launch with
`flatpak-spawn --host`. That is for emulators installed on the host. The
bundled executable is inside the Flatpak at `/app/...`, which the host cannot
see; launching that way fails with `No such file or directory`. Build this
RetroDECK ES-DE variant with `-DFLATPAK_BUILD=off` so bundled emulator
processes start inside the app sandbox. The test remains packaged and run as a
Flatpak. Preserve this behavior when integrating ES-DE into RetroDECK.

Verified on the Chromebook: ES-DE rendered through Panfrost, found the Zelda
GBC ROM in `/home/duet/ROMs/gbc/`, resolved both the bundled RetroArch path and
Gambatte core path, and launched the game. The ES-DE test app has
`--filesystem=home`; an integrated app also needs access to the user's ROM
directory. Revisit Flatpak permission scope for the product build rather than
assuming the smoke-test permission is appropriate.

The log messages `Tried to write to log file before it was open` appeared
around launch but were not the failure. The useful diagnostics were the
resolved launch command and the portal/child process error.
A `--talk-name=org.freedesktop.Flatpak` override was tried during debugging,
but the working fix was compiling with `FLATPAK_BUILD=off`; do not rely on the
override to make a host process able to access the app's `/app` filesystem.

The test manifest omits the PDF conversion helper because Poppler is not
available in the KDE 6.11 SDK. It also carries small AArch64 GLES compatibility
edits for the SDL/GLES headers and FreeImage 3.18. A production ES-DE component
needs a deliberate PDF-helper decision and should not silently inherit
smoke-test-only workarounds.

## Current status and remaining work

### Proven

- AArch64 RetroArch 1.22.2 executable runs inside KDE Platform 6.11.
- Gambatte, Snes9x, and Genesis Plus GX core shared objects are AArch64.
- Direct RetroArch launch plays a GBC game with video and audio.
- ES-DE 3.5.0 builds with GLES enabled and visibly renders on Panfrost.
- ES-DE can launch the bundled RetroArch and Gambatte and play the same GBC
  game when built with `FLATPAK_BUILD=off`.
- The Flatpak runtime/SDK AArch64 refs are available from Flathub; see the
  exact `remote-info` commands in the Chromebook guide.

### Still outstanding

1. Build/package an ARM ES-DE component that retains the RetroDECK config,
   theme, resources, and `linuxarm` definitions. The existing component recipe
   downloads the x86_64 AppImage. The ES-DE fork has
   `tools/create_AppImage_AArch64.sh`, but that script is desktop-GL oriented;
   the Chromebook smoke test instead uses an in-runtime GLES build. Decide
   whether to produce a GLES AppImage/component or build/install ES-DE directly
   into the component layout. Keep the artifact layout compatible with
   `/app/retrodeck/components/es-de/` and the RetroDECK launcher.
2. Integrate `framework` and its startup/configuration flow into the ARM
   manifest. The framework component recipe is local shell/config assets, but
   audit scripts and dependencies for x86-only executables or paths.
3. Make the integrated ARM ES-DE component use
   `resources/systems/linuxarm/es_systems.xml` and `es_find_rules.xml`. The
   components branch already changes `es-de/component_functions.sh` to point
   at `linuxarm`; make sure these files are actually staged in the component
   artifact and that ES-DE itself is compiled with `FLATPAK_BUILD=off` for
   bundled-emulator launches.
4. Put ARM RetroArch, ES-DE, and framework artifacts into the exact component
   input paths consumed by `install_components.sh`; build the complete
   `net.retrodeck.retrodeck.arm64.yml` Flatpak.
5. Verify first-run initialization, theme/config loading, ROM discovery,
   RetroArch core launch, audio/video, controller input, save/config writes,
   and restart behavior in the integrated app.
6. Check the x86_64 build remains unchanged and choose a maintainable
   architecture-selection pattern for component recipes before broadening the
   ARM core/emulator list.

## Recommended continuation sequence

1. Recreate the ARM RetroArch archive using the commands and disk-space notes
   in the Chromebook guide.
2. Turn the successful ES-DE smoke manifest recipe into an ARM ES-DE component
   build/install step. Retain the GLES and `FLATPAK_BUILD=off` decisions, add
   the RetroDECK theme/config, and handle Poppler intentionally.
3. Build the framework component archive and audit its runtime assumptions.
4. Update the ARM Flatpak manifest/component staging so all three components
   are installed at their expected `/app/retrodeck/components/<name>` paths.
5. Build, install, and run the integrated app. Fix packaging/runtime issues
   before expanding supported systems or adding more cores.
6. Record successful commands/results here and in the Chromebook build guide;
   commit on both `arm-prototype` branches and push to the matching `origin`.

## Build constraints and references

- `/tmp` on this Chromebook is a 1.9 GiB tmpfs. The full Libretro database
  checkout exhausted it. The RetroArch wrapper uses the disk-backed workdir
  `/home/duet/dev/retrodeck/RetroDECK/.tmp-arm-retroarch-build`.
- Build ES-DE with `--jobs=2`; a higher parallel job count previously caused
  memory pressure.
- The smoke-test app is `net.retrodeck.esde.gles.test`; its build/run commands
  and host package prerequisites are in `ARM_CHROMEBOOK_ARCH_BUILD.md`.
- ES-DE's checked-out ARM developer notes are in
  `LINUX-AARCH64-DEV.md`; inspect the pinned source in Flatpak Builder's build
  cache or fetch the same commit when resuming.
- RetroArch config switches to OpenGL and uses the AArch64 core-download URL.
  The standalone RetroArch binary dependencies were inspected on the host but
  have only been proven at runtime inside the KDE 6.11 Flatpak via game launch.
