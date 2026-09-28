import Testing
@testable import SystemProfilerExplorer

struct GlossaryTests {
    @Test
    func termsAreUniqueAndDefinitionsAreSentences() {
        let names: [String] = glossary.map(\.term)

        #expect(Set(names).count == names.count)

        for term in glossary {
            #expect(term.definition.hasSuffix("."), "\(term.term)")
            #expect(!term.mentions.isEmpty, "\(term.term)")
        }
    }

    @Test
    func acronymsMatchCaseSensitivelyAndAsWholeWords() {
        #expect(names(in: "SIP is on and the drive reports SMART Verified.") == ["SMART", "System Integrity Protection (SIP)"])
        #expect(names(in: "A smart sip of water.").isEmpty)
        #expect(names(in: "PPPoE and SIPs").isEmpty)
    }

    @Test
    func phrasesMatchRegardlessOfCase() {
        #expect(names(in: "Signal strength is measured in dBm. Uses Unified Memory.") == ["Unified memory", "dBm"])
        #expect(names(in: "Connected using Wi-Fi 6 (802.11ax) on the 5 GHz band.") == ["Wi-Fi generations", "Wi-Fi bands"])
    }

    @Test
    func modemExplanationLinksSerialTerms() throws {
        let explanation = try #require(valueExplanation(
            dataType: .network,
            path: ["hardware"],
            scalar: .string("Modem"),
            siblings: [
                "_name": .string("nRF52 USB Product"),
                "type": .string("PPP (PPPSerial)"),
                "interface": .string("usbmodem0001")
            ]
        ))
        let texts: [String] = [explanation.summary, explanation.detail ?? ""] + (explanation.confidence?.reasons ?? [])

        #expect(names(in: texts.joined(separator: " ")).contains("USB serial (CDC-ACM)"))
        #expect(names(in: texts.joined(separator: " ")).contains("PPP"))
    }
}

private func names(in text: String) -> [String] {
    glossaryTerms(mentionedIn: [text]).map(\.term)
}
