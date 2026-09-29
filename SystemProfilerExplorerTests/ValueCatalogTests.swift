import Foundation
import Testing
@testable import SystemProfilerExplorer

/// One known value of a limited-set field, as system_profiler reports it.
/// docs/value-explanations.md lists the same values with their sources.
struct ValueSample: Sendable, CustomTestStringConvertible {
    let dataType: SystemProfilerDataType
    let path: [String]
    let scalar: ProfileScalar
    let siblings: [String: ProfileValue]
    let report: ValueReportContext

    init(
        _ dataType: SystemProfilerDataType,
        _ path: [String],
        _ value: String,
        siblings: [String: ProfileValue] = [:],
        report: ValueReportContext = .empty
    ) {
        self.init(dataType, path, scalar: .string(value), siblings: siblings, report: report)
    }

    init(
        _ dataType: SystemProfilerDataType,
        _ path: [String],
        scalar: ProfileScalar,
        siblings: [String: ProfileValue] = [:],
        report: ValueReportContext = .empty
    ) {
        self.dataType = dataType
        self.path = path
        self.scalar = scalar
        self.siblings = siblings
        self.report = report
    }

    var testDescription: String {
        "\(dataType.rawValue).\(path.joined(separator: ".")) = \(scalar.rawDescription)"
    }

    func explain() -> ValueExplanation? {
        valueExplanation(dataType: dataType, path: path, scalar: scalar, siblings: siblings, report: report)
    }
}

let appleSiliconReport: ValueReportContext = ValueReportContext(usbDeviceNames: nil, processor: .appleSilicon)
let intelReport: ValueReportContext = ValueReportContext(usbDeviceNames: nil, processor: .intel)

/// Every value the app explains for fields with a limited set of values.
let explainedValueSamples: [ValueSample] = applicationValueSamples + fontValueSamples + extensionValueSamples

/// Each value is checked with no Hardware section, on Apple silicon, and on an Intel Mac,
/// because what an architecture means depends on the Mac.
private let applicationValueSamples: [ValueSample] = {
    let architectures: [String] = [
        "arch_arm", "arch_arm_i64", "arch_i64", "arch_i32_i64", "arch_ios", "arch_other", "arch_i32", "arch_ppc"
    ]
    let origins: [String] = ["apple", "mac_app_store", "app_store", "ios_app_store", "identified_developer", "unknown"]
    var samples: [ValueSample] = []

    for dataType in [SystemProfilerDataType.applications, .frameworks] {
        for architecture in architectures {
            for report in [ValueReportContext.empty, appleSiliconReport, intelReport] {
                samples.append(ValueSample(dataType, ["arch_kind"], architecture, report: report))
            }
        }

        for origin in origins {
            samples.append(ValueSample(dataType, ["obtained_from"], origin))
        }
    }

    samples += origins.map { ValueSample(.extensions, ["obtained_from"], $0) }
    samples += ["yes", "no"].map { ValueSample(.frameworks, ["private_framework"], $0) }
    return samples
}()

private let fontValueSamples: [ValueSample] = {
    var samples: [ValueSample] = ["truetype", "opentype", "postscript", "bitmap", "unknown"].map {
        ValueSample(.fonts, ["type"], $0)
    }

    for flag in ["enabled", "valid"] {
        for value in ["yes", "no"] {
            samples.append(ValueSample(.fonts, [flag], value))
            samples.append(ValueSample(.fonts, ["typefaces", "[]", flag], value))
        }
    }

    for flag in ["duplicate", "copy_protected", "embeddable", "outline"] {
        for value in ["yes", "no"] {
            samples.append(ValueSample(.fonts, ["typefaces", "[]", flag], value))
        }
    }

    return samples
}()

private let extensionValueSamples: [ValueSample] = {
    var samples: [ValueSample] = []

    for value in ["spext_yes", "spext_no"] {
        samples.append(ValueSample(.extensions, ["spext_loaded"], value))
        samples.append(ValueSample(.extensions, ["spext_notarized"], value))

        for report in [ValueReportContext.empty, appleSiliconReport, intelReport] {
            samples.append(ValueSample(.extensions, ["spext_has64BitIntelCode"], value, report: report))
        }
    }

    samples += ["spext_satisfied", "spext_incomplete"].map { ValueSample(.extensions, ["spext_hasAllDependencies"], $0) }
    samples += ["yes", "no"].map { ValueSample(.extensions, ["spext_loadable"], $0) }
    samples += ["arm64e", "arm64", "x86_64", "i386"].map { ValueSample(.extensions, ["spext_architectures", "[]"], $0) }
    samples += ["spext_arch_arm", "spext_arch_x86", "spext_universal", "spext_arch_ppc"].map {
        ValueSample(.extensions, ["spext_runtime_environment"], $0)
    }
    samples += ["spext_apple", "spext_identified_developer", "spext_unknown", "spext_not_signed"].map {
        ValueSample(.extensions, ["spext_obtained_from"], $0)
    }
    return samples
}()

struct ValueCatalogTests {
    @Test(arguments: explainedValueSamples)
    func everyKnownValueHasEveryPart(_ sample: ValueSample) throws {
        let explanation = try #require(sample.explain(), "\(sample.testDescription) has no explanation")

        #expect(explanation.status != .unknown)
        #expect(!explanation.summary.isEmpty)
        #expect(explanation.detail?.isEmpty == false, "missing what this result means")
        #expect(explanation.significance?.isEmpty == false, "missing why it matters")
        #expect(explanation.suggestedAction?.isEmpty == false, "missing what to check")
        #expect(explanation.confidence != nil, "missing a source")
    }

    // MARK: - Applications and frameworks

    @Test
    func architectureDependsOnThisMacsProcessor() throws {
        func explain(_ value: String, _ report: ValueReportContext) -> ValueExplanation? {
            valueExplanation(dataType: .applications, path: ["arch_kind"], scalar: .string(value), report: report)
        }

        let intelOnAppleSilicon = try #require(explain("arch_i64", appleSiliconReport))
        let intelOnIntel = try #require(explain("arch_i64", intelReport))
        let armOnIntel = try #require(explain("arch_arm", intelReport))

        #expect(intelOnAppleSilicon.status == .informational)
        #expect(intelOnAppleSilicon.detail?.contains("Rosetta 2") == true)
        #expect(intelOnAppleSilicon.significance?.contains("macOS 27") == true)
        #expect(intelOnIntel.status == .normal)
        #expect(intelOnIntel.detail?.contains("natively") == true)
        #expect(armOnIntel.status == .informational)
        #expect(armOnIntel.detail?.contains("can't run") == true)
        #expect(explain("arch_arm", appleSiliconReport)?.status == .normal)
        #expect(explain("arch_arm_i64", intelReport)?.status == .normal)
        #expect(explain("arch_future", appleSiliconReport)?.status == .unknown)
    }

    @Test
    func frameworksAreNotCalledApps() throws {
        let framework = try #require(valueExplanation(
            dataType: .frameworks,
            path: ["arch_kind"],
            scalar: .string("arch_other")
        ))

        #expect(framework.detail?.contains("frameworks whose main program") == true)
        #expect(framework.confidence?.reasons.isEmpty == false)
    }

    @Test
    func unsignedOriginIsInformationNotAWarning() throws {
        let unknown = try #require(valueExplanation(dataType: .applications, path: ["obtained_from"], scalar: .string("unknown")))

        #expect(unknown.status == .informational)
        #expect(unknown.significance?.contains("doesn't mean it's harmful") == true)
        #expect(valueExplanation(dataType: .applications, path: ["obtained_from"], scalar: .string("somewhere_else"))?.status == .unknown)
    }

    // MARK: - Extensions

    @Test
    func missingDependenciesAreWorthALook() {
        func status(_ value: String) -> ValueStatus? {
            valueExplanation(dataType: .extensions, path: ["spext_hasAllDependencies"], scalar: .string(value))?.status
        }

        #expect(status("spext_satisfied") == .normal)
        #expect(status("spext_incomplete") == .worthReviewing)
        #expect(status("spext_partly") == .unknown)
    }

    @Test
    func intelOnlyGapMattersOnlyOnAnIntelMac() throws {
        let onIntel = try #require(valueExplanation(
            dataType: .extensions,
            path: ["spext_has64BitIntelCode"],
            scalar: .string("spext_no"),
            report: intelReport
        ))
        let onAppleSilicon = try #require(valueExplanation(
            dataType: .extensions,
            path: ["spext_has64BitIntelCode"],
            scalar: .string("spext_no"),
            report: appleSiliconReport
        ))

        #expect(onIntel.detail?.contains("can't load on this Mac") == true)
        #expect(onAppleSilicon.detail?.contains("only for Macs with Apple silicon") == true)
    }

    @Test
    func processorFamilyComesFromTheHardwareOverview() {
        let appleSilicon: [ProfileValue] = [.object(["_name": .string("hardware_overview"), "chip_type": .string("Apple M1")])]
        let intel: [ProfileValue] = [.object(["_name": .string("hardware_overview"), "cpu_type": .string("Quad-Core Intel Core i5")])]

        #expect(processorFamily(inHardwareItems: appleSilicon) == .appleSilicon)
        #expect(processorFamily(inHardwareItems: intel) == .intel)
        #expect(processorFamily(inHardwareItems: [.object(["_name": .string("hardware_overview")])]) == nil)
    }
}
