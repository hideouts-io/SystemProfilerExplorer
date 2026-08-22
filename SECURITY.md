# Security Policy

System Profiler Explorer is pre-release software. Security fixes currently target the latest code on the default branch.

## Reporting a vulnerability

When the repository is hosted on GitHub, use GitHub's private vulnerability reporting or a private Security Advisory draft. Do not open a public issue for a vulnerability that includes sensitive system data or an unredacted profiler report.

Include only the minimum information needed to reproduce the vulnerability. Remove credentials, serial numbers, UUIDs, UDIDs, network addresses, user paths, installed-software inventories, and other host fingerprints. If a private report is essential to reproduce the problem, first ask the maintainers for an approved private transfer method; do not attach it by default.

Ordinary incorrect explanations, missing field coverage, and UI defects can use the bug-report template after all system data is sanitized. A surprising `system_profiler` value is not itself a vulnerability in this application.

## Scope

Security reports may cover unsafe file handling, failure of redaction, unintended report persistence, command injection, collection outside the displayed scope, or disclosure of private profiler values. Reports about vulnerabilities in macOS or third-party software should be sent to the responsible vendor instead.
