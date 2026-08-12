import Foundation
import AppKit

final class CmuxLauncher {

    static let bundleIdentifier = "com.cmuxterm.app"

    static var isInstalled: Bool {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) != nil
    }

    static func open(at directory: URL) {
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else {
            FinderFeedback.error("未找到 cmux")
            return
        }

        let config = NSWorkspace.OpenConfiguration()
        config.arguments = []

        NSWorkspace.shared.open(
            [directory],
            withApplicationAt: appURL,
            configuration: config
        ) { _, error in
            if let error = error {
                FinderFeedback.error("打开 cmux 失败：\(error.localizedDescription)")
            }
        }
    }
}
