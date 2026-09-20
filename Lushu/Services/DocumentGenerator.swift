import Foundation

/// 文书生成只接受 StructuredCaseInputs。引用必须先过 LegalCorpus.validate。
struct DocumentGenerator {
    var corpus: LegalCorpus = .empty

    func generate(kind: DocumentKind, inputs: StructuredCaseInputs) throws -> DraftDocument {
        guard kind.isAvailable else {
            throw DocumentGenerationError.unstructuredInputsRejected
        }
        guard inputs.hasStructuredPayload else {
            throw DocumentGenerationError.unstructuredInputsRejected
        }

        switch kind {
        case .summary:
            return summary(from: inputs)
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

    private func summary(from inputs: StructuredCaseInputs) -> DraftDocument {
        let tableLines = inputs.tables.map { table in
            let cols = table.schema.columns.map(\.name).joined(separator: " / ")
            let lock = table.isLocked ? "已锁定" : "待锁定"
            return "- \(table.filename)（真表 · \(lock) · 列：\(cols)）"
        }
        let textLines = inputs.texts.map { block in
            "- \(block.locator.relativePath)（已定位文本块，\(block.text.count) 字）"
        }

        var draft = DraftDocument.blankSummary(caseTitle: inputs.caseTitle)
        draft.generatedAt = Date()
        draft.generatorLabel = "结构化案件包 · 本地"
        draft.citations = []
        draft.sections = [
            DraftSection(
                id: UUID(),
                heading: "案件概要",
                body: "本稿仅根据结构化案件包整理材料轮廓，不自动引用法条。引用必须是 LegalKnowledge 子集原文，并经 LegalCorpus.validate。"
            ),
            DraftSection(
                id: UUID(),
                heading: "材料清单",
                body: (tableLines + textLines).joined(separator: "\n")
            ),
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
            DraftSection(
                id: UUID(),
                heading: "待办与缺口",
                body: """
                - 表头确认并锁定后，再补行数据。
                - 法条引用：lawID + articleNum 必须通过 LegalCorpus 校验。
                - 溯源工位打开 bundled 子集原文；完整法索包是后续事项。
                """
            )
        ]
        return draft
    }
}
