# Uninstallation Guide

This guide explains how to remove OpenCode Native for Termux without
accidentally deleting unrelated installations or personal data.

> **Important:** OpenCode `2.2.6` was built and tested on native Android
> ARM64 Termux. The project remains experimental. Use the uninstall
> instructions that match the installation method and release you
> installed. Normal uninstall removes the project executable and its
> installer ownership metadata only. Full cleanup is a separate,
> destructive option that removes personal OpenCode data.

## 1. Before Uninstalling

Before removing OpenCode:

1.  Close any running OpenCode sessions.
2.  Back up configuration, authentication details, or session data you
    want to keep.
3.  Identify how OpenCode was installed and which executable you intend
    to remove.
4.  Check whether another OpenCode installation uses the same executable
    path.

Do not assume that every file named `opencode` belongs to this project.

## 2. Identify the Active Executable

Run:

``` sh
command -v opencode
```

If a path is returned, inspect it:

``` sh
ls -l "$(command -v opencode)"
```

For the native Termux installer, the usual executable path is:

``` text
$PREFIX/bin/opencode
```

The active command path alone does not prove which installer created it.
If you have multiple installations, review your shell `PATH` and the
instructions for the installation method you used.

If `command -v opencode` returns no path, the executable may already be
removed or may not be on your `PATH`.

## 3. Normal Uninstall (Keep Your Data)

Use this option if you want to remove OpenCode Native for Termux but
keep your configuration, authentication, sessions, state, and cache.

The native Termux installer stores an ownership record here:

``` text
$PREFIX/var/lib/opencode-termux-native/managed-install
```

That file contains the version recorded by the installer. It is separate
from the OpenCode executable.

### 3.1 Inspect the executable and ownership record

Run:

``` sh
echo "=== Executable ==="
ls -l "$PREFIX/bin/opencode" 2>&1

echo
echo "=== Installer ownership record ==="
ls -l "$PREFIX/var/lib/opencode-termux-native/managed-install" 2>&1
```

If the ownership record exists, inspect its contents:

``` sh
cat "$PREFIX/var/lib/opencode-termux-native/managed-install"
```

Only continue if you recognize the record as belonging to the OpenCode
Native for Termux installer and have confirmed that
`$PREFIX/bin/opencode` is the executable you intend to remove.

### 3.2 Remove the project executable and ownership record

If both belong to this project, run:

``` sh
rm "$PREFIX/bin/opencode"
rm "$PREFIX/var/lib/opencode-termux-native/managed-install"
rmdir "$PREFIX/var/lib/opencode-termux-native" 2>/dev/null || true
```

The `rmdir` command removes the metadata directory only if it is empty.
It will not remove other files inside it.

If you installed the executable at a different path, do not use the
example above. Remove only the exact executable you have positively
identified as belonging to this project.

### 3.3 Refresh the shell command cache and verify

Run:

``` sh
hash -r 2>/dev/null || true
command -v opencode
```

If another OpenCode installation is on your `PATH`, `command -v` may
still show its path. That does not necessarily mean this project was not
uninstalled.

## 4. Fix Stale Ownership Metadata

You may see this installer error when reinstalling:

``` text
Ownership metadata already exists .../managed-install while the executable is missing. Inspect it before installing.
```

This means the installer ownership record remains, but the executable at
`$PREFIX/bin/opencode` is missing. It can happen if the executable was
manually deleted or removed without completing the normal uninstall.

First inspect both paths:

``` sh
echo "=== Executable ==="
ls -l "$PREFIX/bin/opencode" 2>&1

echo
echo "=== Ownership record ==="
ls -l "$PREFIX/var/lib/opencode-termux-native/managed-install" 2>&1

echo
echo "=== Ownership record contents ==="
cat "$PREFIX/var/lib/opencode-termux-native/managed-install"
```

If the executable is missing and you have confirmed that the ownership
record is the leftover record from this project's installer, remove only
that record:

``` sh
rm "$PREFIX/var/lib/opencode-termux-native/managed-install"
rmdir "$PREFIX/var/lib/opencode-termux-native" 2>/dev/null || true
```

You can then run the installation command from the project's README or
release instructions again.

**Do not remove the ownership record if you are unsure where it came
from.** If the executable still exists, or the record contents are
unexpected, stop and inspect the installation before changing anything.

## 5. Full Cleanup (Remove Configuration and User Data)

Use this option only if you want to completely remove OpenCode's local
data from your Termux home directory as well as the native Termux
executable and installer metadata.

> **Warning:** This permanently deletes local configuration, saved
> authentication information, session history, state, and cache. Back up
> anything you may need. This may also remove data shared by another
> OpenCode installation that uses the same directories.

Common OpenCode data locations include:

``` text
~/.config/opencode/
~/.local/share/opencode/
~/.local/state/opencode/
~/.cache/opencode/
~/.local/share/opentui/
```

Review the directories before deleting them:

``` sh
for path in \
  "$HOME/.config/opencode" \
  "$HOME/.local/share/opencode" \
  "$HOME/.local/state/opencode" \
  "$HOME/.cache/opencode" \
  "$HOME/.local/share/opentui"
do
  if [ -e "$path" ]; then
    echo
    echo "=== $path ==="
    ls -la "$path"
  fi
done
```

If you have backed up anything important and are certain you want to
delete all of the listed data, run:

``` sh
rm -rf \
  "$HOME/.config/opencode" \
  "$HOME/.local/share/opencode" \
  "$HOME/.local/state/opencode" \
  "$HOME/.cache/opencode" \
  "$HOME/.local/share/opentui"
```

This command removes only the listed paths. Review them carefully before
running it. If you want to keep any of these directories, remove that
path from the command.

### 5.1 Remove downloaded installer files (optional)

If you used the project instructions and no longer need the downloaded
release files, inspect the download directory:

``` sh
ls -la "$HOME/opencode-termux-download"
```

Only if it contains files you no longer need, remove that directory:

``` sh
rm -rf "$HOME/opencode-termux-download"
```

Do not run this if you keep other files in that directory.

## 6. Verify the Result

Check whether another `opencode` command is still available:

``` sh
hash -r 2>/dev/null || true
command -v opencode
```

Interpret the result carefully:

-   **No output:** The shell cannot find an `opencode` command on its
    current `PATH`.
-   **A path is shown:** Another installation may still be present, or
    the intended executable was not removed.

For the normal uninstall, the project executable and its ownership
record should be absent. Verify with:

``` sh
ls -l "$PREFIX/bin/opencode" 2>&1
ls -l "$PREFIX/var/lib/opencode-termux-native/managed-install" 2>&1
```

For full cleanup, check the data directories you chose to remove. Do not
delete other copies merely to make `command -v opencode` return no
output.

## 7. Troubleshooting

### The command still exists after uninstalling

Check the path returned by `command -v opencode`. You may have another
installation earlier or later in your `PATH`. Remove only the copy you
have positively identified as belonging to this project.

### The installer reports that ownership metadata already exists

Follow [Section 4](#4-fix-stale-ownership-metadata). Inspect the
metadata contents first. Remove the marker only after confirming it is a
stale record from this project's installer and the project executable is
missing.

### The command is no longer available, but configuration remains

This is expected after a normal uninstall. The executable and installer
metadata are removed, but personal configuration, sessions, state, and
cache are preserved. Use [Section
5](#5-full-cleanup-remove-configuration-and-user-data) only if you
intentionally want to delete them.

### You are unsure which files belong to this project

Stop before deleting anything. Review the original installation method,
shell `PATH`, and file locations. If you need help, share the relevant
paths and command output after removing private information.

## 8. Important Safety Notes

-   Normal uninstall should not delete personal configuration,
    authentication details, session history, state, or cache.
-   Full cleanup is optional and destructive. Review every path before
    running `rm -rf`.
-   Never use broad commands such as `rm -rf "$HOME"` or remove the
    Termux prefix to uninstall one application.
-   Do not remove another OpenCode installation unless you intentionally
    want to uninstall it too.
-   Do not share credentials, tokens, or private session data when
    asking for help.

## 9. Project Status

OpenCode Native for Termux is an independent community project, not an
official OpenCode release. OpenCode `2.2.6` was built successfully and
the TUI and WebUI were tested on native Android ARM64 Termux. The
project remains experimental, and exact uninstall steps may differ by
release and installation method. Use the instructions that match the
release you installed.

-   Project repository:
    https://github.com/aliasnull/opencode-termux-native
