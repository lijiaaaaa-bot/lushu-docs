import Foundation

enum SampleData {
    static func laborDispute() -> CaseSource {
        let id = UUID(uuidString: "A1111111-1111-1111-1111-111111111111") ?? UUID()
        let title = "张某与北辰科技劳动争议"
        return CaseSource(
            id: id,
            title: title,
            origin: .anxiaFolder,
            locationCaption: "iCloud/案匣/劳动争议/张某-北辰科技",
            materials: [
                item("01-仲裁申请书.pdf", .pdf, 186_432),
                item("02-劳动合同.docx", .docx, 42_880),
                item("03-工资流水-2024.txt", .txt, 8_192, tableStatus: .pendingStructure),
                item("04-解除劳动合同通知.md", .markdown, 3_140),
                item("05-谈话记录.txt", .txt, 12_288),
                item("庭审笔记.md", .markdown, 6_540),
                item("工资表-扫描.pdf", .pdf, 220_160, tableStatus: .pendingStructure)
            ],
            locatedTexts: [],
            pack: CasePack.make(id: id, title: title),
            isSample: true,
            lastOpenedAt: Date()
        )
    }

    static func houseContract() -> CaseSource {
        let id = UUID(uuidString: "A2222222-2222-2222-2222-222222222222") ?? UUID()
        let title = "李某房屋买卖合同纠纷"
        return CaseSource(
            id: id,
            title: title,
            origin: .importedFolder,
            locationCaption: "导入 · 李某-房屋买卖",
            materials: [
                item("买卖合同.docx", .docx, 98_112),
                item("付款凭证.pdf", .pdf, 244_800, tableStatus: .pendingStructure),
                item("微信沟通记录.txt", .txt, 15_772),
                item("中介确认函.md", .markdown, 2_208),
                item("现场照片说明.pages", .other, 1_024, included: false)
            ],
            locatedTexts: [],
            pack: CasePack.make(id: id, title: title),
            isSample: true,
            lastOpenedAt: Date().addingTimeInterval(-3_600)
        )
    }

    private static func item(
        _ name: String,
        _ kind: MaterialKind,
        _ bytes: Int,
        included: Bool = true,
        tableStatus: TableStatus = .notTable
    ) -> MaterialItem {
        MaterialItem(
            filename: name,
            kind: kind,
            byteCount: bytes,
            relativePath: "\(CasePackLayout.raw)/\(name)",
            included: included,
            layer: .raw,
            tableStatus: tableStatus
        )
    }
}
