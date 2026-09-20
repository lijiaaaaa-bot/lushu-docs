import Foundation

/// 在应用支持目录创建 CasePack 骨架：raw / structured/tables / structured/texts / citations / drafts。
struct CasePackStore {
    let rootURL: URL

    init(rootURL: URL? = nil) {
        if let rootURL {
            self.rootURL = rootURL
        } else {
            let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
            self.rootURL = base.appendingPathComponent("Lushu", isDirectory: true)
        }
    }

    func url(for pack: CasePack) -> URL {
        rootURL.appendingPathComponent(pack.folderName, isDirectory: true)
    }

    func subdirectory(_ pack: CasePack, _ relative: String) -> URL {
        url(for: pack).appendingPathComponent(relative, isDirectory: true)
    }

    @discardableResult
    func createSkeleton(_ pack: CasePack) throws -> URL {
        let fm = FileManager.default
        try fm.createDirectory(at: url(for: pack), withIntermediateDirectories: true)
        for leaf in CasePackLayout.allRelative {
            try fm.createDirectory(at: subdirectory(pack, leaf), withIntermediateDirectories: true)
        }
        return url(for: pack)
    }

    func writeRawPlaceholder(_ pack: CasePack, filename: String) throws {
        let dest = subdirectory(pack, CasePackLayout.raw).appendingPathComponent(filename)
        if !FileManager.default.fileExists(atPath: dest.path) {
            try Data("raw-placeholder\n".utf8).write(to: dest)
        }
    }

    func copyReplacing(from source: URL, to dest: URL) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: dest.deletingLastPathComponent(), withIntermediateDirectories: true)
        if fm.fileExists(atPath: dest.path) {
            try fm.removeItem(at: dest)
        }
        try fm.copyItem(at: source, to: dest)
    }

    func writeTextBlocks(_ pack: CasePack, filename: String, blocks: [LocatedTextBlock]) throws {
        let dest = subdirectory(pack, CasePackLayout.structuredTexts).appendingPathComponent(filename)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        var lines: [String] = []
        for block in blocks {
            let data = try encoder.encode(block)
            if let line = String(data: data, encoding: .utf8) {
                lines.append(line)
            }
        }
        try lines.joined(separator: "\n").write(to: dest, atomically: true, encoding: .utf8)
    }

    func writeCitations(_ pack: CasePack, citations: [LegalCitation]) throws {
        let dest = subdirectory(pack, CasePackLayout.citations).appendingPathComponent("citations.json")
        let data = try JSONEncoder().encode(citations)
        try data.write(to: dest, options: .atomic)
    }

    func writeDraft(_ pack: CasePack, draft: DraftDocument) throws {
        let dest = subdirectory(pack, CasePackLayout.drafts)
            .appendingPathComponent("\(draft.kind.rawValue).md")
        try draft.markdown.write(to: dest, atomically: true, encoding: .utf8)
    }

    func tableURL(_ pack: CasePack, filename: String) -> URL {
        subdirectory(pack, CasePackLayout.structuredTables).appendingPathComponent(filename)
    }
}
