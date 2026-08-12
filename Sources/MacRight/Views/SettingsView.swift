import SwiftUI
import FinderSync

struct SettingsView: View {
    @State private var preferredTerminal: TerminalApp = Preferences.shared.preferredTerminal
    @State private var enableDocx: Bool = Preferences.shared.enableDocx
    @State private var enableXlsx: Bool = Preferences.shared.enableXlsx
    @State private var enablePptx: Bool = Preferences.shared.enablePptx
    @State private var enableMarkdown: Bool = Preferences.shared.enableMarkdown
    @State private var enableJson: Bool = Preferences.shared.enableJson
    @State private var enableCsv: Bool = Preferences.shared.enableCsv
    @State private var txtFileName: String = Preferences.shared.fileName(for: "txt", defaultValue: "未命名文本.txt")
    @State private var docxFileName: String = Preferences.shared.fileName(for: "docx", defaultValue: "未命名文档.docx")
    @State private var xlsxFileName: String = Preferences.shared.fileName(for: "xlsx", defaultValue: "未命名表格.xlsx")
    @State private var pptxFileName: String = Preferences.shared.fileName(for: "pptx", defaultValue: "未命名演示.pptx")
    @State private var markdownFileName: String = Preferences.shared.fileName(for: "md", defaultValue: "未命名笔记.md")
    @State private var jsonFileName: String = Preferences.shared.fileName(for: "json", defaultValue: "未命名数据.json")
    @State private var csvFileName: String = Preferences.shared.fileName(for: "csv", defaultValue: "未命名表格.csv")
    @State private var refreshInProgress = false
    @State private var refreshMessage = ""

    var body: some View {
        Form {
            Section("终端设置") {
                Picker("默认终端", selection: $preferredTerminal) {
                    ForEach(TerminalApp.allCases) { app in
                        Text(app.displayName).tag(app)
                    }
                }
                .onChange(of: preferredTerminal) { newValue in
                    Preferences.shared.preferredTerminal = newValue
                }
            }

            Section("文件类型") {
                Toggle("Word 文档 (.docx)", isOn: $enableDocx)
                    .onChange(of: enableDocx) { newValue in
                        Preferences.shared.enableDocx = newValue
                    }

                Toggle("Excel 表格 (.xlsx)", isOn: $enableXlsx)
                    .onChange(of: enableXlsx) { newValue in
                        Preferences.shared.enableXlsx = newValue
                    }

                Toggle("PowerPoint 演示 (.pptx)", isOn: $enablePptx)
                    .onChange(of: enablePptx) { newValue in
                        Preferences.shared.enablePptx = newValue
                    }

                Toggle("Markdown 笔记 (.md)", isOn: $enableMarkdown)
                    .onChange(of: enableMarkdown) { newValue in
                        Preferences.shared.enableMarkdown = newValue
                    }

                Toggle("JSON 数据 (.json)", isOn: $enableJson)
                    .onChange(of: enableJson) { newValue in
                        Preferences.shared.enableJson = newValue
                    }

                Toggle("CSV 表格 (.csv)", isOn: $enableCsv)
                    .onChange(of: enableCsv) { newValue in
                        Preferences.shared.enableCsv = newValue
                    }
            }

            Section("默认文件名") {
                FileNameField(title: "文本", name: $txtFileName, key: "txt")
                FileNameField(title: "Word", name: $docxFileName, key: "docx")
                FileNameField(title: "Excel", name: $xlsxFileName, key: "xlsx")
                FileNameField(title: "PowerPoint", name: $pptxFileName, key: "pptx")
                FileNameField(title: "Markdown", name: $markdownFileName, key: "md")
                FileNameField(title: "JSON", name: $jsonFileName, key: "json")
                FileNameField(title: "CSV", name: $csvFileName, key: "csv")
                Text("扩展名会自动补全，无需手动输入。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Finder 扩展") {
                Button {
                    refreshFinderExtension()
                } label: {
                    if refreshInProgress {
                        ProgressView()
                            .controlSize(.small)
                        Text("正在刷新…")
                    } else {
                        Label("立即刷新 Finder 扩展", systemImage: "arrow.clockwise")
                    }
                }
                .disabled(refreshInProgress)

                if !refreshMessage.isEmpty {
                    Text(refreshMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 420, height: 560)
    }

    private func refreshFinderExtension() {
        refreshInProgress = true
        refreshMessage = ""

        DispatchQueue.global(qos: .userInitiated).async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/pluginkit")
            process.arguments = ["-e", "use", "-i", AppConstants.extensionBundleID]
            let errorPipe = Pipe()
            process.standardError = errorPipe

            do {
                try process.run()
                process.waitUntilExit()
                let succeeded = process.terminationStatus == 0
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let errorMessage = String(data: errorData, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                DispatchQueue.main.async {
                    refreshInProgress = false
                    if FIFinderSyncController.isExtensionEnabled {
                        refreshMessage = succeeded
                            ? "扩展已启用，刷新完成。"
                            : "扩展已启用，但刷新命令返回异常；当前功能仍可使用。"
                    } else if succeeded {
                        refreshMessage = "刷新命令已执行，请稍候或重启 Finder。"
                    } else if errorMessage.isEmpty {
                        refreshMessage = "刷新失败，请在系统设置中启用扩展。"
                    } else {
                        refreshMessage = "刷新失败：\(errorMessage)"
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    refreshInProgress = false
                    refreshMessage = "刷新失败：\(error.localizedDescription)"
                }
            }
        }
    }
}

private struct FileNameField: View {
    let title: String
    @Binding var name: String
    let key: String

    var body: some View {
        TextField(title, text: $name)
            .onChange(of: name) { newValue in
                Preferences.shared.setFileName(newValue, for: key)
            }
    }
}
