import SwiftUI

/// App identity and scope, separate from the report workspace.
struct AboutAppView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image("BrandLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 112, height: 112)
                .accessibilityLabel("System Profiler Explorer Open Layers logo")
                .accessibilityIdentifier("about-brand-logo")

            VStack(spacing: 6) {
                Text("System Profiler Explorer")
                    .font(.title2.weight(.semibold))
                Text("System information, made clear.")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                versionInformation
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("about-version")
            }

            Text("Explore Mac hardware and software, read explanations, and compare saved reports. Scans are read-only; report processing stays on this Mac.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Divider()

            Text("Explanations add context to reported data; they are not proof of compromise or a complete security assessment.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Text("© 2026 hideouts-io · MIT License")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(32)
        .frame(width: 460)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("about-app-content")
    }

    @ViewBuilder
    private var versionInformation: some View {
        if let version: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
           let build: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String {
            Text("Version \(version) (\(build))")
        } else {
            Text("Version information is missing from this app’s metadata.")
        }
    }
}
