# Installation Guide

This guide explains how to install OpenCode Native for Termux on Android ARM64.

> **Important:** This is an experimental, community-maintained build. Read the release notes and verify the downloaded binary before installing it.

## 1. Requirements

- Termux installed on an Android device.
- A 64-bit ARM device. Check the architecture:

  ```sh
  uname -m
  ```

  Expected output:

  ```text
  aarch64
  ```

- Internet access.
- Enough free storage for the download and installation.

This build targets native Termux on Android ARM64. It is not intended for installation inside a proot or chroot Linux distribution.

## 2. Download the Release

Open the official project release:

**Release:** https://github.com/aliasnull/opencode-termux-native/releases/tag/v2.2.5-termux.1

The release provides these files:

- `opencode-aarch64`: OpenCode executable for Termux ARM64.
- `SHA256SUMS.txt`: SHA-256 checksum for verifying the executable.

Download both files into the same directory. You can use the following commands in Termux:

```sh
mkdir -p "$HOME/opencode-termux-download"
cd "$HOME/opencode-termux-download"

curl -fLO https://github.com/aliasnull/opencode-termux-native/releases/download/v2.2.5-termux.1/opencode-aarch64
curl -fLO https://github.com/aliasnull/opencode-termux-native/releases/download/v2.2.5-termux.1/SHA256SUMS.txt
```

If `curl` is not installed, install it with:

```sh
pkg install curl
```

## 3. Verify the Download

Before installing the executable, verify its SHA-256 checksum:

```sh
cd "$HOME/opencode-termux-download"
sha256sum -c SHA256SUMS.txt
```

Expected output:

```text
opencode-aarch64: OK
```

Do not install or execute the file if verification fails. Download the files again and retry. If the mismatch persists, stop and report the issue.

A matching checksum confirms that the file matches the published digest. It does not independently prove that the publisher or release is trustworthy.

## 4. Install OpenCode

To avoid overwriting an existing `opencode` executable, this guide initially installs the binary under the separate command name `opencode-native`.

First, check whether that command already exists:

```sh
command -v opencode-native
```

If the command already exists, inspect the existing installation before replacing anything.

Install the downloaded executable:

```sh
install -Dm755 "$HOME/opencode-termux-download/opencode-aarch64" "$PREFIX/bin/opencode-native"
```

This installs the executable into Termux's binary directory without changing your existing `opencode` command.

## 5. Verify the Installation

Run:

```sh
command -v opencode-native
opencode-native --version
```

The first command should display the path of the installed executable, usually:

```text
/data/data/com.termux/files/usr/bin/opencode-native
```

The second should display the installed OpenCode version.

If the command cannot be found, confirm that `$PREFIX/bin` is included in your `PATH`:

```sh
printf '%s\n' "$PATH"
```

Do not change unrelated shell configuration files unless necessary.

### Using the command name `opencode`

If you already have another OpenCode installation, do not overwrite it blindly. Keep using `opencode-native`, or back up and review the existing installation before deciding whether to replace it.

If no `opencode` command exists and you want to use that name, check first:

```sh
command -v opencode
```

Only if the command is not found, install the binary under that name:

```sh
install -Dm755 "$HOME/opencode-termux-download/opencode-aarch64" "$PREFIX/bin/opencode"
```

Then verify it:

```sh
opencode --version
```

## 6. Updating

Before updating, read the release notes for the target version and download its corresponding binary and checksum file.

Verify the checksum before installing the new executable.

If you installed it as `opencode-native`, update it with:

```sh
install -Dm755 "$HOME/opencode-termux-download/opencode-aarch64" "$PREFIX/bin/opencode-native"
```

Download and verify the target release's files before running this command.

The update replaces the executable, not your OpenCode configuration or session data. Do not delete configuration, state, session history, or cache directories as part of an update.

## 7. Troubleshooting

### Architecture is not `aarch64`

This build targets Android ARM64. Do not install it on an incompatible architecture or inside a proot/chroot environment.

### Checksum verification fails

Do not execute or install the file. Download the binary and checksum file again from the official release page. If verification still fails, stop and report the issue.

### `opencode-native: command not found`

Check that the executable exists:

```sh
ls -l "$PREFIX/bin/opencode-native"
```

Check your `PATH`:

```sh
printf '%s\n' "$PATH"
```

### Permission denied

Confirm that the executable has appropriate permissions:

```sh
ls -l "$PREFIX/bin/opencode-native"
```

If necessary, reinstall it using the installation command in this guide. Avoid broad permission changes to your home directory.

### Startup or runtime errors

When reporting a problem, include the OpenCode version, Android and Termux details, device architecture, and exact error output. Remove API keys, tokens, passwords, and other private information from logs.

## 8. Uninstallation

If you installed the executable using this guide, remove only that executable:

```sh
rm "$PREFIX/bin/opencode-native"
```

If you installed it as `opencode`, remove that executable only after confirming it belongs to this installation:

```sh
command -v opencode
```

Do not delete your OpenCode configuration, session history, state, or cache as part of uninstalling the executable.

The downloaded files can be removed separately if they are no longer needed:

```sh
rm -rf "$HOME/opencode-termux-download"
```

Run that command only if the directory contains no other files you want to keep.

## 9. Project Status

OpenCode Native for Termux is an independent community project, not an official OpenCode release. This release is experimental, and future versions may change.

- Project repository: https://github.com/aliasnull/opencode-termux-native
- Releases: https://github.com/aliasnull/opencode-termux-native/releases
- Upstream OpenCode repository: https://github.com/anomalyco/opencode
