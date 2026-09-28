import SwiftUI

/// Actions the menu bar can trigger in the focused window.
struct AppCommandActions {
    let scanTitle: String
    let canScan: Bool
    let isScanning: Bool
    let scan: () -> Void
    let cancel: () -> Void
    let importReport: () -> Void
    let showGlossary: () -> Void
}

private struct AppCommandActionsKey: FocusedValueKey {
    typealias Value = AppCommandActions
}

extension FocusedValues {
    var appCommandActions: AppCommandActions? {
        get { self[AppCommandActionsKey.self] }
        set { self[AppCommandActionsKey.self] = newValue }
    }
}

struct AppCommands: Commands {
    @FocusedValue(\.appCommandActions) private var actions

    var body: some Commands {
        CommandMenu("Scan") {
            Button(actions?.scanTitle ?? "Scan") {
                actions?.scan()
            }
            .keyboardShortcut("r")
            .disabled(actions?.canScan != true)

            Button("Cancel Scan") {
                actions?.cancel()
            }
            .keyboardShortcut(".")
            .disabled(actions?.isScanning != true)

            Divider()

            Button("Import system_profiler JSON…") {
                actions?.importReport()
            }
            .keyboardShortcut("o")
            .disabled(actions == nil || actions?.isScanning == true)
        }

        CommandGroup(before: .help) {
            Button("Glossary") {
                actions?.showGlossary()
            }
            .keyboardShortcut("g", modifiers: [.command, .shift])
            .disabled(actions == nil)
        }
    }
}
