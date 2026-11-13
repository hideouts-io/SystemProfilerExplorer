import Foundation
import Testing
@testable import SystemProfilerExplorer

#if canImport(FoundationModels) && !SYSTEM_PROFILER_WITHOUT_ON_DEVICE_MODEL
import FoundationModels
#endif

struct PlainEnglishExplanationTests {
    #if canImport(FoundationModels) && !SYSTEM_PROFILER_WITHOUT_ON_DEVICE_MODEL
    @Test
    func nativeAvailabilityClassificationPreservesDocumentedReasons() {
        guard #available(macOS 26.0, *) else {
            #expect(onDevicePlainEnglishAvailability() == .unavailable(.operatingSystem))
            return
        }
        let cases: [(SystemLanguageModel.Availability, PlainEnglishAvailability)] = [
            (.available, .available),
            (.unavailable(.deviceNotEligible), .unavailable(.deviceNotEligible)),
            (.unavailable(.appleIntelligenceNotEnabled), .unavailable(.notEnabled)),
            (.unavailable(.modelNotReady), .unavailable(.modelNotReady))
        ]
        for (native, expected) in cases {
            #expect(plainEnglishModelAvailability(native) == expected)
        }
    }

    /// Constructs documented SDK errors, not a simulated model or a live model failure.
    @Test
    func nativeFailuresPreserveSpecificReasonsWithoutExposingContext() throws {
        guard #available(macOS 26.0, *) else { return }
        let privateContext: String = "SYNTHETIC-PRIVATE-NATIVE-CONTEXT"
        let context = LanguageModelSession.GenerationError.Context(debugDescription: privateContext)
        let cases: [(LanguageModelSession.GenerationError, PlainEnglishExplanationError)] = [
            (.exceededContextWindowSize(context), .contextLimit),
            (.assetsUnavailable(context), .unavailable(.modelNotReady)),
            (.unsupportedLanguageOrLocale(context), .unavailable(.unsupportedLanguage))
        ]
        for (native, expected) in cases {
            let classified: PlainEnglishExplanationError = plainEnglishGenerationFailure(native)
            #expect(classified == expected)
            #expect(!classified.localizedDescription.contains(privateContext))
        }
        for native in [
            LanguageModelSession.GenerationError.guardrailViolation(context),
            .decodingFailure(context), .rateLimited(context), .concurrentRequests(context)
        ] {
            let classified: PlainEnglishExplanationError = plainEnglishGenerationFailure(native)
            let nativeCode: NSError = native as NSError
            #expect(classified == .generationFailed(domain: nativeCode.domain, code: nativeCode.code))
            #expect(!classified.localizedDescription.contains(privateContext))
            #expect(plainEnglishFailureState(error: classified) == .failed(classified))
        }
    }
    #else
    @Test
    func frameworkFreeBuildRefusesInferenceBeforePreparingInput() async {
        #expect(onDevicePlainEnglishAvailability() == .unavailable(.buildWithoutFramework))
        await #expect(throws: PlainEnglishExplanationError.unavailable(.buildWithoutFramework)) {
            try await generateOnDevicePlainEnglishExplanation(input: PlainEnglishExplanationInput(
                title: "", meaning: "", significance: "", interpretation: ""
            ))
        }
    }
    #endif

    @Test
    func cancelledRequestStopsBeforeAvailabilityOrInference() async throws {
        let input: PlainEnglishExplanationInput = try plainEnglishExplanationInput(
            dataType: .hardware, path: ["physical_memory"]
        )
        let request = Task {
            try withUnsafeCurrentTask { task in
                try #require(task).cancel()
            }
            return try await generateOnDevicePlainEnglishExplanation(input: input)
        }
        await #expect(throws: CancellationError.self) {
            try await request.value
        }
    }

    @Test(arguments: [
        PlainEnglishUnavailableReason.operatingSystem, .buildWithoutFramework,
        .deviceNotEligible, .notEnabled, .modelNotReady, .unsupportedLanguage, .unknown
    ])
    func availabilityLostDuringRequestKeepsItsSpecificUnavailableState(
        reason: PlainEnglishUnavailableReason
    ) throws {
        #expect(plainEnglishFailureState(error: .unavailable(reason)) == .unavailable(reason))
        let input: PlainEnglishExplanationInput = try plainEnglishExplanationInput(
            dataType: .hardware, path: ["physical_memory"]
        )
        #expect(!input.meaning.isEmpty)
    }

    @Test(arguments: [
        PlainEnglishExplanationError.invalidInput, .inputTooLarge, .contextLimit,
        .emptyOutput, .outputTooLarge, .timedOut,
        .generationFailed(domain: "SyntheticNativeFailure", code: 1)
    ])
    func generationFailuresAreNotMisrepresentedAsModelUnavailability(error: PlainEnglishExplanationError) {
        #expect(plainEnglishFailureState(error: error) == .failed(error))
    }

    @Test(arguments: ["chip_type", "physical_memory", "machine_model"])
    func preparesOnlyMaintainedFieldContext(field: String) throws {
        let input = try plainEnglishExplanationInput(dataType: .hardware, path: [field])
        let catalog = try #require(hardwareExplanation(path: [field], reportedValue: ""))
        #expect(input.meaning == catalog.meaning)
        #expect(input.interpretation == catalog.interpretation)
        let prompt = try plainEnglishPrompt(input: input)
        #expect(prompt.utf8.count <= 6_000)
        #expect(try JSONDecoder().decode(PlainEnglishExplanationInput.self, from: Data(prompt.utf8)) == input)
    }

    @Test
    func nestedBatteryInputDoesNotContainImportedParentNamesOrValues() throws {
        let input = try plainEnglishExplanationInput(
            dataType: .power,
            path: ["PRIVATE-RECORD-NAME", "sppower_battery_cycle_count"]
        )
        let prompt = try plainEnglishPrompt(input: input)
        #expect(input.title == "Battery Cycle Count")
        #expect(!prompt.contains("PRIVATE-RECORD-NAME"))
        #expect(!prompt.contains("SPPowerDataType"))
    }

    @Test(arguments: ["serial_number", "platform_UUID", "unrecognized_private_key", "activation_lock_status"])
    func refusesPrivateUnknownAndValueDependentFields(field: String) {
        #expect(!plainEnglishFieldIsSupported(dataType: .hardware, path: [field]))
        #expect(throws: PlainEnglishExplanationError.unsupportedField) {
            try plainEnglishExplanationInput(dataType: .hardware, path: [field])
        }
    }

    @Test
    func refusesLogContentAndGeneralDataTypeContext() {
        #expect(throws: PlainEnglishExplanationError.unsupportedField) {
            try plainEnglishExplanationInput(dataType: .logs, path: ["contents"])
        }
        #expect(throws: PlainEnglishExplanationError.unsupportedField) {
            try plainEnglishExplanationInput(dataType: .pci, path: ["vendor_id"])
        }
    }

    @Test
    func promptRejectsMissingTextAndOversizedEncodedInput() {
        #expect(throws: PlainEnglishExplanationError.invalidInput) {
            try plainEnglishPrompt(input: PlainEnglishExplanationInput(
                title: "Memory", meaning: " ", significance: "Context", interpretation: "Limits"
            ))
        }
        #expect(throws: PlainEnglishExplanationError.inputTooLarge) {
            try plainEnglishPrompt(input: PlainEnglishExplanationInput(
                title: "Memory", meaning: String(repeating: "é", count: 3_000),
                significance: "Context", interpretation: "Limits"
            ))
        }
    }

    @Test
    func outputRequiresNonemptyBoundedText() throws {
        #expect(throws: PlainEnglishExplanationError.emptyOutput) {
            try validatedPlainEnglishOutput(" \n\t")
        }
        let boundary = String(repeating: "a", count: 2_400)
        #expect(try validatedPlainEnglishOutput(boundary) == boundary)
        #expect(try validatedPlainEnglishOutput("  General field context.\n") == "General field context.")
        #expect(throws: PlainEnglishExplanationError.outputTooLarge) {
            try validatedPlainEnglishOutput(boundary + "a")
        }
        #expect(throws: PlainEnglishExplanationError.outputTooLarge) {
            try validatedPlainEnglishOutput(String(repeating: "é", count: 1_201))
        }
    }

    /// Opt-in real native-model check, not a mocked generator. An unavailable model
    /// exercises the explicit refusal path; it does not claim generation succeeded.
    @Test(.enabled(
        if: ProcessInfo.processInfo.environment["SYSTEM_PROFILER_NATIVE_EXPLANATION_TEST"] == "1",
        "Requires an explicit local on-device model check; no cloud fallback is allowed."
    ))
    func installedModelHonorsAvailabilityAndGenerationBoundary() async throws {
        let report: SystemProfilerReport = SystemProfilerReport(
            sections: [SystemProfilerSection(dataType: .hardware, items: [
                .object(["_name": .string("Synthetic Hardware"), "physical_memory": .string("16 GB")])
            ])],
            commandArguments: ["-json", "SPHardwareDataType"], standardError: "",
            startedAt: Date(timeIntervalSince1970: 1_700_000_000),
            completedAt: Date(timeIntervalSince1970: 1_700_000_001)
        )
        let originalExport: Data = try encodeReportExport(makeFullReportExport(report))
        let input = try plainEnglishExplanationInput(dataType: .hardware, path: ["physical_memory"])
        let availability: PlainEnglishAvailability = onDevicePlainEnglishAvailability()
        switch availability {
        case .available:
            let output: String = try await generateOnDevicePlainEnglishExplanation(input: input)
            #expect(!output.isEmpty)
            #expect(output.utf8.count <= 2_400)
            print("Native explanation check: real on-device generation succeeded (\(output.utf8.count) output bytes).")
        case let .unavailable(reason):
            await #expect(throws: PlainEnglishExplanationError.unavailable(reason)) {
                try await generateOnDevicePlainEnglishExplanation(input: input)
            }
            print("Native explanation check: generation unavailable. \(reason.message)")
        }
        // Maintained explanations and their source data are independent of model readiness.
        #expect(try plainEnglishExplanationInput(dataType: .hardware, path: ["physical_memory"]) == input)
        #expect(try encodeReportExport(makeFullReportExport(report)) == originalExport)
        #expect(try compareReports(baseline: report, current: report).summary.changeCount == 0)
    }
}
