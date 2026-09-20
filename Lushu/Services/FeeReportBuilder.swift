import Foundation

/// 乙方电费+停车费测算报告。读真表金额与测算原文，不把材料清单当正文。
enum FeeReportBuilder {
    static func isFeeReport(brief: BriefCard, kind: DocumentKind) -> Bool {
        guard kind == .customReport else { return false }
        let text = brief.sourceMessage + brief.documentPurpose
        let fee = text.contains("电费") || text.contains("停车") || text.contains("测算")
        return fee && (text.contains("报告") || text.contains("专项"))
    }

    static func build(inputs: StructuredCaseInputs, brief: BriefCard) -> DraftDocument {
        let source = brief.sourceMessage
        let ledgers = ParkingLedgerReader.read(tables: inputs.tables)
        let lightingText = inputs.texts.map(\.text).joined(separator: "\n")
        let zones = LightingMeasurementParser.zones(in: lightingText)
        let title = BriefFacts.reportTitle(
            in: source,
            fallback: "关于\(shortCaseName(inputs.caseTitle))停车场电费及职工停车费测算的报告"
        )

        var draft = DraftDocument.blankSummary(caseTitle: inputs.caseTitle)
        draft.kind = .customReport
        draft.title = title
        draft.generatedAt = Date()
        draft.generatorLabel = "结构化测算报告 · 本地组装"
        draft.citations = []
        draft.sections = [
            DraftSection(id: UUID(), heading: "抬头与背景", body: opening(inputs: inputs, brief: brief)),
            DraftSection(id: UUID(), heading: "测算依据", body: basis(inputs: inputs, brief: brief, ledgers: ledgers, zones: zones)),
            DraftSection(id: UUID(), heading: "停车场电费", body: electricity(brief: brief, zones: zones, lightingText: lightingText)),
            DraftSection(id: UUID(), heading: "职工停车费", body: parking(brief: brief, ledgers: ledgers)),
            DraftSection(id: UUID(), heading: "测算结论", body: conclusion(brief: brief, ledgers: ledgers, zones: zones))
        ]
        return draft
    }

    private static func shortCaseName(_ title: String) -> String {
        if title.contains("阜外") { return "阜外华中心血管病医院地下停车场项目" }
        return title
    }

    private static func opening(inputs: StructuredCaseInputs, brief: BriefCard) -> String {
        let addressee = BriefFacts.addressee(in: brief.sourceMessage) ?? "贵院"
        var lines = ["致\(addressee)："]
        lines.append("现按\(brief.stance.title)立场，依据案件包内已锁定的职工停车信息表与停车场照明用电测算材料，就停车场电费及职工停车费进行测算，形成本报告。")
        if !brief.yearsScope.isEmpty {
            lines.append("委托对照范围：\(brief.yearsScope)。未入库年份不编造行金额。")
        }
        if inputs.caseTitle.contains("海天") || brief.sourceMessage.contains("海天") {
            lines.append("乙方为阳光海天／北京阳光海天停车管理有限公司（以任务卡已写名称为准）。")
        }
        return lines.joined(separator: "\n")
    }

    private static func basis(
        inputs: StructuredCaseInputs,
        brief: BriefCard,
        ledgers: [ParkingYearLedger],
        zones: [LightingZone]
    ) -> String {
        var lines = ["（一）合同约定"]
        let clauses = BriefFacts.contractClauses(in: brief.sourceMessage)
        if clauses.isEmpty {
            lines.append("案件包未收入合同.pdf。任务卡亦未粘贴合同条款，本节不编造条文号。")
        } else {
            lines.append("以下仅转写任务卡已粘贴条款，未另造条号：")
            lines += clauses.map { $0 }
        }

        lines.append("（二）事实依据")
        let lightingNames = inputs.texts.map(\.locator.relativePath).filter { $0.contains("测算") || $0.contains("照明") }
        if lightingNames.isEmpty, zones.isEmpty {
            lines.append("1、照明测算材料尚未锁定。")
        } else {
            let name = lightingNames.first.map { ($0 as NSString).lastPathComponent } ?? "停车场照明用电测算表"
            lines.append("1、《\(name)》：四区现场加装电表并抄表，本稿只采用已提取的分区读数与灯具功率。")
        }
        if ledgers.isEmpty {
            lines.append("2、职工停车信息表尚未读出汇总金额。")
        } else {
            let years = ledgers.map { "\($0.year)年" }.joined(separator: "、")
            lines.append("2、\(years)《职工停车信息表》汇总页：载明各月金额及年度合计（有则用之）。")
        }
        if brief.sourceMessage.contains("审计") && brief.sourceMessage.contains("未入库") {
            lines.append("3、审计件未入库，不假装已读。")
        }
        return lines.joined(separator: "\n")
    }

    private static func electricity(brief: BriefCard, zones: [LightingZone], lightingText: String) -> String {
        var lines = ["测量概况和实测数据"]
        if zones.isEmpty {
            if lightingText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                lines.append("结构化文本中没有照明测算原文。本章仍保留，电费金额待补。")
            } else {
                lines.append(String(lightingText.prefix(800)))
            }
        } else {
            lines.append("测算表记录四区实测如下：")
            for (index, zone) in zones.enumerated() {
                var detail = "\(index + 1)、\(zone.name)"
                if let lamps = zone.lampCount { detail += "（\(lamps)个灯）" }
                if let watts = zone.watts { detail += "，每个灯\(ReportNumber.plain(watts, decimals: 2))瓦" }
                if let kWh = zone.kWh { detail += "，用电合计\(ReportNumber.plain(kWh, decimals: 1))度" }
                if let a = zone.installReading, let b = zone.copyReading {
                    detail += "（安装\(ReportNumber.plain(a, decimals: 1))度 / 抄表\(ReportNumber.plain(b, decimals: 1))度）"
                }
                lines.append(detail)
            }
        }

        let avg = LightingMeasurementParser.averageWatts(of: zones)
        if let avg {
            lines.append("四区平均每个灯\(ReportNumber.plain(avg, decimals: 2))瓦。")
        }

        let counts = BriefFacts.lampCounts(in: brief.sourceMessage)
        if let b1 = counts.b1 { lines.append("任务卡写明负一层照明灯\(b1)个。") }
        if let b2 = counts.b2 { lines.append("任务卡写明负二层照明灯\(b2)个。") }
        let n = counts.total
        let p = BriefFacts.referencePrice(in: brief.sourceMessage)
        if let n { lines.append("任务卡写明全场灯数N=\(n)。") }

        lines.append("测算步骤：小时用电量（千瓦）= 平均功率（瓦）× 灯数N ÷ 1000；电量（度）= 小时用电量 × 24 × 天数；电费（元）= 电量 × 参考电价P。")

        if let p {
            lines.append("任务卡给出参考电价P=\(ReportNumber.plain(p, decimals: 2))元/度，最终以双方确认为准。")
        } else {
            lines.append("参考电价P未在任务卡写明，电费金额留空，不套行业经验值。")
        }

        if let avg, let n, let p {
            let kw = avg * Decimal(n) / 1000
            lines.append("每小时用电量=\(ReportNumber.plain(avg, decimals: 2))×\(n)÷1000=\(ReportNumber.plain(kw, decimals: 4))千瓦。")
            let periods = BriefFacts.electricityPeriods(in: brief.sourceMessage)
            var fees: [Decimal] = []
            if periods.isEmpty {
                lines.append("任务卡未写明测算起止日与天数，跨期电费总额待补。")
            } else {
                for period in periods {
                    guard let days = period.statedDays else {
                        lines.append("\(period.startText)至\(period.endText)：天数未写明，该段电费留空。")
                        continue
                    }
                    let kwh = kw * 24 * Decimal(days)
                    let fee = kwh * p
                    fees.append(fee)
                    lines.append("\(period.startText)至\(period.endText)共\(days)天：电量\(ReportNumber.plain(kwh, decimals: 4))度，电费\(ReportNumber.money(fee))元。")
                }
                if fees.count == periods.count, !fees.isEmpty {
                    let total = fees.reduce(0, +)
                    lines.append("则合作期间停车场电费测算合计\(ReportNumber.money(total))元（参考电价，以双方确认为准）。")
                }
            }
        } else if p == nil || n == nil {
            lines.append("缺灯数N或参考电价P时，只列实测分区与公式，不填跨期电费总额。")
        }
        return lines.joined(separator: "\n")
    }

    private static func parking(brief: BriefCard, ledgers: [ParkingYearLedger]) -> String {
        var lines = ["（一）计费方式"]
        let clauses = BriefFacts.contractClauses(in: brief.sourceMessage)
        if let feeClause = clauses.first(where: { $0.contains("3元") || $0.contains("职工停车") }) {
            lines.append(feeClause)
        } else {
            lines.append("停车费以各年职工停车信息表汇总页「金额」列为准，不另估单价。")
        }
        lines.append("（二）各年度职工停车费明细")
        if ledgers.isEmpty {
            lines.append("案件包内没有可读的停车费汇总页，不能填写年度金额。")
            return lines.joined(separator: "\n")
        }

        lines.append("年度 | 金额（元） | 说明")
        var confirmed: [(Int, Decimal)] = []
        for ledger in ledgers {
            if let amount = ledger.reportedAmount {
                confirmed.append((ledger.year, amount))
                lines.append("\(ledger.year)年 | \(ReportNumber.money(amount)) | \(ledger.note)")
            } else {
                lines.append("\(ledger.year)年 | （汇总页未填） | \(ledger.note)")
            }
        }

        let y2022_2025 = confirmed.filter { (2022...2025).contains($0.0) }
        if y2022_2025.count == 4 {
            let subtotal = y2022_2025.map(\.1).reduce(0, +)
            lines.append("小计（2022—2025年） | \(ReportNumber.money(subtotal)) | —")
            if let y2026 = confirmed.first(where: { $0.0 == 2026 }) {
                lines.append("累计（截至2026年已填月份） | \(ReportNumber.money(subtotal + y2026.1)) | 仅加总已读出年份")
            }
        }

        let missing = BriefCardParser.yearGaps(requested: brief.yearsScope, tables: ledgers.map {
            StructuredTableRef(
                id: UUID(),
                filename: $0.filename,
                relativePath: $0.filename,
                fileURL: URL(fileURLWithPath: "/"),
                schema: TableSchema(sheetName: "汇总", columns: []),
                isLocked: true
            )
        })
        if !missing.isEmpty {
            lines.append("范围 \(brief.yearsScope) 中缺失、不编行金额：\(missing.joined(separator: "、"))。")
        }

        if BriefFacts.allowsPriorYearEstimate(in: brief.sourceMessage), y2022_2025.count == 4 {
            let subtotal = y2022_2025.map(\.1).reduce(0, +)
            let monthly = subtotal / 48
            let prior = monthly * 40
            lines.append("2018–2021年停车表不在包内。任务卡已写明估算方法：参照2022–2025年已确认小计\(ReportNumber.money(subtotal))元按48个月月均摊，月均\(ReportNumber.money(monthly))元；按40个月计\(ReportNumber.money(prior))元。")
            if let y2026 = confirmed.first(where: { $0.0 == 2026 }) {
                let grand = prior + subtotal + y2026.1
                lines.append("则2018年9月至2026年已填月份停车费共计\(ReportNumber.money(prior))+\(ReportNumber.money(subtotal))+\(ReportNumber.money(y2026.1))=\(ReportNumber.money(grand))元。")
            }
        } else if !missing.isEmpty {
            lines.append("2018–2021年未写明估算方法，故只列缺口，不补金额。")
        }
        return lines.joined(separator: "\n")
    }

    private static func conclusion(brief: BriefCard, ledgers: [ParkingYearLedger], zones: [LightingZone]) -> String {
        var lines = ["表  测算结论汇总"]
        lines.append("序号 | 费用项目 | 测算结果（元） | 说明")

        let p = BriefFacts.referencePrice(in: brief.sourceMessage)
        let n = BriefFacts.lampCounts(in: brief.sourceMessage).total
        let avg = LightingMeasurementParser.averageWatts(of: zones)
        let periods = BriefFacts.electricityPeriods(in: brief.sourceMessage)
        var electricityTotal: Decimal?
        if let avg, let n, let p {
            let kw = avg * Decimal(n) / 1000
            let fees = periods.compactMap { period -> Decimal? in
                guard let days = period.statedDays else { return nil }
                return kw * 24 * Decimal(days) * p
            }
            if fees.count == periods.count, !fees.isEmpty {
                electricityTotal = fees.reduce(0, +)
            }
        }
        if let electricityTotal, p != nil {
            lines.append("1 | 乙方应缴纳停车场电费 | \(ReportNumber.money(electricityTotal)) | 按参考电价\(ReportNumber.plain(p!, decimals: 2))元/度测算，最终以双方确认单价为准")
        } else {
            lines.append("1 | 乙方应缴纳停车场电费 | （待补） | 分区实测已列；缺参考电价P或灯数N或天数时不填总额")
        }

        let confirmed = ledgers.compactMap { ledger -> (Int, Decimal)? in
            guard let amount = ledger.reportedAmount else { return nil }
            return (ledger.year, amount)
        }
        let y2022_2025 = confirmed.filter { (2022...2025).contains($0.0) }
        var parkingNote = "以汇总页已读出金额为准"
        var parkingTotal: Decimal?
        if y2022_2025.count == 4 {
            let subtotal = y2022_2025.map(\.1).reduce(0, +)
            parkingTotal = subtotal
            if let y2026 = confirmed.first(where: { $0.0 == 2026 }) {
                parkingTotal = subtotal + y2026.1
                parkingNote = "2022—2025年\(ReportNumber.money(subtotal))元，2026年已填月份\(ReportNumber.money(y2026.1))元"
            }
            if BriefFacts.allowsPriorYearEstimate(in: brief.sourceMessage) {
                let prior = subtotal / 48 * 40
                parkingTotal = (parkingTotal ?? 0) + prior
                parkingNote += "；2018–2021年按任务卡方法估算\(ReportNumber.money(prior))元"
            }
        }
        if let parkingTotal {
            lines.append("2 | 甲方应向乙方支付职工停车费 | \(ReportNumber.money(parkingTotal)) | \(parkingNote)")
        } else {
            lines.append("2 | 甲方应向乙方支付职工停车费 | （待补） | 汇总页尚未读出足够年份")
        }

        lines.append("综上：电费按实测分区与任务卡已给参数测算，参考电价须双方确认；停车费只加总汇总页已填金额，缺年不编行。")
        if brief.sourceMessage.contains("海天") {
            lines.append("阳光海天智能科技集团有限公司")
            lines.append("（北京阳光海天停车管理有限公司）")
        }
        return lines.joined(separator: "\n")
    }
}
