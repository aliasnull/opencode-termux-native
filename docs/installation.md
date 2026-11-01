# Installation Guide

This guide describes the planned installation flow for OpenCode Native for Termux.

> **Important:** This project is experimental. The GitHub Release assets and installation script may not be available yet. Do not run placeholder commands or assume that a release has been published. Follow the instructions for the specific release once its assets and checksums are announced.

## 1. Requirements

- Termux installed on an Android device.
- A 64-bit ARM device. Check the architecture with:

  ```sh
  uname -m
  ```

  The expected output is:

  ```text
  aarch64
  ```

- Network access to download the release asset.
- Enough free storage to download and install the binary.

This project targets native Termux on Android ARM64. It is not intended as a guide for installing inside a proot or chroot Linux distribution.

## 2. Choose a Release

When a release is published, open the project's GitHub Releases page and read the notes for that exact version.

Confirm the release provides an asset built for Android/Termux ARM64 and a published SHA-256 checksum. Do not download a binary from an unrelated mirror or use a checksum copied from a different release.

**Releases page:** https://github.com/aliasnull/opencode-termux-native/releases

If no release is available, the installation process is not ready yet. Do not guess asset names or use commands copied from an older version of this guide.

## 3. Download and Verify

Use the exact asset name and checksum file specified by the release notes. Before installing, verify the downloaded file's SHA-256 digest against the value published for that same asset.

For a downloaded file, Termux commonly provides `sha256sum`. Example verification command:

```sh
sha256sum downloaded-file
```

Replace `downloaded-file` with the actual downloaded filename. Compare the complete output hash with the release's published SHA-256 value. A matching hash helps confirm file integrity, but it does not by itself prove that a release is trustworthy.

**Do not continue if the checksum does not match.** Delete the incomplete or mismatched download and investigate before trying again.

## 4. Install

The recommended installation method and exact commands will be documented here once the release asset names and installation script are finalized and tested.

Until then:

- Do not assume a particular archive or binary filename.
- Do not run a guessed `curl | bash` command.
- Do not overwrite an existing `$PREFIX/bin/opencode` installation without first deciding how to back it up.
- Do not delete OpenCode configuration, sessions, state, or cache directories as part of installation.

The installer should verify the platform and architecture, verify the release checksum, and install the binary to the intended Termux executable directory.

## 5. Verify the Installation

After installation, run:

```sh
command -v opencode
opencode --version
```

The first command should show the path of the installed executable. The second should print the installed OpenCode version.

If the shell cannot find the command, confirm that the install location is included in your `PATH` and that the executable has appropriate permissions. Avoid changing unrelated shell configuration files unless necessary.

## 6. Updating

Before upgrading, read the release notes for the target version and verify the new asset's checksum.

The finalized update process should preserve the user's existing OpenCode configuration and session data. Do not manually delete configuration or data directories to troubleshoot an upgrade unless you have a backup and understand the consequences.

## 7. Troubleshooting

### Architecture is not `aarch64`

This build targets Android ARM64. Do not install the ARM64 release on an incompatible device or environment.

### Checksum mismatch

Do not execute or install the file. Download the asset again from the official project release page and verify it against that release's published checksum. If the mismatch persists, stop and report the issue.

### `opencode: command not found`

Check the installation path with `command -v opencode` and inspect your `PATH`. If the installation script was used, consult its instructions for the selected release.

### Permission denied

Confirm that the file was installed to an appropriate executable location and has executable permissions. Do not apply broad permission changes to your home directory.

### Startup or runtime errors

Include the OpenCode version, Android and Termux details, device architecture, and exact error output when reporting the problem. Remove API keys, tokens, passwords, and other private information from logs.

## 8. Uninstallation

Use the project's dedicated uninstall instructions once they are published. Avoid removing files manually until you know which files belong to this installation.

Uninstalling the executable should not require deleting user configuration, session history, state, or cache. Back up important data before making changes.

## 9. Project Status

OpenCode Native for Termux is an independent community project, not an official OpenCode release. Installation details may change between releases. Always follow the release notes and instructions for the exact version you intend to install.

- Project repository: https://github.com/aliasnull/opencode-termux-native
- Upstream OpenCode repository: https://github.com/anomalyco/opencode
