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
4. [ ] Fonts (the most values in a scan): font kind, enabled, valid,
   duplicate, copy protected, embeddable, outline.
5. [ ] Extensions: loaded, loadable, dependencies, Intel code,
   architectures.
6. [ ] Network services and locations: hardware, service type, IPv4 and IPv6
   configuration, proxies, VPN On Demand and its rules, PPP and VPN
   switches, Wi-Fi join mode, VPN sign-in, Ethernet media, active location,
   network volumes.
7. [ ] Install history, legacy software, and firewall.
8. [ ] Wi-Fi: status, security, network type, capabilities, regulatory
   locale.
9. [ ] Power and battery: battery condition and charge states, power
   source, hibernate mode, Low and High Power Mode, network reachability,
   reduced brightness, adapter, UPS, scheduled events.
10. [ ] Storage and NVMe: SMART, file system, medium, partition map,
    writable, internal, protocol, ownership, TRIM, removable, detachable,
    volume content.
11. [ ] Startup security, software overview and hardware: Secure Boot and
    its protections, SIP, secure virtual memory, boot mode, Activation Lock.
12. [ ] Displays, audio, Bluetooth, Thunderbolt, USB, memory, card readers.
13. [ ] Settings and profiles: accessibility, language and region,
    configuration profiles, managed preferences, printers, sync services,
    Secure Element.
14. [ ] Update `docs/value-inventory.md` to point at the new list, and
    finish the scan list below.

## Values that need a scan on a real Mac

To be completed as the steps land. These are spellings that no public
source confirms, or fields whose values the inventory withheld.

## Blocked or deferred

- Regenerating `docs/value-inventory.md` needs a full scan on a Mac.
