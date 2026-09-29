# Plan: value-aware explanations for common enumeration fields

`docs/value-inventory.md` was generated before value rules existed, so its
"value-aware" column (2 of 526 fields) is out of date. Comparing its
enumeration and on/off fields with the rules in
`SystemProfilerExplorer/Core/Explanations/Values` shows about 100 fields that
still get no value explanation. PR #8 covers field explanations only, so none
of these overlap with it.

This branch adds value rules for the ones that matter most, in small steps.
Each step adds rules, tests for every value observed in the inventory, and
tests for the values that change the status.

Rules only go on fields whose values don't identify a person or a Mac,
because anonymized samples keep the values of fields that have a rule.

## Steps

1. [x] Write this plan.
2. [x] Startup security (Apple Bridge): Secure Boot level, System Integrity
   Protection, Signed System Volume, kernel CTRR, boot-argument filtering,
   third-party kernel extensions, and privileged MDM operations.
3. [x] Proxy settings (Network and Network Locations): each proxy switch,
   automatic proxy configuration and discovery, passive FTP, simple host
   names, and VPN On Demand.
4. [x] Power: Low Power Mode, High Power Mode, network reachability during
   sleep, reduced brightness on battery, power adapter connected, UPS, and
   scheduled power event types.
5. [ ] Storage: internal or external disk, connection protocol, ignored
   ownership, and NVMe removable and detachable media.
6. [ ] Software and Secure Element: font format and flags, private
   frameworks, extension loadability and architectures, Secure Element
   restricted mode and production signing.
7. [ ] Note in `docs/value-inventory.md` that value rules now exist and
   which enumeration fields are still unexplained.

## Verification

This environment has no Xcode, so each pushed commit is verified by the CI
`build-and-test` job. Nothing here needs a live scan, but the owner's Mac is
the only way to confirm the exact spellings macOS uses for values that did
not appear in the inventory (for example `Reduced Security`).

## Blocked or deferred

- Regenerating `docs/value-inventory.md` needs a full scan on a Mac.
