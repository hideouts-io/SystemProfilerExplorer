# system_profiler value inventory

Generated 2026-09-27 from a full `system_profiler -json -detailLevel full` run of every data type on one Apple silicon Mac (macOS 27). It records which fields appear, what kind of values they hold, and whether the app explains them today. It is input for the value-explanation work.

**Privacy:** personal data is removed. Dictionary keys that contain names (Bluetooth devices, firewall app identifiers, other named entries) are collapsed to `<name>`, `<device name>`, or `<app identifier>`. Values are listed only for enumeration and boolean-like fields whose key and values are not identifying; everything else shows only counts. Serial numbers, UUIDs, MAC/IP addresses, network names, host and user names, and paths are never listed.

## Summary

- Data types that returned data on this Mac: 38 of 51 reported by `system_profiler -listDataTypes`
- Distinct fields (after collapsing name keys): 526
- Scalar values: 75,551
- Field explanation coverage: curated 344, general data-type context 128, none 54
- Fields whose explanation text changes with the reported value: 2

Column key: **class** = enumeration, boolean-like, numeric, identifier, or free text (heuristic). **explained** = curated field explanation, general context only, or none. **value-aware** = the explanation text differed between two observed values (only detectable when more than one value was seen).

## Value explanations added since this inventory

The **value-aware** column and the count above predate value explanations. Each value is now explained by the rules in `SystemProfilerExplorer/Core/Explanations/Values`, and **`docs/value-explanations.md` lists every explained value** with its status, its source, and whether its spelling is confirmed. The tables below are unchanged, because regenerating them needs a full scan on a Mac.

Among the fields this inventory classes as enumeration or boolean-like, these have no value rule yet:

- **Values that are identifiers, names, dates, versions, or sizes**, which the class heuristic counted as enumerations. The field explanation covers them, and a rule would keep personal values in anonymized samples. Examples: `machine_model`, `chip_type`, `boot_volume`, locale and language codes, SDK versions, display and card reader IDs, `lastModified`, battery lot codes, Secure Element versions, Thunderbolt route strings and UIDs, and printer names.
- **Enumerations whose values the inventory withheld and whose format no public source shows**: `contrast` (Accessibility), `ibridge_extra_boot_policies` (Apple Bridge), and `UserVisible` (scheduled power events). `link_status_key` (Thunderbolt) and `printersharing` and `scanner` (Printers) now have rules for the spellings Apple's strings or the usual yes/no forms use, but the format this Mac reports still needs a sample; an unmatched value is shown as not yet explained.
- **Audio device names and manufacturers** (`coreaudio_input_source`, `coreaudio_output_source`, `coreaudio_device_manufacturer`), which are free text.

## Wi-Fi (`SPAirPortDataType`)

| field | class | values seen | distinct | explained | value-aware | example values |
|---|---|---:|---:|---|---|---|
| `spairport_airport_interfaces.[]._name` | free text | 2 | 2 | none | no |  |
| `spairport_airport_interfaces.[].spairport_airport_other_local_wireless_networks.[]._name` | free text | 6 | 1 | none | no |  |
| `spairport_airport_interfaces.[].spairport_airport_other_local_wireless_networks.[].spairport_network_channel` | enumeration | 6 | 4 | curated | no | _withheld_ |
| `spairport_airport_interfaces.[].spairport_airport_other_local_wireless_networks.[].spairport_network_phymode` | enumeration | 6 | 2 | curated | no | _withheld_ |
| `spairport_airport_interfaces.[].spairport_airport_other_local_wireless_networks.[].spairport_network_type` | enumeration | 6 | 1 | curated | no | `spairport_network_type_station` |
| `spairport_airport_interfaces.[].spairport_airport_other_local_wireless_networks.[].spairport_security_mode` | enumeration | 6 | 4 | curated | no | `spairport_security_mode_wpa2_personal`, `pairport_security_mode_wpa3_transition`, `spairport_security_mode_wpa3_personal`, `spairport_security_mode_wpa2_enterprise` |
| `spairport_airport_interfaces.[].spairport_airport_other_local_wireless_networks.[].spairport_signal_noise` | enumeration | 1 | 1 | curated | no | _withheld_ |
| `spairport_airport_interfaces.[].spairport_caps_airdrop` | enumeration | 1 | 1 | curated | no | `spairport_caps_supported` |
| `spairport_airport_interfaces.[].spairport_caps_autounlock` | enumeration | 1 | 1 | curated | no | `spairport_caps_supported` |
| `spairport_airport_interfaces.[].spairport_caps_wow` | enumeration | 1 | 1 | curated | no | `spairport_caps_supported` |
| `spairport_airport_interfaces.[].spairport_current_network_information._name` | free text | 1 | 1 | none | no |  |
| `spairport_airport_interfaces.[].spairport_current_network_information.spairport_network_channel` | enumeration | 1 | 1 | curated | no | _withheld_ |
| `spairport_airport_interfaces.[].spairport_current_network_information.spairport_network_country_code` | enumeration | 1 | 1 | curated | no | `US` |
| `spairport_airport_interfaces.[].spairport_current_network_information.spairport_network_mcs` | numeric | 1 | 1 | curated | no |  |
| `spairport_airport_interfaces.[].spairport_current_network_information.spairport_network_phymode` | enumeration | 1 | 1 | curated | no | _withheld_ |
| `spairport_airport_interfaces.[].spairport_current_network_information.spairport_network_rate` | numeric | 1 | 1 | curated | no |  |
| `spairport_airport_interfaces.[].spairport_current_network_information.spairport_network_type` | enumeration | 2 | 1 | curated | no | `spairport_network_type_station` |
| `spairport_airport_interfaces.[].spairport_current_network_information.spairport_security_mode` | enumeration | 1 | 1 | curated | no | `spairport_security_mode_wpa3_personal` |
| `spairport_airport_interfaces.[].spairport_current_network_information.spairport_signal_noise` | enumeration | 1 | 1 | curated | no | _withheld_ |
| `spairport_airport_interfaces.[].spairport_status_information` | enumeration | 1 | 1 | curated | no | `spairport_status_connected` |
| `spairport_airport_interfaces.[].spairport_supported_channels.[]` | free text | 194 | 97 | curated | no |  |
| `spairport_airport_interfaces.[].spairport_supported_phymodes` | enumeration | 1 | 1 | curated | no | _withheld_ |
| `spairport_airport_interfaces.[].spairport_wireless_card_type` | free text | 1 | 1 | curated | no |  |
| `spairport_airport_interfaces.[].spairport_wireless_country_code` | enumeration | 1 | 1 | curated | no | `US` |
| `spairport_airport_interfaces.[].spairport_wireless_firmware_version` | identifier | 1 | 1 | curated | no |  |
| `spairport_airport_interfaces.[].spairport_wireless_locale` | enumeration | 1 | 1 | curated | no | `FCC` |
| `spairport_airport_interfaces.[].spairport_wireless_mac_address` | identifier | 2 | 2 | curated | no |  |
| `spairport_software_information.spairport_corewlan_version` | free text | 1 | 1 | curated | no |  |
| `spairport_software_information.spairport_corewlankit_version` | free text | 1 | 1 | curated | no |  |
| `spairport_software_information.spairport_diagnostics_version` | free text | 1 | 1 | curated | no |  |
| `spairport_software_information.spairport_extra_version` | free text | 1 | 1 | curated | no |  |
| `spairport_software_information.spairport_family_version` | free text | 1 | 1 | curated | no |  |
| `spairport_software_information.spairport_profiler_version` | free text | 1 | 1 | curated | no |  |
| `spairport_software_information.spairport_utility_version` | free text | 1 | 1 | curated | no |  |

## Applications (`SPApplicationsDataType`)

| field | class | values seen | distinct | explained | value-aware | example values |
|---|---|---:|---:|---|---|---|
| `_name` | free text | 769 | 552 | none | no |  |
| `arch_kind` | enumeration | 769 | 5 | curated | no | `arch_arm`, `arch_other`, `arch_arm_i64`, `arch_ios`, `arch_i64` |
| `info` | identifier | 58 | 49 | curated | no |  |
| `lastModified` | free text | 769 | 200 | curated | no |  |
| `obtained_from` | free text | 769 | 5 | curated | no |  |
| `path` | free text | 769 | 669 | curated | no |  |
| `signed_by.[]` | free text | 1371 | 54 | curated | no |  |
| `version` | free text | 526 | 214 | curated | no |  |

## Audio (`SPAudioDataType`)

| field | class | values seen | distinct | explained | value-aware | example values |
|---|---|---:|---:|---|---|---|
| `_items.[]._name` | free text | 2 | 2 | general | no |  |
| `_items.[]._properties` | enumeration | 1 | 1 | general | no | `coreaudio_default_audio_system_device` |
| `_items.[].coreaudio_default_audio_input_device` | enumeration | 1 | 1 | general | no | `spaudio_yes` |
| `_items.[].coreaudio_default_audio_output_device` | enumeration | 1 | 1 | general | no | `spaudio_yes` |
| `_items.[].coreaudio_default_audio_system_device` | enumeration | 1 | 1 | general | no | `spaudio_yes` |
| `_items.[].coreaudio_device_input` | numeric | 1 | 1 | general | no |  |
| `_items.[].coreaudio_device_manufacturer` | enumeration | 2 | 1 | general | no | `Apple Inc.` |
| `_items.[].coreaudio_device_output` | numeric | 1 | 1 | general | no |  |
| `_items.[].coreaudio_device_srate` | numeric | 2 | 1 | general | no |  |
| `_items.[].coreaudio_device_transport` | enumeration | 2 | 1 | general | no | `coreaudio_device_type_builtin` |
| `_items.[].coreaudio_input_source` | enumeration | 1 | 1 | general | no | `MacBook Pro Microphone` |
| `_items.[].coreaudio_output_source` | enumeration | 1 | 1 | general | no | `MacBook Pro Speakers` |
| `_name` | free text | 1 | 1 | general | no |  |

## Bluetooth (`SPBluetoothDataType`)

| field | class | values seen | distinct | explained | value-aware | example values |
|---|---|---:|---:|---|---|---|
| `controller_properties.controller_address` | identifier | 1 | 1 | curated | no |  |
| `controller_properties.controller_chipset` | enumeration | 1 | 1 | curated | no | `BCM_4388` |
| `controller_properties.controller_discoverable` | enumeration | 1 | 1 | curated | no | `attrib_off` |
| `controller_properties.controller_firmwareVersion` | free text | 1 | 1 | curated | no |  |
| `controller_properties.controller_productID` | enumeration | 1 | 1 | curated | no | _withheld_ |
| `controller_properties.controller_state` | enumeration | 1 | 1 | curated | no | `attrib_on` |
| `controller_properties.controller_supportedServices` | free text | 1 | 1 | curated | no |  |
| `controller_properties.controller_transport` | enumeration | 1 | 1 | curated | no | `PCIe` |
| `controller_properties.controller_vendorID` | enumeration | 1 | 1 | curated | no | _withheld_ |
| `device_not_connected.[].<device name>.device_address` | identifier | 3 | 3 | none | no |  |
| `device_not_connected.[].<device name>.device_firmwareVersion` | free text | 1 | 1 | none | no |  |
| `device_not_connected.[].<device name>.device_minorType` | enumeration | 3 | 3 | none | no | _withheld_ |
| `device_not_connected.[].<device name>.device_productID` | enumeration | 2 | 2 | none | no | _withheld_ |
| `device_not_connected.[].<device name>.device_serialNumber` | identifier | 1 | 1 | none | no |  |
| `device_not_connected.[].<device name>.device_vendorID` | enumeration | 2 | 2 | none | no | _withheld_ |
| `device_not_connected.[].<device name>.<name>.device_address` | identifier | 1 | 1 | none | no |  |
| `device_not_connected.[].<device name>.<name>.device_rssi` | enumeration | 1 | 1 | none | no | _withheld_ |
| `device_not_connected.[].<device name>.device_caseVersion` | free text | 1 | 1 | none | no |  |

## Cameras (`SPCameraDataType`)

| field | class | values seen | distinct | explained | value-aware | example values |
|---|---|---:|---:|---|---|---|
| `_name` | free text | 2 | 2 | general | no |  |
| `spcamera_model-id` | enumeration | 2 | 2 | general | no | _withheld_ |
| `spcamera_unique-id` | identifier | 2 | 2 | general | no |  |

## Card Readers (`SPCardReaderDataType`)

| field | class | values seen | distinct | explained | value-aware | example values |
|---|---|---:|---:|---|---|---|
| `_name` | free text | 1 | 1 | general | no |  |
| `spcardreader_device-id` | enumeration | 1 | 1 | general | no | _withheld_ |
| `spcardreader_link-speed` | boolean-like | 1 | 1 | general | no | `Off` |
| `spcardreader_link-width` | boolean-like | 1 | 1 | general | no | `Off` |
| `spcardreader_revision-id` | enumeration | 1 | 1 | general | no | _withheld_ |
| `spcardreader_subsystem-id` | enumeration | 1 | 1 | general | no | _withheld_ |
| `spcardreader_subsystem_vendor-id` | enumeration | 1 | 1 | general | no | _withheld_ |
| `spcardreader_vendor-id` | enumeration | 1 | 1 | general | no | _withheld_ |

## Configuration Profiles (`SPConfigurationProfileDataType`)

| field | class | values seen | distinct | explained | value-aware | example values |
|---|---|---:|---:|---|---|---|
| `_items.[]._items.[]._name` | free text | 1 | 1 | none | no |  |
| `_items.[]._items.[].spconfigprofile_payload_data` | free text | 1 | 1 | curated | no |  |
| `_items.[]._items.[].spconfigprofile_payload_display_name` | free text | 1 | 1 | curated | no |  |
| `_items.[]._items.[].spconfigprofile_payload_identifier` | identifier | 1 | 1 | curated | no |  |
| `_items.[]._items.[].spconfigprofile_payload_uuid` | identifier | 1 | 1 | curated | no |  |
| `_items.[]._items.[].spconfigprofile_payload_version` | numeric | 1 | 1 | curated | no |  |
| `_items.[]._name` | free text | 1 | 1 | none | no |  |
| `_items.[].spconfigprofile_RemovalDisallowed` | boolean-like | 1 | 1 | curated | no | `no` |
| `_items.[].spconfigprofile_description` | enumeration | 1 | 1 | curated | no | `Enable Unified Log Private Data` |
| `_items.[].spconfigprofile_install_date` | free text | 1 | 1 | curated | no |  |
| `_items.[].spconfigprofile_install_source` | enumeration | 1 | 1 | curated | no | `Manual` |
| `_items.[].spconfigprofile_profile_identifier` | identifier | 1 | 1 | curated | no |  |
| `_items.[].spconfigprofile_profile_uuid` | identifier | 1 | 1 | curated | no |  |
| `_items.[].spconfigprofile_verification_state` | enumeration | 1 | 1 | curated | no | `unsigned` |
| `_items.[].spconfigprofile_version` | numeric | 1 | 1 | curated | no |  |
| `_name` | free text | 1 | 1 | none | no |  |

## Developer Tools (`SPDeveloperToolsDataType`)

| field | class | values seen | distinct | explained | value-aware | example values |
|---|---|---:|---:|---|---|---|
| `_name` | free text | 1 | 1 | none | no |  |
| `spdevtools_apps.spinstruments_app` | enumeration | 1 | 1 | curated | no | _withheld_ |
| `spdevtools_apps.spxcode_app` | enumeration | 1 | 1 | curated | no | _withheld_ |
| `spdevtools_path` | free text | 1 | 1 | curated | no |  |
| `spdevtools_sdks.DriverKit.<name>.<name>` | enumeration | 1 | 1 | curated | no | _withheld_ |
| `spdevtools_sdks.<name>.<name>.<name>` | enumeration | 4 | 4 | curated | no | _withheld_ |
| `spdevtools_sdks.iOS.<name>.<name>` | enumeration | 1 | 1 | curated | no | _withheld_ |
| `spdevtools_sdks.macOS.<name>.<name>` | enumeration | 1 | 1 | curated | no | _withheld_ |
| `spdevtools_sdks.tvOS.<name>.<name>` | enumeration | 1 | 1 | curated | no | _withheld_ |
| `spdevtools_sdks.visionOS.<name>.<name>` | enumeration | 1 | 1 | curated | no | _withheld_ |
| `spdevtools_sdks.watchOS.<name>.<name>` | enumeration | 1 | 1 | curated | no | _withheld_ |
| `spdevtools_version` | free text | 1 | 1 | curated | no |  |

## Graphics and Displays (`SPDisplaysDataType`)

| field | class | values seen | distinct | explained | value-aware | example values |
|---|---|---:|---:|---|---|---|
| `_name` | free text | 1 | 1 | general | no |  |
| `spdisplays_mtlgpufamilysupport` | enumeration | 1 | 1 | general | no | `spdisplays_metal4` |
| `spdisplays_ndrvs.[]._name` | free text | 1 | 1 | general | no |  |
| `spdisplays_ndrvs.[]._spdisplays_display-product-id` | enumeration | 1 | 1 | general | no | _withheld_ |
| `spdisplays_ndrvs.[]._spdisplays_display-serial-number` | identifier | 1 | 1 | general | no |  |
| `spdisplays_ndrvs.[]._spdisplays_display-vendor-id` | enumeration | 1 | 1 | general | no | _withheld_ |
| `spdisplays_ndrvs.[]._spdisplays_display-week` | enumeration | 1 | 1 | general | no | _withheld_ |
| `spdisplays_ndrvs.[]._spdisplays_display-year` | enumeration | 1 | 1 | general | no | _withheld_ |
| `spdisplays_ndrvs.[]._spdisplays_displayID` | enumeration | 1 | 1 | general | no | _withheld_ |
| `spdisplays_ndrvs.[]._spdisplays_pixels` | enumeration | 1 | 1 | general | no | _withheld_ |
| `spdisplays_ndrvs.[]._spdisplays_resolution` | identifier | 1 | 1 | general | no |  |
| `spdisplays_ndrvs.[].spdisplays_ambient_brightness` | enumeration | 1 | 1 | general | no | `spdisplays_yes` |
| `spdisplays_ndrvs.[].spdisplays_connection_type` | enumeration | 1 | 1 | general | no | `spdisplays_internal` |
| `spdisplays_ndrvs.[].spdisplays_display_type` | enumeration | 1 | 1 | general | no | `spdisplays_built-in-liquid-retina-xdr` |
| `spdisplays_ndrvs.[].spdisplays_main` | enumeration | 1 | 1 | general | no | `spdisplays_yes` |
| `spdisplays_ndrvs.[].spdisplays_mirror` | enumeration | 1 | 1 | general | no | `spdisplays_off` |
| `spdisplays_ndrvs.[].spdisplays_online` | enumeration | 1 | 1 | general | no | `spdisplays_yes` |
| `spdisplays_ndrvs.[].spdisplays_pixelresolution` | enumeration | 1 | 1 | general | no | `spdisplays_3024x1964Retina` |
| `spdisplays_vendor` | enumeration | 1 | 1 | general | no | `sppci_vendor_Apple` |
| `sppci_bus` | enumeration | 1 | 1 | general | no | `spdisplays_builtin` |
| `sppci_cores` | enumeration | 1 | 1 | general | no | _withheld_ |
| `sppci_device_type` | enumeration | 1 | 1 | general | no | `spdisplays_gpu` |
| `sppci_model` | enumeration | 1 | 1 | general | no | `Apple M3 Max` |

## Extensions (`SPExtensionsDataType`)

| field | class | values seen | distinct | explained | value-aware | example values |
|---|---|---:|---:|---|---|---|
| `_name` | free text | 402 | 396 | none | no |  |
| `spext_architectures.[]` | enumeration | 402 | 1 | curated | no | `arm64e` |
| `spext_bundleid` | identifier | 402 | 402 | curated | no |  |
| `spext_description` | enumeration | 10 | 3 | curated | no | _withheld_ |
| `spext_has64BitIntelCode` | enumeration | 402 | 1 | curated | no | `spext_no` |
| `spext_hasAllDependencies` | enumeration | 402 | 1 | curated | no | `spext_satisfied` |
| `spext_info` | free text | 109 | 85 | curated | no |  |
| `spext_lastModified` | enumeration | 402 | 4 | curated | no | _withheld_ |
| `spext_load_address` | identifier | 385 | 361 | curated | no |  |
| `spext_loadable` | boolean-like | 402 | 1 | curated | no | `yes` |
| `spext_loaded` | enumeration | 402 | 1 | curated | no | `spext_yes` |
| `spext_path` | free text | 402 | 401 | curated | no |  |
| `spext_signed_by` | identifier | 398 | 25 | curated | no |  |
| `spext_version` | free text | 402 | 116 | curated | no |  |
| `version` | free text | 402 | 116 | curated | no |  |

## Firewall (`SPFirewallDataType`)

| field | class | values seen | distinct | explained | value-aware | example values |
|---|---|---:|---:|---|---|---|
| `_name` | free text | 1 | 1 | none | no |  |
| `spfirewall_applications.<app identifier>` | enumeration | 23 | 23 | curated | no | _withheld_ |
| `spfirewall_globalstate` | enumeration | 1 | 1 | curated | no | `spfirewall_globalstate_limit_connections` |
| `spfirewall_loggingenabled` | boolean-like | 1 | 1 | curated | no | `No` |
| `spfirewall_stealthenabled` | boolean-like | 1 | 1 | curated | no | `Yes` |

## Fonts (`SPFontsDataType`)

| field | class | values seen | distinct | explained | value-aware | example values |
|---|---|---:|---:|---|---|---|
| `_name` | free text | 236 | 236 | none | no |  |
| `enabled` | boolean-like | 236 | 1 | curated | no | `yes` |
| `path` | free text | 236 | 236 | curated | no |  |
| `type` | enumeration | 236 | 4 | curated | no | `truetype`, `opentype`, `postscript`, `bitmap` |
| `typefaces.[]._name` | free text | 2671 | 2671 | none | no |  |
| `typefaces.[].copy_protected` | boolean-like | 2671 | 1 | curated | no | `no` |
| `typefaces.[].copyright` | free text | 2601 | 180 | curated | no |  |
| `typefaces.[].description` | free text | 1922 | 47 | curated | no |  |
| `typefaces.[].designer` | free text | 2099 | 53 | curated | no |  |
| `typefaces.[].duplicate` | boolean-like | 2671 | 1 | curated | no | `no` |
| `typefaces.[].embeddable` | boolean-like | 2671 | 1 | curated | no | `yes` |
| `typefaces.[].enabled` | boolean-like | 2671 | 1 | curated | no | `yes` |
| `typefaces.[].family` | free text | 2671 | 274 | curated | no |  |
| `typefaces.[].fullname` | free text | 2671 | 2669 | curated | no |  |
| `typefaces.[].outline` | boolean-like | 2671 | 2 | curated | yes | `yes`, `no` |
| `typefaces.[].style` | free text | 2671 | 851 | curated | no |  |
| `typefaces.[].trademark` | free text | 2023 | 146 | curated | no |  |
| `typefaces.[].unique` | free text | 2671 | 613 | curated | no |  |
| `typefaces.[].valid` | boolean-like | 2671 | 1 | curated | no | _withheld_ |
| `typefaces.[].vendor` | free text | 2083 | 39 | curated | no |  |
| `typefaces.[].version` | free text | 2671 | 35 | curated | no |  |
| `valid` | boolean-like | 236 | 1 | curated | no | _withheld_ |

## Frameworks (`SPFrameworksDataType`)

| field | class | values seen | distinct | explained | value-aware | example values |
|---|---|---:|---:|---|---|---|
| `_name` | free text | 2905 | 2875 | none | no |  |
| `arch_kind` | enumeration | 21 | 1 | curated | no | `arch_arm_i64` |
| `info` | identifier | 61 | 51 | curated | no |  |
| `lastModified` | enumeration | 2905 | 5 | curated | no | _withheld_ |
| `obtained_from` | free text | 2905 | 3 | curated | no |  |
| `path` | free text | 2905 | 2905 | curated | no |  |
| `private_framework` | boolean-like | 2905 | 2 | curated | yes | `yes`, `no` |
| `signed_by.[]` | free text | 96 | 7 | curated | no |  |
| `version` | free text | 2833 | 328 | curated | no |  |

## Hardware Overview (`SPHardwareDataType`)

| field | class | values seen | distinct | explained | value-aware | example values |
|---|---|---:|---:|---|---|---|
| `_name` | free text | 1 | 1 | none | no |  |
| `activation_lock_status` | enumeration | 1 | 1 | curated | no | `activation_lock_enabled` |
| `boot_rom_version` | free text | 1 | 1 | curated | no |  |
| `chip_type` | enumeration | 1 | 1 | curated | no | `Apple M3 Max` |
| `machine_model` | enumeration | 1 | 1 | curated | no | _withheld_ |
| `machine_name` | free text | 1 | 1 | curated | no |  |
| `model_number` | enumeration | 1 | 1 | curated | no | _withheld_ |
| `number_processors` | enumeration | 1 | 1 | curated | no | `proc 14:0:10:4` |
| `os_loader_version` | free text | 1 | 1 | curated | no |  |
| `physical_memory` | enumeration | 1 | 1 | curated | no | _withheld_ |
| `platform_UUID` | identifier | 1 | 1 | curated | no |  |
| `provisioning_UDID` | identifier | 1 | 1 | curated | no |  |
| `serial_number` | identifier | 1 | 1 | curated | no |  |

## Install History (`SPInstallHistoryDataType`)

| field | class | values seen | distinct | explained | value-aware | example values |
|---|---|---:|---:|---|---|---|
| `_name` | free text | 32 | 19 | none | no |  |
| `install_date` | free text | 32 | 30 | curated | no |  |
| `install_version` | free text | 24 | 15 | curated | no |  |
| `package_source` | enumeration | 32 | 2 | curated | no | `package_source_apple`, `package_source_other` |

## Language and Region (`SPInternationalDataType`)

| field | class | values seen | distinct | explained | value-aware | example values |
|---|---|---:|---:|---|---|---|
| `_name` | free text | 3 | 3 | none | no |  |
| `boot_kbd` | enumeration | 1 | 1 | none | no | _withheld_ |
| `boot_locale` | enumeration | 1 | 1 | none | no | `en-US` |
| `linguistic_data_assets_requested.[]` | free text | 22 | 22 | curated | no |  |
| `system_country` | enumeration | 1 | 1 | curated | no | `US` |
| `system_interface_languages.[]` | free text | 44 | 44 | curated | no |  |
| `system_languages.[]` | enumeration | 1 | 1 | curated | no | `en-US` |
| `system_locale` | enumeration | 1 | 1 | curated | no | `en_US` |
| `system_text_direction` | enumeration | 1 | 1 | curated | no | `text_direction_ltr` |
| `system_uses_metric_system` | enumeration | 1 | 1 | curated | no | `value_no` |
| `user_assistant_language` | enumeration | 1 | 1 | curated | no | _withheld_ |
| `user_assistant_voice_gender` | enumeration | 1 | 1 | none | no | _withheld_ |
| `user_assistant_voice_language` | enumeration | 1 | 1 | curated | no | _withheld_ |
| `user_calendar` | enumeration | 1 | 1 | curated | no | _withheld_ |
| `user_country_code` | enumeration | 1 | 1 | curated | no | _withheld_ |
| `user_current_input_source` | enumeration | 1 | 1 | curated | no | _withheld_ |
| `user_language_code` | enumeration | 1 | 1 | curated | no | _withheld_ |
| `user_locale` | enumeration | 1 | 1 | curated | no | _withheld_ |
| `user_preferred_interface_languages.[]` | enumeration | 1 | 1 | curated | no | `en-US` |
| `user_uses_metric_system` | enumeration | 1 | 1 | curated | no | _withheld_ |

## Legacy Software (`SPLegacySoftwareDataType`)

| field | class | values seen | distinct | explained | value-aware | example values |
|---|---|---:|---:|---|---|---|
| `_name` | free text | 46 | 30 | none | no |  |
| `number_of_times_launched` | numeric | 46 | 28 | curated | no |  |
| `previously_launched_date` | free text | 46 | 31 | curated | no |  |
| `process_developer_name` | free text | 46 | 4 | curated | no |  |
| `process_identity.identity_bundle_id` | identifier | 46 | 7 | none | no |  |
| `process_identity.identity_path` | identifier | 46 | 31 | none | no |  |
| `process_identity.identity_team_id` | identifier | 46 | 5 | none | no |  |
| `process_identity.identity_version` | identifier | 46 | 8 | none | no |  |
| `process_name` | free text | 46 | 24 | curated | no |  |
| `process_uid` | enumeration | 46 | 1 | none | no | _withheld_ |
| `reason` | enumeration | 5 | 2 | curated | no | `reason_x86_forced_environmental`, `reason_x86_only` |
| `responsible_developer_name` | free text | 46 | 5 | curated | no |  |
| `responsible_identity.identity_bundle_id` | identifier | 46 | 8 | none | no |  |
| `responsible_identity.identity_path` | identifier | 46 | 9 | none | no |  |
| `responsible_identity.identity_team_id` | identifier | 46 | 5 | none | no |  |
| `responsible_identity.identity_version` | identifier | 46 | 11 | none | no |  |
| `responsible_name` | free text | 46 | 7 | curated | no |  |

## System Logs (`SPLogsDataType`)

| field | class | values seen | distinct | explained | value-aware | example values |
|---|---|---:|---:|---|---|---|
| `_name` | free text | 12 | 11 | general | no |  |
| `byteSize` | numeric | 12 | 12 | general | no |  |
| `contents` | identifier | 12 | 12 | general | no |  |
| `lastModified` | enumeration | 11 | 10 | general | no | _withheld_ |
| `source` | identifier | 12 | 11 | general | no |  |

## Managed Client (`SPManagedClientDataType`)

| field | class | values seen | distinct | explained | value-aware | example values |
|---|---|---:|---:|---|---|---|
| `_items.[]._name` | free text | 3 | 3 | none | no |  |
| `_items.[].data_keyValue` | identifier | 3 | 3 | curated | no |  |
| `_items.[].data_source` | free text | 3 | 1 | curated | no |  |
| `_items.[].data_state` | enumeration | 3 | 1 | curated | no | `always` |
| `_name` | free text | 1 | 1 | none | no |  |

## Memory (`SPMemoryDataType`)

| field | class | values seen | distinct | explained | value-aware | example values |
|---|---|---:|---:|---|---|---|
| `SPMemoryDataType` | enumeration | 1 | 1 | general | no | _withheld_ |
| `dimm_manufacturer` | enumeration | 1 | 1 | general | no | `Micron` |
| `dimm_type` | enumeration | 1 | 1 | general | no | `LPDDR5` |

## NVMExpress (`SPNVMeDataType`)

| field | class | values seen | distinct | explained | value-aware | example values |
|---|---|---:|---:|---|---|---|
| `_items.[]._name` | free text | 1 | 1 | general | no |  |
| `_items.[].bsd_name` | free text | 1 | 1 | general | no |  |
| `_items.[].detachable_drive` | boolean-like | 1 | 1 | general | no | `no` |
| `_items.[].device_model` | enumeration | 1 | 1 | general | no | `APPLE SSD AP1024Z` |
| `_items.[].device_revision` | enumeration | 1 | 1 | general | no | _withheld_ |
| `_items.[].device_serial` | identifier | 1 | 1 | general | no |  |
| `_items.[].partition_map_type` | enumeration | 1 | 1 | general | no | `guid_partition_map_type` |
| `_items.[].removable_media` | boolean-like | 1 | 1 | general | no | `no` |
| `_items.[].size` | enumeration | 1 | 1 | general | no | _withheld_ |
| `_items.[].size_in_bytes` | numeric | 1 | 1 | general | no |  |
| `_items.[].smart_status` | enumeration | 1 | 1 | general | no | `Verified` |
| `_items.[].spnvme_trim_support` | boolean-like | 1 | 1 | general | no | `Yes` |
| `_items.[].volumes.[]._name` | free text | 3 | 3 | general | no |  |
| `_items.[].volumes.[].bsd_name` | free text | 3 | 3 | general | no |  |
| `_items.[].volumes.[].iocontent` | enumeration | 3 | 3 | general | no | `Apple_APFS_ISC`, `Apple_APFS`, `Apple_APFS_Recovery` |
| `_items.[].volumes.[].size` | enumeration | 3 | 3 | general | no | _withheld_ |
| `_items.[].volumes.[].size_in_bytes` | numeric | 3 | 3 | general | no |  |
| `_name` | free text | 1 | 1 | general | no |  |

## Network (`SPNetworkDataType`)

| field | class | values seen | distinct | explained | value-aware | example values |
|---|---|---:|---:|---|---|---|
| `DNS.ServerAddresses.[]` | identifier | 1 | 1 | curated | no |  |
| `Ethernet.<name>` | identifier | 4 | 4 | curated | no |  |
| `Ethernet.MediaSubType` | enumeration | 4 | 2 | curated | no | `none`, `autoselect` |
| `IPv4.ARPResolvedHardwareAddress` | identifier | 1 | 1 | curated | no |  |
| `IPv4.ARPResolvedIPAddress` | identifier | 1 | 1 | curated | no |  |
| `IPv4.AdditionalRoutes.[].DestinationAddress` | identifier | 2 | 2 | curated | no |  |
| `IPv4.AdditionalRoutes.[].SubnetMask` | identifier | 2 | 2 | curated | no |  |
| `IPv4.Addresses.[]` | identifier | 1 | 1 | curated | no |  |
| `IPv4.ConfigMethod` | enumeration | 12 | 4 | curated | no | `DHCP`, `PPP`, `Manual`, `VPN` |
| `IPv4.ConfirmedInterfaceName` | free text | 1 | 1 | curated | no |  |
| `IPv4.InterfaceName` | free text | 1 | 1 | curated | no |  |
| `IPv4.NetworkSignature` | identifier | 1 | 1 | curated | no |  |
| `IPv4.NetworkSignatureHash` | free text | 1 | 1 | curated | no |  |
| `IPv4.Router` | identifier | 1 | 1 | curated | no |  |
| `IPv4.SubnetMasks.[]` | identifier | 1 | 1 | curated | no |  |
| `IPv6.ConfigMethod` | enumeration | 10 | 1 | curated | no | `Automatic` |
| `Proxies.ExceptionsList.[]` | enumeration | 20 | 2 | curated | no | _withheld_ |
| `Proxies.ExcludeSimpleHostnames` | numeric | 1 | 1 | curated | no |  |
| `Proxies.FTPEnable` | boolean-like | 1 | 1 | curated | no | `no` |
| `Proxies.FTPPassive` | boolean-like | 12 | 1 | curated | no | `yes` |
| `Proxies.GopherEnable` | boolean-like | 1 | 1 | curated | no | `no` |
| `Proxies.HTTPEnable` | boolean-like | 1 | 1 | curated | no | `no` |
| `Proxies.HTTPSEnable` | boolean-like | 1 | 1 | curated | no | `no` |
| `Proxies.ProxyAutoConfigEnable` | boolean-like | 1 | 1 | curated | no | `no` |
| `Proxies.ProxyAutoDiscoveryEnable` | boolean-like | 1 | 1 | curated | no | `no` |
| `Proxies.RTSPEnable` | boolean-like | 1 | 1 | curated | no | `no` |
| `Proxies.SOCKSEnable` | boolean-like | 1 | 1 | curated | no | `no` |
| `_name` | free text | 12 | 12 | none | no |  |
| `hardware` | enumeration | 11 | 3 | curated | no | `Ethernet`, `Modem`, `AirPort` |
| `interface` | enumeration | 11 | 11 | curated | no | _withheld_ |
| `ip_address.[]` | identifier | 1 | 1 | curated | no |  |
| `spnetwork_service_order` | numeric | 12 | 12 | curated | no |  |
| `type` | enumeration | 12 | 4 | curated | no | `Ethernet`, `PPP (PPPSerial)`, `AirPort`, `VPN (<app identifier>)` |

## Network Locations (`SPNetworkLocationDataType`)

| field | class | values seen | distinct | explained | value-aware | example values |
|---|---|---:|---:|---|---|---|
| `_name` | free text | 1 | 1 | none | no |  |
| `spnetworklocation_isActive` | boolean-like | 1 | 1 | curated | no | _withheld_ |
| `spnetworklocation_services.[].DNS.ServerAddresses.[]` | identifier | 1 | 1 | curated | no |  |
| `spnetworklocation_services.[].IEEE80211.JoinMode` | enumeration | 1 | 1 | curated | no | `Automatic` |
| `spnetworklocation_services.[].IPv4.Addresses.[]` | identifier | 1 | 1 | curated | no |  |
| `spnetworklocation_services.[].IPv4.ConfigMethod` | enumeration | 12 | 4 | curated | no | `DHCP`, `PPP`, `Manual`, `VPN` |
| `spnetworklocation_services.[].IPv4.Router` | identifier | 1 | 1 | curated | no |  |
| `spnetworklocation_services.[].IPv4.SubnetMasks.[]` | identifier | 1 | 1 | curated | no |  |
| `spnetworklocation_services.[].IPv6.ConfigMethod` | enumeration | 10 | 1 | curated | no | `Automatic` |
| `spnetworklocation_services.[].PPP.ACSPEnabled` | boolean-like | 1 | 1 | curated | no | `no` |
| `spnetworklocation_services.[].PPP.CommDisplayTerminalWindow` | boolean-like | 1 | 1 | curated | no | `no` |
| `spnetworklocation_services.[].PPP.CommRedialCount` | numeric | 1 | 1 | curated | no |  |
| `spnetworklocation_services.[].PPP.CommRedialEnabled` | boolean-like | 1 | 1 | curated | no | `yes` |
| `spnetworklocation_services.[].PPP.CommRedialInterval` | numeric | 1 | 1 | curated | no |  |
| `spnetworklocation_services.[].PPP.CommUseTerminalScript` | boolean-like | 1 | 1 | curated | no | `no` |
| `spnetworklocation_services.[].PPP.DialOnDemand` | boolean-like | 1 | 1 | curated | no | `no` |
| `spnetworklocation_services.[].PPP.DisconnectOnFastUserSwitch` | boolean-like | 1 | 1 | curated | no | _withheld_ |
| `spnetworklocation_services.[].PPP.DisconnectOnIdle` | boolean-like | 1 | 1 | curated | no | `yes` |
| `spnetworklocation_services.[].PPP.DisconnectOnIdleTimer` | numeric | 1 | 1 | curated | no |  |
| `spnetworklocation_services.[].PPP.DisconnectOnLogout` | boolean-like | 1 | 1 | curated | no | `yes` |
| `spnetworklocation_services.[].PPP.DisconnectOnSleep` | boolean-like | 1 | 1 | curated | no | `yes` |
| `spnetworklocation_services.[].PPP.IPCPCompressionVJ` | boolean-like | 1 | 1 | curated | no | `yes` |
| `spnetworklocation_services.[].PPP.IdleReminder` | boolean-like | 1 | 1 | curated | no | `no` |
| `spnetworklocation_services.[].PPP.IdleReminderTimer` | numeric | 1 | 1 | curated | no |  |
| `spnetworklocation_services.[].PPP.LCPEchoEnabled` | boolean-like | 1 | 1 | curated | no | `yes` |
| `spnetworklocation_services.[].PPP.LCPEchoFailure` | numeric | 1 | 1 | curated | no |  |
| `spnetworklocation_services.[].PPP.LCPEchoInterval` | numeric | 1 | 1 | curated | no |  |
| `spnetworklocation_services.[].PPP.Logfile` | enumeration | 1 | 1 | curated | no | _withheld_ |
| `spnetworklocation_services.[].PPP.VerboseLogging` | boolean-like | 1 | 1 | curated | no | `no` |
| `spnetworklocation_services.[].Proxies.ExceptionsList.[]` | enumeration | 20 | 2 | curated | no | _withheld_ |
| `spnetworklocation_services.[].Proxies.ExcludeSimpleHostnames` | boolean-like | 1 | 1 | curated | no | _withheld_ |
| `spnetworklocation_services.[].Proxies.FTPEnable` | boolean-like | 1 | 1 | curated | no | `no` |
| `spnetworklocation_services.[].Proxies.FTPPassive` | boolean-like | 12 | 1 | curated | no | `yes` |
| `spnetworklocation_services.[].Proxies.GopherEnable` | boolean-like | 1 | 1 | curated | no | `no` |
| `spnetworklocation_services.[].Proxies.HTTPEnable` | boolean-like | 1 | 1 | curated | no | `no` |
| `spnetworklocation_services.[].Proxies.HTTPSEnable` | boolean-like | 1 | 1 | curated | no | `no` |
| `spnetworklocation_services.[].Proxies.ProxyAutoConfigEnable` | numeric | 1 | 1 | curated | no |  |
| `spnetworklocation_services.[].Proxies.ProxyAutoDiscoveryEnable` | boolean-like | 1 | 1 | curated | no | `no` |
| `spnetworklocation_services.[].Proxies.RTSPEnable` | boolean-like | 1 | 1 | curated | no | `no` |
| `spnetworklocation_services.[].Proxies.SOCKSEnable` | boolean-like | 1 | 1 | curated | no | `no` |
| `spnetworklocation_services.[].VPN.AuthenticationMethod` | enumeration | 1 | 1 | curated | no | `Password` |
| `spnetworklocation_services.[].VPN.DesignatedRequirement` | identifier | 1 | 1 | curated | no |  |
| `spnetworklocation_services.[].VPN.DisconnectOnFastUserSwitch` | boolean-like | 1 | 1 | curated | no | _withheld_ |
| `spnetworklocation_services.[].VPN.DisconnectOnIdle` | boolean-like | 1 | 1 | curated | no | `no` |
| `spnetworklocation_services.[].VPN.DisconnectOnIdleTimer` | numeric | 1 | 1 | curated | no |  |
| `spnetworklocation_services.[].VPN.DisconnectOnLogout` | boolean-like | 1 | 1 | curated | no | `no` |
| `spnetworklocation_services.[].VPN.DisconnectOnSleep` | boolean-like | 1 | 1 | curated | no | `no` |
| `spnetworklocation_services.[].VPN.DisconnectOnWake` | numeric | 1 | 1 | curated | no |  |
| `spnetworklocation_services.[].VPN.DisconnectOnWakeTimer` | numeric | 1 | 1 | curated | no |  |
| `spnetworklocation_services.[].VPN.NEProviderBundleIdentifier` | identifier | 1 | 1 | curated | no |  |
| `spnetworklocation_services.[].VPN.OnDemandEnabled` | boolean-like | 1 | 1 | curated | no | `false` |
| `spnetworklocation_services.[].VPN.OnDemandRules.[].Action` | enumeration | 2 | 1 | curated | no | `Connect` |
| `spnetworklocation_services.[].VPN.OnDemandRules.[].InterfaceTypeMatch` | enumeration | 2 | 2 | curated | no | _withheld_ |
| `spnetworklocation_services.[].VPN.Proxies.ExcludeSimpleHostnames` | numeric | 1 | 1 | curated | no |  |
| `spnetworklocation_services.[].VPN.Proxies.FTPEnable` | numeric | 1 | 1 | curated | no |  |
| `spnetworklocation_services.[].VPN.Proxies.FTPPassive` | numeric | 1 | 1 | curated | no |  |
| `spnetworklocation_services.[].VPN.Proxies.GopherEnable` | numeric | 1 | 1 | curated | no |  |
| `spnetworklocation_services.[].VPN.Proxies.HTTPEnable` | numeric | 1 | 1 | curated | no |  |
| `spnetworklocation_services.[].VPN.Proxies.HTTPSEnable` | numeric | 1 | 1 | curated | no |  |
| `spnetworklocation_services.[].VPN.Proxies.ProxyAutoConfigEnable` | numeric | 1 | 1 | curated | no |  |
| `spnetworklocation_services.[].VPN.Proxies.ProxyAutoDiscoveryEnable` | numeric | 1 | 1 | curated | no |  |
| `spnetworklocation_services.[].VPN.Proxies.RTSPEnable` | numeric | 1 | 1 | curated | no |  |
| `spnetworklocation_services.[].VPN.Proxies.SOCKSEnable` | numeric | 1 | 1 | curated | no |  |
| `spnetworklocation_services.[].VPN.RemoteAddress` | identifier | 1 | 1 | curated | no |  |
| `spnetworklocation_services.[]._name` | free text | 12 | 12 | none | no |  |
| `spnetworklocation_services.[].bsd_device_name` | free text | 10 | 10 | curated | no |  |
| `spnetworklocation_services.[].hardware_address` | identifier | 5 | 5 | curated | no |  |
| `spnetworklocation_services.[].type` | enumeration | 12 | 5 | curated | no | `Ethernet`, `PPP`, `Bridge`, `IEEE80211`, `VPN` |

## Network Volumes (`SPNetworkVolumeDataType`)

| field | class | values seen | distinct | explained | value-aware | example values |
|---|---|---:|---:|---|---|---|
| `_name` | free text | 1 | 1 | none | no |  |
| `spnetworkvolume_automounted` | boolean-like | 1 | 1 | curated | no | _withheld_ |
| `spnetworkvolume_fsmtnonname` | free text | 1 | 1 | curated | no |  |
| `spnetworkvolume_fstypename` | free text | 1 | 1 | curated | no |  |
| `spnetworkvolume_mntfromname` | free text | 1 | 1 | curated | no |  |

## Power (`SPPowerDataType`)

| field | class | values seen | distinct | explained | value-aware | example values |
|---|---|---:|---:|---|---|---|
| `<name>.<name>` | numeric | 13 | 13 | curated | no |  |
| `<name>.HighPowerMode` | boolean-like | 2 | 2 | curated | no | _withheld_ |
| `<name>.LowPowerMode` | boolean-like | 2 | 2 | curated | no | _withheld_ |
| `<name>.PrioritizeNetworkReachabilityOverSleep` | boolean-like | 2 | 2 | curated | no | _withheld_ |
| `<name>.ReduceBrightness` | boolean-like | 1 | 1 | curated | no | _withheld_ |
| `_items.[]._items.[].UserVisible` | boolean-like | 4 | 1 | curated | no | _withheld_ |
| `_items.[]._items.[].appPID` | numeric | 4 | 4 | curated | no |  |
| `_items.[]._items.[].eventtype` | enumeration | 4 | 1 | curated | no | `wake` |
| `_items.[]._items.[].scheduledby` | free text | 4 | 3 | curated | no |  |
| `_items.[]._items.[].time` | enumeration | 4 | 4 | curated | no | _withheld_ |
| `_items.[]._name` | free text | 1 | 1 | none | no |  |
| `_name` | free text | 5 | 5 | none | no |  |
| `sppower_battery_charge_info.sppower_battery_at_warn_level` | boolean-like | 1 | 1 | curated | no | `TRUE` |
| `sppower_battery_charge_info.sppower_battery_fully_charged` | boolean-like | 1 | 1 | curated | no | `FALSE` |
| `sppower_battery_charge_info.sppower_battery_is_charging` | boolean-like | 1 | 1 | curated | no | `FALSE` |
| `sppower_battery_charge_info.sppower_battery_state_of_charge` | numeric | 1 | 1 | curated | no |  |
| `sppower_battery_charger_connected` | boolean-like | 1 | 1 | curated | no | `FALSE` |
| `sppower_battery_health_info.sppower_battery_cycle_count` | numeric | 1 | 1 | curated | no |  |
| `sppower_battery_health_info.sppower_battery_health` | enumeration | 1 | 1 | curated | no | `Good` |
| `sppower_battery_health_info.sppower_battery_health_maximum_capacity` | enumeration | 1 | 1 | curated | no | _withheld_ |
| `sppower_battery_is_charging` | boolean-like | 1 | 1 | curated | no | `FALSE` |
| `sppower_battery_model_info.sppower_battery_cell_revision` | enumeration | 1 | 1 | curated | no | _withheld_ |
| `sppower_battery_model_info.sppower_battery_device_name` | free text | 1 | 1 | curated | no |  |
| `sppower_battery_model_info.sppower_battery_firmware_version` | free text | 1 | 1 | curated | no |  |
| `sppower_battery_model_info.sppower_battery_hardware_revision` | enumeration | 1 | 1 | curated | no | _withheld_ |
| `sppower_battery_model_info.sppower_battery_pack_lot_code` | enumeration | 1 | 1 | curated | no | _withheld_ |
| `sppower_battery_model_info.sppower_battery_pcb_lot_code` | enumeration | 1 | 1 | curated | no | _withheld_ |
| `sppower_battery_model_info.sppower_battery_serial_number` | identifier | 1 | 1 | curated | no |  |
| `sppower_ups_installed` | boolean-like | 1 | 1 | curated | no | `FALSE` |

## Printers (`SPPrintersDataType`)

| field | class | values seen | distinct | explained | value-aware | example values |
|---|---|---:|---:|---|---|---|
| `<name>` | boolean-like | 1 | 1 | general | no | _withheld_ |
| `_name` | free text | 1 | 1 | general | no |  |
| `airprintversion` | free text | 1 | 1 | general | no |  |
| `creationDate` | free text | 1 | 1 | general | no |  |
| `<name>.[].<name>` | enumeration | 2 | 2 | general | no | _withheld_ |
| `cupsversion` | free text | 1 | 1 | general | no |  |
| `default` | boolean-like | 1 | 1 | general | no | _withheld_ |
| `driverversion` | free text | 1 | 1 | general | no |  |
| `ppd` | enumeration | 1 | 1 | general | no | _withheld_ |
| `ppdfileversion` | free text | 1 | 1 | general | no |  |
| `printercommands` | enumeration | 1 | 1 | general | no | _withheld_ |
| `printerfirmwareversion` | free text | 1 | 1 | general | no |  |
| `printersharing` | boolean-like | 1 | 1 | general | no | _withheld_ |
| `printserver` | enumeration | 1 | 1 | general | no | _withheld_ |
| `psversion` | free text | 1 | 1 | general | no |  |
| `scanner` | boolean-like | 1 | 1 | general | no | _withheld_ |
| `shared` | boolean-like | 1 | 1 | general | no | _withheld_ |
| `status` | enumeration | 1 | 1 | general | no | _withheld_ |
| `urfversion` | free text | 1 | 1 | general | no |  |
| `uri` | identifier | 1 | 1 | general | no |  |

## Printer Software (`SPPrintersSoftwareDataType`)

| field | class | values seen | distinct | explained | value-aware | example values |
|---|---|---:|---:|---|---|---|
| `_name` | free text | 4 | 4 | none | no |  |
| `<name>.[].<name>` | free text | 2 | 2 | curated | no |  |

## RAW Camera Support (`SPRawCameraDataType`)

| field | class | values seen | distinct | explained | value-aware | example values |
|---|---|---:|---:|---|---|---|
| `_name` | free text | 916 | 916 | general | no |  |

## SPI (`SPSPIDataType`)

| field | class | values seen | distinct | explained | value-aware | example values |
|---|---|---:|---:|---|---|---|
| `_name` | free text | 1 | 1 | general | no |  |
| `a_product_id` | identifier | 1 | 1 | general | no |  |
| `b_vendor_id` | identifier | 1 | 1 | general | no |  |
| `c_stfw_version` | free text | 1 | 1 | general | no |  |
| `d_serial_num` | identifier | 1 | 1 | general | no |  |
| `f_manufacturer` | enumeration | 1 | 1 | general | no | `Apple` |
| `g_location_id` | identifier | 1 | 1 | general | no |  |
| `i_hardware_id` | identifier | 1 | 1 | general | no |  |

## Secure Element (`SPSecureElementDataType`)

| field | class | values seen | distinct | explained | value-aware | example values |
|---|---|---:|---:|---|---|---|
| `ctl_fw` | enumeration | 1 | 1 | curated | no | _withheld_ |
| `ctl_hw` | enumeration | 1 | 1 | curated | no | _withheld_ |
| `ctl_info` | free text | 1 | 1 | curated | no |  |
| `ctl_mw` | enumeration | 1 | 1 | curated | no | _withheld_ |
| `se_device` | enumeration | 1 | 1 | curated | no | _withheld_ |
| `se_fw` | enumeration | 1 | 1 | curated | no | _withheld_ |
| `se_hw` | enumeration | 1 | 1 | curated | no | _withheld_ |
| `se_id` | identifier | 1 | 1 | curated | no |  |
| `se_in_restricted_mode` | boolean-like | 1 | 1 | curated | no | `No` |
| `se_info` | free text | 1 | 1 | curated | no |  |
| `se_os_id` | identifier | 1 | 1 | curated | no |  |
| `se_os_version` | free text | 1 | 1 | curated | no |  |
| `se_plt` | enumeration | 1 | 1 | curated | no | _withheld_ |
| `se_prod_signed` | boolean-like | 1 | 1 | curated | no | _withheld_ |

## Smart Cards (`SPSmartCardsDataType`)

| field | class | values seen | distinct | explained | value-aware | example values |
|---|---|---:|---:|---|---|---|
| `<name>` | free text | 3 | 3 | curated | no |  |
| `_items.[]._name` | free text | 4 | 2 | none | no |  |
| `_name` | free text | 5 | 5 | none | no |  |

## Software Overview (`SPSoftwareDataType`)

| field | class | values seen | distinct | explained | value-aware | example values |
|---|---|---:|---:|---|---|---|
| `_name` | free text | 1 | 1 | none | no |  |
| `boot_mode` | enumeration | 1 | 1 | curated | no | `normal_boot` |
| `boot_volume` | enumeration | 1 | 1 | curated | no | `Macintosh HD` |
| `kernel_version` | free text | 1 | 1 | curated | no |  |
| `local_host_name` | free text | 1 | 1 | curated | no |  |
| `os_version` | free text | 1 | 1 | curated | no |  |
| `secure_vm` | enumeration | 1 | 1 | curated | no | `secure_vm_enabled` |
| `system_integrity` | enumeration | 1 | 1 | curated | no | `integrity_enabled` |
| `uptime` | enumeration | 1 | 1 | curated | no | _withheld_ |
| `user_name` | free text | 1 | 1 | curated | no |  |

## Storage (`SPStorageDataType`)

| field | class | values seen | distinct | explained | value-aware | example values |
|---|---|---:|---:|---|---|---|
| `_name` | free text | 3 | 3 | none | no |  |
| `bsd_name` | free text | 3 | 3 | curated | no |  |
| `file_system` | enumeration | 3 | 1 | curated | no | `APFS` |
| `free_space_in_bytes` | numeric | 3 | 2 | curated | no |  |
| `ignore_ownership` | boolean-like | 3 | 1 | curated | no | `no` |
| `mount_point` | free text | 3 | 3 | curated | no |  |
| `physical_drive.device_name` | free text | 3 | 2 | curated | no |  |
| `physical_drive.is_internal_disk` | boolean-like | 3 | 2 | curated | no | `yes`, `no` |
| `physical_drive.media_name` | free text | 3 | 1 | curated | no |  |
| `physical_drive.medium_type` | enumeration | 3 | 1 | curated | no | `ssd` |
| `physical_drive.partition_map_type` | enumeration | 3 | 1 | curated | no | `unknown_partition_map_type` |
| `physical_drive.protocol` | enumeration | 3 | 2 | curated | no | `Apple Fabric`, `Disk Image` |
| `physical_drive.smart_status` | enumeration | 2 | 1 | curated | no | `Verified` |
| `size_in_bytes` | numeric | 3 | 2 | curated | no |  |
| `volume_uuid` | identifier | 3 | 3 | curated | no |  |
| `writable` | boolean-like | 3 | 2 | curated | no | `no`, `yes` |

## Sync Services (`SPSyncServicesDataType`)

| field | class | values seen | distinct | explained | value-aware | example values |
|---|---|---:|---:|---|---|---|
| `_items.[]._name` | free text | 2 | 1 | none | no |  |
| `_items.[].contents` | free text | 1 | 1 | curated | no |  |
| `_items.[].description` | enumeration | 1 | 1 | curated | no | `system_log_description` |
| `_items.[].lastModified` | enumeration | 1 | 1 | curated | no | _withheld_ |
| `_items.[].size` | enumeration | 1 | 1 | curated | no | _withheld_ |
| `_items.[].summary_of_sync_log` | enumeration | 1 | 1 | curated | no | _withheld_ |
| `_name` | free text | 2 | 2 | none | no |  |
| `summary_os_version` | free text | 1 | 1 | curated | no |  |

## Thunderbolt and USB4 (`SPThunderboltDataType`)

| field | class | values seen | distinct | explained | value-aware | example values |
|---|---|---:|---:|---|---|---|
| `_name` | free text | 3 | 3 | general | no |  |
| `device_name_key` | enumeration | 3 | 1 | general | no | _withheld_ |
| `domain_uuid_key` | identifier | 3 | 3 | general | no |  |
| `receptacle_1_tag.current_speed_key` | enumeration | 3 | 1 | general | no | `Up to 40 Gb/s` |
| `receptacle_1_tag.link_status_key` | enumeration | 3 | 1 | general | no | _withheld_ |
| `receptacle_1_tag.receptacle_id_key` | enumeration | 3 | 3 | general | no | _withheld_ |
| `receptacle_1_tag.receptacle_status_key` | enumeration | 3 | 1 | general | no | `receptacle_no_devices_connected` |
| `route_string_key` | enumeration | 3 | 1 | general | no | _withheld_ |
| `switch_uid_key` | enumeration | 3 | 3 | general | no | _withheld_ |
| `vendor_name_key` | enumeration | 3 | 1 | general | no | _withheld_ |

## USB (`SPUSBHostDataType`)

| field | class | values seen | distinct | explained | value-aware | example values |
|---|---|---:|---:|---|---|---|
| `Driver` | enumeration | 3 | 1 | general | no | _withheld_ |
| `USBKeyHardwareType` | enumeration | 3 | 1 | general | no | `Built-in` |
| `USBKeyLocationID` | free text | 3 | 3 | general | no |  |
| `_name` | free text | 3 | 1 | general | no |  |

## Accessibility (`SPUniversalAccessDataType`)

| field | class | values seen | distinct | explained | value-aware | example values |
|---|---|---:|---:|---|---|---|
| `_name` | free text | 1 | 1 | none | no |  |
| `contrast` | enumeration | 1 | 1 | curated | no | _withheld_ |
| `cursor_mag` | boolean-like | 1 | 1 | curated | no | `off` |
| `display` | enumeration | 1 | 1 | curated | no | `black_on_white` |
| `flash_screen` | boolean-like | 1 | 1 | curated | no | `off` |
| `keyboardZoom` | boolean-like | 1 | 1 | curated | no | `off` |
| `mouse_keys` | boolean-like | 1 | 1 | curated | no | `off` |
| `scrollZoom` | boolean-like | 1 | 1 | curated | no | `off` |
| `slow_keys` | boolean-like | 1 | 1 | curated | no | `off` |
| `sticky_keys` | boolean-like | 1 | 1 | curated | no | `off` |
| `voiceover` | boolean-like | 1 | 1 | curated | no | `off` |
| `zoomMode` | enumeration | 1 | 1 | curated | no | `zoom_full_screen` |

## Apple Bridge (`SPiBridgeDataType`)

| field | class | values seen | distinct | explained | value-aware | example values |
|---|---|---:|---:|---|---|---|
| `ibridge_boot_uuid` | identifier | 1 | 1 | general | no |  |
| `ibridge_build` | enumeration | 1 | 1 | general | no | _withheld_ |
| `ibridge_extra_boot_policies` | enumeration | 1 | 1 | general | no | _withheld_ |
| `ibridge_model_identifier_top` | identifier | 1 | 1 | general | no |  |
| `ibridge_sb_boot_args` | boolean-like | 1 | 1 | general | no | `Enabled` |
| `ibridge_sb_ctrr` | boolean-like | 1 | 1 | general | no | `Enabled` |
| `ibridge_sb_device_mdm` | boolean-like | 1 | 1 | general | no | `No` |
| `ibridge_sb_manual_mdm` | boolean-like | 1 | 1 | general | no | `No` |
| `ibridge_sb_other_kext` | boolean-like | 1 | 1 | general | no | `No` |
| `ibridge_sb_sip` | boolean-like | 1 | 1 | general | no | `Enabled` |
| `ibridge_sb_ssv` | boolean-like | 1 | 1 | general | no | `Enabled` |
| `ibridge_secure_boot` | enumeration | 1 | 1 | general | no | `Full Security` |

## Data types with no data on this Mac

These returned an empty result here (no matching hardware or feature), so they need test fixtures from other Macs: `SPAppleVirtualPlatformDataType`, `SPDiagnosticsDataType`, `SPDisabledSoftwareDataType`, `SPDiscBurningDataType`, `SPEthernetDataType`, `SPFibreChannelDataType`, `SPPCIDataType`, `SPParallelATADataType`, `SPParallelSCSIDataType`, `SPPrefPaneDataType`, `SPSASDataType`, `SPSerialATADataType`, `SPStartupItemDataType`.
