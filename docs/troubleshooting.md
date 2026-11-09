# Troubleshooting

This guide lists common issues that may occur when using OpenCode Native
for Termux. The OpenCode `2.2.6` build is experimental and was tested on
native Android ARM64 Termux. The TUI and WebUI were both launched and
tested successfully in the tested environment. Behavior can still vary
by release, Android version, device, provider, and configuration.

Before troubleshooting, note the installed OpenCode version and keep a
copy of any important configuration or session data. Avoid deleting
application data as a first step.

## 1. `opencode: command not found`

The shell cannot find the executable.

1.  Check whether the command is available:

    ``` sh
    command -v opencode
    ```

2.  Check that the installation directory is included in `PATH`.

3.  If you recently installed the binary, open a new shell or follow the
    instructions for your shell to refresh its command lookup.

4.  Confirm that the installation completed successfully.

Do not delete configuration or session directories to solve a command
lookup issue.

## 2. Architecture or Executable Format Error

This project targets native Termux on 64-bit ARM Android.

Check the device architecture:

``` sh
uname -m
```

The expected output is:

``` text
aarch64
```

If the architecture differs, do not install the ARM64 release. An error
such as an executable-format error may mean the binary was built for a
different platform or architecture. Verify that you downloaded the
correct release asset.

## 3. Checksum Verification Failed

Do not run or install a binary if its SHA-256 digest does not match the
checksum published for that exact release asset.

-   Confirm that you are comparing the correct file with the matching
    release checksum.
-   Download the asset again from the project's official release page.
-   Check that the download completed.
-   If the mismatch continues, stop and report it with the release
    version and asset name.

Never use a checksum copied from a different version.

## 4. OpenCode Does Not Start

If the executable exists but startup fails:

1.  Run `opencode --version` to check whether the binary can start and
    report its version.
2.  Read the full error message.
3.  Confirm that the binary is from a release intended for native Termux
    ARM64.
4.  Check the release notes for known limitations.
5.  If the issue began after an update, preserve the current files and
    review the update steps before making further changes.

Do not remove configuration, state, sessions, or cache directories as a
first-line fix.

## 5. TUI or WebUI Problems

The OpenCode `2.2.6` build was successfully launched in both TUI and
WebUI modes during testing. This confirms those modes worked in the
tested environment, but does not guarantee that every device, terminal,
browser, or workflow will behave identically.

When reporting a TUI or WebUI issue, include:

-   Whether the issue occurs in TUI, WebUI, or both.
-   The command or steps used to start OpenCode.
-   The complete error output, with secrets removed.
-   The OpenCode version and release asset used.
-   The output of `uname -m`.
-   Whether the issue happens consistently.

## 6. Terminal or Command Execution Problems

The Termux build includes a fallback path for terminal command
execution, but not every terminal-related feature is guaranteed to work
in every environment.

When reporting a terminal issue, include:

-   The exact command that failed, with secrets removed.
-   The complete error output.
-   The OpenCode version and release asset used.
-   The output of `uname -m`.
-   Whether the issue happens consistently.

Do not run unknown commands copied from an error message or issue report
without understanding what they do.

## 7. Provider Authentication or Model Errors

Authentication and model availability depend on the provider and your
account.

-   Confirm that the provider supports the model identifier you
    selected.
-   Check the provider's current status, account access, quota, and
    authentication instructions.
-   Confirm that credentials were configured using the supported method.
-   If a key may have been exposed, revoke or rotate it with the
    provider.

Do not post API keys, access tokens, passwords, or full private
configuration in a public issue. Free model availability and usage
limits can change at any time.

## 8. Configuration Errors

If OpenCode reports a configuration error:

1.  Read the error message carefully.
2.  Check the configuration against the documentation for your installed
    version.
3.  Review your most recent change.
4.  If necessary, restore a backup of the specific file you edited.

Avoid replacing your entire configuration directory with a sample from
another version. Do not delete user data to fix a syntax or setting
issue.

Typical Termux user data locations include:

``` text
~/.config/opencode/
~/.local/share/opencode/
~/.local/state/opencode/
~/.cache/opencode/
```

The exact locations may vary. These directories can contain valuable
settings, sessions, or other user data.

## 9. File Watching or Live Updates Behave Unexpectedly

The Termux build uses a polling fallback for the Parcel watcher path.
File-change detection timing may therefore differ from a desktop
environment.

If changes are not detected:

-   Confirm that the file was saved to the expected path.
-   Reproduce the issue with a small test project if possible.
-   Restart the relevant operation and check whether the issue persists.
-   Report the steps and timing that reproduce the behavior.

Do not claim a general watcher failure based on one unrelated file or
project.

## 10. Upgrade Problems

Before upgrading, back up important configuration and data. Verify the
checksum of the new release and follow its release-specific
instructions.

If the new version fails:

-   Keep the error output.
-   Record the old and new versions.
-   Avoid deleting configuration or session data.
-   Follow documented rollback instructions, if available.

Do not overwrite an existing installation with an unverified binary.

## 11. When Reporting a Bug

Open an issue in the project repository and include relevant
information:

-   OpenCode Native for Termux release/version.
-   Device architecture from `uname -m`.
-   Android and Termux versions, if known.
-   Shell in use, if relevant.
-   Steps to reproduce.
-   Expected behavior and actual behavior.
-   Complete error output, with private information removed.
-   Whether the problem occurs every time.

Do not include API keys, tokens, passwords, private files, session
databases, or personal information. Search existing issues before
opening a duplicate.

Project issues:
https://github.com/aliasnull/opencode-termux-native/issues

## 12. Still Stuck?

Check the release notes and the upstream OpenCode documentation for
version-specific guidance:

-   Project repository:
    https://github.com/aliasnull/opencode-termux-native
-   Upstream repository: https://github.com/anomalyco/opencode
-   Upstream website: https://opencode.ai/

This is an independent community project, not an official OpenCode
release. A fix that works on desktop Linux may not apply to native
Termux.
