# Plan: explain the values of drives and accessories the inventory Mac didn't have

`docs/value-inventory.md` comes from one Apple silicon Mac with no connected
Bluetooth accessories, no Serial ATA drive, no disc drive, and no card in its
card reader. Every limited-set field that Mac reported now has a value rule,
but these sections only get the general data-type text, even though they are
common on other Macs:

- **Bluetooth accessories**: the accessory type, battery levels, and the
  services an accessory or the controller supports. Most Macs have a paired
  keyboard, mouse, trackpad, or headphones.
- **Serial ATA**: every Intel iMac, Mac mini, and older MacBook reports its
  drive here, along with the same volume fields the Storage section has.
- **Card readers**: a card in the slot is reported with the same drive and
  volume fields.
- **Disc burning**: Macs with a built-in or USB optical drive.

Spellings come from published output: the macOS samples in
<https://github.com/glpi-project/glpi-agent> (`resources/macos/system_profiler`,
the XML form, whose keys and values are what `-json` reports), and code that
reads `system_profiler SPBluetoothDataType -json`, such as the Toothpick
extension in <https://github.com/raycast/extensions>. A value no source shows
is marked unconfirmed, and anything else is shown as not yet explained.

The list of values that need a scan was in the previous `PLAN.md`, which was
removed, so `docs/value-explanations.md` points at a file that no longer
exists. This branch moves that list into the docs.

## Steps

1. [x] Write this plan.
2. [x] Apply the drive and volume rules (SMART, partition map, file system,
   writable, partition content, removable and detachable) to Serial ATA drives
   and to cards in a card reader, and explain `Windows_FAT_32`. Free space
   stays on the Storage section, so a shortage isn't reported twice.
3. [x] Serial ATA: medium type, physical interconnect, negotiated and port
   link speed, Native Command Queuing, and the PCI Express link of Apple's SSD
   controller.
4. [x] Disc burning: support level, media in the drive, DVD reading,
   interconnect, writable CD and DVD formats, and burn strategies.
5. [x] Bluetooth accessories: accessory type, battery levels (main, left,
   right, case), and supported services for accessories and the controller.
6. [ ] Docs: list every new value in `docs/value-explanations.md` with its
   source and spelling, mark the spellings the published samples confirm, and
   move the list of values that need a scan into that file.
7. [ ] Remove this plan.

## Verification

There is no Xcode here, so each pushed commit is built and tested by the CI
`build-and-test` job. Each step adds its values to `ValueCatalogTests`, which
checks that every listed value has every part of an explanation, plus tests for
the values that change the status.
