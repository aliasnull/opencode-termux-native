# OpenCode Native for Termux

Run OpenCode natively on Android using Termux, without proot or chroot.

This project provides a prebuilt ARM64 binary of OpenCode with
Android-specific build adjustments.

> **Status:** Experimental. OpenCode `2.2.6` was built and tested on a
> real Android ARM64 device running Termux. The TUI and WebUI were both
> tested successfully. Compatibility with other devices and Android
> versions may vary.

## Features

-   Native execution on Android ARM64 (`aarch64`)
-   No proot or chroot required
-   Prebuilt binary, so compiling on your phone is unnecessary
-   Android-specific OpenTUI compatibility adjustments using AndroidTUI
    `0.8.3`
-   PTY fallback when a supported native PTY binary is unavailable
-   File-watcher polling fallback when native filesystem watching is
    unavailable

## Requirements

-   Android device with ARM64 architecture
-   Termux
-   Internet access
-   An OpenCode provider or model configuration

Check your architecture:

``` bash
uname -m
```

Expected output:

``` text
aarch64
```

## Installation

Open the [latest available
release](https://github.com/aliasnull/opencode-termux-native/releases)
and download the `opencode-aarch64` binary and `SHA256SUMS.txt`.

For detailed installation, verification, updating, and uninstallation
instructions, see the [Installation Guide](docs/installation.md).

**Current tested version:** OpenCode `2.2.6` for Termux (ARM64).

Download binaries only from this repository's official Releases page.

## Verify a Download

Download `opencode-aarch64` and `SHA256SUMS.txt` from the same release,
then run this command in the directory containing both files:

``` bash
sha256sum -c SHA256SUMS.txt
```

Proceed only if verification succeeds and the output reports
`opencode-aarch64: OK`. Do not execute a binary whose checksum does not
match.

## Build Information

  Item                  Value
  --------------------- ---------------------------------------
  OpenCode version      `2.2.6`
  Upstream repository   https://github.com/anomalyco/opencode
  Upstream commit       `dc2ffcf`
  Build tool            Bun `1.4.4`
  AndroidTUI version    `0.8.3`
  Target architecture   Android ARM64 (`aarch64`)
  License               MIT

The build includes Android-specific adjustments for OpenTUI package
resolution, PTY handling, file watching, and Bun compilation settings.

See `BUILD.md` for build notes and the `docs/` directory for additional
documentation.

## Compatibility Notes

-   This build targets Android ARM64 in Termux.
-   Compatibility with every Android device or version is not
    guaranteed.
-   PTY support may use a fallback.
-   File watching may use polling instead of native filesystem
    notifications.
-   Features that depend on unsupported native libraries may behave
    differently from desktop Linux.
-   Bash was used during testing. Zsh compatibility has not been tested.

## Troubleshooting

### Binary does not start

Check your architecture and verify the downloaded binary's checksum:

``` bash
uname -m
sha256sum opencode
```

### Permission denied

If you downloaded the binary manually, make it executable:

``` bash
chmod +x opencode
```

### Need help?

Open an issue in this repository and include your Android version,
device architecture, Termux version, OpenCode version, and exact error
message.

Never include API keys, passwords, or other secrets in issue reports.

## Credits and License

OpenCode is developed by the OpenCode contributors:

https://github.com/anomalyco/opencode

This is an independent Termux-focused build. The upstream MIT license
and copyright notice are retained. See `LICENSE` for the license terms.

## Disclaimer

This is an independent community project and is not an official release
of the OpenCode project. Use it at your own discretion.
