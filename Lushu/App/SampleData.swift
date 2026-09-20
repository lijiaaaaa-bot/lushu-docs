import Foundation

enum SampleData {
    static func laborDispute() -> CaseSource {
        CaseSource(
            id: UUID(uuidString: "A1111111-1111-1111-1111-111111111111") ?? UUID(),
            title: "张某与北辰科技劳动争议",
            origin: .anxiaFolder,
            locationCaption: "iCloud/案匣/劳动争议/张某-北辰科技",
            materials: [
                item("01-仲裁申请书.pdf", .pdf, 186_432),
                item("02-劳动合同.docx", .docx, 42_880),
                item("03-工资流水-2024.txt", .txt, 8_192),
                item("04-解除劳动合同通知.md", .markdown, 3_140),
                item("05-谈话记录.txt", .txt, 12_288),
                item("庭审笔记.md", .markdown, 6_540)
            ],
            isSample: true,
            lastOpenedAt: Date()
        )
    }

    static func houseContract() -> CaseSource {
        CaseSource(
            id: UUID(uuidString: "A2222222-2222-2222-2222-222222222222") ?? UUID(),
            title: "李某房屋买卖合同纠纷",
            origin: .importedFolder,
            locationCaption: "导入 · 李某-房屋买卖",
            materials: [
                item("买卖合同.docx", .docx, 98_112),
                item("付款凭证.pdf", .pdf, 244_800),
                item("微信沟通记录.txt", .txt, 15_772),
                item("中介确认函.md", .markdown, 2_208),
                item("现场照片说明.pages", .other, 1_024, included: false)
            ],
            isSample: true,
            lastOpenedAt: Date().addingTimeInterval(-3_600)
        )
    }

    static func summary(for source: CaseSource) -> DraftDocument {
        switch source.origin {
        case .anxiaFolder:
            return laborSummary(title: source.title)
        case .importedFiles, .importedFolder:
            return houseSummary(title: source.title)
        }
    }

    private static func item(
        _ name: String,
        _ kind: MaterialKind,
        _ bytes: Int,
        included: Bool = true
    ) -> MaterialItem {
        MaterialItem(
            id: UUID(),
            filename: name,
            kind: kind,
            byteCount: bytes,
            relativePath: name,
            included: included
        )
    }

    private static func laborSummary(title: String) -> DraftDocument {
        DraftDocument(
            id: UUID(),
            kind: .summary,
            title: "\(title) · 材料总结",
            sections: [
                DraftSection(
                    id: UUID(),
                    heading: "案件概要",
                    body: """
                    申请人张某主张与被申请人北辰科技存在劳动关系，请求支付违法解除赔偿金、未休年休假工资及部分工资差额。材料显示双方签订书面劳动合同，解除以通知书送达为节点。本稿为界面示例，供审阅版式，不构成法律意见。
                    """
                ),
                DraftSection(
                    id: UUID(),
                    heading: "材料清单",
                    body: """
                    1. 仲裁申请书（PDF）— 请求事项与事实理由
                    2. 劳动合同（DOCX）— 岗位、期限、薪酬约定
                    3. 工资流水（TXT）— 2024 年度发放记录
                    4. 解除劳动合同通知（MD）— 解除理由与送达表述
                    5. 谈话记录（TXT）— 人事面谈纪要
                    6. 庭审笔记（MD）— 庭审争点摘记
                    """
                ),
                DraftSection(
                    id: UUID(),
                    heading: "事实要点",
                    body: """
                    - 入职与合同签订时间需与申请书核对。
                    - 工资流水可用作实发工资与岗位约定的对照。
                    - 解除通知载明的理由，应与谈话记录是否一致。
                    - 年休假主张目前未见独立考勤或休假台账。
                    """
                ),
                DraftSection(
                    id: UUID(),
                    heading: "时间线",
                    body: """
                    - （待核）入职 / 合同起始日
                    - 2024 年 — 工资流水覆盖期间
                    - （待核）谈话记录形成日
                    - （待核）解除通知载明的解除日
                    - （待核）申请仲裁日
                    """
                ),
                DraftSection(
                    id: UUID(),
                    heading: "争议焦点",
                    body: """
                    1. 解除是否属于违法解除，抑或合法解除。
                    2. 工资差额的计算基数与期间。
                    3. 未休年休假天数及工资折算依据。
                    """
                ),
                DraftSection(
                    id: UUID(),
                    heading: "待办与缺口",
                    body: """
                    - 补齐考勤、年休假台账。
                    - 核对解除通知送达证据。
                    - 将 PDF / DOCX 正文解析接入后回填精确日期（本轮界面先行，未做解析）。
                    """
                )
            ],
            generatedAt: Date(),
            generatorLabel: "本地示例稿"
        )
    }

    private static func houseSummary(title: String) -> DraftDocument {
        DraftDocument(
            id: UUID(),
            kind: .summary,
            title: "\(title) · 材料总结",
            sections: [
                DraftSection(
                    id: UUID(),
                    heading: "案件概要",
                    body: "买受人李某与出卖人就房屋买卖合同的履行、付款与过户安排产生争议。当前材料以合同、付款凭证与沟通记录为主。本稿为导入来源的界面示例。"
                ),
                DraftSection(
                    id: UUID(),
                    heading: "材料清单",
                    body: """
                    1. 买卖合同（DOCX）
                    2. 付款凭证（PDF）
                    3. 微信沟通记录（TXT）
                    4. 中介确认函（MD）
                    5. 现场照片说明（其他，仅列名、未纳入正文）
                    """
                ),
                DraftSection(
                    id: UUID(),
                    heading: "事实要点",
                    body: """
                    - 合同价款、定金与尾款节点需与凭证逐笔核对。
                    - 沟通记录中可能存在变更交付或过户的口头安排。
                    - 中介确认函的角色与担保范围待核。
                    """
                ),
                DraftSection(
                    id: UUID(),
                    heading: "时间线",
                    body: """
                    - （待核）签约日
                    - （待核）各笔付款日
                    - （待核）约定过户日 / 实际沟通日
                    """
                ),
                DraftSection(
                    id: UUID(),
                    heading: "争议焦点",
                    body: """
                    1. 是否构成根本违约及解除条件是否成就。
                    2. 已付款项的性质（定金 / 价款）与返还或双倍主张。
                    """
                ),
                DraftSection(
                    id: UUID(),
                    heading: "待办与缺口",
                    body: "- 产权与抵押状态证明尚未导入。\n- 解析器接入后回填合同条款摘录。"
                )
            ],
            generatedAt: Date(),
            generatorLabel: "本地示例稿"
        )
    }
}
