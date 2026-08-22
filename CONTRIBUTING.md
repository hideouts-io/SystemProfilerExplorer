# Contributing

Contributions should keep System Profiler Explorer read-only, local-first, and careful about the boundary between observed data and interpretation.

## Development setup

Use macOS 14 or later and an Xcode toolchain compatible with Swift 6. The checked-in Xcode project builds without XcodeGen. Run XcodeGen only after changing `project.yml`:

```sh
xcodegen generate
```

Before opening a pull request, run:

```sh
./scripts/check-publication-boundary.sh

xcodebuild -project SystemProfilerExplorer.xcodeproj \
  -scheme SystemProfilerExplorer \
  -destination 'platform=macOS' \
  build test
```

## Code and interpretation requirements

- Keep collection read-only and use `/usr/sbin/system_profiler` directly.
- Preserve original structured values in memory; do not silently normalize away evidence.
- Keep functions small, typed, and single-purpose.
- Raise explicit, actionable errors when collection, parsing, export, or import fails.
- Explanations must separate what a field reports, why it matters, interpretation limits, and privacy considerations.
- Do not infer malicious activity from an unfamiliar value without corroborating evidence.
- Add the minimum useful integration or behavior test for a change.
- Use stable accessibility identifiers for UI automation.

## Privacy requirements

Never commit or attach a raw/full profiler report, local snapshot, screenshot containing private values, or copied live output. Test fixtures must be synthetic and must not contain real serial numbers, UUIDs, UDIDs, addresses, user names, user paths, installed-software inventories, or precise host timestamps.

The redacted export mode removes reported scalar values, but contributors must still review any exported file or screenshot before sharing it. Run the publication-boundary script before staging changes.

## Pull requests

Keep each pull request focused. Explain the behavior change, the validation performed, and any coverage or interpretation limits. Do not include unrelated formatting or generated local state.
