# Older Intel Mac compatibility testing

This procedure tests an **unreleased local candidate**, not the current GitHub
download. The app targets macOS 13 or later; its test target requires macOS 14.
An older Mac does not need Xcode to run the supplied app. Source builds additionally
need an installed Xcode/Swift 6 toolchain that supports that Mac's OS; consult
[Apple's Xcode requirements](https://developer.apple.com/xcode/system-requirements).
Do not upgrade the test Mac just to satisfy the current build host's requirements.

## Candidate and isolation

Obtain the locally prepared `IntelCompatibilityKit.zip` and its SHA-256 file from
the maintainer through an agreed transfer. No upload or publication is required.
The kit contains the normal universal Release app **with** the optional model
integration, the synthetic JSON fixtures described below, this guide, the license, and a
`source-inputs.sha256` manifest. That manifest identifies the reviewed source bytes,
including uncommitted files; a Git revision or app version alone does not identify
this candidate. A fresh clone of the published branch does not include local edits.
An already prepared kit does not update when source changes. Before testing raw
evidence navigation, verify its manifest includes `ComparisonRawEvidence.swift`,
`ComparisonRawEvidenceView.swift`, `raw-evidence-baseline.json`, and
`raw-evidence-current.json`. For pagination, also require
`raw-evidence-pagination-baseline.json` and `raw-evidence-pagination-current.json`.
If a required file is absent,
record those checks as **not run** and obtain a newly prepared candidate.

Before extracting, verify in the directory containing the ZIP and checksum:

```sh
shasum -a 256 -c IntelCompatibilityKit.zip.sha256
```

Stop if verification fails. A matching checksum establishes byte identity, not
publisher authenticity or freedom from defects. Confirm the sender and intended
candidate separately. After extracting, change to `IntelCompatibilityKit` and run:

```sh
codesign --verify --deep --strict --verbose=2 SystemProfilerExplorer.app
lipo -archs SystemProfilerExplorer.app/Contents/MacOS/SystemProfilerExplorer
plutil -extract LSMinimumSystemVersion raw -o - SystemProfilerExplorer.app/Contents/Info.plist
plutil -extract CFBundleIdentifier raw -o - SystemProfilerExplorer.app/Contents/Info.plist
sw_vers -productVersion
uname -m
```

Expected: a valid **ad hoc** signature, `x86_64` and `arm64` slices, minimum OS
`13.0`, preview identifier
`io.hideouts.systemprofilerexplorer.intel-compatibility-preview`, and `x86_64`
on the physical Intel test Mac. This is not Developer ID signing or notarization.
Leave the app in the test folder; do not overwrite an installed production app.
The display name is **System Profiler Explorer Intel Compatibility Preview**.

Use a separate local test account if testing snapshot save/retention. A different
bundle identifier isolates preferences but **does not isolate snapshot files**:
the store uses `Library/Application Support/com.netctl.SystemProfilerExplorer/Snapshots`
inside the current account's home directory. If a separate test account is not
available, skip snapshot mutations rather than alter existing history. Do not
delete existing reports, snapshots, or app instances.

If Gatekeeper intervenes, follow the README's
[app-specific approval procedure](../README.md#open-the-app-safely-when-gatekeeper-intervenes)
only after verifying and trusting this candidate. Apple's current procedure is
[Privacy & Security → Open Anyway](https://support.apple.com/en-us/102445).
Do not disable Gatekeeper/SIP, remove quarantine recursively, override a malware
warning, or bypass an administrator's policy. Record a policy block as **blocked**,
not as a successful launch or an app crash.

## Manual checks on the older machine

Use only the supplied files in `Fixtures`. They are invented hardware-shaped test
data, not reports captured from a Mac. Their nested module fields deliberately
include unknown context and duplicate names; no model should interpret those values.

1. **Launch and navigation.** Open the preview from its test folder. Verify the
   welcome/About artwork, subject sidebar, What Changed? workspace, window resizing,
   light/dark appearance, and keyboard navigation. Record any missing controls or
   rendering problems. A successful launch alone is not a complete compatibility test.
2. **Import and maintained explanations.** Choose **File → Import system_profiler
   JSON…** (⌘O) and open `baseline.json`. Expand Hardware and Installed Memory (`16 GB`),
   then About this field. Check that the maintained meaning/limits are readable.
   Search for `16 GB`, clear the search, expand/collapse nested records, and bookmark
   the memory finding. Raw source locations must still refer to the imported fields.
   Also import `camera-identifiers.json`. Camera Model Identifier and Camera Device
   Identifier must have curated field explanations and keep the exact invented
   values `synthetic_camera_model` and `synthetic_camera_unit_enabled`, without
   turning them into enumeration labels or a Yes/No result. The future Camera
   field must remain general data-type context. Expand the known fields: their
   descriptions distinguish model from device identity, include privacy guidance,
   and do not claim camera use or image capture. Neither identifier offers the
   optional plain-English model action. In Developer mode, export an anonymized
   sample and verify both identifier values were removed; a full private export
   must preserve them. These are invented values, not a live camera-access check.
   If the fixture is absent, obtain a refreshed kit before claiming this check.
3. **Optional model unavailable.** Select Explain in plain English for Installed
   Memory. On macOS 13–15, the normal candidate must show the macOS-26 requirement
   without loading the absent FoundationModels framework. On an Intel Mac running
   macOS 26 or later, expect a device-ineligible reason from Apple's API; record the
   actual reason if different rather than relabel it. Check availability must remain
   an explicit recheck. Close the sheet; collection, search, raw `16 GB`, bookmarks,
   and maintained explanations must remain usable. There must be no generated result
   or request to enable Intelligence, download models, or use a cloud provider.
4. **Reorder without false changes.** Import `reordered.json` as the current report.
   In What Changed?, choose `baseline.json` as the baseline file. Expected:
   **0 added, 0 removed, 0 changed**, despite reordered unique/duplicate nested records.
5. **One real structured difference.** Import `changed.json` as current and choose
   `baseline.json` as baseline. Expected: **0 added, 0 removed, 1 changed**,
   Installed Memory `16 GB` → `32 GB`, source
   `SPHardwareDataType[0].physical_memory`. Its explanation describes the reported
   difference without inventing a cause or security diagnosis.
   Then import `moved-change.json` and compare with `baseline.json`: expect one
   changed Synthetic Alpha version, `1` → `3`, with baseline location
   `SPHardwareDataType[0]._items[0].version` and current location
   `SPHardwareDataType[0]._items[1].version`. The other reordered modules are
   unchanged. Both locations must be readable/selectable in the dashboard. Open
   **Review Details** for the comparison sheet; searching either path must find
   the difference.
   Reversing the reports reverses the values and locations, not their identities.
   Open **View baseline raw evidence** and **View current raw evidence** in both
   the dashboard and Review Details: the viewer must show `"1"` and `"3"`
   respectively, with the correct original indices and separate exact address
   components. Close it with **Done**; the comparison must remain available.
   For literal-key checks, import `raw-evidence-current.json` and compare with
   `raw-evidence-baseline.json`: expect **1 added, 1 removed, 7 changed**. Literal
   `a.b` and nested `a` → `b` look similar in display paths but must open distinct
   values (`1` → `11` and `2` → `12`). Likewise literal `items[0]` and array item
   `items` → index `0` must open `3` → `13` and `4` → `14`. Empty and `[]` keys
   remain literal fields. Reported `null` is viewable, not an absent side. Added
   and removed fields expose only the side where they exist. This works without
   the on-device model framework; no report values are model input.
   For pagination, import `raw-evidence-pagination-current.json` and compare with
   `raw-evidence-pagination-baseline.json`: expect **0 added, 0 removed, 1 changed**
   at `SPHardwareDataType[0].value`. Baseline raw evidence must show the JSON string
   `"short baseline"` on one page. Current raw evidence must show **three pages**:
   page 1 starts with `"BEGIN-PAGE-1|` and contains repeated `é🙂`; page 2 starts
   with `BEGIN-PAGE-2|` and contains repeated `界`; page 3 is `BEGIN-PAGE-3|END"`.
   Previous is disabled only on page 1, Next only on page 3, and both are enabled
   on page 2. Move forward and backward and confirm the same markers and content
   return without alteration. The JSON string spans pages: individual pages are
   not complete JSON documents. Its complete reconstructed JSON has 24,017 Swift
   characters, split into 12,000, 12,000, and 17; behavioral tests verify that
   joining the pages restores the exact parsed value, not the original file bytes.
   Close with Done and reopen: the comparison must remain and the viewer must
   restart at page 1. Repeat from both What Changed? and Review Details. Record
   these UI checks separately from the behavioral test; green tests do not prove
   page buttons, dismissal, or rendering worked on the target Mac.
6. **Ambiguous records.** Import `ambiguous.json` and compare with `baseline.json`.
   Expected: an explicit ambiguity error for Synthetic Module and the affected
   `SPHardwareDataType[0]._items` array in **both** reports. No fabricated comparison
   may remain visible from the previous successful comparison. Import `reordered.json`
   and compare again to verify recovery through a new explicit operation.
   Also choose `incomplete-export.json` as the baseline: comparison must stop with
   **Baseline: Wi-Fi (Skipped)** because its invented command metadata requests Wi-Fi
   but contains only Hardware. The fixture's dates are invented, not host timestamps.
   A previous successful result must not remain visible. This checks collection loss,
   not a raw JSON import's unknown original scope. The fixture and this behavior require
   a newly built candidate; older kits without `incomplete-export.json` or
   `moved-change.json` predate these corrections.
7. **Separate exports.** With the baseline imported, export a full private Report
   File and reimport it; memory remains `16 GB`. Export a redacted Report File;
   values are redacted and it must be refused as a comparison baseline. Export a
   Summary as Markdown and PDF: readable maintained explanations, limits/privacy
   warning, and the bookmarked field; no model-generated prose or embedded raw JSON.
   Store outputs in the test account's test folder, not the repository.
   Then import `review-unicode.json` and bookmark **Unicode Rendering**, not just
   Installed Memory. This invented, unrecognized field contains 300 numbered rows
   with accents, CJK, Greek, and joined technologist (`🧑‍💻`), scientist (`👩‍🔬`),
   and family (`👨‍👩‍👧`) emoji. Export its Summary as Markdown and PDF. Check first,
   middle, and final pages: each joined sequence is one glyph, wrapped text stays
   within the margins, all rows through `ROW-300` / `END-300` remain in order once,
   and the collection/privacy limits and final Raw Data section remain readable.
   Page counts and glyph artwork can vary with the target OS's fonts. PDF text
   extraction can change invisible joiners or accent representation even when
   rendering is correct; do not treat copied PDF text as exact raw evidence.
   The Markdown must retain the original reported Unicode value. Record this
   check separately from raw-evidence pagination and from current-host tests.
   If this fixture is absent, obtain a refreshed kit before claiming this check.
8. **Snapshots, only in an isolated account.** Select Keep all before saving a named
   full baseline. Import `changed.json` and compare with that baseline through
   What Changed?: one memory change. Save a redacted snapshot; it must not be offered
   as a comparable baseline. To test retention, create six **synthetic test-only**
   snapshots with Keep 5 in an account containing only this test's synthetic history; the oldest must be
   removed and five retained. Never exercise retention against existing user history.
9. **Live read-only collection, separate evidence.** Optionally run the focused
   Hardware scan on the Intel Mac. Confirm completion/progress/error handling and
   per-data-type collection labels. If incomplete sections occur, View Incomplete
   Collection must expose them; do not induce permission changes to manufacture a
   failure. Hardware-specific empty/missing sections are not evidence of absence
   or compromise. Do not expect the synthetic fixture's exact values or coverage.
   Keep actual inventories and screenshots private.
10. **Relaunch.** Quit only the preview you opened, reopen it, reimport the baseline,
    and repeat the unavailable sheet check. The app must work without a generated
    explanation and must not retain generated text in reports or exports.

For any freeze, record the last action and affected synthetic file, then use
Activity Monitor's Sample Process on the **preview's exact PID**, not another app
instance. Treat samples/crash reports as private: they can contain paths and other
identifiers. Arrange a private, reviewed transfer before sharing them. A missing
framework/dyld crash during launch is a runtime compatibility failure, not a
Gatekeeper approval issue.

## Developer checks and unavailable-state coverage

Run from the candidate source checkout, not the kit. The checked-in Xcode project
is sufficient; no XcodeGen regeneration or extra dependencies are needed. Run the
publication boundary before native checks:

```sh
./scripts/check-publication-boundary.sh
TEST_RUNNER_SYSTEM_PROFILER_NATIVE_EXPLANATION_TEST=1 xcodebuild \
  -project SystemProfilerExplorer.xcodeproj -scheme SystemProfilerExplorer \
  -destination 'platform=macOS,arch=x86_64' \
  -derivedDataPath .build/IntelCompatibilityTests \
  CODE_SIGNING_ALLOWED=NO build test
```

The opt-in test uses the actual native availability/generation path with only
maintained field context. On an unavailable machine it verifies refusal; that is
**not** successful generation. macOS 13 cannot run this project's macOS-14 test
target: run the manual prebuilt-app checks there instead. An older SDK without
FoundationModels compiles out the integration and therefore cannot verify normal
weak-linked-framework behavior on an older OS.

For the deliberately framework-free configuration, use a different derived-data
directory and add
`SWIFT_ACTIVE_COMPILATION_CONDITIONS='$(inherited) SYSTEM_PROFILER_WITHOUT_ON_DEVICE_MODEL'`
to that command. Expected reason: **This build does not include the on-device model
framework**, on any OS. This variant is a separate check, not a substitute for
steps 1–10 using the normal kit. Do not use `script/build_and_run.sh` while preserving
other app instances: it terminates matching processes.

For UI automation, use the existing accessibility identifiers
`explain-plain-english-SPHardwareDataType-physical_memory`, `plain-english-sheet`,
`plain-english-check-availability`, and `plain-english-close`; locate the preview
by its exact bundle identifier and do not fall back to another instance.
For comparison navigation, focus `workspace-sidebar` and use native keyboard
selection to reach What Changed?. Expand a difference using its
`what-changed-insight-<change ID>` identifier. Its raw-evidence actions use
`view-baseline-raw-evidence-<change ID>` and
`view-current-raw-evidence-<change ID>`; absent sides have no action. The viewer
exposes `comparison-raw-evidence-json`, `comparison-raw-evidence-page`,
`comparison-raw-evidence-previous`, `comparison-raw-evidence-next`, and
`close-comparison-raw-evidence`. Check both the dashboard and the nested viewer
inside `what-changed-review-details`; closing the viewer must retain the comparison.
For exports, open `share-report` and choose `share-report-file` or
`share-system-review`. The summary format picker is `system-review-export-format`;
`close-report-export` and `close-system-review` dismiss only their review sheet.
Use the native save panel's identifiers, verify the saved bytes, and keep all
synthetic outputs in the test folder. Do not select an ambiguous menu action by
its visible label or reuse an accessibility index after the UI changes.

| Check | What it establishes | What still requires other evidence |
| --- | --- | --- |
| Universal binary, minimum OS, weak framework load command | Static architecture/link metadata | Launch and behavior on each target OS |
| x86_64 suite under Rosetta on Apple silicon | Translated Intel-code execution on that host OS | Physical Intel and older-OS compatibility |
| Native availability enum/error classification tests | Documented refusal/error mapping with synthetic SDK values | Actual device-ineligible, disabled, downloading, or language configurations |
| Cancelled task before adapter entry | No availability/session/inference after entry cancellation | Native inference cancellation latency and cooperative deadline |
| Real on-device generation on an eligible Mac | That host's inference path | Unsupported Macs or all output correctness |
| Physical Intel unavailable UI + import/compare/export | Usability without the model on the recorded Mac/OS | Every Mac model, profiler section, or permission state |

Disabled Intelligence, model-not-ready, and unsupported-language checks additionally
need eligible machines already in those states or explicit approval to change their
configuration. Record them as **not run** if unavailable. Do not change settings,
download a model, simulate availability, or claim a synthetic classifier test proves
those live states. The 30-second inference deadline requests cancellation; its actual
return time depends on Apple's native request honoring cancellation.

## Result to return

Return only reviewed, non-identifying results:

- Kit SHA-256 and `source-inputs.sha256` digest; preview bundle ID and build variant.
- macOS version/build, physical Intel vs Rosetta, and generic model family (no serial,
  hardware UUID, host/user name, addresses, or installed-software inventory).
- Steps 1–10 individually: **passed / failed / blocked / not run**, with the exact
  synthetic file/action and safe error domain/code where applicable.
- Actual unavailable reason, whether maintained features still worked, and any
  native suite counts/skips if run.
- Rendering issues captured only with synthetic fixtures; live collection reported
  separately. Keep raw reports, snapshots, process samples, and crash logs private.

Do not report “all Macs supported” from one machine or green build/test status.
