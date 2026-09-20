import Foundation
#if os(macOS)
import AppKit
import UniformTypeIdentifiers
#endif

enum DocumentExport {
    static func suggestedFilename(for draft: DraftDocument, ext: String) -> String {
        let stem = draft.title
            .replacingOccurrences(of: "/", with: "·")
            .replacingOccurrences(of: ":", with: "·")
        return "\(stem).\(ext)"
    }

    /// 优先弹出系统保存面板写 .docx；取消或失败时回退 Downloads 的 .md。
    @MainActor
    static func saveUserCopy(docx: URL, markdown: URL, draft: DraftDocument) throws {
        let docxExists = FileManager.default.fileExists(atPath: docx.path)
        #if os(macOS)
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.title = "下载文书"
        panel.nameFieldStringValue = suggestedFilename(for: draft, ext: docxExists ? "docx" : "md")
        if let word = UTType(filenameExtension: "docx") {
            panel.allowedContentTypes = [word, .utf8PlainText]
        } else {
            panel.allowedFileTypes = ["docx", "md"]
        }
        guard panel.runModal() == .OK, let dest = panel.url else { return }
        let useMarkdown = dest.pathExtension.lowercased() == "md" || !docxExists
        let source = useMarkdown ? markdown : docx
        try copyReplacing(from: source, to: dest)
        #else
        try copyToDownloads(docxExists ? docx : markdown, draft: draft, ext: docxExists ? "docx" : "md")
        #endif
    }

    static func copyToDownloads(_ source: URL, draft: DraftDocument, ext: String) throws {
        let folder = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let dest = folder.appendingPathComponent(suggestedFilename(for: draft, ext: ext))
        try copyReplacing(from: source, to: dest)
    }

    private static func copyReplacing(from source: URL, to dest: URL) throws {
        let fm = FileManager.default
        if fm.fileExists(atPath: dest.path) {
            try fm.removeItem(at: dest)
        }
        try fm.copyItem(at: source, to: dest)
    }
}
