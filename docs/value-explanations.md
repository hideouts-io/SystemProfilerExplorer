# Value explanations

Every value the app explains for fields with a limited set of values, with the
source of the explanation and whether the exact spelling is confirmed. The
rules live in `SystemProfilerExplorer/Core/Explanations/Values`, and
`SystemProfilerExplorerTests/ValueCatalogTests.swift` checks that each value
below has every part of an explanation.

Each explained value has a one-line summary, what it means on this Mac, why it
matters, what to check, a status, and a source. A value that isn't listed for a
field that has a rule is shown as **Not yet explained**; the app never guesses.

## Key

**Status:** Normal, Info, or Worth a look. Some values change status with the
rest of the report (for example the processor, or whether a network is the
current one); the table says so.

**Source:**

- **Apple**: Apple documentation, or Apple's own System Information strings.
- **Standard**: standard macOS behavior or a widely used convention.
- **Inferred**: an inference the app shows its reasons for.

**Spelling:**

- **seen**: in `docs/value-inventory.md` (a full scan of one Mac).
- **Apple key**: a key in Apple's System Information localization strings,
  published in the macOS glossaries at
  <https://github.com/clindsay3/GlossaryLookup> (files such as
  `Apple_System_Profiler.lg` and `SP*Reporter.lg`). These glossaries come from
  an older macOS release, so a key there is a spelling Apple used, not proof
  that current macOS still reports it.
- **published**: in system_profiler output published online.
- **unconfirmed**: no source shows this spelling. It's matched so the value is
  explained if it appears, and it's listed under "Values that need a scan" in
  `PLAN.md`.

## Applications and frameworks

Sources: Apple Support, "Using Intel-based apps on a Mac with Apple silicon"
(<https://support.apple.com/en-us/102527>), which names the Kind column's
Apple silicon, Intel, Universal and 32-bit kinds; Apple Developer News on
Rosetta after macOS 27 (<https://developer.apple.com/news/?id=w5ngl9k2>);
CPython issue 137673 (<https://github.com/python/cpython/issues/137673>),
which shows `arch_ios` reported for a Mac app without
`CFBundleSupportedPlatforms`; mondoohq/mql pull request 11104
(<https://github.com/mondoohq/mql/pull/11104>), which shows `arch_other` for
an app whose main program is a shell script.

| field | value | meaning | status | source | spelling |
|---|---|---|---|---|---|
| `arch_kind` | `arch_arm` | Apple silicon only | Normal; Info on an Intel Mac | Apple | seen |
| `arch_kind` | `arch_arm_i64` | Universal | Normal | Apple | seen |
| `arch_kind` | `arch_i64` | Intel only (Rosetta 2 on Apple silicon) | Info; Normal on an Intel Mac | Apple | seen |
| `arch_kind` | `arch_i32_i64` | Intel only, 32- and 64-bit | Info; Normal on an Intel Mac | Apple | Apple key |
| `arch_kind` | `arch_ios` | iPhone or iPad app | Info | Apple | seen |
| `arch_kind` | `arch_other` | not a kind System Information recognizes | Info | Inferred | seen |
| `arch_kind` | `arch_i32` | 32-bit Intel, can't run | Info | Apple | Apple key |
| `arch_kind` | `arch_ppc` | PowerPC, can't run | Info | Apple | unconfirmed |
| `obtained_from` | `apple` | Apple | Normal | Apple | Apple key, published |
| `obtained_from` | `mac_app_store` | Mac App Store | Normal | Apple | Apple key, published |
| `obtained_from` | `app_store` | App Store | Normal | Apple | Apple key |
| `obtained_from` | `ios_app_store` | App Store, as an iPhone or iPad app | Normal | Apple | unconfirmed |
| `obtained_from` | `identified_developer` | Developer ID | Normal | Apple | Apple key, published |
| `obtained_from` | `unknown` | no trusted signature | Info | Apple | Apple key, published |
| `private_framework` | `yes`, `no` | private or public framework | Info | Apple | seen |

`obtained_from` is also explained for extensions. Its values aren't listed in
`docs/value-inventory.md` (the field was classed as free text), so their
spellings come from Apple's keys and published output, such as the samples in
<https://github.com/glpi-project/glpi-agent> (`resources/macos/system_profiler`).

## Fonts

Sources: the font kinds and yes/no values are keys in Apple's
`SPFontReporter` strings; Font Book's Validate Font and duplicate handling are
described in the Font Book User Guide (<https://support.apple.com/guide/font-book/>).
Adobe ended support for PostScript Type 1 fonts in January 2023
(<https://helpx.adobe.com/fonts/kb/postscript-type-1-fonts-end-of-support.html>).

| field | value | meaning | status | source | spelling |
|---|---|---|---|---|---|
| `type` | `truetype` | TrueType | Info | Apple | seen |
| `type` | `opentype` | OpenType | Info | Apple | seen |
| `type` | `postscript` | PostScript Type 1 | Info | Standard | seen |
| `type` | `bitmap` | bitmap | Info | Apple | seen |
| `type` | `unknown` | unrecognized format | Info | Apple | Apple key |
| `enabled` | `yes`, `no` | turned on or off in Font Book | Normal, Info | Apple | seen (`yes`), Apple key (`no`) |
| `valid` | `yes`, `no` | passed or failed macOS's checks | Normal, Info | Apple | Apple key |
| `duplicate` | `yes`, `no` | another copy is installed | Info, Normal | Apple | seen (`no`), Apple key (`yes`) |
| `copy_protected` | `yes`, `no` | marked copy-protected | Info, Normal | Apple | seen (`no`), Apple key (`yes`) |
| `embeddable` | `yes`, `no` | license allows embedding | Info | Apple | seen (`yes`), Apple key (`no`) |
| `outline` | `yes`, `no` | outline or bitmap characters | Info | Apple | seen |

`enabled` and `valid` are explained both for the font file and for each typeface.

## Extensions

Sources: the values seen in `docs/value-inventory.md` and the keys in Apple's
`SPExtensionsReporter` strings. Apple documents that kernel extensions on
Apple silicon must be built for arm64e and that Rosetta 2 can't translate
kernel extensions (<https://developer.apple.com/documentation/apple-silicon/installing-a-custom-kernel-extension>),
and describes notarization in
<https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution>.
`spext_runtime_environment`, `spext_obtained_from`, and `spext_notarized` are
Apple keys that current macOS may no longer report.

| field | value | meaning | status | source | spelling |
|---|---|---|---|---|---|
| `spext_loaded` | `spext_yes`, `spext_no` | loaded or not when scanned | Info | Apple | seen (`spext_yes`), Apple key |
| `spext_hasAllDependencies` | `spext_satisfied` | dependencies present | Normal | Apple | seen |
| `spext_hasAllDependencies` | `spext_incomplete` | a dependency is missing | Worth a look | Apple | Apple key |
| `spext_has64BitIntelCode` | `spext_yes`, `spext_no` | has Intel code | Info (says it can't load when an Intel Mac lacks it) | Apple | seen (`spext_no`), Apple key |
| `spext_loadable` | `yes`, `no` | can or can't load | Normal, Info | Apple | seen (`yes`) |
| `spext_architectures` | `arm64e`, `arm64`, `x86_64`, `i386` | code it contains | Info | Apple | seen (`arm64e`), standard names |
| `spext_runtime_environment` | `spext_arch_arm`, `spext_arch_x86`, `spext_universal`, `spext_arch_ppc` | kind | Info, Normal (Universal) | Apple | Apple key |
| `spext_obtained_from` | `spext_apple`, `spext_identified_developer`, `spext_unknown`, `spext_not_signed` | where it came from | as for apps; Info for not signed | Apple | Apple key |
| `spext_notarized` | `spext_yes`, `spext_no` | notarized or not | Normal, Info | Apple | Apple key |
