# System Profiler Explorer

## Validation and evidence

- Read `CONTRIBUTING.md` and `SECURITY.md`. Run `./scripts/check-publication-boundary.sh`, then `xcodebuild -project SystemProfilerExplorer.xcodeproj -scheme SystemProfilerExplorer -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build test` before a PR.
- Keep the checked-in Xcode project; regenerate it with XcodeGen only when `project.yml` changes. Preserve the publication-boundary gate and native build/test CI.
- Branding dependencies live in `scripts/branding`; use its lockfile and run `npm ci --ignore-scripts` followed by `npm run check` there. Type checks do not regenerate or validate rendered artwork.
- Keep collection read-only and separate reported values from interpretation. Tests and CodeQL do not establish live collection on every supported Mac or compromise.
- Never include raw profiler reports, private snapshots, identifiers, installed-software inventories, host timestamps, or screenshots with private values in Git or PRs. Use synthetic fixtures; review the documented anonymized-sample exception before sharing.
- Verify successful Swift, JavaScript/TypeScript, and GitHub Actions CodeQL analyses at the candidate revision; scanner configuration or an older run does not establish current coverage.
- Keep CodeQL extraction/build jobs read-only. Upload SARIF in a separate job that runs no repository code, and preserve the strict `CodeQL results` gate across every language.

## Publication

- `scripts/build-release.sh` builds a local distribution candidate. Tags and CI do not publish a product release; distribution signing, notarization, tagging, and publication require authorization covering those actions.
