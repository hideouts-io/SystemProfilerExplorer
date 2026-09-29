# Plan: lead with the value, and explain every value of limited-set fields

This branch builds on `value-aware-explanations` (PR #9), which added value
rules for about 60 fields. It changes what an expanded row shows, and then
gives every value of every limited-set field a full explanation.

## The problem

Expanding a row such as Applications › SystemIntents › Supported
Architecture = `arch_arm` shows a large "About this field" block: What it
means, Why it matters, Interpret carefully. That text describes the field
`arch_kind`, not the value. It is identical on all 769 application rows, the
field name is already on the left, and the value is already on the right. So
the biggest thing in the panel says nothing about the result the user
clicked, and the value's own explanation is at most one line above it.

**Is "About this field" redundant?** At full size on every row, yes. The text
itself is still useful: the first time someone meets a field, and as the only
explanation for names, numbers and identifiers, where there is nothing
value-specific to say. So it stays, but once, small, and collapsed.

## New layout of an expanded row

1. **Row (unchanged):** field name on the left, value on the right, then the
   status badge and a one-line summary of what this value means.
2. **Value panel** (tinted by the value's status), in this order:
   - **What this result means**: what this specific value says about this Mac.
   - **Why it matters**: what this value changes for the user.
   - **Why the app thinks so**: only for inferred explanations, listing the clues.
   - **What to check**: what to look at or do next ("Nothing to do" when normal).
   - A small footer line: **Source:** Documented by Apple, Standard macOS
     behavior, or Inferred by the app.
3. **About this field**: a single caption-sized disclosure line with an info
   icon, collapsed by default. It holds the field-level text (what the field
   records, why it matters, interpret carefully, privacy), the explanation
   coverage note that used to appear as "Curated explanation", and in
   Developer mode the source path and "Show Raw Source Location". It starts
   open only when the value has no explanation of its own (names, numbers,
   identifiers, free text), because then it is the only explanation.
4. **Terms used here** (unchanged).

Removed: the Developer-mode "Curated explanation" badge under every field
name, and the coverage box at the top of the panel. Both now live in the
About this field area.

A value the app doesn't recognize for a limited-set field shows the status
"Not yet explained" and says so plainly. The app never guesses.

## What each value explanation has

- a short plain summary (the row line)
- what it means on this Mac
- why it matters
- what to check or do
- a status: Normal, Info, Worth a look (or Not yet explained)
- its source: documented by Apple, standard macOS behavior, or inferred
  (with the reasons shown)

Sources and spelling status for every value are listed in
`docs/value-explanations.md`. A spelling is **confirmed** when it appears in
`docs/value-inventory.md`, in Apple's own System Information localization
strings, or in system_profiler output published online; otherwise it is
marked **unconfirmed**.

## Steps

Each step is one commit with its tests, and runs the publication-boundary
check. There is no Xcode here, so CI's `build-and-test` job is the build and
test run.

1. [x] Write this plan.
2. [x] Layout: add "why it matters" to value explanations, build the
   value-first panel and the collapsed About this field area, move the
   coverage note into it, and include the new parts in Copy as Markdown.
3. [x] Applications and frameworks (most rows in a scan): architecture
   (`arch_kind`), where it came from (`obtained_from`), and private
   frameworks.
4. [x] Fonts (the most values in a scan): font kind, enabled, valid,
   duplicate, copy protected, embeddable, outline.
5. [x] Extensions: loaded, loadable, dependencies, Intel code,
   architectures.
6. [x] Network services and locations: hardware, service type, IPv4 and IPv6
   configuration, proxies, VPN On Demand and its rules, PPP and VPN
   switches, Wi-Fi join mode, VPN sign-in, Ethernet media, active location,
   network volumes.
7. [x] Install history, legacy software, and firewall.
8. [x] Wi-Fi: status, security, network type, capabilities, regulatory
   locale.
9. [x] Power and battery: battery condition and charge states, power
   source, hibernate mode, Low and High Power Mode, network reachability,
   reduced brightness, adapter, UPS, scheduled events.
10. [x] Storage and NVMe: SMART, file system, medium, partition map,
    writable, internal, protocol, ownership, TRIM, removable, detachable,
    volume content.
11. [x] Startup security, software overview and hardware: Secure Boot and
    its protections, SIP, secure virtual memory, boot mode, Activation Lock.
12. [x] Displays, audio, Bluetooth, Thunderbolt, USB, memory, card readers,
    and Ethernet.
13. [x] Settings and profiles: accessibility, language and region,
    configuration profiles, managed preferences, printers, sync services,
    Secure Element.
14. [x] Update `docs/value-inventory.md` to point at the new list, and
    finish the scan list below.

## Values that need a scan on a real Mac

Each of these is explained, but no public source confirms the exact spelling
current macOS reports, or the inventory withheld the field's values. A scan with
the matching hardware or setting would confirm them (or show a spelling to add).
Until then, a different spelling is shown as "not yet explained".

**Fields whose value format is unknown** (no rule, or the rule may never match):

- `contrast` (Accessibility): no rule; its values were withheld.
- `ibridge_extra_boot_policies` (Apple Bridge): no rule; its values were withheld.
- `UserVisible` (scheduled power events): no rule; its values were withheld.
- `link_status_key` (Thunderbolt): the rule matches Apple's `trained_link_status`
  family, but current macOS may report a number such as `0x2`.
- `printersharing`, `scanner`, `shared`, `default`, and `status` (Printers):
  needs a Mac with a printer set up.

**Spellings to confirm, by section** (full list in `docs/value-explanations.md`):

- Applications: `arch_ppc`, `ios_app_store`; and whether current macOS still
  reports the older Apple keys `arch_i32`, `arch_i32_i64`, `app_store`.
- Extensions: whether current macOS still reports `spext_runtime_environment`,
  `spext_obtained_from`, and `spext_notarized`.
- Network: `PPP (PPPoE)`, `PPP (L2TP)`, `PPP (PPTP)`; Ethernet media speeds
  other than `100baseTX` and `1000baseT`; `spethernet_pcie`,
  `spethernet_builtin`; USB link speeds other than `high_speed` (needs a USB
  Ethernet adapter on a faster port).
- Firewall: `spfirewall_globalstate_off` (turn the firewall off and scan).
- Wi-Fi: `spairport_status_disconnected`, `_not_associated`; security modes
  `wpa3_enterprise`, `wpa2_wpa3_enterprise`, `owe`, `wpa_personal_mixed`;
  locale `MKK` (needs networks of those kinds nearby, or a Mac in Japan).
- Battery: `Normal`, `Service Recommended` and the other System Settings
  names (needs a notebook whose battery isn't `Good`).
- Storage: file systems `ExFAT`, `MS-DOS FAT32`, `NTFS`; protocols `USB`,
  `Thunderbolt`, `SATA`, `PCI-Express`, `NVMe`, `Secure Digital`; partition
  types `EFI`, `Apple_HFS`, `Apple_Boot`, `Apple_CoreStorage`,
  `Microsoft Basic Data` (needs external drives formatted each way).
- Startup security: `Reduced Security`, `Permissive Security`; `Disabled` for
  the `ibridge_sb_*` protections; `Custom Configuration`; `Yes` for
  `ibridge_sb_other_kext` and the MDM fields (needs a Mac with a lowered
  security policy).
- Displays and audio: `spdisplays_external`, `spdisplays_pcie`; audio
  transports `bluetoothle` and `aggregate`; Thunderbolt 5 speeds.
- Bluetooth: controller transports `USB` and `UART` (older Macs).
- Settings: zoom styles `zoom_picture_in_picture` and `zoom_pip`; profile
  states `verified`, `invalid`, `unverified` and MDM install sources; managed
  preference states `often` and `once`; other sync log names.

## Blocked or deferred

- Regenerating `docs/value-inventory.md` needs a full scan on a Mac.
- Apple Bridge `ibridge_external_boot` (Macs with the T2 Security Chip) has
  Apple strings (`External Drive`, `Network`, `Internal`, `Disallowed`,
  `BootCamp`), but which field reports which of them isn't clear without a
  scan of a T2 Mac, so it has no rule yet.
