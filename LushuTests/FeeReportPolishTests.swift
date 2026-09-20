import XCTest
@testable import Lushu

final class FeeReportPolishTests: XCTestCase {
    func testNumberLockExtractsMoneyArticlesAndDates() {
        let skeleton = """
        《合同》第九条第七款约定：职工停车收费按3元/车/天。
        2018年9月1日至2021年7月20日。
        2022年 | 561,930.00 | 汇总
        累计 3,685,344.00
        参考电价P=0.65
        """
        let tokens = NumberLock.lockedTokens(in: skeleton)
        XCTAssertTrue(tokens.contains("第九条第七款"))
        XCTAssertTrue(tokens.contains("2018年9月1日"))
        XCTAssertTrue(tokens.contains("2021年7月20日"))
        XCTAssertTrue(tokens.contains("561,930.00"))
        XCTAssertTrue(tokens.contains("3,685,344.00"))
        XCTAssertTrue(tokens.contains("0.65"))
        XCTAssertTrue(tokens.contains("3"))
    }

    func testPolishWordingRejectsWhenModelChangesLockedAmount() {
        let draft = parkingDraft(body: """
        2022年 | 561,930.00 | 确认金额
        《合同》第九条第七款
        2018年9月1日
        """)
        let bad = """
        ## 职工停车费
        现将年度列示。2022年 | 561,931.00 | 确认金额
        《合同》第九条第七款
        2018年9月1日
        """
        let result = DocumentGenerator().polishWording(draft, polishedMarkdown: bad)
        XCTAssertEqual(result.sections[0].body, draft.sections[0].body)
        XCTAssertFalse(result.generatorLabel.contains("DeepSeek"))
        XCTAssertTrue(result.generatorLabel.contains("函件测算报告"))
    }

    func testPolishWordingAcceptsVoiceChangeWhenNumbersLocked() {
        let draft = parkingDraft(body: """
        2022年 | 561,930.00 | 确认金额
        《合同》第九条第七款
        2018年9月1日
        """)
        let good = """
        ## 职工停车费
        现将已确认年度列示如下。2022年 | 561,930.00 | 确认金额
        《合同》第九条第七款仍按原文。自2018年9月1日起算。
        """
        let result = DocumentGenerator().polishWording(draft, polishedMarkdown: good)
        XCTAssertTrue(result.sections[0].body.contains("现将已确认"))
        XCTAssertTrue(result.sections[0].body.contains("561,930.00"))
        XCTAssertTrue(result.generatorLabel.contains("DeepSeek"))
    }

    func testPolishWordingWithoutModelKeepsSkeleton() {
        let draft = parkingDraft(body: "2022年 | 561,930.00 | 汇总")
        let result = DocumentGenerator().polishWording(draft)
        XCTAssertEqual(result.sections[0].body, draft.sections[0].body)
        XCTAssertFalse(result.generatorLabel.contains("措辞未改"))
        XCTAssertFalse(result.generatorLabel.contains("DeepSeek"))
    }

    func testWriterEmitsWordTablesAndSignatureWithoutKey() {
        var draft = parkingDraft(body: """
        （二）各年度职工停车费明细
        年度 | 金额（元） | 说明
        2022年 | 561,930.00 | 2022年2月至12月
        累计（截至2026年7月） | 3,685,344.00 | —
        """)
        draft.sections.append(
            DraftSection(
                id: UUID(),
                heading: "测算结论",
                body: """
                表  测算结论汇总
                序号 | 费用项目 | 测算结果（元） | 说明
                1 | 乙方应缴纳停车场电费 | 1,055,846.57 | 参考电价
                2 | 甲方应向乙方支付职工停车费 | 6,273,861.50 | 含估算
                综上：电费按实测分区测算。
                阳光海天智能科技集团有限公司
                （北京阳光海天停车管理有限公司）
                """
            )
        )
        let xml = DOCXDocumentWriter.documentXML(for: draft)
        XCTAssertTrue(xml.contains("<w:tbl>"))
        XCTAssertTrue(xml.contains("<w:tblGrid>"))
        XCTAssertTrue(xml.contains("<w:tr>"))
        XCTAssertTrue(xml.contains("<w:tc>"))
        XCTAssertTrue(xml.contains("561,930.00"))
        XCTAssertTrue(xml.contains("3,685,344.00"))
        XCTAssertTrue(xml.contains("w:pStyle w:val=\"Title\""))
        XCTAssertTrue(xml.contains("w:pStyle w:val=\"Heading1\""))
        XCTAssertTrue(xml.contains("w:jc w:val=\"right\""))
        XCTAssertTrue(xml.contains("阳光海天智能科技集团有限公司"))
        XCTAssertFalse(xml.contains("2022年 | 561,930.00"))
        XCTAssertFalse(xml.contains("1 | 乙方应缴纳停车场电费"))
        XCTAssertFalse(xml.contains("任务卡"))
        XCTAssertFalse(xml.contains("DeepSeek"))
        XCTAssertFalse(xml.contains("润色稿"))
        XCTAssertFalse(xml.contains("## "))
        XCTAssertFalse(xml.contains("抬头与背景"))
    }

    func testPolishStripsReintroducedBannedPhrases() {
        let draft = parkingDraft(body: """
        2022年 | 561,930.00 | 确认金额
        《合同》第九条第七款
        2018年9月1日
        """)
        let dirty = """
        ## 职工停车费
        已锁定2022年 | 561,930.00 | 确认金额。第九条第七款。2018年9月1日。
        """
        let result = DocumentGenerator().polishWording(draft, polishedMarkdown: dirty)
        XCTAssertTrue(result.generatorLabel.contains("DeepSeek"))
        XCTAssertTrue(result.sections[0].body.contains("561,930.00"))
        XCTAssertFalse(result.sections[0].body.contains("已锁定"))
    }

    func testFeeReportPolishMessagesIncludeGoldStyleAndLocks() {
        let draft = parkingDraft(body: "2022年 | 561,930.00 |\n第九条第七款\n2018年9月1日")
        let messages = GroundedLLM.polishMessages(draft: draft)
        let joined = messages.map(\.content).joined(separator: "\n")
        XCTAssertTrue(GroundedLLM.isFeeReportDraft(draft))
        XCTAssertTrue(joined.contains("561,930.00"))
        XCTAssertTrue(joined.contains("第九条第七款"))
        XCTAssertTrue(joined.contains("2018年9月1日"))
        XCTAssertTrue(joined.contains("禁止重算") || joined.contains("硬锁"))
        XCTAssertTrue(joined.contains("任务卡"))
        XCTAssertTrue(joined.contains("致河南省人民医院"))
        XCTAssertFalse(joined.contains("sk-"))
    }

    private func parkingDraft(body: String) -> DraftDocument {
        DraftDocument(
            id: UUID(),
            kind: .customReport,
            title: "关于停车场电费及职工停车费测算的报告",
            sections: [
                DraftSection(id: UUID(), heading: "职工停车费", body: body)
            ],
            generatedAt: Date(),
            generatorLabel: "函件测算报告",
            citations: []
        )
    }
}
