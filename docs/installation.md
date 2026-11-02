# Installation Guide

This guide explains how to install OpenCode Native for Termux on Android ARM64.

> **Important:** This is an experimental, community-maintained build. Read the release notes before installing it. The automatic installer verifies the downloaded binary's SHA-256 checksum, but a matching checksum does not independently prove that the publisher or release is trustworthy.

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

## 2. Install OpenCode

Choose one of the following methods.

### Method A: Automatic Installation (Recommended)

The installer downloads the latest compatible published Termux release, verifies its checksum, checks the binary, and installs it into Termux's binary directory.

Run in Termux:

```sh
curl -fsSL https://raw.githubusercontent.com/aliasnull/opencode-termux-native/main/scripts/termux-install.sh | bash
```

If `curl` is not installed, install it first:

```sh
pkg install curl
```

**Security note:** This command downloads a script and runs it immediately. If you prefer to inspect the script first, download it and read it before executing:

```sh
curl -fsSLO https://raw.githubusercontent.com/aliasnull/opencode-termux-native/main/scripts/termux-install.sh
less termux-install.sh
bash termux-install.sh
```

The installer will stop rather than overwrite an existing `$PREFIX/bin/opencode` installation. If you already have OpenCode installed, inspect that installation and follow the updating instructions below instead.

### Method B: Manual Installation

Use this method if you prefer to download and verify the release binary yourself.

Open the project's [Releases page](https://github.com/aliasnull/opencode-termux-native/releases) and choose the release you want. The example below uses `v2.2.5-termux.1`.

Download both release files into the same directory:

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

Verify the downloaded binary before installing it:

```sh
cd "$HOME/opencode-termux-download"
sha256sum -c SHA256SUMS.txt
```

Expected output:

```text
opencode-aarch64: OK
```

Do not install or execute the file if verification fails. Download the files again and retry. If the mismatch persists, stop and report the issue.

Before installing, check whether an `opencode` command already exists:

```sh
command -v opencode
```

If the command returns a path, inspect the existing installation before continuing. Do not overwrite an existing executable unless you have confirmed it is safe to replace.

If no existing command is found, install the binary:

```sh
install -Dm755 "$HOME/opencode-termux-download/opencode-aarch64" "$PREFIX/bin/opencode"
```

This installs the executable into Termux's binary directory.

## 3. Verify the Installation

Run:

```sh
command -v opencode
opencode --version
```

The first command should show the installed executable's path, usually:

```text
/data/data/com.termux/files/usr/bin/opencode
```

The second command should display the installed OpenCode version.

If the command cannot be found, confirm that `$PREFIX/bin` is included in your `PATH`:

```sh
printf '%s\n' "$PATH"
```

Do not change unrelated shell configuration files unless necessary.

## 4. Updating OpenCode

### Automatic Update

If OpenCode was installed using this project's automatic installer, run:

```sh
curl -fsSL https://raw.githubusercontent.com/aliasnull/opencode-termux-native/main/scripts/termux-update.sh | bash
```

The updater checks the latest compatible published release, verifies the downloaded binary, and replaces the managed executable. It also includes rollback handling if the update fails.

For the same security reason as the installer, you can download and inspect the updater before running it:

```sh
curl -fsSLO https://raw.githubusercontent.com/aliasnull/opencode-termux-native/main/scripts/termux-update.sh
less termux-update.sh
bash termux-update.sh
```

If OpenCode was installed manually and the updater reports that the installation is not managed by this project, do not force an update. Review the script's supported options and confirm that `$PREFIX/bin/opencode` is the intended executable before using its `--adopt-existing` option.

### Manual Update

Before updating manually, read the release notes for the target version and download its corresponding binary and checksum file. Verify the checksum using the steps in **Method B: Manual Installation**.

If this build is installed at `$PREFIX/bin/opencode`, replace it with the verified binary:

```sh
install -Dm755 "$HOME/opencode-termux-download/opencode-aarch64" "$PREFIX/bin/opencode"
```

This command replaces the executable at that path. If the existing file belongs to another installation, back it up and confirm you want to replace it first.

Updating replaces the executable, not your OpenCode configuration or session data. Do not delete configuration, state, session history, or cache directories as part of an update.

## 5. Troubleshooting

### Architecture is not `aarch64`

This build targets Android ARM64. Do not install it on an incompatible architecture or inside a proot/chroot environment.

### Checksum verification fails

Do not execute or install the file. Download the binary and checksum file again from the project's [Releases page](https://github.com/aliasnull/opencode-termux-native/releases). If verification still fails, stop and report the issue.

### `opencode: command not found`

Check that the executable exists:

```sh
ls -l "$PREFIX/bin/opencode"
```

Check your `PATH`:

```sh
printf '%s\n' "$PATH"
```

### Permission denied

Confirm that the executable has appropriate permissions:

```sh
ls -l "$PREFIX/bin/opencode"
```

If necessary, reinstall it using the installation command in this guide. Avoid broad permission changes to your home directory.

### Startup or runtime errors

When reporting a problem, include the OpenCode version, Android and Termux details, device architecture, and exact error output. Remove API keys, tokens, passwords, and other private information from logs.

## 6. Uninstallation

If you installed this build at `$PREFIX/bin/opencode`, first confirm that the file belongs to this project:

```sh
command -v opencode
```

If you are certain it is this build and want to uninstall it, remove only the executable:

```sh
rm "$PREFIX/bin/opencode"
```

Do not delete your OpenCode configuration, session history, state, or cache as part of uninstalling the executable.

If you installed it using the automatic installer, its management marker is stored under `$PREFIX/var/lib/opencode-termux-native/`. You may remove that project's marker directory after confirming you no longer need the installer/updater to manage this installation:

```sh
rm -r "$PREFIX/var/lib/opencode-termux-native"
```

The downloaded manual-installation files can be removed separately if they are no longer needed:

```sh
rm -rf "$HOME/opencode-termux-download"
```

Run that command only if the directory contains no other files you want to keep.

## 7. Project Status

OpenCode Native for Termux is an independent community project, not an official OpenCode release. This release is experimental, and future versions may change. Installation through `pkg install` is not available yet.

- Project repository: https://github.com/aliasnull/opencode-termux-native
- Releases: https://github.com/aliasnull/opencode-termux-native/releases
- Upstream OpenCode repository: https://github.com/anomalyco/opencode
