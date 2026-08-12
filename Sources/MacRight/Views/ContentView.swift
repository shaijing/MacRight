import SwiftUI
import FinderSync

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var extensionEnabled = false

    var body: some View {
        ScrollView {
            VStack(alignment: .center, spacing: 12) {
                VStack(spacing: 3) {
                    Image(systemName: "contextualmenu.and.cursorarrow")
                        .font(.system(size: 38))
                        .foregroundStyle(.blue)

                    Text("MacRight")
                        .font(.title.bold())
                    Text("Finder 右键菜单增强工具")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Divider()

                HStack(spacing: 12) {
                    Image(systemName: extensionEnabled ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(extensionEnabled ? .green : .red)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(extensionEnabled ? "Finder 扩展已启用" : "Finder 扩展未启用")
                            .font(.headline)
                        Text(extensionEnabled ? "右键菜单功能已就绪" : "请在系统设置中启用扩展")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 8)
                }
                .padding(10)
                .frame(maxWidth: 380, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(extensionEnabled ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
                )

                Button("打开系统设置 - 扩展") {
                    openExtensionSettings()
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)

                if !extensionEnabled {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("如何启用")
                            .font(.headline)

                        StepView(number: 1, text: "打开上方的系统设置")
                        StepView(number: 2, text: "进入 通用 → 登录项与扩展")
                        StepView(number: 3, text: "找到 MacRight 并启用 Finder 扩展")
                    }
                    .padding(10)
                    .frame(maxWidth: 380, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.blue.opacity(0.05))
                    )
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("功能")
                        .font(.headline)

                    FeatureRow(icon: "doc.badge.plus", title: "新建文件", description: "支持 TXT、Office、Markdown、JSON、CSV")
                    FeatureRow(icon: "terminal", title: "在此打开终端", description: "支持 Terminal、iTerm、Ghostty 和 cmux")
                }
                .padding(10)
                .frame(maxWidth: 380, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.gray.opacity(0.05))
                )
            }
            .frame(maxWidth: 400)
            .padding(16)
        }
        .frame(minWidth: 320, idealWidth: 380, minHeight: 300, idealHeight: 430)
        .onAppear {
            checkExtensionStatus()
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                checkExtensionStatus()
            }
        }
    }

    private func checkExtensionStatus() {
        // This API reports the actual Finder Sync enablement state directly.
        extensionEnabled = FIFinderSyncController.isExtensionEnabled
    }

    private func openExtensionSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.ExtensionsPreferences") {
            NSWorkspace.shared.open(url)
        }
    }

}

struct StepView: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(spacing: 10) {
            Text("\(number)")
                .font(.caption.bold())
                .frame(width: 22, height: 22)
                .background(Circle().fill(.blue))
                .foregroundStyle(.white)
            Text(text)
                .font(.body)
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .frame(width: 28)
                .foregroundStyle(.blue)
            VStack(alignment: .leading) {
                Text(title).font(.body.bold())
                Text(description).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
