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
- **published**: in system_profiler output published online, or in code that
  reads `system_profiler -json`. The macOS samples in
  <https://github.com/glpi-project/glpi-agent> (`resources/macos/system_profiler`)
  are XML output from older macOS releases; XML and JSON use the same keys and
  values.
- **unconfirmed**: no source shows this spelling. It's matched so the value is
  explained if it appears, and it's listed under
  [Values that need a scan](#values-that-need-a-scan-on-a-real-mac) at the end of
  this file.

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

## Network services and locations

Sources: service hardware, service types and PPP subtypes, IPv4 and IPv6
configuration methods, proxy switches, PPP options, AirPort join modes, and VPN
authentication methods are System Configuration constants, documented in
Apple's `SCSchemaDefinitions.h` and `SCNetworkConfiguration.h`
(<https://developer.apple.com/documentation/systemconfiguration>). VPN On
Demand rule actions and interface types are documented in Apple's device
management reference for `VPN.OnDemandRulesElement`
(<https://developer.apple.com/documentation/devicemanagement/vpn/ondemandruleselement>).
Apple removed its PPTP client in macOS Sierra
(<https://support.apple.com/en-us/102003>). Ethernet media options are keys in
Apple's `SPNetworkReporter` strings.

| field | values | status | source | spelling |
|---|---|---|---|---|
| `hardware` | `Ethernet`, `AirPort`, `Modem` | Normal; Modem Info (a USB serial device is Inferred) | Apple, Inferred | seen |
| `hardware` | `FireWire` | Info | Apple | Apple key |
| `type` | `Ethernet`, `AirPort`, `IEEE80211`, `Bridge`, `PPP`, `PPP (PPPSerial)`, `VPN`, `VPN (<app>)` | Normal (Ethernet, Wi-Fi); Info | Apple | seen |
| `type` | `Bond`, `VLAN`, `6to4`, `IPSec` | Info | Apple | Apple constant |
| `type` | `PPP (PPPoE)`, `PPP (L2TP)`, `PPP (PPTP)` | Info | Apple | subtypes are Apple keys; the `PPP (subtype)` form is unconfirmed for these |
| IPv4 `ConfigMethod` | `DHCP`, `Manual`, `PPP`, `VPN` | Normal (DHCP); Info | Apple | seen |
| IPv4 `ConfigMethod` | `INFORM`, `BOOTP`, `LinkLocal`, `Automatic` | Info; Normal (Automatic) | Apple | Apple key |
| IPv6 `ConfigMethod` | `Automatic` | Normal | Apple | seen |
| IPv6 `ConfigMethod` | `LinkLocal`, `Manual`, `RouterAdvertisement`, `6to4` | Info; Normal (RouterAdvertisement) | Apple | Apple constant |
| proxy switches (`HTTPEnable`, `HTTPSEnable`, `SOCKSEnable`, `FTPEnable`, `GopherEnable`, `RTSPEnable`) | on, off (`yes`/`no`, `1`/`0`) | Info when on, Normal when off | Apple | seen |
| `ProxyAutoConfigEnable`, `ProxyAutoDiscoveryEnable` | on, off | Info when on, Normal when off | Apple | seen |
| `FTPPassive` | on, off | Normal, Info | Apple | seen |
| `ExcludeSimpleHostnames` | on, off | Info | Apple | seen (withheld values) |
| `OnDemandEnabled` | `true`, `false` | Info | Apple | seen |
| On Demand `Action` | `Connect`, `Disconnect`, `EvaluateConnection`, `Ignore` | Info | Apple | seen (`Connect`), Apple docs |
| `InterfaceTypeMatch` | `WiFi`, `Ethernet`, `Cellular` | Info | Apple | Apple docs (the inventory withheld them) |
| `DisconnectOnIdle`, `DisconnectOnLogout`, `DisconnectOnSleep`, `DisconnectOnFastUserSwitch`, `DisconnectOnWake` | on, off | Info | Apple | seen |
| PPP switches (`DialOnDemand`, `CommRedialEnabled`, `IdleReminder`, `LCPEchoEnabled`, `VerboseLogging`, `IPCPCompressionVJ`, `CommDisplayTerminalWindow`, `CommUseTerminalScript`, `ACSPEnabled`) | on, off | Info | Apple | seen |
| PPP switches (`CCPEnabled`, `CCPMPPE40Enabled`, `CCPMPPE128Enabled`, `IPCPUsePeerDNS`, `LCPCompressionACField`, `LCPCompressionPField`, `UseSessionTimer`) | on, off | Info | Apple | Apple key |
| `spnetworklocation_isActive` | on, off | Info | Apple | seen (withheld values) |
| `JoinMode` | `Automatic` | Normal | Apple | seen |
| `JoinMode` | `Preferred`, `Ranked`, `Recent`, `Strongest` | Info | Apple | Apple constant |
| `AuthenticationMethod` | `Password` | Info | Apple | seen |
| `AuthenticationMethod` | `Certificate`, `SharedSecret`, `Hybrid` | Info | Apple | Apple constant |
| `MediaSubType` | `autoselect`, `none` | Normal, Info | Apple | seen |
| `MediaSubType` | fixed speeds such as `1000baseT`, `100baseTX`, `10GbaseT` | Info | Apple | Apple key (`100baseTX`, `1000baseT`); other speeds unconfirmed |
| `MediaOptions` | `full-duplex`, `half-duplex`, `flow-control` | Normal, Info | Apple | Apple key |
| `spnetworkvolume_automounted` | on, off | Info | Apple | seen (withheld values) |

`ACSPEnabled` is explained from its Apple name ("ACSP Enabled") and Apple's
PPP documentation; what the server sends is not visible in the report.

## Install history, legacy software, and firewall

Sources: `package_source_*` and `reason_*` values appear in
`docs/value-inventory.md`. Firewall states are keys in Apple's
`SPFirewallReporter` strings, and the firewall settings are described in the
Mac User Guide (<https://support.apple.com/guide/mac-help/mh34041>).

| field | value | status | source | spelling |
|---|---|---|---|---|
| `package_source` | `package_source_apple` | Normal | Standard | seen |
| `package_source` | `package_source_other` | Info | Standard | seen |
| `reason` (legacy software) | `reason_x86_only` | Info | Apple | seen |
| `reason` (legacy software) | `reason_x86_forced_environmental` | Info | Inferred | seen |
| `spfirewall_globalstate` | `spfirewall_globalstate_limit_connections` | Normal | Apple | seen |
| `spfirewall_globalstate` | `spfirewall_globalstate_block_all` | Normal | Apple | Apple key |
| `spfirewall_globalstate` | `spfirewall_globalstate_allow_all` (firewall off) | Worth a look | Apple | Apple key |
| `spfirewall_globalstate` | `spfirewall_globalstate_off` | Worth a look | Apple | unconfirmed |
| `spfirewall_applications` | `spfirewall_allow_all` | Info | Apple | Apple key (values withheld in the inventory) |
| `spfirewall_applications` | `spfirewall_block_all` | Normal | Apple | Apple key |
| `spfirewall_applications` | `spfirewall_allow_local` | Info | Apple | Apple key |
| `spfirewall_stealthenabled` | `Yes`, `No` | Normal, Info | Apple | seen (`Yes`) |
| `spfirewall_loggingenabled` | `Yes`, `No` | Info | Standard | seen (`No`) |

## Wi-Fi

Sources: the values seen in `docs/value-inventory.md`, and the keys in Apple's
`SPAirPortReporter` strings. Security types follow Apple's "Recommended settings
for Wi-Fi routers and access points" (<https://support.apple.com/en-us/102766>).
Published `system_profiler SPAirPortDataType` output shows the locales `ETSI`
and `RoW` (for example <https://github.com/bettercap/bettercap/issues/361> and
<https://noname.com.ua/mediawiki/index.php/Macos_WiFi>). Signal-strength bands
are common Wi-Fi guidance, not an Apple specification.

Security modes are Worth a look only on the network this Mac is connected to;
on a nearby network the same value is Info.

| field | value | status | source | spelling |
|---|---|---|---|---|
| `spairport_status_information` | `spairport_status_connected` | Normal | Apple | seen |
| `spairport_status_information` | `spairport_status_off` | Info | Apple | Apple key |
| `spairport_status_information` | `spairport_status_disassociated` ("Not Associated") | Info | Apple | Apple key |
| `spairport_status_information` | `spairport_status_inactive` ("Network Service Inactive") | Info | Apple | Apple key |
| `spairport_status_information` | `spairport_status_disconnected`, `spairport_status_not_associated` | Info | Apple | unconfirmed |
| `spairport_security_mode` | `wpa3_personal` | Normal | Apple | seen |
| `spairport_security_mode` | `wpa3_transition` (reported as `pairport_security_mode_wpa3_transition`) | Normal | Apple | seen |
| `spairport_security_mode` | `wpa2_personal`, `wpa2_enterprise` | Normal | Apple | seen |
| `spairport_security_mode` | `wpa3_enterprise`, `wpa2_wpa3_enterprise`, `owe` | Normal | Apple | unconfirmed |
| `spairport_security_mode` | `wpa2_personal_mixed`, `wpa2_enterprise_mixed` | Worth a look / Info | Apple | Apple key |
| `spairport_security_mode` | `wpa_personal`, `wpa_enterprise` | Worth a look / Info | Apple | Apple key |
| `spairport_security_mode` | `wpa_personal_mixed` | Worth a look / Info | Apple | unconfirmed |
| `spairport_security_mode` | `wep`, `wep40`, `wep128`, `8021x` (802.1X with WEP) | Worth a look / Info | Apple | Apple key |
| `spairport_security_mode` | `wps` | Worth a look / Info | Apple | Apple key |
| `spairport_security_mode` | `none` | Worth a look / Info | Apple | Apple key |
| `spairport_network_type` | `spairport_network_type_station` (Infrastructure) | Info | Apple | seen |
| `spairport_network_type` | `spairport_network_type_ibss` (Computer-to-Computer) | Info | Apple | Apple key |
| `spairport_network_type` | `spairport_network_type_sharing` (Wi-Fi Internet Sharing) | Info | Apple | Apple key |
| `spairport_caps_airdrop`, `_autounlock`, `_wow`, `_awdl` | `spairport_caps_supported` | Info | Apple | seen (not `_awdl`) |
| `spairport_caps_airdrop`, `_autounlock`, `_wow`, `_awdl` | `spairport_caps_unsupported` | Info | Apple | Apple key |
| `spairport_wireless_locale` | `FCC` | Info | Apple | seen |
| `spairport_wireless_locale` | `ETSI`, `RoW` | Info | Apple (`ETSI`), Standard (`RoW`) | published |
| `spairport_wireless_locale` | `MKK` | Info | Apple | unconfirmed |
| `spairport_signal_noise` | any `-NN dBm / -NN dBm` (Excellent to Poor) | Normal to Worth a look (current), Info (nearby) | Standard | seen (values withheld) |
| `spairport_network_channel` | any `N (2GHz/5GHz/6GHz, NNMHz)` | Info | Apple | seen (values withheld) |
| `spairport_network_phymode`, `spairport_supported_phymodes` | `802.11` lists up to `be` | Normal (current), Info | Apple | seen (values withheld) |
| `spairport_network_rate` | a number of Mbps | Info | Apple | seen |
| `spairport_network_country_code`, `spairport_wireless_country_code` | two-letter country codes | Info | Apple | seen (`US`) |

## Power and battery

Sources: the values seen in `docs/value-inventory.md`, and the keys in Apple's
`SPPowerReporter` strings. Battery conditions: "Check the condition of your Mac
laptop's battery" (<https://support.apple.com/guide/mac-help/mh20865>) and "If
you see battery Service Recommended" (<https://support.apple.com/en-us/108376>).
Cycle and capacity limits: <https://support.apple.com/en-us/102888>. Hibernate
modes: the `pmset` man page.

| field | value | status | source | spelling |
|---|---|---|---|---|
| `sppower_battery_health` | `Good` (shown as Normal) | Normal | Apple | seen |
| `sppower_battery_health` | `Fair` (Replace Soon) | Worth a look | Apple | Apple key |
| `sppower_battery_health` | `Poor` (Replace Now) | Worth a look | Apple | Apple key |
| `sppower_battery_health` | `Check Battery` (Service Battery) | Worth a look | Apple | Apple key |
| `sppower_battery_health` | `Normal`, `Service Recommended`, `Replace Soon`, `Replace Now`, `Service Battery` | Normal, Worth a look | Apple | unconfirmed (shown in System Settings and menus) |
| `sppower_battery_at_warn_level` | `TRUE` (charging or not), `FALSE` | Info or Worth a look, Normal | Apple | seen (`TRUE`), Apple key (`FALSE`) |
| `sppower_battery_is_charging` | `TRUE`, `FALSE` (full or not) | Normal, Info | Apple | seen (`FALSE`), Apple key |
| `sppower_battery_fully_charged` | `TRUE`, `FALSE` | Normal, Info | Apple | seen (`FALSE`), Apple key |
| `sppower_battery_charger_connected` | `TRUE`, `FALSE` | Info | Apple | seen (`FALSE`), Apple key |
| `sppower_ups_installed` | `TRUE`, `FALSE` | Info | Apple | seen (`FALSE`), Apple key |
| `sppower_battery_state_of_charge` | a percentage (10% or less and not charging is Worth a look) | Normal, Worth a look | Apple | seen |
| `sppower_battery_cycle_count` | a number (1,000 or more is Info) | Normal, Info | Apple | seen |
| `sppower_battery_health_maximum_capacity` | a percentage (below 80% is Worth a look) | Normal, Worth a look | Apple | seen (withheld) |
| `Current Power Source` | `TRUE` under `AC Power`, `Battery Power`, `UPS Power` | Info | Apple | Apple key |
| `Hibernate Mode` | `0`, `3`, `25` | Normal, Info | Apple | seen (`3`) |
| `Display`, `System`, `Disk Sleep Timer` | minutes, `0` (never) | Info | Apple | seen |
| `LowPowerMode`, `HighPowerMode` | `0`/`1` (or yes/no) | Normal, Info | Apple | seen (withheld) |
| `PrioritizeNetworkReachabilityOverSleep` | `0`/`1` | Normal, Info | Apple | seen (withheld) |
| `ReduceBrightness` | `0`/`1` | Info | Apple | seen (withheld) |
| `eventtype` | `wake` | Info | Apple | seen |
| `eventtype` | `poweron`, `wakepoweron`, `sleep`, `shutdown`, `restart` | Info | Apple | Apple key |

## Storage and NVMe

Sources: the values seen in `docs/value-inventory.md`, the keys in Apple's
`SPStorageReporter`, `SPNVMeReporter`, `SPSerialATAReporter` and `SPSupport`
strings, and the glpi-agent samples, which show a Serial ATA drive with Journaled
HFS+ and MS-DOS FAT32 volumes and an SD card in a card reader. File systems: "File system formats available in Disk Utility on Mac"
(<https://support.apple.com/guide/disk-utility/dsku19ed921c>). The sealed system
volume: "Signed system volume security"
(<https://support.apple.com/guide/security/secd698747c9>).

| field | value | status | source | spelling |
|---|---|---|---|---|
| `smart_status` | `Verified` | Normal | Apple | seen |
| `smart_status` | `Failing` | Worth a look | Apple | Apple key |
| `smart_status` | `Not Supported` | Info | Apple | Apple key, published |
| `medium_type` | `ssd` | Info | Apple | seen |
| `medium_type` | `rotational` | Info | Apple | Apple key |
| `file_system` | `APFS` | Normal | Apple | seen |
| `file_system` | `Journaled HFS+`, `Case-sensitive Journaled HFS+` | Info | Apple | Apple key |
| `file_system` | `MS-DOS FAT32` | Info | Apple | published |
| `file_system` | `ExFAT`, `NTFS` | Info | Apple | unconfirmed (matched by name) |
| `partition_map_type` | `guid_partition_map_type` | Normal | Apple | seen |
| `partition_map_type` | `master_boot_record_partition_map_type` | Info | Apple | Apple key, published |
| `partition_map_type` | `apple_partition_map_type` | Info | Apple | Apple key |
| `partition_map_type` | `unknown_partition_map_type` | Info | Inferred | seen |
| `writable` | `yes`; `no` on the system volume, a disk image, or another volume | Normal, Info | Apple | seen |
| `free_space_in_bytes` | a byte count (under 10% free is Worth a look) | Normal, Info, Worth a look | Standard | seen |
| `is_internal_disk` | `yes`, `no` (external or disk image) | Info | Apple | seen |
| `protocol` | `Apple Fabric` | Info | Inferred | seen |
| `protocol` | `Disk Image` | Info | Apple | seen |
| `protocol` | `USB`, `Thunderbolt`, `SATA`, `PCI-Express`, `NVMe`, `Secure Digital` | Info | Apple | unconfirmed |
| `ignore_ownership` | `yes`, `no` | Info, Normal | Apple | seen (`no`) |
| `removable_media`, `detachable_drive` | `yes`, `no` | Info | Apple | seen (`no`) |
| `spnvme_trim_support`, `spsata_trim_support` | `Yes`, `No` | Normal, Info | Apple | seen (`Yes`), Apple key (field) |
| `iocontent` | `Apple_APFS`, `Apple_APFS_ISC`, `Apple_APFS_Recovery` | Info | Apple | seen |
| `iocontent` | `EFI`, `Apple_HFS`, `Apple_Boot`, `Apple_CoreStorage` | Info | Standard | published (Serial ATA volumes) |
| `iocontent` | `Windows_FAT_32` | Info | Standard | published (a card in a card reader) |
| `iocontent` | `Microsoft Basic Data` | Info | Standard | unconfirmed (the name `diskutil list` shows) |

Serial ATA drives and cards in a card reader report the same drive and volume
fields, and get the same explanations: `smart_status`, `partition_map_type`,
`removable_media`, `detachable_drive`, and each volume's `file_system`,
`writable`, and `iocontent`. Free space is explained only in the Storage
section, which lists the same volumes, so a shortage isn't reported twice.

## Serial ATA

Sources: the glpi-agent samples (an Intel SATA controller, Apple's SSD
controller, and a virtual machine). SATA generations follow the SATA-IO
specifications and PCI Express rates the PCI-SIG specifications.

| field | value | status | source | spelling |
|---|---|---|---|---|
| `spsata_medium_type` | `Rotational`, `Solid State` | Info | Standard | published |
| `spsata_physical_interconnect` | `SATA` | Info | Standard | published |
| `spsata_physical_interconnect` | `PCI` (Apple's SSD controller) | Info | Inferred | published |
| `spsata_portspeed` | `1.5 Gigabit`, `3 Gigabit`, `6 Gigabit` | Info | Standard | published (`3 Gigabit`); others unconfirmed |
| `spsata_negotiatedlinkspeed` | the same speeds; slower than `spsata_portspeed` is Info | Normal, Info | Standard | published (`3 Gigabit`); others unconfirmed |
| `spsata_ncq` | `Yes`, `No` | Normal, Info | Standard | published |
| `spsata_linkspeed` | `2.5`, `5.0`, `8.0`, `16.0`, `32.0 GT/s` | Info | Standard | published (`5.0 GT/s`); others unconfirmed |
| `spsata_linkwidth` | `x1`, `x2`, `x4`, `x8`, `x16` | Info | Standard | published (`x2`); others unconfirmed |

Speeds written with a decimal comma, such as `1,5 Gigabit`, are read too, since
the samples show sizes written that way in some languages. Lane counts require
`x` followed by a complete unsigned ASCII integer in the supported set; signed
or malformed suffixes stay unexplained. `spsata_power_off`
and `spsata_async_notify` (both `No` in the samples) have no rule, because no
source says what they report.

## Disc burning

Sources: the glpi-agent samples, and the support levels and interconnects of
Apple's Disc Recording framework (`DRDeviceSupportLevel…` and
`DRDevicePhysicalInterconnect…`, listed in
<https://developer.apple.com/library/archive/releasenotes/General/APIDiffsMacOSX10_10_3/modules/DiscRecording.html>).
Apple SDK `DRDevice.h` and `DRCoreDevice.h` define support levels, physical
interfaces, and medium-specific write capabilities. The installed
`SPDiscBurningReporter` also contains the DVD format suffixes below; that
confirms spellings, not a live drive's capabilities.

| field | value | status | source | spelling |
|---|---|---|---|---|
| `burn_support` | `DRDeviceSupportLevelAppleShipping` | Normal | Apple | published |
| `burn_support` | `DRDeviceSupportLevelAppleSupported` | Normal | Apple | Apple constant |
| `burn_support` | `DRDeviceSupportLevelVendorSupported`, `DRDeviceSupportLevelUnsupported`, `DRDeviceSupportLevelNone` | Info | Apple | Apple constant |
| `device_media` | `media_none` | Info | Standard | published |
| `device_readdvd` | `yes`, `no` | Info | Standard | published (`yes`) |
| `interconnect` | `ATAPI` | Info | Apple | published |
| `interconnect` | `USB`, `FireWire`, `SCSI` | Info | Apple | Apple constant |
| `device_cdwrite` | lists of `-R`, `-RW` only | Info | Standard | published |
| `device_dvdwrite` | lists of `-R`, `-RW`, `+R`, `+RW`, `-R DL`, `+R DL` | Info | Standard | published |
| `device_dvdwrite` | lists that include `-RW DL`, `-RAM`, or `+RW DL` | Info | Standard | Apple capability constants and installed reporter strings; not live-tested |
| `device_strategies` | lists of `CD-TAO`, `CD-SAO`, `CD-Raw`, `DVD-DAO` | Info | Apple | published |
| `device_strategies` | lists that include `BD-DAO` | Info | Apple | unconfirmed (Apple constant) |

Format and strategy lists with an unknown or empty entry are shown as not yet
explained, rather than partly explained. DVD-only formats in `device_cdwrite`
remain unexplained. Raw values are unchanged. A listed format is a reported
capability, not proof of a successful burn or compatible inserted media.
`device_media` values other than `media_none` (a disc in the drive) are not
explained yet.

Support labels follow Apple's framework contract: AppleSupported means tested
by Apple; VendorSupported means tested by a third party; Unsupported still lets
the engine try the drive; None means no support from that engine. They don't
prove a successful burn, maker-provided software, or read-only hardware.
Interconnect values identify an interface, not internal/external location.

## Startup security, software overview, and hardware

Sources: the values seen in `docs/value-inventory.md`, and the keys in Apple's
`SPiBridgeReporter`, `SPOSReporter` and `SPHardwareReporter` strings. Security
levels: "Startup Disk security policy control for a Mac with Apple silicon"
(<https://support.apple.com/guide/security/sec7d92dc49f>) and "Change security
settings on the startup disk of a Mac with Apple silicon"
(<https://support.apple.com/guide/mac-help/mchl768f7291>). Safe Mode:
<https://support.apple.com/guide/mac-help/mh21245>. Activation Lock:
<https://support.apple.com/en-us/102541>.

| field | value | status | source | spelling |
|---|---|---|---|---|
| `ibridge_secure_boot` | `Full Security` | Normal | Apple | seen |
| `ibridge_secure_boot` | `Medium Security` | Info | Apple | Apple key (T2 Macs) |
| `ibridge_secure_boot` | `No Security` | Worth a look | Apple | Apple key (T2 Macs) |
| `ibridge_secure_boot` | `Reduced Security` | Info | Apple | unconfirmed |
| `ibridge_secure_boot` | `Permissive Security` | Worth a look | Apple | unconfirmed |
| `ibridge_sb_sip` | `Enabled`, `Disabled`, `Custom Configuration` | Normal, Worth a look | Apple | seen (`Enabled`); others unconfirmed |
| `ibridge_sb_ssv`, `ibridge_sb_ctrr` | `Enabled`, `Disabled` | Normal, Worth a look | Apple | seen (`Enabled`); `Disabled` unconfirmed |
| `ibridge_sb_boot_args` | `Enabled` (filtered), `Disabled` | Normal, Info | Apple | seen (`Enabled`); `Disabled` unconfirmed |
| `ibridge_sb_other_kext` | `No`, `Yes` | Normal, Info | Apple | seen (`No`); `Yes` unconfirmed |
| `ibridge_sb_manual_mdm`, `ibridge_sb_device_mdm` | `No`, `Yes` | Normal, Info | Inferred | seen (`No`); `Yes` unconfirmed |
| `system_integrity` | `integrity_enabled`, `integrity_disabled` | Normal, Worth a look | Apple | seen, Apple key |
| `secure_vm` | `secure_vm_enabled`, `secure_vm_disabled` | Normal, Worth a look | Apple | seen, Apple key |
| `boot_mode` | `normal_boot` | Normal | Apple | seen |
| `boot_mode` | `safe_boot`, `installer_boot` | Info | Apple | Apple key |
| `uptime` | `up d:h:m:s` (30 days or more is Info) | Normal, Info | Standard | seen |
| `activation_lock_status` | `activation_lock_enabled`, `activation_lock_disabled` | Normal, Info | Apple | seen, Apple key |
| `number_processors` | `proc total:…:performance:efficiency` | Info | Inferred | seen |
| `physical_memory` | a size on Apple silicon | Info | Apple | seen (withheld) |

## Displays, audio, Bluetooth, Thunderbolt, USB, memory, card readers, and Ethernet

Sources: the values seen in `docs/value-inventory.md`, and the keys in Apple's
`SPDisplaysReporter`, `SPAudioReporter`, `SPThunderboltReporter`,
`SPMemoryReporter`, and `SPEthernetReporter` strings. The glossaries have no
Bluetooth or USB reporter, so those spellings come only from the inventory.
Bluetooth visibility: <https://support.apple.com/guide/mac-help/blth1004>.

| field | value | status | source | spelling |
|---|---|---|---|---|
| `spdisplays_display_type` | `spdisplays_built-in-liquid-retina-xdr` | Info | Standard | seen |
| `spdisplays_display_type` | `LCD`, `CRT`, `retinaLCD`, `built-in_retinaLCD`, `projector`, `television`, `airplaydisplay` | Info | Apple | Apple key |
| `spdisplays_display_type` | other `spdisplays_…` names (shown as written) | Info | Standard | as reported |
| `spdisplays_connection_type` | `spdisplays_internal` | Info | Apple | seen |
| `spdisplays_connection_type` | `spdisplays_airplay` | Info | Apple | Apple key |
| `spdisplays_connection_type` | `spdisplays_external` | Info | Apple | unconfirmed |
| `spdisplays_online`, `_main`, `_mirror`, `_ambient_brightness` | `spdisplays_yes`/`_on`, `spdisplays_no`/`_off` | Normal, Info | Apple | seen (`yes`, `off`), Apple key |
| `sppci_device_type` | `spdisplays_gpu` | Info | Apple | seen |
| `sppci_device_type` | `spdisplays_egpu` | Info | Apple | Apple key |
| `sppci_bus` | `spdisplays_builtin` | Info | Apple | seen |
| `sppci_bus` | `spdisplays_pcie_device`, `spdisplays_tb_device`, `spdisplays_agp_device` | Info | Apple | Apple key |
| `sppci_bus` | `spdisplays_pcie` | Info | Apple | unconfirmed |
| `spdisplays_mtlgpufamilysupport` | `spdisplays_metalN` | Info | Apple | seen (`metal4`) |
| `spdisplays_mtlgpufamilysupport` | `spdisplays_mtlgpufamilymacN`, `…commonN` | Info | Apple | Apple key |
| `spdisplays_vendor` | `sppci_vendor_…` | Info | Apple | seen (`Apple`), Apple key (`Nvidia`, `amd`) |
| `coreaudio_device_transport` | `coreaudio_device_type_builtin` | Info | Apple | seen |
| `coreaudio_device_transport` | `airplay`, `avb`, `bluetooth`, `displayport`, `firewire`, `hdmi`, `network`, `other`, `pci`, `thunderbolt`, `unknown`, `usb`, `virtual`, `wireless` | Info | Apple | Apple key |
| `coreaudio_device_transport` | `bluetoothle`, `aggregate` | Info | Standard | unconfirmed |
| `coreaudio_default_audio_*_device`, `_properties` | `spaudio_yes`, `coreaudio_default_audio_*_device` | Info | Apple | seen |
| `receptacle_status_key` | `receptacle_no_devices_connected` | Info | Apple | seen |
| `receptacle_status_key` | `receptacle_connected` | Info | Apple | Apple key |
| `link_status_key` | `trained`, `training`, `untrained`, `disabled`, `off`, `Loopback`, `unknown` + `_link_status` | Normal, Info | Apple | Apple key; current format unconfirmed (withheld in the inventory) |
| `current_speed_key` | `Up to 40 Gb/s` | Info | Apple | seen |
| `current_speed_key` | `Up to 10/20 Gb/s x1/x2` | Info | Apple | Apple key |
| `current_speed_key` | `Up to 80/120 Gb/s` (Thunderbolt 5) | Info | Apple | unconfirmed |
| `controller_state`, `controller_discoverable` | `attrib_on`, `attrib_off` | Normal, Info | Apple | seen |
| `controller_transport` | `PCIe` | Info | Apple | seen |
| `controller_transport` | `USB`, `UART` | Info | Apple | unconfirmed |
| `USBKeyHardwareType` | `Built-in` | Info | Apple | seen |
| `dimm_type` | `LPDDR…`, `DDR…` | Info | Apple | seen (`LPDDR5`) |
| `dimm_status` | `ok`, `empty`, `mapped_out`, `unknown` | Normal, Info, Worth a look | Apple | Apple key |
| `global_ecc_state` | `ecc_enabled`, `ecc_disabled` | Normal, Info | Apple | Apple key |
| `is_memory_upgradeable` | `Yes`, `No` | Info | Apple | Apple key (field) |
| `spcardreader_link-speed`, `-width` | `Off` | Info | Inferred | seen |
| `spethernet_bus` | `spethernet_usb_device`, `spethernet_pcie`, `spethernet_builtin` | Info | Apple | seen (`usb_device`); others unconfirmed |
| `spethernet_max_link_speed` | `ethernet_speed_N` | Info | Apple | seen |
| `spethernet_usb_device_speed` | `low_speed` … `super_speed_plus_by_2` | Info | Apple | seen (`high_speed`); others unconfirmed |

## Bluetooth accessories

Sources: the inventory Mac had no connected accessories, so these spellings come
from code that reads `system_profiler SPBluetoothDataType -json`: the Toothpick
extension in <https://github.com/raycast/extensions>
(`extensions/toothpick/src/core/devices`), which reads `device_minorType` and the
four battery levels; <https://github.com/yigegongjiang/jj-ice>, which reads
`Headphones` and `Headset`; and a published accessory in
<https://github.com/raycast/extensions/issues/5860> (`Mouse`, `0x400000 < BLE >`).
`Trackpad` is from older text output read by
<https://github.com/matryer/xbar-plugins>
(`System/Battery/trackpad-system_profiler.1m.rb`). Service names are standard
Bluetooth profile abbreviations.

| field | value | status | source | spelling |
|---|---|---|---|---|
| `device_minorType` | `Headphones`, `Headset`, `Keyboard`, `Mouse`, `Speaker`, `Gamepad` | Info | Standard | published |
| `device_minorType` | `Trackpad` | Info | Standard | published (older text output) |
| `device_batteryLevelMain`, `_Left`, `_Right`, `_Case` | a percentage such as `85%`: over 20% Normal, 11–20% Info, 10% or less Worth a look | Normal, Info, Worth a look | Standard | published (keys and `%` format) |
| `device_services`, `controller_supportedServices` | `< BLE >` | Info | Standard | published |
| `device_services`, `controller_supportedServices` | lists of `A2DP`, `AVRCP`, `HFP`, `HID`, `GATT`, `Braille`, `SerialPort`, `Serial`, `HSP`, `PAN` | Info | Standard | unconfirmed in this form |
| `device_services`, `controller_supportedServices` | lists that include `AACP` | Info | Inferred | unconfirmed |

A service list names any service the app doesn't know, and a list with none it
knows is shown as not yet explained. The accessory types other than these are
not explained yet.

Battery levels require a complete unsigned ASCII integer from 0 through 100
followed by `%`. Surrounding whitespace and a space/nonbreaking space before
`%` are accepted for percent-formatter compatibility. Decimal, signed,
out-of-range, or partially numeric text such as `85garbage%` stays unexplained;
the raw value is retained. The 10% and 20% boundaries are app review thresholds,
not vendor health diagnoses, and a reported level doesn't prove a current
connection or charging state.

Service lists require a complete `<…>` structure, optionally preceded by a
hexadecimal `0x…` value. Extra surrounding text or nested brackets remain
unexplained. Whitespace-separated unfamiliar names stay visible; the app does
not infer token meanings from the bitmask. BLE and GATT are capabilities, not
both profiles, and listing a capability doesn't prove active use.

## Settings and profiles

Sources: the values seen in `docs/value-inventory.md`, and the keys in Apple's
`SPUniversalAccessReporter`, `SPInternationalReporter`, and
`SPSecureElementReporter` strings. The glossaries have no strings for
configuration profiles, managed preferences, printers, or sync services.
Profiles: "Use configuration profiles to standardize settings on Mac computers"
(<https://support.apple.com/guide/mac-help/mh35561>). Printer states follow the
CUPS printer states.

| field | value | status | source | spelling |
|---|---|---|---|---|
| `display` (accessibility) | `black_on_white` | Info | Apple | seen |
| `display` (accessibility) | `white_on_black` | Info | Apple | Apple key |
| `zoomMode` | `zoom_full_screen` | Info | Apple | seen |
| `zoomMode` | `zoom_split_screen`, `zoom_in_window` | Info | Apple | Apple key |
| `zoomMode` | `zoom_picture_in_picture`, `zoom_pip` | Info | Apple | unconfirmed |
| `voiceover`, `sticky_keys`, `slow_keys`, `mouse_keys`, `cursor_mag`, `flash_screen`, `keyboardZoom`, `scrollZoom` | `on` | Info | Apple | Apple key |
| same fields | `off` | Normal | Apple | seen |
| `system_text_direction`, `user_text_direction` | `text_direction_ltr`, `text_direction_rtl` | Info | Apple | seen (`ltr`), Apple key |
| `system_uses_metric_system`, `user_uses_metric_system` | `value_yes`, `value_no` | Info | Apple | seen (`value_no`), Apple key |
| `system_country` | two-letter country codes | Info | Apple | seen (`US`) |
| `user_assistant_voice_gender` | `voice_gender_female`, `voice_gender_male` | Info | Apple | Apple key (withheld in the inventory) |
| `user_temperature_unit` | `Celsius`, `Fahrenheit` | Info | Apple | Apple key |
| `user_calendar` | `gregorian`, `buddhist`, `chinese`, `coptic`, `ethiopic`, `ethiopic-amete-alem`, `hebrew`, `indian`, `islamic`, `islamic-civil`, `islamic-tbla`, `islamic-umalqura`, `iso8601`, `japanese`, `persian`, `roc` | Info | Apple | Apple key (withheld in the inventory) |
| `spconfigprofile_verification_state` | `unsigned` | Info | Apple | seen |
| `spconfigprofile_verification_state` | `verified` | Normal | Apple | unconfirmed |
| `spconfigprofile_verification_state` | `invalid`, `unverified` | Worth a look | Apple | unconfirmed |
| `spconfigprofile_install_source` | `Manual` | Info | Apple | seen |
| `spconfigprofile_install_source` | values containing `MDM` or `management` | Info | Apple | unconfirmed |
| `spconfigprofile_RemovalDisallowed` | `yes`, `no` | Info | Apple | seen (`no`) |
| `data_state` (managed preferences) | `always` | Info | Apple | seen |
| `data_state` (managed preferences) | `often`, `once` | Info | Apple | unconfirmed |
| `status` (printers) | `idle`, `processing`/`printing`, `stopped` | Info | Standard | unconfirmed (withheld in the inventory) |
| `shared`, `default`, `printersharing`, `scanner` (printers) | yes, no | Normal, Info | Apple, Standard | unconfirmed (withheld in the inventory) |
| `description` (sync services) | `system_log_description` | Info | Inferred | seen |
| `description` (sync services) | other `…_log_description` names | Info | Inferred | unconfirmed |
| `se_in_restricted_mode` | `No`, `Yes` | Normal, Info | Inferred | seen (`No`), Apple key |
| `se_prod_signed` | `Yes`, `No` | Normal, Info | Inferred | Apple key (withheld in the inventory) |

## Values that need a scan on a real Mac

Each of these is explained, but no public source confirms the exact spelling
current macOS reports, or the inventory withheld the field's values. A scan with
the matching hardware or setting would confirm them (or show a spelling to add).
Until then, a different spelling is shown as "not yet explained".

**Fields whose value format is unknown** (no rule, or the rule may never match):

- `contrast` (Accessibility): no rule; its values were withheld.
- `ibridge_extra_boot_policies` (Apple Bridge): no rule; its values were withheld.
- `UserVisible` (scheduled power events): no rule; its values were withheld.
- `ibridge_external_boot` (Macs with the T2 Security Chip): Apple's strings name
  `External Drive`, `Network`, `Internal`, `Disallowed`, and `BootCamp`, but which
  field reports which isn't clear without a scan of a T2 Mac, so it has no rule.
- `link_status_key` (Thunderbolt): the rule matches Apple's `trained_link_status`
  family, but current macOS may report a number such as `0x2`.
- `printersharing`, `scanner`, `shared`, `default`, and `status` (Printers):
  needs a Mac with a printer set up.
- `spsata_power_off` and `spsata_async_notify` (Serial ATA): no rule; no source
  says what they report.

**Spellings to confirm, by section:**

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
- Storage: file systems `ExFAT` and `NTFS`; protocols `USB`, `Thunderbolt`,
  `SATA`, `PCI-Express`, `NVMe`, `Secure Digital`; partition type
  `Microsoft Basic Data` (needs external drives formatted each way).
- Serial ATA: link speeds other than `3 Gigabit`, PCI Express rates other than
  `5.0 GT/s`, and whether current macOS reports the same keys as the older
  samples (needs an Intel Mac with a SATA drive).
- Disc burning: the support levels other than `AppleShipping`, interconnects
  `USB`, `FireWire`, and `SCSI`, the `-RAM` and `+RW DL` formats, `BD-DAO`, and
  `device_media` with a disc inserted (needs a Mac with an optical drive, such
  as a USB SuperDrive).
- Bluetooth accessories: the service list spellings other than `BLE`, accessory
  types other than the published ones, and whether `Trackpad` is still the type
  current macOS reports (needs a scan with a trackpad, headphones, and a game
  controller connected).
- Startup security: `Reduced Security`, `Permissive Security`; `Disabled` for
  the `ibridge_sb_*` protections; `Custom Configuration`; `Yes` for
  `ibridge_sb_other_kext` and the MDM fields (needs a Mac with a lowered
  security policy).
- Displays and audio: `spdisplays_external`, `spdisplays_pcie`; audio
  transports `bluetoothle` and `aggregate`; Thunderbolt 5 speeds.
- Bluetooth controller: transports `USB` and `UART` (older Macs).
- Settings: zoom styles `zoom_picture_in_picture` and `zoom_pip`; profile
  states `verified`, `invalid`, `unverified` and MDM install sources; managed
  preference states `often` and `once`; other sync log names.
