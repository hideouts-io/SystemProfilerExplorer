import SwiftUI

/// The reported value is used solely to invalidate an open request after a rescan. It
/// is never included in the catalog input or passed to the model adapter.
struct PlainEnglishExplanationButton: View {
    let dataType: SystemProfilerDataType
    let path: [String]
    let refreshValue: String

    @State private var isPresented: Bool = false

    var body: some View {
        if plainEnglishFieldIsSupported(dataType: dataType, path: path) {
            Button {
                isPresented = true
            } label: {
                Label("Explain in plain English", systemImage: "text.bubble")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .help("Simplify maintained field information on this Mac. No reported values are used.")
            .accessibilityIdentifier("explain-plain-english-\(dataType.rawValue)-\(path.last ?? "field")")
            .sheet(isPresented: $isPresented) {
                PlainEnglishExplanationView(dataType: dataType, path: path)
            }
            .onChange(of: refreshValue) { _ in isPresented = false }
            .onChange(of: path) { _ in isPresented = false }
            .onChange(of: dataType) { _ in isPresented = false }
        }
    }
}

struct PlainEnglishExplanationView: View {
    let dataType: SystemProfilerDataType
    let path: [String]

    @Environment(\.dismiss) private var dismiss
    @State private var state: PlainEnglishViewState = .loading
    @State private var attempt: Int = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label("Plain-English field guide", systemImage: "text.bubble")
                .font(.title2.weight(.semibold))

            Text("Only the app’s maintained field description is used. Reported values, names, identifiers, logs, and snapshots are not sent to the model.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            ScrollView {
                content
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(minHeight: 150)

            Text("This explains the field, not your Mac’s reported value. Generated wording may be inaccurate: check the maintained explanation and original source. It does not establish health, security, or the cause of a change.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("plain-english-limits")

            HStack {
                if case .loading = state {
                    Text("On-device only • No cloud fallback")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if case .unavailable = state {
                    Button("Check availability") { attempt += 1 }
                        .accessibilityIdentifier("plain-english-check-availability")
                } else {
                    Button("Try again") { attempt += 1 }
                        .accessibilityIdentifier("plain-english-retry")
                }
                Spacer()
                Button("Close") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                    .accessibilityIdentifier("plain-english-close")
            }
        }
        .padding(24)
        .frame(width: 560, height: 420)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("plain-english-sheet")
        // SwiftUI cancels this task when the sheet closes or the row is invalidated.
        // A retry is an explicit new user action; there are no automatic retries.
        .task(id: attempt) { await explainField() }
    }

    @ViewBuilder
    private var content: some View {
        switch state {
        case .loading:
            ProgressView("Preparing an on-device explanation…")
                .accessibilityIdentifier("plain-english-loading")
        case let .generated(title, text):
            VStack(alignment: .leading, spacing: 10) {
                Label("Generated on this Mac • Apple Intelligence", systemImage: "desktopcomputer")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(title).font(.headline)
                // Render as literal text, not Markdown, links, commands, or actions.
                Text(verbatim: text)
                    .font(.body)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("plain-english-output")
            }
            .accessibilityElement(children: .contain)
        case let .unavailable(reason):
            VStack(alignment: .leading, spacing: 10) {
                message(title: "On-device explanations are unavailable", text: reason.message)
                Text("Collection, comparison, and maintained explanations do not require Apple Intelligence. No model request was completed, and no cloud service is used.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("plain-english-unavailable")
        case let .failed(error):
            message(title: "Explanation was not generated", text: error.localizedDescription)
                .accessibilityIdentifier("plain-english-error")
        case .cancelled:
            message(title: "Explanation cancelled", text: "No generated text was retained. The maintained explanation is unchanged.")
                .accessibilityIdentifier("plain-english-cancelled")
        }
    }

    private func message(title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            Text(verbatim: text)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @MainActor
    private func explainField() async {
        let requestAttempt: Int = attempt
        guard !Task.isCancelled else { return }
        state = .loading
        let availability: PlainEnglishAvailability = onDevicePlainEnglishAvailability()
        if case let .unavailable(reason) = availability {
            state = .unavailable(reason)
            return
        }

        do {
            let input: PlainEnglishExplanationInput = try plainEnglishExplanationInput(dataType: dataType, path: path)
            let text: String = try await generateOnDevicePlainEnglishExplanation(input: input)
            try Task.checkCancellation()
            guard attempt == requestAttempt else { return }
            state = .generated(title: input.title, text: text)
        } catch is CancellationError {
            // Dismissal is an expected cancelled operation, not a successful result.
            guard !Task.isCancelled, attempt == requestAttempt else { return }
            state = .cancelled
        } catch let error as PlainEnglishExplanationError {
            guard !Task.isCancelled, attempt == requestAttempt else { return }
            state = plainEnglishFailureState(error: error)
        } catch {
            guard !Task.isCancelled, attempt == requestAttempt else { return }
            let nativeError: NSError = error as NSError
            state = .failed(.generationFailed(domain: nativeError.domain, code: nativeError.code))
        }
    }
}
