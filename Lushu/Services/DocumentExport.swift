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

    /// 系统保存面板默认文件名与目标：有 docx 就写 .docx，否则 .md。
    static func savePlan(docx: URL, markdown: URL, draft: DraftDocument) -> (source: URL, filename: String, ext: String) {
        if FileManager.default.fileExists(atPath: docx.path) {
            return (docx, suggestedFilename(for: draft, ext: "docx"), "docx")
        }
        return (markdown, suggestedFilename(for: draft, ext: "md"), "md")
    }

    static func resolvedDestination(_ picked: URL, preferredExtension: String) -> URL {
        let ext = picked.pathExtension.lowercased()
        if ext == "docx" || ext == "md" { return picked }
        if ext.isEmpty {
            return picked.appendingPathExtension(preferredExtension)
        }
        return picked.deletingPathExtension().appendingPathExtension(preferredExtension)
    }

    /// 弹出系统保存面板，默认写出 .docx。
    @MainActor
    static func saveUserCopy(docx: URL, markdown: URL, draft: DraftDocument) throws {
        let plan = savePlan(docx: docx, markdown: markdown, draft: draft)
        #if os(macOS)
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.title = "下载文书"
        panel.nameFieldStringValue = plan.filename
        panel.allowsOtherFileTypes = false
        if plan.ext == "docx", let word = UTType(filenameExtension: "docx") {
            var types = [word]
            if let md = UTType(filenameExtension: "md") { types.append(md) }
            panel.allowedContentTypes = types
        } else if let md = UTType(filenameExtension: "md") {
            panel.allowedContentTypes = [md]
        } else {
            panel.allowedFileTypes = [plan.ext, "md"]
        }
        guard panel.runModal() == .OK, let picked = panel.url else { return }
        let dest = resolvedDestination(picked, preferredExtension: plan.ext)
        let source = dest.pathExtension.lowercased() == "md" ? markdown : plan.source
        try copyReplacing(from: source, to: dest)
        #else
        try copyToDownloads(plan.source, draft: draft, ext: plan.ext)
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
