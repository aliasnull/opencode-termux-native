# Patch Guide

This directory contains the Termux/Android-specific patches used by this project.

## Compatibility

These patches were created against the OpenCode upstream repository at commit:

- Repository: https://github.com/anomalyco/opencode
- Commit: `baa2359`
- Tested OpenCode version: `2.2.5`

They are not guaranteed to apply to other commits or versions. If the upstream source changes, review and update the patches before using them.

## Patch files

- `bun-lock.patch` updates dependency aliases and lockfile entries for the AndroidTUI packages used by this build.
- `build-script.patch` updates the CLI build script for Android/Termux compatibility, including PTY and file-watcher fallbacks, plus build options.

Apply both patches to a clean checkout of the specified upstream commit. The patches modify separate files, so either order works; the commands below apply the lockfile patch first.

## Apply and verify

Run these commands in Termux. They create a separate source checkout so you do not have to modify an existing working build directory.

```bash
git clone https://github.com/anomalyco/opencode.git ~/opencode-patch-check
cd ~/opencode-patch-check
git checkout baa2359

git apply --check ~/opencode-termux-native/patches/bun-lock.patch
git apply --check ~/opencode-termux-native/patches/build-script.patch

git apply ~/opencode-termux-native/patches/bun-lock.patch
git apply ~/opencode-termux-native/patches/build-script.patch

git diff --check
git status --short
```

The commands assume this repository is located at `~/opencode-termux-native`. If you keep it elsewhere, update the two patch paths accordingly.

`git apply --check` verifies that each patch can be applied before making changes. If either check fails, stop and inspect the error rather than forcing the patch.

After applying, `git diff --check` checks for whitespace errors. `git status --short` should show changes to `bun.lock` and `packages/cli/script/build.ts`.

## Important notes

- These patches are build inputs, not a prebuilt binary or a complete installer.
- Applying the patches does not build or install OpenCode.
- Do not run dependency installation or rebuild commands until you have reviewed the build instructions and are ready to test.
- The lockfile patch intentionally changes the `trustedDependencies` list and removes one patched dependency entry. Review these changes when auditing or updating the build.
- Keep your existing source/build directory untouched until the clean-checkout verification succeeds.
