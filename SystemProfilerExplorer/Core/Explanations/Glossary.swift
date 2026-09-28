import Foundation

struct GlossaryTerm: Identifiable, Sendable, Equatable {
    let term: String
    let definition: String
    /// Words or phrases that mention this term. Acronyms and phrases with digits match
    /// case-sensitively so "SMART" doesn't match "smart".
    let mentions: [String]

    var id: String { term }
}

let glossary: [GlossaryTerm] = [
    GlossaryTerm(
        term: "Apple silicon",
        definition: "Apple's own chips for Mac, such as M1, M2, and M3. The CPU, GPU, and memory share one package.",
        mentions: ["Apple silicon"]
    ),
    GlossaryTerm(
        term: "Performance and efficiency cores",
        definition: "Apple silicon CPUs have two kinds of cores: performance cores for demanding work, and efficiency cores that handle lighter tasks using less power.",
        mentions: ["performance cores", "efficiency cores", "performance and efficiency"]
    ),
    GlossaryTerm(
        term: "Unified memory",
        definition: "Memory on Apple silicon that the CPU and GPU share, instead of each having its own.",
        mentions: ["unified memory"]
    ),
    GlossaryTerm(
        term: "Rosetta 2",
        definition: "Software that lets a Mac with Apple silicon run apps built for Intel processors by translating them.",
        mentions: ["Rosetta"]
    ),
    GlossaryTerm(
        term: "Universal app",
        definition: "An app that contains code for both Apple silicon and Intel Macs, so it runs natively on either.",
        mentions: ["Universal"]
    ),
    GlossaryTerm(
        term: "APFS",
        definition: "Apple File System, the standard format for Mac drives since macOS High Sierra. It supports encryption, snapshots, and volumes that share space.",
        mentions: ["APFS"]
    ),
    GlossaryTerm(
        term: "SSD",
        definition: "Solid-state drive: storage built from flash memory, with no moving parts.",
        mentions: ["SSD", "solid-state drive"]
    ),
    GlossaryTerm(
        term: "SMART",
        definition: "Self-Monitoring, Analysis and Reporting Technology: a drive's built-in health check. “Verified” means the drive reports no problems.",
        mentions: ["SMART"]
    ),
    GlossaryTerm(
        term: "Signed System Volume",
        definition: "The read-only volume that holds macOS itself. Apple seals it cryptographically, so any change to it can be detected.",
        mentions: ["Signed System Volume", "system volume"]
    ),
    GlossaryTerm(
        term: "System Integrity Protection (SIP)",
        definition: "A macOS security feature that stops any software, even with administrator rights, from changing protected system files and processes.",
        mentions: ["System Integrity Protection", "SIP"]
    ),
    GlossaryTerm(
        term: "Activation Lock",
        definition: "A Find My feature that requires the owner's Apple Account before a Mac can be erased and set up again.",
        mentions: ["Activation Lock"]
    ),
    GlossaryTerm(
        term: "Gatekeeper",
        definition: "The macOS feature that checks an app comes from the App Store or an identified developer, and is notarized, before it first opens.",
        mentions: ["Gatekeeper"]
    ),
    GlossaryTerm(
        term: "Developer ID",
        definition: "A certificate Apple issues to developers who distribute Mac software outside the App Store, so macOS can verify who signed it.",
        mentions: ["Developer ID", "identified developer"]
    ),
    GlossaryTerm(
        term: "Notarization",
        definition: "Apple's automated check of Developer ID software for malicious content before it's distributed.",
        mentions: ["notarization", "notarized"]
    ),
    GlossaryTerm(
        term: "Kernel and system extensions",
        definition: "Add-ons that extend macOS. Kernel extensions run inside the core of macOS; newer system extensions run outside it, which is safer and more stable.",
        mentions: ["kernel extension", "system extension"]
    ),
    GlossaryTerm(
        term: "Application Firewall",
        definition: "The macOS firewall controls which apps and services can accept incoming network connections. It doesn't filter outgoing traffic.",
        mentions: ["firewall"]
    ),
    GlossaryTerm(
        term: "Stealth mode",
        definition: "A firewall option that makes the Mac ignore probing requests such as ping, so it's harder to discover on a network.",
        mentions: ["stealth mode"]
    ),
    GlossaryTerm(
        term: "IP address",
        definition: "The address that identifies a device on a network. IPv4 addresses look like 192.168.1.20; IPv6 addresses are longer.",
        mentions: ["IP address", "IPv4", "IPv6"]
    ),
    GlossaryTerm(
        term: "DHCP",
        definition: "Dynamic Host Configuration Protocol: how a router automatically gives devices an IP address and other network settings.",
        mentions: ["DHCP"]
    ),
    GlossaryTerm(
        term: "VPN",
        definition: "Virtual private network: an encrypted connection that carries network traffic to another network or a VPN provider.",
        mentions: ["VPN"]
    ),
    GlossaryTerm(
        term: "PPP",
        definition: "Point-to-Point Protocol: an older way to connect over a modem or serial link, used for dial-up connections.",
        mentions: ["PPP", "dial-up"]
    ),
    GlossaryTerm(
        term: "USB serial (CDC-ACM)",
        definition: "A standard way for USB devices such as development boards and modems to appear as a serial port. macOS names these ports usbmodem followed by an identifier.",
        mentions: ["CDC-ACM", "USB serial", "usbmodem"]
    ),
    GlossaryTerm(
        term: "Thunderbolt Bridge",
        definition: "A network connection between two Macs over a Thunderbolt cable, used for fast direct transfers.",
        mentions: ["Thunderbolt Bridge"]
    ),
    GlossaryTerm(
        term: "MAC address",
        definition: "A hardware address that identifies a network interface on the local network. macOS can use a private address on Wi-Fi networks to limit tracking.",
        mentions: ["MAC address"]
    ),
    GlossaryTerm(
        term: "dBm",
        definition: "A unit for radio signal strength. Values are negative, and closer to 0 is stronger: −45 dBm is stronger than −70 dBm.",
        mentions: ["dBm"]
    ),
    GlossaryTerm(
        term: "Background noise",
        definition: "Radio noise the hardware picks up besides the network itself. The larger the gap between signal and noise, the more reliable the connection.",
        mentions: ["background noise"]
    ),
    GlossaryTerm(
        term: "Wi-Fi generations",
        definition: "Wi-Fi 4, 5, 6, and 7 are the names of the 802.11n, ac, ax, and be standards. Newer generations are faster and cope better with busy networks.",
        mentions: ["Wi-Fi 4", "Wi-Fi 5", "Wi-Fi 6", "Wi-Fi 7", "802.11n", "802.11ac", "802.11ax", "802.11be"]
    ),
    GlossaryTerm(
        term: "Wi-Fi bands",
        definition: "Wi-Fi uses 2.4 GHz (longer range, slower), 5 GHz (faster, shorter range), and 6 GHz (fastest and least crowded, Wi-Fi 6E and later).",
        mentions: ["2.4 GHz", "5 GHz", "6 GHz"]
    ),
    GlossaryTerm(
        term: "WPA2 and WPA3",
        definition: "Wi-Fi security standards that encrypt traffic between devices and the router. WPA3 is the newest; WPA2 is still widely used.",
        mentions: ["WPA2", "WPA3", "WPA"]
    ),
    GlossaryTerm(
        term: "Charge cycle",
        definition: "Using 100% of a battery's capacity in total, even across several partial charges. Current Mac notebook batteries are designed for 1,000 cycles.",
        mentions: ["charge cycle"]
    ),
    GlossaryTerm(
        term: "Optimized Battery Charging",
        definition: "A macOS feature that learns your charging routine and can hold the battery at 80% until you need it, to reduce wear.",
        mentions: ["Optimized Battery Charging"]
    ),
    GlossaryTerm(
        term: "Safe sleep",
        definition: "When the Mac sleeps, it keeps memory powered and also saves its contents to disk, so nothing is lost if the battery runs out.",
        mentions: ["Safe sleep", "safe sleep"]
    ),
    GlossaryTerm(
        term: "Safe Mode",
        definition: "A way to start up a Mac that loads only essential software, used to troubleshoot problems.",
        mentions: ["Safe Mode"]
    )
]

/// Glossary terms mentioned in any of the given texts, in glossary order.
func glossaryTerms(mentionedIn texts: [String]) -> [GlossaryTerm] {
    let combined: String = texts.joined(separator: "\n")

    guard !combined.isEmpty else {
        return []
    }

    return glossary.filter { term in
        term.mentions.contains { mention in textMentions(combined, mention) }
    }
}

private func textMentions(_ text: String, _ mention: String) -> Bool {
    let isCaseSensitive: Bool = mention.contains { $0.isNumber } || mention == mention.uppercased()
    var options: String.CompareOptions = isCaseSensitive ? [] : [.caseInsensitive]
    options.insert(.regularExpression)

    // Whole-word match, so "PPP" doesn't match inside another word.
    let escaped: String = NSRegularExpression.escapedPattern(for: mention)
    return text.range(of: "(?<![\\p{L}\\p{N}])\(escaped)(?![\\p{L}\\p{N}])", options: options) != nil
}
