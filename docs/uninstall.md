# Uninstallation Guide

This guide explains how to remove OpenCode Native for Termux without accidentally deleting unrelated installations or personal data.

> **Important:** The project is experimental. Use the exact uninstall instructions provided with the release you installed. Do not run destructive cleanup commands unless you have confirmed every path they affect.

## 1. Before Uninstalling

Before removing the executable:

1. Close any running OpenCode sessions.
2. Make a backup of important configuration or session data if you need to keep it.
3. Identify how OpenCode was installed and which executable you intend to remove.
4. Check whether another OpenCode installation uses the same executable path.

Do not assume that every file named `opencode` belongs to this project.

## 2. Identify the Active Executable

Run:

```sh
command -v opencode
```

If a path is returned, inspect it before taking any action. For example:

```sh
ls -l "$(command -v opencode)"
```

This helps identify the active command, but it does not by itself prove which installer created it. If you have multiple installations, review your shell `PATH` and the instructions for the installation method you used.

If the command returns no path, the executable may already be removed or may not be on your `PATH`.

## 3. Use the Release's Uninstaller

If the release you installed includes a project-provided uninstall script, review that script before running it and follow the instructions published for that release.

The project's uninstall script should remove only files installed by this project. It should not delete unrelated executables, user configuration, session history, state, or cache directories.

Do not run a guessed download-and-execute command or use an unverified script. If no verified uninstaller is available, identify the exact installed executable path and use the manual method below only after confirming ownership.

## 4. Manual Removal of the Executable

Use this method only if you have confirmed the exact executable path and know it belongs to this project.

For example, if you installed the project binary to `$PREFIX/bin/opencode`, inspect that exact file first:

```sh
ls -l "$PREFIX/bin/opencode"
```

Only after confirming that this is the binary you want to remove, remove that single file:

```sh
rm "$PREFIX/bin/opencode"
```

Do not run this example blindly. The path may refer to another OpenCode installation. If you installed the binary somewhere else, follow the instructions for that location instead.

After removal, check command resolution:

```sh
command -v opencode
```

If another installation exists on your `PATH`, the command may still return a path. That does not necessarily mean the uninstall failed.

## 5. Preserve Configuration and User Data

Uninstalling the executable should not require deleting personal OpenCode data. Typical Termux locations include:

```text
~/.config/opencode/
~/.local/share/opencode/
~/.local/state/opencode/
~/.cache/opencode/
~/.local/share/opentui/
```

These directories may contain configuration, authentication details, sessions, state, or cache. Keep them unless you have a separate, deliberate reason to remove specific data.

If you want to clean up user data, first review the contents and make a backup. Data cleanup is separate from removing the executable and should never be performed automatically by a routine uninstall.

## 6. Verify the Result

After uninstalling:

```sh
command -v opencode
```

Interpret the result carefully:

- **No output:** The shell cannot find an `opencode` command on its current `PATH`.
- **A path is shown:** Another installation may still be present, or the intended executable was not removed.

If needed, inspect the returned path before making any further changes. Do not delete other copies merely to make the command disappear.

## 7. Troubleshooting

### The command still exists after uninstalling

Check the path returned by `command -v opencode`. You may have another installation earlier or later in your `PATH`. Remove only the copy you have positively identified as belonging to this project.

### The command is no longer available, but configuration remains

This is expected. Uninstalling the binary does not need to remove your configuration, sessions, state, or cache.

### You are unsure which files belong to this project

Stop before deleting anything. Review the original installation method, shell `PATH`, and file locations. If you need help, share the relevant paths and command output after removing private information.

## 8. Important Safety Notes

- Never use broad commands such as `rm -rf ~/.config/opencode` as a routine uninstall step.
- Do not delete your home directory, Termux prefix, or package-managed files to remove one application.
- Do not remove another OpenCode installation unless you intentionally want to uninstall it too.
- Do not share credentials or private session data when asking for help.

## 9. Project Status

OpenCode Native for Termux is an independent community project, not an official OpenCode release. Exact uninstall steps may differ by release and installation method. Use the instructions that match the release you installed.

- Project repository: https://github.com/aliasnull/opencode-termux-native
