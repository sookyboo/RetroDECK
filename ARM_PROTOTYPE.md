# ARM64 RetroDECK prototype handoff

This is the working handoff for continuing the ARM port. The host-specific
setup and command transcripts are in
[ARM_CHROMEBOOK_ARCH_BUILD.md](ARM_CHROMEBOOK_ARCH_BUILD.md).

## Goal and current boundary

Target a full local RetroDECK Flatpak on the AArch64 Arch Linux Chromebook:

- Mali-G72 MC3 GPU using Panfrost; desktop OpenGL 3.1 and GLES 3.1 work.
- Vulkan has no driver on this host. Use RetroArch's OpenGL video driver.
- KDE Flatpak Platform and SDK 6.11, AArch64.
- The initial game-test baseline was RetroArch with Gambatte, Snes9x, and Genesis Plus GX; the current manifest packages additional standalone emulators.

The ARM Flatpak prototype now integrates the framework, ES-DE, and ARM
components through its normal first-run flow. ES-DE has launched games through
RetroArch cores and standalone emulators on the Chromebook. This remains a
hardware-specific prototype: component inclusion in the manifest does not mean
every emulator or game has been tested. See the build guide's component
inventory for packaged, tested, and remaining work. Do not describe it as a
production ARM RetroDECK release.

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

The ARM component worktree now has builders for the framework, ES-DE,
RetroArch, PICO-8, PPSSPP, Ruffle, ScummVM, Azahar, Dolphin, melonDS, MAME,
xemu, and PortMaster. The main ARM manifest stages these 13 components for
`install_components.sh`; see the component inventory in the Chromebook guide
for game-test status. Generated archives remain local and Git-ignored.

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
- The ARM component builders and manifest stage the 13 components listed
  above. The full integrated Flatpak completed first-run setup and launched
  games; individual component coverage is tracked in the Chromebook guide.
- The installed integrated prototype completed the Zenity first-run wizard,
  ran the ES-DE scraper, and launched a Game Boy game. The ARM manifest links
  ES-DE's component resources into `/app/share/es-de`, as required by its
  `/app` install prefix.
- Through ES-DE, Snes9x launches SNES games, and Genesis Plus GX launches Mega
  Drive/Genesis, Master System, Game Gear, and Sega CD games. Sega CD required
  BIOS files in RetroDECK's configured BIOS directory.
- A Bluetooth Xbox controller works; pressing LS and RS together opens the
  RetroArch menu, including its save option. Game Boy game saves also work.
- PortMaster ARM games launch on the Chromebook. `gptokeyb` needs host access to
  `/dev/uinput` to translate controller input into virtual keyboard and mouse
  events. A temporary ACL allowed the Flatpak to open the device; persistent
  host setup is documented below. Steam Deck already allows this through its
  SteamOS device rules. Steam ROM Manager remains deferred.
- The Flatpak runtime/SDK AArch64 refs are available from Flathub; see the
  exact `remote-info` commands in the Chromebook guide.

### Still outstanding

1. Verify theme/config loading. Restart persistence has been verified.
2. Test the ARM-packaged standalone emulators that do not yet have recorded
   game-launch validation, including their Configurator reset paths.
3. Choose the next components from the unported list in the Chromebook guide;
   check the x86_64 build remains unchanged as ARM support is added.

## Recommended continuation sequence

1. Validate launch and Configurator reset behavior for the ARM-packaged
   components that lack Chromebook game tests.
2. Choose the next systems from the unported component list and preserve the
   x86_64 build while broadening ARM support.
3. Record successful commands/results here and in the Chromebook build guide;
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

## PortMaster controller-to-keyboard and mouse input

PortMaster ports use `gptokeyb`/`gptokeyb2` to translate gamepad input into
keyboard and mouse events through Linux `/dev/uinput`. The kernel restricts
this device by default. RetroDECK's Flatpak already grants device access with
`--device=all`, but the host must also permit the logged-in user to open
`/dev/uinput`. See the [Linux kernel uinput documentation](https://docs.kernel.org/input/uinput.html).

### Temporary permission for the current device node

To grant the current user access until `/dev/uinput` is recreated (usually at
reboot), run:

```bash
sudo setfacl -m "u:$(id -un):rw" /dev/uinput
getfacl /dev/uinput
```

The ACL should list the current username with `rw-`. This is a quick test and
does not persist after the device node is recreated.

### Persistent permission

Add a udev rule that grants `/dev/uinput` access to the active local session.
This does not require Steam or Steam Input. It uses the same udev access
mechanism as Valve's Steam device rule:

```bash
sudo tee /etc/udev/rules.d/60-retrodeck-uinput.rules >/dev/null <<'EOF'
KERNEL=="uinput", SUBSYSTEM=="misc", TAG+="uaccess", OPTIONS+="static_node=uinput"
EOF

echo uinput | sudo tee /etc/modules-load.d/uinput.conf
sudo modprobe uinput
sudo udevadm control --reload-rules
sudo udevadm trigger --action=add --subsystem-match=misc --sysname-match=uinput
getfacl /dev/uinput
```

If the ACL is still missing, log out and back in, then check it again. This
permission allows trusted applications running as the active user to create
virtual input devices, including keyboards and mice; only enable it on systems
where that capability is intended. After changing host permissions, verify
RetroDECK can open `/dev/uinput` from inside its Flatpak.

Alternatively, if Steam device rules are already desired on the system, the
optional `steam-devices` package provides related rules on Ubuntu
(`sudo apt install steam-devices`), Fedora (`sudo dnf install steam-devices`),
and Arch Linux x86_64 (`sudo pacman -S steam-devices`). It is not a RetroDECK
dependency. Steam Deck already has the required permission through its SteamOS
device rules.

The udev rule location and behavior follow the
[ArchWiki udev documentation](https://wiki.archlinux.org/title/Udev); see also
[Valve's rule](https://github.com/ValveSoftware/steam-devices/blob/master/60-steam-input.rules)
and package listings for [Ubuntu](https://packages.ubuntu.com/noble/all/steam-devices/filelist)
and [Fedora](https://packages.fedoraproject.org/pkgs/steam-devices/steam-devices/).
