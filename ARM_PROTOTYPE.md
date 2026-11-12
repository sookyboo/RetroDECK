# ARM64 RetroDECK prototype

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

This is a preparation scaffold, not yet a buildable ARM package:

1. The checked out component repository has no prebuilt `artifacts/` archives
   for ES-DE or RetroArch, and no ARM component archives are present.
2. The existing component recipes select x86_64 releases. An ARM-only
   RetroArch recipe now packages the inspected AArch64 executable with
   architecture-neutral assets and the selected ARM cores. ES-DE's RetroDECK
   fork documents an AArch64 AppImage build script; its ARM component recipe
   and artifact are still outstanding.
3. `retrodeck_builder.sh` fetches the normal component release by default. The
   prototype must instead receive explicitly prepared ARM `.tar.gz` component
   archives; never feed it the current x86_64 release archives.
4. The ARM manifest is copied from the current manifest and still contains
   x86_64/amd64 and i386-specific assumptions: the GStreamer search path,
   rclone binary download, yq binary download, and i386 codec extension/path.
   Each must be removed, replaced by an architecture-neutral implementation,
   or supplied from a verified aarch64 source before building.
5. Review the framework and component scripts for any further x86-only runtime
   paths after the first ARM archives are available.

6. Resolve the ES-DE graphics requirement against the Chromebook GPU. The
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

1. Prepare ARM component artifacts in `components/linux-arm64/` using the
   existing artifact directory layout and archive names consumed by
   `install_components.sh`.
2. Build and inspect the ARM RetroArch artifact, then resolve any packaging
   or KDE runtime dependency issues. Port ES-DE packaging while preserving its
   RetroDECK launcher, configuration, theme, and component directory layout.
3. Verify that each selected core is a 64-bit ARM shared library compatible
   with the RetroArch build; omit custom cores until ARM builds are confirmed.
4. Resolve the manifest architecture-specific dependencies and paths, then
   build explicitly for aarch64 with `flatpak-builder --arch=aarch64` and the
   provided ARM archives.
5. Install/run the local build and verify RetroDECK -> ES-DE -> RetroArch ->
   core launch, OpenGL rendering, controller input, audio, and file access.

No existing x86_64 component recipe or CI workflow has been changed. The
Alchemist artifact output now accepts an environment override so the ARM
artifact can be kept separate. No packages were installed and no build was
run; the ARM RetroArch recipe and component scripts are staged but unexecuted.
