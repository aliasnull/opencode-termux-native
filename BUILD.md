# Build Guide

This document records the tested native Android/Termux ARM64 build of
OpenCode and the Termux-specific changes carried in this project.

> **Status:** Experimental. OpenCode `2.2.6` was built successfully on
> native Termux for ARM64. The TUI and WebUI were both launched and
> tested successfully. This does not guarantee compatibility with every
> Android device or future upstream release.

## 1. Build Information

| Item | Value |
|---|---|
| Project | OpenCode Native for Termux |
| Upstream repository | https://github.com/anomalyco/opencode |
| Upstream version | `2.2.6` |
| Upstream commit | `dc2ffcf` |
| Bun version used | `1.4.4` |
| AndroidTUI version | `0.8.3` |
| Target platform | Android / Termux, ARM64 (`aarch64`) |
| License | MIT |

The build targets native Termux on ARM64. It does not require a proot or
chroot Linux distribution.

## 2. Build Environment

Use a current Termux installation on a 64-bit ARM Android device.
Confirm the architecture:

``` sh
uname -m
```

Expected output:

``` text
aarch64
```

The tested build used Bun `1.4.4`. Check the installed version with:

``` sh
bun --version
```

Install the standard tools required by the upstream project and this
repository's build process. Requirements can change between upstream
versions, so review the package scripts and build instructions before
building a different revision.

## 3. Source Code

The upstream source repository is:

https://github.com/anomalyco/opencode

The tested source revision was OpenCode `2.2.6`, commit `dc2ffcf`.

The temporary v2.2.6 workspace used for the tested build contained the
upstream source together with the Termux-specific compatibility changes
described below. The main repository is an independent Termux project,
not an official OpenCode repository or a fork intended to track upstream
unchanged.

For a reproducible build, use the recorded upstream revision and the
corresponding Termux changes. Do not assume that checking out the
upstream commit alone produces a working native Termux build.

## 4. Termux Compatibility Changes

The v2.2.6 build included targeted changes for Android/Termux. The key
confirmed dependency and build-script changes are summarized here.

### AndroidTUI package compatibility

The build uses the Android-compatible `@androidtui/*` packages at
version `0.8.3`. The build script includes an alias-resolution plugin
that remaps relevant bare `@opentui/*` imports to their `@androidtui/*`
counterparts when the importer is inside the AndroidTUI package paths.
This avoids globally rewriting unrelated OpenTUI imports.

The AndroidTUI packages used by the tested dependency set included:

-   `@androidtui/core`
-   `@androidtui/keymap`
-   `@androidtui/solid`
-   `@androidtui/core-android-arm64`

### Other platform compatibility changes

The Termux compatibility work also carries platform-specific handling
for native Android limitations, including terminal process handling and
file watching. These changes should be reviewed in the current source
before rebasing onto another upstream revision.

Do not assume that a compatibility change remains necessary or behaves
identically after upstream changes. Rebuild and test on a real Termux
ARM64 device after modifying the relevant code or dependencies.

### Bun build options

The Termux build configuration includes platform-specific build
settings. Review the current `packages/cli/script/build.ts` before
changing or overriding its options. Do not copy build settings from an
older upstream revision without checking the current script.

## 5. Dependency and Lockfile Changes

For v2.2.6, the dependency mapping was updated in `package.json` and
`bun.lock` was regenerated using Bun `1.4.4`.

The AndroidTUI dependency set was updated from the earlier `0.6.8`
series to `0.8.3`. The regenerated lockfile was successfully installed
with:

``` sh
bun install --frozen-lockfile --minimum-release-age=0
```

The old `bun-lock.patch` from the v2.2.5 setup is obsolete and is not
part of the current v2.2.6 patch set. The current dependency state is
represented by `package.json` and `bun.lock`; do not reapply the old
lockfile patch.

When updating dependencies in the future:

1.  Review upstream dependency changes.
2.  Update the relevant dependency mappings.
3.  Regenerate `bun.lock` with the project's Bun version.
4.  Run the frozen-lockfile install.
5.  Build and test the resulting application on native Termux.

## 6. Build Output

The tested CLI binary was produced successfully for native
Android/Termux ARM64.

The expected build output location is:

``` text
packages/cli/dist/cli-linux-arm64/bin/opencode
```

Generate a SHA-256 digest from the exact binary intended for release:

``` sh
sha256sum packages/cli/dist/cli-linux-arm64/bin/opencode
```

Do not publish a checksum copied from an earlier build. A rebuild can
produce different binary bytes, even when the source revision is
unchanged.

## 7. Validation Performed

The OpenCode `2.2.6` build completed successfully in native Termux on
ARM64.

The user verified that:

-   The TUI launched and worked.
-   The WebUI launched and worked.

These checks confirm the tested build's basic operation in the tested
environment. They are not a formal guarantee of complete compatibility
across all devices, Android versions, or workflows. Additional testing
should be performed before publishing a release.

## 8. Reproducibility and Maintenance

For a future build:

1.  Select and record the exact upstream commit.
2.  Review upstream build scripts and dependency changes.
3.  Carry forward only the Termux-specific changes still required by
    that revision.
4.  Update `package.json` and regenerate `bun.lock` when dependency
    mappings change.
5.  Install dependencies using the project's lockfile policy.
6.  Build for the intended Android ARM64 target using the documented Bun
    version.
7.  Test the resulting binary on a real native Termux device.
8.  Record the source commit, tool versions, dependency changes, test
    results, binary size, and SHA-256 digest.
9.  Publish the checksum generated from the exact release artifact.

Keep the Termux-specific source changes and maintained patch files
aligned. A patch file should be retained only when it is still needed to
reproduce or apply a current Termux change. Remove obsolete patches when
their changes have been incorporated into the current source or
dependency files.

## 9. Upstream and Project Status

This is an independent community project and is not an official OpenCode
release. OpenCode's upstream source and licensing terms remain
applicable. Preserve upstream license and copyright notices when
redistributing source-derived components or binaries, and review the
applicable licenses of bundled dependencies.

-   Upstream source: https://github.com/anomalyco/opencode
-   Upstream license: MIT
