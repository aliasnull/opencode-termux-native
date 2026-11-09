# Patch Guide

This directory contains the Termux/Android-specific build patch retained
by this project.

## Current tested source

The current project source is based on:

-   Repository: https://github.com/anomalyco/opencode
-   OpenCode version: `2.2.6`
-   Upstream commit: `dc2ffcf`
-   AndroidTUI version: `0.8.3`

The main repository and the temporary v2.2.6 workspace were compared,
and their `packages/cli/script/build.ts` files were identical. A fresh
native Termux build from the main repository also completed
successfully, producing `opencode v2.2.6` for `linux-arm64` with the
WebUI enabled.

## Retained patch

### `build-script.patch`

This is a historical Termux/Android build patch. It contains
build-script adaptations, including the AndroidTUI import alias handling
that maps relevant `@opentui/*` imports to the `@androidtui/*` packages
used by this project. The patch also records earlier Termux-specific
build adjustments.

The v2.2.6 source already contains the required build-script changes.
The current `packages/cli/script/build.ts` has been verified against the
temporary v2.2.6 workspace, and the main repository builds successfully.
Therefore:

-   Do not apply `build-script.patch` again to the current v2.2.6
    source.
-   Keep the patch as a historical reference for reviewing or porting
    the Termux-specific changes to a future upstream source update.
-   Before using it with another upstream version, inspect the target
    source and review the patch. Do not force-apply it.

## Removed patch

`bun-lock.patch` was part of the earlier v2.2.5 setup. It became
obsolete after the dependency aliases and lockfile were updated for the
v2.2.6 source and Bun 1.4.4. It is no longer included in this
repository.

## Build verification

The main repository was built natively in Termux with:

``` bash
OPENCODE_VERSION=2.2.6 OPENCODE_TARGET=linux-arm64 bun run --cwd packages/cli build -- --skip-install
```

The build completed with the WebUI enabled. The generated binary
reported:

``` text
opencode v2.2.6
```

The resulting CLI binary was generated at:

``` text
packages/cli/dist/cli-linux-arm64/bin/opencode
```

Build output under `dist/` is ignored by Git and should not be
committed.

## Important notes

-   These patches are source-level build adjustments, not prebuilt
    binaries or a complete installer.
-   The current v2.2.6 source already includes the required build-script
    changes.
-   When updating to a new upstream version, review the relevant source
    changes and validate the Termux build before updating or applying
    any patch.
-   Keep a known-good source/build workspace until the updated source
    has been built and tested successfully.
