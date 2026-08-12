import Foundation
import Darwin

enum FileType: String, CaseIterable {
    case txt
    case docx
    case xlsx
    case pptx

    var templateName: String { "blank" }
    var fileExtension: String { rawValue }
    var needsTemplate: Bool { self != .txt }

    var defaultFileName: String {
        switch self {
        case .txt:  return "未命名文本.txt"
        case .docx: return "未命名文档.docx"
        case .xlsx: return "未命名表格.xlsx"
        case .pptx: return "未命名演示.pptx"
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
                NSLog("MacRight: Template not found for \(type.rawValue)")
                return nil
            }

            do {
                data = try Data(contentsOf: templateURL)
            } catch {
                NSLog("MacRight: Failed to read template: \(error.localizedDescription)")
                return nil
            }
        } else {
            data = Data()
        }

        // O_EXCL claims the filename and prevents two Finder actions from
        // selecting the same destination between checking and writing.
        let name = type.defaultFileName
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
                NSLog("MacRight: Failed to create \(destination.path): \(error.localizedDescription)")
                return nil
            }
        }

        NSLog("MacRight: Could not find an available filename for \(name)")
        return nil
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
