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

## Project working defaults

These instructions apply only to this project and its canonical repository.

### Before changing files

- Read `WORKSPACE.md`, the applicable `AGENTS.md` and `AGENTS.override.md` files, the actual TODO list, project documentation, and the latest project checkpoint before making changes.
- Always verify the canonical checkout, Git root, current branch, HEAD, remote, upstream, attached worktrees, open pull requests, and staged, unstaged, and untracked files.
- Preserve all unrelated work.

### Standing Git and GitHub authorization

The user has authorized the normal Git and GitHub delivery steps for work implemented and verified in this project:

- Stage only reviewed files or hunks belonging to the current task.
- Create focused commits with clear, conventional messages.
- Create and use a `codex/` feature branch when appropriate.
- Push the task branch to the verified GitHub repository.
- Create a new pull request when review or CI is the safest delivery path.
- Update an existing pull request when the work clearly belongs to it.
- Mark a draft pull request ready after implementation and required checks are complete.
- Push follow-up fixes needed to make required pull-request CI checks pass.
- Choose between committing and pushing to the authorized task branch or opening/updating a pull request based on the repository’s current branch, protection rules, scope, and review needs.

Use a pull request by default for source, application behavior, packaging, workflow, dependency, security-sensitive, or substantial multi-file changes. A direct push is acceptable only on the correct non-protected task branch when it follows repository practice and does not bypass required review or branch protection.

Before every commit or push:

1. Confirm the canonical repository, branch, remote URL, upstream, HEAD, and outgoing diff.
2. Preserve unrelated staged, unstaged, and untracked work.
3. Stage explicit files or reviewed hunks; never use `git add .`, `git add -A`, or `git commit -a` in a dirty canonical checkout.
4. Inspect the complete staged diff.
5. Check that credentials, private evidence, device identifiers, personal data, local absolute paths, backups, logs, downloaded indicators, build caches, and private test artifacts will not enter Git history.
6. Run applicable tests, linting, documentation checks, packaging checks, and native UI checks.
7. Review the final diff for regressions, security issues, scope drift, generated-file mistakes, and unrelated changes.
8. Fetch and inspect the verified remote before integrating upstream changes. Do not use a blind pull.
9. Push only the intended branch and verify that the remote revision matches the expected commit.
10. Inspect resulting GitHub checks and fix failures without weakening tests, assertions, security controls, or required gates.

If the canonical checkout contains overlapping or conflicting user work, preserve it and use an existing suitable review worktree or create a focused worktree from the correct committed base. Do not reset, clean, stash, discard, overwrite, or silently include unrelated changes.

This authorization does not cover merging pull requests, force-pushing or rewriting published history, deleting remote branches, creating tags or GitHub releases, publishing release artifacts, deploying, approving protected environments or publication jobs, changing repository settings or permissions, installing or broadening GitHub App access, or sending unrelated external messages. Ask for separate authorization before those operations.

### Continuity during active work

- Do not start adapters, dependencies, installers, packaging, or CI work while an actionable TODO remains.
- At the beginning of a work session, load the latest project memory and checkpoint.
- At least once every hour while actively working, and again before ending or pausing, save a concise checkpoint in the existing project checkpoint or continuity location. Do not create duplicate planning documents or empty repetitive entries.
- A checkpoint records the current objective and scope, checkout/worktree, branch and HEAD, remote branch and pull request, relevant Git state, intentionally changed files, completed and remaining TODOs, implementation decisions, tests/builds/CI/native checks with exact status, app bundle and native-window evidence when applicable, investigated failures, blockers, and the next safe action.
- Do not store credentials, secrets, signing material, device identifiers, raw backups, private logs, downloaded threat intelligence, personal information, or large command output in memory. Record safe summaries and paths to private local evidence instead.

Continue autonomously through implementation, verification, commit, push, pull-request creation or update, and CI repair under this authorization. Merging, releasing, deploying, publication, settings changes, force pushes, and device operations remain separately authorized boundaries.

### Completion report

When work is complete, report what changed and why; commit hashes and pushed branch; pull-request URL and current review state when applicable; test, build, and CI outcomes; remaining macOS TODOs and concrete blockers; the exact path and visible state of the updated app when applicable; and whether any publication-sensitive step still needs authorization.
