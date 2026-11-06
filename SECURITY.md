# Security Policy

## Security model

AEmulator UID Shim has no authorization or privilege-isolation model.

After installation, any application that can execute `/system/bin/su` can obtain the emulated UID 0 identity provided by AEmulator. Renaming or hiding the executable does not create a security boundary.

The project does not provide:

- Per-application authorization.
- Allow/deny prompts.
- Signature verification.
- A protected authorization database.
- Real Linux capabilities.
- A real kernel UID transition.

## Intended use

Use this project only inside an AEmulator guest for compatibility with tools that expect `su`. Do not use it on a device or VM that contains sensitive data, and do not treat it as a replacement for Magisk in a security-sensitive environment.

If emulated root is not required, uninstall the shim.

## Reporting a problem

If you find a documentation error or a compatibility bug, open a GitHub issue with:

- AEmulator version.
- GSI name, Android version, and ABI.
- Host device and Android version.
- Exact command and output.

Do not include private keys, account credentials, or personal data in an issue.
