# Contributing

Thanks for your interest in contributing to OpenCode Native for Termux.

This is an independent community project that documents and tests an experimental native ARM64 build of OpenCode for Termux on Android. Contributions that improve correctness, reproducibility, documentation, and safe installation are welcome.

## Before Opening an Issue

Please search existing issues first to avoid duplicates. When reporting a problem, include as much relevant information as possible:

- Device architecture, such as the output of `uname -m`.
- Android version and Termux version, if known.
- OpenCode version and the project release or commit you are using.
- The exact command you ran and the complete error output.
- Whether the problem occurs with a clean configuration or an existing setup.
- Steps to reproduce the problem.

Remove API keys, access tokens, passwords, personal information, and other secrets from logs before posting them. Do not attach private configuration files or databases.

## Reporting Compatibility Problems

This project targets native Termux on Android ARM64. It does not target proot or chroot Linux environments as its primary setup.

When reporting a compatibility issue, state whether it occurs in native Termux and whether it is reproducible. Please avoid claiming support for architectures, Android versions, shells, or environments that have not been tested.

## Proposing Changes

For a code or documentation change:

1. Keep the change focused on one issue or improvement.
2. Explain the reason for the change and any relevant background.
3. Update documentation when behavior, installation, configuration, or troubleshooting steps change.
4. Avoid including generated build output, large binaries, caches, `node_modules`, credentials, or personal configuration.
5. Do not remove or overwrite user data as part of installation or cleanup changes.
6. Preserve upstream license and copyright notices where applicable.

If your change modifies build behavior or dependencies, document the upstream revision, affected files, and reason for the change.

## Testing Expectations

Before submitting a change, test the affected behavior on a real ARM64 Android device running Termux whenever possible.

Depending on the change, include relevant checks such as:

- Architecture and version checks.
- Build or installation validation.
- Interactive startup and model response.
- Terminal command execution.
- File reading, writing, and editing.
- Git integration.
- Session persistence and resume.
- Upgrade and uninstall behavior.
- Checksum verification for release artifacts.

Clearly state which tests were run, which were not run, and any limitations. Do not describe a change as tested on a platform if it was not actually tested there.

## Pull Requests

A useful pull request should include:

- A concise summary of the change.
- The problem it solves and why the approach was chosen.
- Any compatibility or security implications.
- Test steps and their results.
- Documentation updates, if needed.

Keep pull requests focused and avoid unrelated formatting or refactoring.

## Security Issues

Please do not publish secrets, API keys, credentials, or exploitable details involving an unpatched security issue in a public issue. For sensitive reports, use a private reporting channel if the repository owner has provided one. Do not assume a private security reporting channel exists unless it is explicitly available.

Never include someone else's private data or configuration in a report.

## Scope and Project Status

This is an independent community project and is not an official OpenCode release. Upstream changes may affect compatibility. Please verify behavior against the specific version and revision under discussion.

Contributions are welcome, but proposed changes should not claim official endorsement by the upstream project.
