import Foundation
import Darwin

enum FileType: String, CaseIterable {
    case txt
    case docx
    case xlsx
    case pptx
    case md
    case json
    case csv

    var templateName: String { "blank" }
    var fileExtension: String { rawValue }
    var needsTemplate: Bool { [.docx, .xlsx, .pptx].contains(self) }

    var defaultFileName: String {
        switch self {
        case .txt:  return "未命名文本.txt"
        case .docx: return "未命名文档.docx"
        case .xlsx: return "未命名表格.xlsx"
        case .pptx: return "未命名演示.pptx"
        case .md:   return "未命名笔记.md"
        case .json: return "未命名数据.json"
        case .csv:  return "未命名表格.csv"
        }
    }
}

final class FileCreator {

    @discardableResult
    static func createFile(type: FileType, in directory: URL) -> URL? {
        // Try security-scoped access for sandboxed context
        let accessing = directory.startAccessingSecurityScopedResource()
        defer {
            if accessing { directory.stopAccessingSecurityScopedResource() }
        }

        let data: Data
        if type.needsTemplate {
            guard let templateURL = Bundle.main.url(
                forResource: type.templateName,
                withExtension: type.fileExtension,
                subdirectory: "Templates"
            ) else {
                FinderFeedback.error("找不到 \(type.rawValue) 模板")
                return nil
            }

            do {
                data = try Data(contentsOf: templateURL)
            } catch {
                FinderFeedback.error("读取模板失败：\(error.localizedDescription)")
                return nil
            }
        } else {
            data = Data()
        }

        // O_EXCL claims the filename and prevents two Finder actions from
        // selecting the same destination between checking and writing.
        let configuredName = Preferences.shared.fileName(for: type.rawValue, defaultValue: type.defaultFileName)
        let name = normalizedFileName(configuredName, extension: type.fileExtension)
        let base = (name as NSString).deletingPathExtension
        let ext = (name as NSString).pathExtension

        for counter in 1...10_000 {
            let filename = counter == 1 ? name : "\(base) \(counter).\(ext)"
            let destination = directory.appendingPathComponent(filename)

            switch writeExclusively(data, to: destination) {
            case .created:
                NSLog("MacRight: Created file at \(destination.path)")
                return destination
            case .alreadyExists:
                continue
            case .failed(let error):
                FinderFeedback.error("创建文件失败：\(error.localizedDescription)")
                return nil
            }
        }

        FinderFeedback.error("无法为文件找到可用文件名")
        return nil
    }

    private static func normalizedFileName(_ name: String, extension fileExtension: String) -> String {
        let trimmed = name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "/", with: "-")
        guard !trimmed.isEmpty else { return "未命名.\(fileExtension)" }
        return (trimmed as NSString).pathExtension.lowercased() == fileExtension
            ? trimmed
            : "\(trimmed).\(fileExtension)"
    }

    private enum WriteResult {
        case created
        case alreadyExists
        case failed(Error)
    }

    private static func writeExclusively(_ data: Data, to url: URL) -> WriteResult {
        let descriptor = open(url.path, O_WRONLY | O_CREAT | O_EXCL, 0o644)
        guard descriptor >= 0 else {
            if errno == EEXIST { return .alreadyExists }
            return .failed(CocoaError(.fileWriteUnknown, userInfo: [NSFilePathErrorKey: url.path]))
        }

        let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
        do {
            try handle.write(contentsOf: data)
            try handle.close()
            return .created
        } catch {
            try? handle.close()
            try? FileManager.default.removeItem(at: url)
            return .failed(error)
        }
    }
}
