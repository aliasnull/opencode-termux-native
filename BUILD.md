# Build Guide

This document describes the known build environment and Android/Termux-specific changes used for the experimental native ARM64 build of OpenCode.

> **Status:** Experimental. These notes describe the tested build based on OpenCode `2.2.5`. They are not a promise that the same steps will work unchanged with later upstream versions.

## 1. Build Information

| Item | Value |
|---|---|
| Project | OpenCode Native for Termux |
| Upstream repository | https://github.com/anomalyco/opencode |
| Upstream version | `2.2.5` |
| Upstream commit | `baa2359` |
| Bun version used | `1.4.4` |
| Target platform | Android / Termux, ARM64 (`aarch64`) |
| License | MIT |

The tested binary was produced for native Termux on ARM64. It does not require a proot or chroot Linux distribution.

## 2. Build Environment

Use a current Termux installation on a 64-bit ARM Android device. Confirm the architecture:

```sh
uname -m
```

Expected output:

```text
aarch64
```

Install the standard tools required by the upstream project and its build process. The exact dependencies can change between upstream versions, so consult the upstream documentation before building a different version.

The tested build used Bun `1.4.4`. Check the installed version with:

```sh
bun --version
```

## 3. Source Code

The upstream source repository is:

https://github.com/anomalyco/opencode

The tested source revision was commit `baa2359`, corresponding to OpenCode `2.2.5`. For a reproducible build, check out the intended revision before applying the Termux compatibility changes.

Example:

```sh
git clone https://github.com/anomalyco/opencode.git
cd opencode
git checkout baa2359
```

These commands fetch the upstream source. They do not apply the Termux-specific changes described below.

## 4. Termux Compatibility Changes

The tested build required targeted changes for Android/Termux. The following summary describes their intent; it is not a substitute for the actual patch files.

### OpenTUI package compatibility

The build script uses an alias-resolution plugin so imports from the Android-compatible OpenTUI packages resolve to their `@androidtui/*` counterparts. The aliases are scoped to imports originating from the relevant AndroidTUI package paths, rather than globally replacing every matching package import.

The tested dependency set used AndroidTUI version `0.6.8`. Compatibility with other versions has not been established.

### PTY fallback

On Android/Termux, the build identifies the Termux environment and tolerates failure to resolve the native PTY component. In that case, OpenCode can use its child-process fallback for terminal command execution.

This fallback is platform-specific and should be tested again whenever the terminal execution code or its dependencies change.

### Parcel watcher fallback

The Android/Termux build avoids relying on the Parcel watcher binding. The existing guarded fallback then uses polling instead. This is intended to keep file watching functional where the native watcher binding is unavailable.

### Bun build options

The tested build configuration sets:

```ts
bytecode: false,
splitting: false,
```

These settings were used for the tested native Termux binary. Do not assume they are appropriate for every upstream version or target platform without rebuilding and testing.

## 5. Dependency Lockfile Changes

The tested `bun.lock` changes included:

- Aliasing the relevant OpenTUI packages to `npm:@androidtui/*@0.6.8`.
- Adding the Android ARM64 optional core dependency required by that package set.
- Relaxing related peer dependency ranges from `>=0.8.0` to `>=0.6.8`.
- Clearing `trustedDependencies`.
- Removing the patch entry for `@ff-labs/fff-bun@0.10.5`.
- Updating the corresponding lockfile package entries.

These changes describe the tested dependency set, not a universal recipe for future releases. Review upstream dependency changes carefully before carrying the modifications forward.

## 6. Build and Output

The tested output binary was located at:

```text
packages/cli/dist/cli-linux-arm64/bin/opencode
```

Its recorded SHA-256 digest was:

```text
d3bd0c1e5d0e6c49febec9c8b7754a014c635d3349dfb6e8dceac5a12e8ca3a9
```

A digest identifies the exact bytes of a file. If the binary is rebuilt, even from the same source, its digest may differ. Publish the checksum that matches the actual release asset, not a checksum copied from this document.

The binary should be tested on a real ARM64 Termux device before release. Do not infer Android compatibility solely from the output filename or architecture.

## 7. Validation Performed

The tested binary was exercised in native Termux on Android ARM64. Checks included:

- Interactive model response and switching to a free model.
- Session persistence and resuming a session.
- Git integration and working-tree inspection.
- Reading, writing, editing, and diffing files.
- Running Termux environment commands and network requests.
- Error handling, permissions, grep, JSON parsing, and Python exceptions.
- SHA-256 verification and Bash compatibility.
- Multi-file analysis and consistency checks.
- Subprocess timeout, change detection, output consistency, concurrent operations, environment inheritance, and SIGTERM handling.

These are manual test results for the tested build, not a formal guarantee of complete compatibility. Zsh-specific behavior was not tested because Zsh was not installed in the test environment.

## 8. Reproducibility and Maintenance

For a future build:

1. Select and record the exact upstream commit.
2. Review upstream build scripts and dependency changes.
3. Apply the maintained Termux-specific patch set.
4. Install dependencies according to the upstream instructions and the project's lockfile policy.
5. Build for the intended Android ARM64 target using the documented Bun version.
6. Test the resulting binary on a real Termux device.
7. Record the source commit, tool versions, build changes, test results, binary size, and SHA-256 digest.
8. Publish the checksum generated from the exact release artifact.

The complete patch files and exact build commands should be maintained alongside this guide when they are prepared and verified. Do not assume the descriptive notes above alone are sufficient to reproduce the binary bit-for-bit.

## 9. Upstream and Project Status

This is an independent community project and is not an official OpenCode release. OpenCode's upstream source and licensing terms remain applicable. Preserve the upstream license and copyright notices when redistributing source-derived components or binaries, and review the applicable licenses of bundled dependencies.

- Upstream source: https://github.com/anomalyco/opencode
- Upstream license: MIT
