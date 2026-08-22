import Foundation

func networkExplanation(path: [String], reportedValue: String) -> FieldExplanation? {
    let field: String = semanticNetworkField(path)

    return switch field {
    case "Addresses", "ip_address":
        FieldExplanation(
            title: path.contains("IPv6") ? "IPv6 Address" : "IP Address",
            meaning: "This is an Internet Protocol address assigned to the network service or interface when the report was collected.",
            significance: "The address identifies the interface within an IPv4 or IPv6 network and is required for routed communication beyond the local link.",
            interpretation: "An assigned address does not prove Internet access, recent traffic, or that the interface is reachable from outside the local network. VPNs, privacy addressing, multiple interfaces, and address changes must be considered.",
            privacy: "IP addresses can reveal network structure, service providers, VPN use, or an approximate location. Redact them before publishing a report unless the addressing evidence is necessary."
        )

    case "ServerAddresses":
        FieldExplanation(
            title: "DNS Server",
            meaning: "This is an address configured for a Domain Name System resolver used to translate hostnames into network addresses.",
            significance: "Resolver selection affects which DNS infrastructure receives lookup requests and can influence name resolution, filtering, split-horizon access, and troubleshooting.",
            interpretation: "A configured resolver is not proof that every lookup used it. Encrypted DNS, VPNs, per-domain resolvers, application behavior, and cached answers can alter the actual request path.",
            privacy: "Resolver addresses can disclose the local network, VPN, employer, filtering provider, or DNS service in use. Review them before sharing."
        )

    case "InterfaceName", "ConfirmedInterfaceName", "interface", "bsd_device_name":
        FieldExplanation(
            title: "Interface Name",
            meaning: "This is the BSD-style identifier macOS uses for a network interface, such as an Ethernet, Wi‑Fi, tunnel, or virtual interface.",
            significance: "Command-line and diagnostic tools use the identifier to correlate addresses, routes, packets, and link state with a specific interface.",
            interpretation: "Interface names describe the current system topology, not a remote endpoint or application. Numbered names can change as hardware and virtual services are added or removed.",
            privacy: nil
        )

    case "hardware":
        FieldExplanation(
            title: "Network Hardware Type",
            meaning: "This describes the hardware or link family associated with the network service, such as Ethernet, Wi‑Fi, or another interface class.",
            significance: "It provides context for expected link behavior, configuration methods, packet capture, and which diagnostics apply.",
            interpretation: "The category does not establish that a physical cable or radio link is active, and virtual services can be layered over physical hardware.",
            privacy: nil
        )

    case "type":
        FieldExplanation(
            title: "Network Service Type",
            meaning: "This is macOS configuration metadata identifying the class of network service or protocol stack.",
            significance: "The service type helps distinguish physical interfaces, VPNs, PPP services, and other network configurations.",
            interpretation: "A configured service is authorization and configuration, not proof that it is connected, carrying traffic, or remotely controlled.",
            privacy: nil
        )

    case "spnetwork_service_order":
        FieldExplanation(
            title: "Service Order",
            meaning: "This is the priority position macOS assigns to the network service when choosing among available services.",
            significance: "Service order can influence which interface supplies the default route and DNS configuration when several connections are active.",
            interpretation: "Priority alone does not determine the actual path. Reachability, routing metrics, scoped routes, VPN policy, and per-application networking can override the simple order.",
            privacy: nil
        )

    case "MAC Address", "hardware_address":
        FieldExplanation(
            title: "Hardware Address",
            meaning: "This is the link-layer address reported for the network interface or service. Ethernet and Wi‑Fi commonly represent it as a MAC address.",
            significance: "Local networks use link-layer addresses for frame delivery, address resolution, device association, and some access-control or inventory systems.",
            interpretation: "Modern systems can use private or randomized addresses, and a displayed address does not prove device ownership, remote activity, or stable identity across networks.",
            privacy: "A hardware address can persistently identify or correlate a network interface on local networks. Redact it from public reports."
        )

    case "MediaSubType":
        FieldExplanation(
            title: "Link Media",
            meaning: "This describes the link medium or negotiated Ethernet media subtype reported for the interface.",
            significance: "It can provide context for expected link speed, duplex behavior, and whether the interface is using an automatic or specific media mode.",
            interpretation: "The label is not a throughput measurement. Actual performance also depends on negotiation, cabling, radio conditions, peer capability, congestion, and workload.",
            privacy: nil
        )

    case "ConfigMethod":
        FieldExplanation(
            title: "Address Configuration Method",
            meaning: "This reports how the service obtains its IP configuration, such as DHCP, manual configuration, automatic IPv6, or a link-local method.",
            significance: "The method determines whether addresses and routing information are supplied dynamically or maintained as explicit local settings.",
            interpretation: "The configured method does not prove that configuration succeeded or identify every source of routing and DNS data. VPN and per-service settings can add or replace values.",
            privacy: nil
        )

    case "Router":
        FieldExplanation(
            title: "Router",
            meaning: "This is the gateway address configured to forward traffic from the local network toward other networks.",
            significance: "The router commonly supplies the default next hop for destinations that are not directly reachable on the local link.",
            interpretation: "A configured gateway is not proof that it responded, forwarded a particular connection, or represents the public Internet edge. VPN and scoped routes may use different gateways.",
            privacy: "Gateway addresses reveal part of the local or tunnel network layout. Redact them when that topology is not needed."
        )

    case "ServerAddress":
        FieldExplanation(
            title: "Configuration Server",
            meaning: "This is the address of a server associated with dynamic network configuration, commonly a DHCP or BOOTP server.",
            significance: "It helps identify which infrastructure supplied an interface's leased configuration during troubleshooting.",
            interpretation: "The address is configuration evidence, not proof that the server is trustworthy, currently reachable, or responsible for all network settings.",
            privacy: "The server address can reveal internal network topology. Review it before sharing."
        )

    case "SubnetMasks", "SubnetMask":
        FieldExplanation(
            title: "Subnet Mask",
            meaning: "This defines which bits of an IPv4 address identify the local network and which identify a host within that network.",
            significance: "The mask determines which destinations are considered directly reachable and when traffic must be sent through a router.",
            interpretation: "A mask describes configured address scope, not observed reachability. Incorrect or overlapping routes, VPNs, and multiple interfaces can change actual packet handling.",
            privacy: "Subnet masks combined with addresses expose local network structure. Redact the combination from public reports."
        )

    case "PrefixLength":
        FieldExplanation(
            title: "IPv6 Prefix Length",
            meaning: "This is the number of leading bits that identify the IPv6 network prefix for an address or route.",
            significance: "It defines the on-link scope and route size used when deciding how IPv6 traffic should be forwarded.",
            interpretation: "The prefix length is configuration, not evidence of external reachability or successful IPv6 connectivity.",
            privacy: "Combined with an IPv6 address, the prefix can disclose network allocation and topology. Review both before sharing."
        )

    case "DestinationAddress":
        FieldExplanation(
            title: "Route Destination",
            meaning: "This identifies the destination network or host covered by an additional route.",
            significance: "Additional routes direct selected traffic through a particular interface or gateway instead of relying only on the default route.",
            interpretation: "A configured route is not proof that traffic used it or that the destination was contacted. Route priority, reachability, and policy must be evaluated at the relevant time.",
            privacy: "Route destinations can reveal internal networks, VPN ranges, or organizational infrastructure. Redact them when sharing is unnecessary."
        )

    case "ARPResolvedHardwareAddress":
        FieldExplanation(
            title: "Resolved Hardware Address",
            meaning: "This is the link-layer address associated with a resolved IPv4 neighbor through the Address Resolution Protocol.",
            significance: "ARP resolution allows the Mac to deliver local-link Ethernet or Wi‑Fi frames to the device responsible for an IPv4 address.",
            interpretation: "An ARP mapping is local, temporary evidence. It does not establish device identity, ownership, application activity, or that the neighbor is still present.",
            privacy: "This address can identify or correlate a nearby network interface. Redact it from public reports."
        )

    case "ARPResolvedIPAddress":
        FieldExplanation(
            title: "Resolved IPv4 Address",
            meaning: "This is the IPv4 address involved in a locally resolved ARP neighbor mapping.",
            significance: "It provides context for the link-layer address macOS associated with a local IPv4 neighbor.",
            interpretation: "The mapping is not a connection log and does not prove communication beyond address resolution. Entries can be cached, replaced, or stale.",
            privacy: "Local IP addresses expose network topology and can correlate nearby devices. Review them before sharing."
        )

    case "NetworkSignature":
        FieldExplanation(
            title: "Network Signature",
            meaning: "This is macOS metadata used to distinguish the currently recognized network environment from other network configurations.",
            significance: "The operating system can use a signature when associating network-specific settings and recognizing changes in connectivity context.",
            interpretation: "A signature is not a cryptographic trust verdict, SSID ownership proof, or evidence that traffic reached a particular service.",
            privacy: "A network signature may correlate repeated observations of the same network environment. Redact it from public reports."
        )

    case "NetworkSignatureHash":
        FieldExplanation(
            title: "Network Signature Hash",
            meaning: "This is a hashed representation associated with macOS network-environment recognition.",
            significance: "It provides a compact identifier for correlating a network context without displaying all underlying inputs.",
            interpretation: "A hash does not make the context anonymous and does not authenticate the network. It is correlation metadata, not a security verdict.",
            privacy: "The hash can correlate reports from the same network environment. Redact it when that linkage is unnecessary."
        )

    case "ExceptionsList":
        FieldExplanation(
            title: "Proxy Exception",
            meaning: "This is a hostname, domain pattern, or address configured to bypass the service's proxy settings.",
            significance: "Exceptions determine which destinations connect directly rather than through an enabled proxy.",
            interpretation: "An exception is policy configuration, not proof that the destination was contacted or that direct access succeeded.",
            privacy: "Proxy exceptions can reveal internal domains, services, or network architecture. Review them before sharing."
        )

    case "ExcludeSimpleHostnames":
        networkBooleanExplanation(
            title: "Bypass Proxy for Simple Hostnames",
            meaning: "This controls whether hostnames without a domain component bypass configured proxies.",
            significance: "It can keep local or intranet names on a direct path rather than sending them to a proxy that may not resolve them.",
            interpretation: "The setting does not prove that a simple hostname was requested or that bypass traffic succeeded.",
            reportedValue: reportedValue,
            privacy: nil
        )

    case "FTPEnable", "GopherEnable", "HTTPEnable", "HTTPSEnable", "RTSPEnable", "SOCKSEnable":
        proxyEnableExplanation(field: field, reportedValue: reportedValue)

    case "FTPPassive":
        networkBooleanExplanation(
            title: "FTP Passive Mode",
            meaning: "This controls whether FTP uses passive connection negotiation for the configured network service.",
            significance: "Passive mode is generally more compatible with clients behind firewalls or network address translation.",
            interpretation: "This legacy protocol setting does not prove FTP use, server contact, or that unencrypted credentials were transmitted.",
            reportedValue: reportedValue,
            privacy: nil
        )

    case "ProxyAutoConfigEnable":
        networkBooleanExplanation(
            title: "Automatic Proxy Configuration",
            meaning: "This reports whether the service is configured to obtain proxy rules from an automatic configuration script.",
            significance: "A PAC script can select different proxies or direct connections based on the requested destination and current network.",
            interpretation: "An enabled setting is not proof that a script downloaded successfully or that a particular connection used a proxy. The script URL and runtime decisions require separate evidence.",
            reportedValue: reportedValue,
            privacy: nil
        )

    case "ProxyAutoDiscoveryEnable":
        networkBooleanExplanation(
            title: "Proxy Auto-Discovery",
            meaning: "This reports whether the service allows automatic discovery of proxy configuration, commonly through WPAD-style mechanisms.",
            significance: "Discovery can simplify managed-network setup by locating proxy policy without a manually entered server.",
            interpretation: "An enabled setting does not prove that discovery succeeded or that a discovered proxy was trusted or used.",
            reportedValue: reportedValue,
            privacy: nil
        )

    default:
        nil
    }
}

func bluetoothExplanation(path: [String], reportedValue: String) -> FieldExplanation? {
    switch semanticNetworkField(path) {
    case "controller_address":
        FieldExplanation(
            title: "Bluetooth Controller Address",
            meaning: "This is the hardware address reported for the Mac's Bluetooth controller.",
            significance: "Bluetooth uses controller addresses during discovery, connection establishment, diagnostics, and local device correlation.",
            interpretation: "The address identifies the local controller, not a paired accessory or remote session. Privacy features can affect addresses used over the air.",
            privacy: "This address can persistently identify or correlate the Mac's Bluetooth controller. Redact it from public reports."
        )
    case "controller_chipset":
        FieldExplanation(
            title: "Bluetooth Chipset",
            meaning: "This identifies the controller chipset or implementation reported by macOS.",
            significance: "The chipset provides context for supported Bluetooth generations, firmware behavior, and hardware-specific diagnostics.",
            interpretation: "The name does not describe current radio activity, pairing state, firmware integrity, or real-world range.",
            privacy: nil
        )
    case "controller_discoverable":
        networkBooleanExplanation(
            title: "Bluetooth Discoverable",
            meaning: "This reports whether the controller was advertising itself as discoverable to nearby Bluetooth devices at collection time.",
            significance: "Discoverability affects whether new nearby devices can readily locate the Mac during pairing workflows.",
            interpretation: "A discoverable state is point-in-time visibility, not proof that another device paired, connected, or accessed data.",
            reportedValue: reportedValue,
            privacy: nil
        )
    case "controller_firmwareVersion":
        FieldExplanation(
            title: "Bluetooth Firmware Version",
            meaning: "This is the firmware revision reported by the Bluetooth controller.",
            significance: "It can help correlate controller behavior with macOS updates and hardware-specific diagnostics.",
            interpretation: "The version alone does not establish that firmware is current, vulnerable, or modified; comparison requires authoritative model- and OS-specific information.",
            privacy: nil
        )
    case "controller_productID":
        FieldExplanation(
            title: "Bluetooth Product ID",
            meaning: "This is the product identifier associated with the local Bluetooth controller.",
            significance: "Together with the vendor identifier, it helps distinguish the controller implementation used by the Mac.",
            interpretation: "A product ID identifies a hardware family, not this individual Mac, and is not evidence of an attached accessory.",
            privacy: nil
        )
    case "controller_state":
        FieldExplanation(
            title: "Bluetooth State",
            meaning: "This is the operating state of the Mac's Bluetooth controller when the scan ran.",
            significance: "It establishes whether the controller was available for discovery, pairing, and Bluetooth communication.",
            interpretation: "An enabled controller does not prove that any accessory was connected or that Bluetooth traffic occurred.",
            privacy: nil
        )
    case "controller_supportedServices":
        FieldExplanation(
            title: "Supported Bluetooth Services",
            meaning: "This summarizes Bluetooth profiles or service capabilities supported by the local controller and macOS stack.",
            significance: "Supported services determine which categories of Bluetooth interactions the Mac can participate in.",
            interpretation: "Capability is not activity. The list does not prove that a corresponding device is paired, connected, authorized, or in use.",
            privacy: nil
        )
    case "controller_transport":
        FieldExplanation(
            title: "Bluetooth Controller Transport",
            meaning: "This describes how the Bluetooth controller is connected to the system.",
            significance: "The transport provides hardware-topology context for driver, firmware, and reset diagnostics.",
            interpretation: "It does not describe the radio transport used by remote accessories or prove an external Bluetooth adapter is present.",
            privacy: nil
        )
    case "controller_vendorID":
        FieldExplanation(
            title: "Bluetooth Vendor ID",
            meaning: "This is the vendor identifier reported for the local Bluetooth controller.",
            significance: "It helps identify the controller manufacturer or assigned hardware vendor namespace.",
            interpretation: "The identifier is not proof of hardware authenticity, device ownership, or a remote vendor connection.",
            privacy: nil
        )
    default:
        nil
    }
}

func networkVolumeExplanation(path: [String], reportedValue: String) -> FieldExplanation? {
    switch semanticNetworkField(path) {
    case "spnetworkvolume_automounted":
        networkBooleanExplanation(
            title: "Automatically Mounted",
            meaning: "This reports whether macOS considers the network volume automatically mounted rather than mounted only through an immediate manual action.",
            significance: "Automatic mounts can originate from login items, managed configuration, saved server connections, or system services.",
            interpretation: "The state does not identify who configured the mount, prove recent file access, or establish that the remote server is trustworthy.",
            reportedValue: reportedValue,
            privacy: nil
        )
    case "spnetworkvolume_fsmtnonname":
        FieldExplanation(
            title: "Mount Options",
            meaning: "This describes filesystem mount flags or options applied to the network volume.",
            significance: "Mount options affect behavior such as read/write access, caching, execution, ownership, and filesystem semantics.",
            interpretation: "The compact option string is configuration, not a complete access-control or activity audit. Server-side permissions still apply.",
            privacy: nil
        )
    case "spnetworkvolume_fstypename":
        FieldExplanation(
            title: "Network Filesystem Type",
            meaning: "This identifies the filesystem protocol used for the mounted network volume, such as SMB or NFS.",
            significance: "The protocol determines authentication, permissions, discovery, compatibility, and performance behavior.",
            interpretation: "The protocol name does not establish encryption, server identity, data sensitivity, or whether files were accessed.",
            privacy: nil
        )
    case "spnetworkvolume_mntfromname":
        FieldExplanation(
            title: "Network Volume Source",
            meaning: "This identifies the remote server and share from which the network volume was mounted.",
            significance: "It provides the primary source reference needed to correlate the mount with server configuration and network activity.",
            interpretation: "A mounted source does not prove ownership, trust, recent file access, or that the server remains reachable.",
            privacy: "The source can expose server names, addresses, usernames, share names, or organizational infrastructure. Redact it from public reports."
        )
    default:
        nil
    }
}

func semanticNetworkField(_ path: [String]) -> String {
    guard let finalField: String = path.last else {
        return ""
    }

    if finalField == "[]" {
        return path.dropLast().last ?? finalField
    }

    return finalField
}

func networkBooleanExplanation(
    title: String,
    meaning: String,
    significance: String,
    interpretation: String,
    reportedValue: String,
    privacy: String?
) -> FieldExplanation {
    let state: String

    switch reportedValue.lowercased() {
    case "true", "yes", "1":
        state = "enabled"
    case "false", "no", "0":
        state = "disabled"
    default:
        state = "reported as \(reportedValue)"
    }

    return FieldExplanation(
        title: title,
        meaning: meaning,
        significance: "The collected state is \(state). \(significance)",
        interpretation: interpretation,
        privacy: privacy
    )
}

private func proxyEnableExplanation(field: String, reportedValue: String) -> FieldExplanation {
    let protocolName: String

    switch field {
    case "FTPEnable": protocolName = "FTP"
    case "GopherEnable": protocolName = "Gopher"
    case "HTTPEnable": protocolName = "HTTP"
    case "HTTPSEnable": protocolName = "HTTPS"
    case "RTSPEnable": protocolName = "RTSP"
    case "SOCKSEnable": protocolName = "SOCKS"
    default: protocolName = field
    }

    return networkBooleanExplanation(
        title: "\(protocolName) Proxy",
        meaning: "This reports whether the network service has a proxy enabled for \(protocolName) traffic.",
        significance: "When applied, matching connections may be sent through an intermediary proxy rather than directly to the destination.",
        interpretation: "An enabled setting is not proof that traffic occurred or that every application honored the proxy. Per-application networking, VPNs, PAC rules, and direct exceptions can change the path.",
        reportedValue: reportedValue,
        privacy: nil
    )
}
