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

The generated component archives are intentionally ignored by Git, so a new
builder must create them locally using section 6 in the Chromebook guide
before building the ARM Flatpak. Both branches track
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

Two additional component builders are now present:

- `linux-arm64/framework/build-component.sh` packages the architecture-neutral
  framework scripts and metadata.
- `linux-arm64/es-de/build-component.sh` builds the ES-DE GLES smoke-test app
  and assembles an ES-DE component archive containing the executable, required
  private libraries, Linux ARM resources, RetroDECK theme/config, and component
  scripts.

Their expected archives are
`linux-arm64/framework/artifacts/framework.tar.gz` and
`linux-arm64/es-de/artifacts/es-de.tar.gz`. The main ARM manifest stages all
three component artifact directories for `install_components.sh`.

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
- The framework and ES-DE component builders have produced local archives; the
  full ARM manifest built successfully and its installer staged ES-DE,
  framework, and RetroArch together in the appdir.
- The installed integrated prototype completed the Zenity first-run wizard,
  ran the ES-DE scraper, and launched a Game Boy game. The ARM manifest links
  ES-DE's component resources into `/app/share/es-de`, as required by its
  `/app` install prefix.
- Through ES-DE, Snes9x launches SNES games, and Genesis Plus GX launches Mega
  Drive/Genesis, Master System, and Game Gear games.
- A Bluetooth Xbox controller works; pressing LS and RS together opens the
  RetroArch menu, including its save option. Game Boy game saves also work.
- SRM and PortMaster are deferred to separate work. They are not bundled, and
  their missing shell helpers produce startup messages without blocking the
  verified use cases.
- The Flatpak runtime/SDK AArch64 refs are available from Flathub; see the
  exact `remote-info` commands in the Chromebook guide.

### Still outstanding

1. Verify theme/config loading. Restart persistence has been verified.
2. Check the x86_64 build remains unchanged and choose a maintainable
   architecture-selection pattern for component recipes before broadening the
   ARM core/emulator list. Choose the next systems based on user priorities.

## Recommended continuation sequence

1. Check the x86_64 build remains unchanged and choose a maintainable
   architecture-selection pattern before broadening the ARM core/emulator list.
2. Record successful commands/results here and in the Chromebook build guide;
   commit the verified changes on the `arm-prototype` branches. Do not push
   until the user has verified the build works.

## Build constraints and references

- `/tmp` on this Chromebook is a 1.9 GiB tmpfs. The full Libretro database
  checkout exhausted it. The RetroArch wrapper uses the disk-backed workdir
  `/home/duet/dev/retrodeck/RetroDECK/.tmp-arm-retroarch-build`.
- Build ES-DE with `--jobs=2`; a higher parallel job count previously caused
  memory pressure.
- The smoke-test app is `net.retrodeck.esde.gles.test`; its build/run commands
  and host package prerequisites are in `ARM_CHROMEBOOK_ARCH_BUILD.md`.
- The ES-DE component builder depends on the RetroArch archive and sibling
  `RetroDECK-arm-prototype` worktree; it rebuilds the smoke-test appdir in
  `.build-esde-arm64-component` and does not install that test app.
- The RetroDECK theme source is currently fetched from the theme repository's
  `main` branch, following the existing upstream recipe. Pin it for a
  reproducible release build.
- ES-DE's checked-out ARM developer notes are in
  `LINUX-AARCH64-DEV.md`; inspect the pinned source in Flatpak Builder's build
  cache or fetch the same commit when resuming.
- RetroArch config switches to OpenGL and uses the AArch64 core-download URL.
  The standalone RetroArch binary dependencies were inspected on the host but
  have only been proven at runtime inside the KDE 6.11 Flatpak via game launch.
