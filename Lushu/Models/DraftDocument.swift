import Foundation

struct DraftSection: Identifiable, Hashable, Codable {
    var id: UUID
    var heading: String
    var body: String
}

struct DraftDocument: Identifiable, Hashable, Codable {
    var id: UUID
    var kind: DocumentKind
    var title: String
    var sections: [DraftSection]
    var generatedAt: Date?
    var generatorLabel: String
    var citations: [LegalCitation]

    var markdown: String {
        var lines: [String] = ["# \(title)", ""]
        if let generatedAt {
            lines.append("_\(generatorLabel) · \(DraftDocument.formatStamp(generatedAt))_")
            lines.append("")
        }
        for section in sections {
            lines.append("## \(section.heading)")
            lines.append("")
            lines.append(section.body)
            lines.append("")
        }
        return lines.joined(separator: "\n")
    }

    var plainText: String {
        markdown
            .replacingOccurrences(of: "# ", with: "")
            .replacingOccurrences(of: "## ", with: "")
            .replacingOccurrences(of: "_", with: "")
    }

    var isBlank: Bool {
        sections.allSatisfy { $0.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    private static func formatStamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年M月d日 HH:mm"
        return formatter.string(from: date)
    }

    static func blankSummary(caseTitle: String) -> DraftDocument {
        DraftDocument(
            id: UUID(),
            kind: .summary,
            title: "\(caseTitle) · 材料总结",
            sections: [
                DraftSection(id: UUID(), heading: "案件概要", body: ""),
                DraftSection(id: UUID(), heading: "材料清单", body: ""),
                DraftSection(id: UUID(), heading: "事实要点", body: ""),
                DraftSection(id: UUID(), heading: "时间线", body: ""),
                DraftSection(id: UUID(), heading: "争议焦点", body: ""),
                DraftSection(id: UUID(), heading: "待办与缺口", body: "")
            ],
            generatedAt: nil,
            generatorLabel: "尚未生成",
            citations: []
        )
    }
}
