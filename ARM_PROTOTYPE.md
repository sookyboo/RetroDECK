# ARM64 RetroDECK prototype

For the tested Arch Linux ARM Chromebook setup and build/run commands, see
[`ARM_CHROMEBOOK_ARCH_BUILD.md`](ARM_CHROMEBOOK_ARCH_BUILD.md).

## Target

Build a local, full RetroDECK Flatpak for the aarch64 Chromebook. The first
prototype includes the RetroDECK framework, ES-DE, RetroArch, the RetroDECK
theme, and a small set of ARM64 RetroArch cores. It uses OpenGL through
Panfrost; Vulkan is unavailable on the target.

The work is isolated in the `arm-prototype` branches/worktrees. The standard
`main` checkouts and x86_64 manifest remain unchanged.

## Component scope

Include:

- `framework`
- `es-de` (ARM64 application binary, RetroDECK config and theme)
- `retroarch` (ARM64 application binary, config/assets, ARM64 cores)
- Initial core candidates: Gambatte, Snes9x, and Genesis Plus GX. Confirm
  architecture, core ABI, and RetroDECK's custom variants before packaging.

Exclude standalone emulators and optional integrations from the first test.

## Build blockers

The first ARM RetroArch component has been built locally and staged into the
ARM Flatpak manifest. The complete RetroDECK package is still not buildable:

1. ARM artifacts for `framework` and `es-de` are still outstanding.
2. The existing component recipes select x86_64 releases. An ARM-only
   RetroArch recipe now packages the inspected AArch64 executable with
   architecture-neutral assets and the selected ARM cores. ES-DE's RetroDECK
   fork documents an AArch64 AppImage build script; its ARM component recipe
   and artifact are still outstanding.
3. The ARM manifest stages the built RetroArch artifact in `components/`, which
   is where `install_components.sh` expects component archives. The Flatpak
   component installer will consume the ARM RetroArch archive there.
4. The ARM manifest now uses the Linux ARM64 rclone release, removes the unused
   yq binary, and drops the i386 codec extension and x86/i386 GStreamer paths.
   Review the framework and component scripts for any further x86-only runtime
   paths after the first ARM archives are available.
5. Resolve the ES-DE graphics requirement against the Chromebook GPU. The
   device reports desktop OpenGL 3.1; ES-DE's AArch64 documentation describes
   an OpenGL 3.3 path and a Mesa version override workaround for OpenGL ES-only
   devices. A version override does not add missing GPU features, so test the
   frontend on the actual Panfrost stack before accepting this path.

The RetroArch executable archive has now been inspected locally. It contains
one dynamically linked AArch64 executable, with host dependencies including
ALSA, PulseAudio, Wayland/X11, SDL2, GBM/DRM, desktop OpenGL/EGL, and V4L2.
RetroDECK's existing RetroArch config selects Vulkan, so the ARM-only config
switches to OpenGL and uses the Linux AArch64 core-download URL. The binary's
dependencies have not yet been checked inside KDE Platform 6.11.

## Next implementation steps

1. Port `framework` and ES-DE packaging, preserving the RetroDECK launcher,
   configuration, theme, and component directory layout.
2. Build explicitly for aarch64 with `flatpak-builder --arch=aarch64`, then
   resolve any packaging or KDE runtime dependency issues.
3. Install/run the local build and verify RetroDECK -> ES-DE -> RetroArch ->
   core launch, OpenGL rendering, controller input, audio, and file access.

No existing x86_64 component recipe or CI workflow has been changed. The ARM
RetroArch artifact was built and checked: its executable and three cores are
AArch64. Its compatibility with KDE Platform 6.11 has not been tested.
