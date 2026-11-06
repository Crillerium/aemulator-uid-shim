# Changelog

All notable changes to this project are documented here.

## 1.1.0 - 2026-11-07

- Added a fast path for `su -v`, `--version`, `-h`, and `--help`.
- Avoided starting Android Runtime during common root probes.
- Added PowerShell and POSIX shell build, install, and uninstall scripts.
- Added safety checks before replacing or removing an existing `su`.
- Added documentation for the security model and GSI compatibility.

## 1.0.0 - 2026-11-06

- Added the initial AEmulator UID compatibility shim.
- Added `/system/bin/su` and `/system/framework/aemu-su.jar`.
- Verified emulated UID 0 with an ordinary Android application.
