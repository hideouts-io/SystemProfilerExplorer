import SwiftUI

@main
struct SystemProfilerExplorerApp: App {
    var body: some Scene {
        WindowGroup {
            AppShellView(
                collector: SystemProfilerCollector(
                    executableURL: URL(fileURLWithPath: "/usr/sbin/system_profiler")
                ),
                parser: SystemProfilerParser()
            )
                .frame(minWidth: 980, minHeight: 640)
        }
        .defaultSize(width: 1180, height: 760)
        .windowToolbarStyle(.unifiedCompact)
    }
}
