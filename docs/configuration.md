# Configuration Guide

This guide covers configuration for OpenCode Native for Termux. The application is based on upstream OpenCode, so configuration behavior can change with upstream releases. If an option behaves differently in your installed version, consult the documentation for that version.

## 1. Configuration and Data Locations

OpenCode uses separate locations for configuration, application data, state, and cache. In a typical Termux setup, these are under your home directory:

| Purpose | Typical location |
|---|---|
| Configuration | `~/.config/opencode/` |
| Application data and sessions | `~/.local/share/opencode/` |
| State | `~/.local/state/opencode/` |
| Cache | `~/.cache/opencode/` |

OpenTUI may also create data under:

```text
~/.local/share/opentui/
```

These locations may vary with environment variables, application versions, or custom settings. Treat them as user data. Do not delete them as a routine installation, upgrade, or uninstall step.

## 2. Configuration Files

OpenCode supports configuration through its documented configuration files and environment variables. The exact file names, supported fields, and precedence rules can change between versions.

Before editing a configuration file:

1. Read the configuration documentation for your installed OpenCode version.
2. Back up the file you plan to edit.
3. Make one change at a time.
4. Validate the configuration by starting OpenCode and checking for errors.

Do not copy an example configuration from another version without checking whether its fields are supported.

## 3. Providers and Models

OpenCode can work with supported model providers. Provider setup depends on the provider, the authentication method, and the version of OpenCode.

General workflow:

1. Choose a provider supported by your installed version.
2. Follow the provider's current setup instructions.
3. Add credentials using the documented authentication method.
4. Select a model that the provider actually makes available to your account.
5. Test with a small request before relying on it for important work.

Model availability, free tiers, quotas, pricing, and provider policies can change. This project does not guarantee that any specific model will remain free or available.

Use the provider and model identifiers shown by the provider or the current OpenCode documentation. Do not assume a model name from a video or older guide is still valid.

## 4. Protect API Keys and Credentials

Treat API keys, access tokens, passwords, and session credentials as secrets.

- Never commit credentials to Git.
- Do not put real keys in screenshots, issue reports, videos, or public configuration examples.
- Do not paste secrets into public logs or bug reports.
- Prefer the authentication method documented by OpenCode and the provider.
- If a key is exposed, revoke or rotate it with the provider.

Before publishing a configuration example, replace secrets with placeholders such as `YOUR_API_KEY`. Never use a real credential as an example.

## 5. Shell Environment

Termux commonly uses Bash by default, while some users choose another shell. Environment-variable setup differs by shell.

If the provider or OpenCode instructions require an environment variable, follow the instructions for your actual shell and use its appropriate startup file. Do not assume every Termux user uses Zsh, and do not run shell-specific commands without confirming the shell.

Avoid printing environment variables that may contain secrets. If you need to debug whether a variable exists, check its presence without displaying its value.

## 6. Project-Specific Configuration

This project aims to provide a native ARM64 Termux build of OpenCode. It does not intentionally require users to replace their existing OpenCode configuration.

The Termux-specific build changes described in `BUILD.md` address compatibility in the build and runtime paths. They do not mean that every upstream provider, model, plugin, or feature has been separately verified on Android.

If a feature works on desktop Linux but fails in Termux, report the exact OpenCode version, device architecture, shell, steps to reproduce, and error output. Remove credentials and private information before sharing logs.

## 7. Back Up and Restore

Before a major upgrade or configuration change, back up the specific configuration file or user data you need to preserve. Keep backups private because they may contain sensitive settings or credentials.

Do not blindly copy an entire configuration directory over a newer installation. Review the files and merge only the settings you understand. Configuration formats and supported fields can change between releases.

## 8. Troubleshooting

### A provider or model is unavailable

Check the provider's current documentation, your account's access, the exact provider/model identifier, and the installed OpenCode version. Availability and free-tier policies may change.

### Authentication fails

Check that the credential is valid and configured using the documented method. Do not share the credential in logs or issue reports. Rotate it if it may have been exposed.

### Configuration errors at startup

Check the error message and validate the configuration against the documentation for your installed version. Restore your backup if the latest edit caused the problem.

### A setting appears to be ignored

Confirm that the setting is supported by your installed version and is stored in the expected location. Check the version-specific documentation for precedence rules.

### Configuration disappeared after an update

Do not immediately delete or recreate directories. Check the expected data locations, shell environment, and installation method first. Preserve any remaining files and make a backup before troubleshooting further.

## 9. Official Documentation

For the most accurate details, use the documentation associated with the version you have installed.

- OpenCode upstream repository: https://github.com/anomalyco/opencode
- OpenCode project website: https://opencode.ai/

This is an independent community project and is not an official OpenCode release.
