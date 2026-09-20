import Foundation

/// 文书生成只接受 StructuredCaseInputs。引用必须先过 LegalCorpus.validate。
/// 测算报告读真表金额与测算原文；不得把材料清单当成报告正文，也不得编造未读出的行金额或合同条号。
struct DocumentGenerator {
    var corpus: LegalCorpus = .empty

    func generate(kind: DocumentKind, inputs: StructuredCaseInputs, brief: BriefCard? = nil) throws -> DraftDocument {
        guard kind.isAvailable else {
            throw DocumentGenerationError.unstructuredInputsRejected
        }
        guard inputs.hasStructuredPayload else {
            throw DocumentGenerationError.unstructuredInputsRejected
        }

        switch kind {
        case .summary:
            if let brief, brief.isActionable {
                return briefDriven(kind: .summary, inputs: inputs, brief: brief)
            }
            return summary(from: inputs)
        case .customReport:
            let card = brief ?? BriefCard(caseID: UUID(), documentPurpose: "专项报告")
            if FeeReportBuilder.isFeeReport(brief: card, kind: .customReport) {
                return FeeReportBuilder.build(inputs: inputs, brief: card)
            }
            return briefDriven(kind: .customReport, inputs: inputs, brief: card)
        case .complaint, .answer:
            throw DocumentGenerationError.unstructuredInputsRejected
        }
    }

    /// 绑定引用：未通过语料校验则抛错，绝不把编造条文写入稿面。
    func bindCitation(_ citation: LegalCitation, to draft: inout DraftDocument) throws {
        do {
            try corpus.validate(citation)
        } catch {
            throw DocumentGenerationError.citationRejected(error.localizedDescription)
        }
        var copy = citation
        copy.display = .hidden
        draft.citations.append(copy)
    }

    /// 润色只允许改已落稿措辞，不得增补数字或未经校验的法条。本轮不接模型。
    func polishWording(_ draft: DraftDocument) -> DraftDocument {
        var copy = draft
        copy.generatorLabel = draft.generatorLabel + " · 措辞未改（未接模型）"
        return copy
    }

    private func summary(from inputs: StructuredCaseInputs) -> DraftDocument {
        var draft = DraftDocument.blankSummary(caseTitle: inputs.caseTitle)
        draft.generatedAt = Date()
        draft.generatorLabel = "结构化案件包 · 本地"
        draft.citations = []
        draft.sections = defaultSummarySections(inputs)
        return draft
    }

    private func briefDriven(kind: DocumentKind, inputs: StructuredCaseInputs, brief: BriefCard) -> DraftDocument {
        let titleSuffix = kind == .customReport ? "专项报告" : "材料总结"
        let purpose = brief.documentPurpose.isEmpty ? titleSuffix : brief.documentPurpose
        var headings = uniqueHeadings(brief.requiredSections)
        if headings.isEmpty {
            headings = defaultSummarySections(inputs).map(\.heading)
        }
        if !headings.contains(where: { $0.contains("缺口") || $0.contains("待补") }) {
            headings.append("待补材料与缺口")
        }
        headings = uniqueHeadings(headings)

        var draft = DraftDocument.blankSummary(caseTitle: inputs.caseTitle)
        draft.kind = kind
        draft.title = "\(inputs.caseTitle) · \(purpose)"
        draft.generatedAt = Date()
        draft.generatorLabel = "任务卡 · 结构化组装 · 未接模型"
        draft.citations = []
        draft.sections = headings.map { heading in
            DraftSection(id: UUID(), heading: heading, body: assemble(heading: heading, inputs: inputs, brief: brief))
        }
        return draft
    }

    private func defaultSummarySections(_ inputs: StructuredCaseInputs) -> [DraftSection] {
        [
            DraftSection(
                id: UUID(),
                heading: "案件概要",
                body: "本稿仅根据结构化案件包整理材料轮廓，不自动引用法条。引用必须是 LegalKnowledge 子集原文，并经 LegalCorpus.validate。"
            ),
            DraftSection(id: UUID(), heading: "材料清单", body: materialList(inputs)),
            DraftSection(
                id: UUID(),
                heading: "事实要点",
                body: inputs.texts.isEmpty
                    ? "文本块尚未锁定。先完成结构化，再回填事实。"
                    : inputs.texts.map { "· \($0.text)" }.joined(separator: "\n")
            ),
            DraftSection(
                id: UUID(),
                heading: "时间线",
                body: "日期以已锁定真表的日期列为准。原件 PDF 不直接进入本稿。"
            ),
            DraftSection(
                id: UUID(),
                heading: "争议焦点",
                body: "争议焦点待承办律师根据结构化材料归纳。此处不编造请求权基础条文。"
            ),
            DraftSection(id: UUID(), heading: "待办与缺口", body: genericGaps(inputs))
        ]
    }

    private func assemble(heading: String, inputs: StructuredCaseInputs, brief: BriefCard) -> String {
        if heading.contains("立场") || heading.contains("范围") || heading.contains("概要") {
            return stanceAndScope(inputs: inputs, brief: brief)
        }
        if heading.contains("停车") {
            return parkingFromTables(inputs: inputs, brief: brief)
        }
        if heading.contains("照明") || heading.contains("用电") || heading.contains("电费") {
            return lightingFromTexts(inputs: inputs, brief: brief)
        }
        if heading.contains("计算") {
            return calculationRules(brief)
        }
        if heading.contains("清单") {
            return materialList(inputs)
        }
        if heading.contains("缺口") || heading.contains("待补") || heading.contains("待办") {
            return gaps(inputs: inputs, brief: brief)
        }
        if heading.contains("事实") {
            return facts(inputs)
        }
        return groundedFallback(heading: heading, inputs: inputs)
    }

    private func stanceAndScope(inputs: StructuredCaseInputs, brief: BriefCard) -> String {
        var lines = [
            "立场：\(brief.stance.title)。",
            "案件：\(inputs.caseTitle)。",
            "目的：\(brief.documentPurpose.isEmpty ? "材料整理" : brief.documentPurpose)。"
        ]
        if !brief.yearsScope.isEmpty {
            lines.append("委托范围：\(brief.yearsScope)。")
        }
        let years = inputs.tables.compactMap { BriefCardParser.year(in: $0.filename) }.sorted()
        if years.isEmpty {
            lines.append("案件包内尚无带年份的真表。")
        } else {
            lines.append("案件包已纳入真表年份：\(years.map { "\($0)" }.joined(separator: "、"))。")
        }
        lines.append("本稿不读取未入库的合同.pdf / 审计件，不编造台账数字。")
        return lines.joined(separator: "\n")
    }

    private func parkingFromTables(inputs: StructuredCaseInputs, brief: BriefCard) -> String {
        let tables = inputs.tables.sorted { $0.filename.localizedStandardCompare($1.filename) == .orderedAscending }
        if tables.isEmpty {
            return "没有锁定的停车费真表。不能填写金额。"
        }
        var lines = ["以下仅列案件包内已有工作簿。单元格金额以打开的真表为准，本稿不代算、不估数。"]
        for table in tables {
            let cols = table.schema.columns.map(\.name).joined(separator: " / ")
            let year = BriefCardParser.year(in: table.filename).map { "\($0)年" } ?? "年份未标"
            lines.append("- \(table.filename)（\(year) · 表 \(table.schema.sheetName) · 列：\(cols)）")
        }
        let missingYears = BriefCardParser.yearGaps(requested: brief.yearsScope, tables: tables)
        if !missingYears.isEmpty {
            lines.append("范围 \(brief.yearsScope) 中缺失、不得补编：\(missingYears.joined(separator: "、"))。")
        }
        return lines.joined(separator: "\n")
    }

    private func lightingFromTexts(inputs: StructuredCaseInputs, brief: BriefCard) -> String {
        let lighting = inputs.texts.filter {
            $0.text.contains("灯") || $0.text.contains("用电") || $0.text.contains("照明")
        }
        var lines: [String] = []
        if lighting.isEmpty {
            lines.append("结构化文本块中没有照明测算原文。")
        } else {
            lines.append("以下为已定位测算原文，未改写数字：")
            for block in lighting {
                lines.append("—— \(block.locator.relativePath)")
                lines.append(block.text)
            }
        }
        if brief.missingFacts.contains(where: { $0.contains("电价") })
            || BriefCardParser.statedNumber(in: brief.sourceMessage, labels: ["电价P", "电价"]) == nil {
            lines.append("电价P：材料与任务卡均未给出，不能计算电费金额。")
        }
        if brief.missingFacts.contains(where: { $0.contains("灯数") })
            || BriefCardParser.statedNumber(in: brief.sourceMessage, labels: ["全场灯数N", "全场灯数"]) == nil {
            lines.append("全场灯数N：测算表仅为分区抽样，不能外推全场。")
        }
        return lines.joined(separator: "\n")
    }

    private func calculationRules(_ brief: BriefCard) -> String {
        if brief.calculationRules.isEmpty {
            return "任务卡未写下计算口径。律书不另推公式，也不套用行业经验值。"
        }
        var lines = ["只采用任务卡已陈述的口径："]
        lines += brief.calculationRules.map { "- \($0)" }
        lines.append("未在任务卡或真表中出现的参数（如电价P、全场灯数N）一律不填。")
        return lines.joined(separator: "\n")
    }

    private func materialList(_ inputs: StructuredCaseInputs) -> String {
        let tableLines = inputs.tables.map { table in
            let cols = table.schema.columns.map(\.name).joined(separator: " / ")
            let lock = table.isLocked ? "已锁定" : "待锁定"
            return "- \(table.filename)（真表 · \(lock) · 列：\(cols)）"
        }
        let textLines = inputs.texts.map { block in
            "- \(block.locator.relativePath)（已定位文本块，\(block.text.count) 字）"
        }
        let lines = tableLines + textLines
        return lines.isEmpty ? "结构化清单为空。" : lines.joined(separator: "\n")
    }

    private func facts(_ inputs: StructuredCaseInputs) -> String {
        if inputs.texts.isEmpty {
            return "文本块尚未锁定。先完成结构化，再回填事实。"
        }
        return inputs.texts.map { "· \($0.text)" }.joined(separator: "\n")
    }

    private func uniqueHeadings(_ headings: [String]) -> [String] {
        var seen = Set<String>()
        var out: [String] = []
        for heading in headings {
            let key = sectionKey(heading)
            if seen.insert(key).inserted {
                out.append(heading)
            }
        }
        return out
    }

    private func sectionKey(_ heading: String) -> String {
        if heading.contains("电费") { return "电费" }
        if heading.contains("停车") { return "停车" }
        if heading.contains("照明") || heading.contains("用电") { return "照明" }
        if heading.contains("计算") { return "计算" }
        if heading.contains("缺口") || heading.contains("待补") || heading.contains("待办") { return "缺口" }
        if heading.contains("测算依据") { return "测算依据" }
        if heading.contains("测算结论") { return "测算结论" }
        if heading.contains("立场") || heading.contains("范围") || heading.contains("概要") { return "立场" }
        if heading.contains("清单") { return "清单" }
        if heading.contains("事实") { return "事实" }
        return heading
    }

    private func groundedFallback(heading: String, inputs: StructuredCaseInputs) -> String {
        "「\(heading)」只根据结构化材料填写。没有对应原文或真表的部分留空，见缺口。真表 \(inputs.tables.count) 份。"
    }

    private func genericGaps(_ inputs: StructuredCaseInputs) -> String {
        """
        - 表头确认并锁定后，再补行数据。
        - 法条引用：lawID + articleNum 必须通过 LegalCorpus 校验。
        - 溯源工位打开 bundled 子集原文；完整法索包是后续事项。
        - 真表 \(inputs.tables.count) 份，已定位文本 \(inputs.texts.count) 块。
        """
    }

    private func gaps(inputs: StructuredCaseInputs, brief: BriefCard) -> String {
        var items = brief.missingFacts
        items.append(contentsOf: BriefCardParser.yearGaps(requested: brief.yearsScope, tables: inputs.tables))
        items.append(contentsOf: brief.extraConstraints.filter { $0.contains("未") || $0.contains("不得") || $0.contains("不") })
        if inputs.tables.isEmpty {
            items.append("锁定真表")
        }
        var seen = Set<String>()
        let unique = items.filter { seen.insert($0).inserted }
        if unique.isEmpty {
            return "任务卡未点名缺数。仍禁止编造法条与台账金额。"
        }
        return (["下列项目在结构化材料中找不到，本稿不编造："] + unique.map { "- \($0)" })
            .joined(separator: "\n")
    }
}
