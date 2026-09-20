import Foundation

/// 乙方电费+停车费测算报告。只写律师会寄出的函件正文；金额仍只来自真表与已给参数。
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
        draft.generatorLabel = "函件测算报告"
        draft.citations = []
        draft.sections = [
            DraftSection(
                id: UUID(),
                heading: "测算依据",
                body: opening(inputs: inputs, brief: brief, ledgers: ledgers, zones: zones)
                    + "\n"
                    + basis(inputs: inputs, brief: brief, ledgers: ledgers, zones: zones, lightingText: lightingText)
            ),
            DraftSection(
                id: UUID(),
                heading: "停车场电费测算",
                body: electricity(brief: brief, zones: zones, lightingText: lightingText)
            ),
            DraftSection(id: UUID(), heading: "职工停车费", body: parking(brief: brief, ledgers: ledgers)),
            DraftSection(
                id: UUID(),
                heading: "测算结论",
                body: conclusion(brief: brief, ledgers: ledgers, zones: zones, generatedAt: draft.generatedAt ?? Date())
            )
        ]
        return draft
    }

    private static func shortCaseName(_ title: String) -> String {
        if title.contains("阜外") { return "阜外华中心血管病医院地下停车场项目" }
        return title
    }

    private static func opening(
        inputs: StructuredCaseInputs,
        brief: BriefCard,
        ledgers: [ParkingYearLedger],
        zones: [LightingZone]
    ) -> String {
        let addressee = BriefFacts.addressee(in: brief.sourceMessage) ?? "贵院"
        var lines = ["致\(addressee)："]
        let source = brief.sourceMessage
        let haitian = BriefFacts.isHaitianParkingCase(inputs: inputs, brief: brief)
        if haitian, let term = BriefFacts.managementTerm(in: source) {
            let contract = BriefFacts.contractFullName(in: source) ?? "《合同》"
            lines.append("我司北京阳光海天停车管理有限公司（后经名称变更，现为阳光海天智能科技集团有限公司）于2018年与贵院签订\(contract)（以下简称“《合同》”），约定由我司投资建设并受托经营管理阜外华中心血管病医院地下停车场，委托经营管理期限为\(term.years)年，自\(term.start)起至\(term.end)止。")
            let installConsult = source.contains("2026年8月16日") ? "2026年8月16日" : (zones.first?.installDate ?? "现场测定日期")
            let lightingName = lightingTableTitle(inputs: inputs)
            let yearLo = ledgers.first?.year ?? 2022
            let yearHi = ledgers.last?.year ?? 2026
            var second = "合作期间，"
            if source.contains("共用计量") || source.contains("共用计量回路") {
                second += "因医院用电与停车场用电共用计量回路、难以区分，双方经协商于\(installConsult)在停车场照明区域单独加装电能计量表并实测计量，形成《\(lightingName)》"
            } else if !zones.isEmpty {
                second += "双方在停车场照明区域单独加装电能计量表并实测计量，形成《\(lightingName)》"
            } else {
                second += "双方就停车场照明用电进行实测"
            }
            second += "；同时，双方按月、按季度形成了\(yearLo)年至\(yearHi)年度《阜外华中心血管病医院职工地下停车场停车信息确认表》及对应明细记录。为客观、完整地结算合作期间相关费用，乙方依据《合同》约定及上述实测数据，对合作期间乙方应缴纳的停车场电费、以及甲方应向乙方支付的职工停车费进行测算，形成本报告。"
            lines.append(second)
        } else {
            lines.append("现就合作期间停车场电费及职工停车费测算情况报告如下。")
        }
        return FeeReportVoice.sanitize(lines.joined(separator: "\n"))
    }

    private static func basis(
        inputs: StructuredCaseInputs,
        brief: BriefCard,
        ledgers: [ParkingYearLedger],
        zones: [LightingZone],
        lightingText: String
    ) -> String {
        var lines = ["（一）合同约定"]
        let clauses = BriefFacts.contractClauses(in: brief.sourceMessage)
        if clauses.isEmpty {
            lines.append("费用结算条款以双方签署的《合同》为准。")
        } else {
            lines += clauses
        }

        lines.append("（二）事实依据")
        let lightingName = lightingTableTitle(inputs: inputs)
        if zones.isEmpty, lightingText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            lines.append("1、停车场照明用电测算材料待双方核对后列示分区读数。")
        } else {
            let install = zones.compactMap(\.installDate).first ?? "现场安装日"
            let copy = zones.compactMap(\.copyDate).first ?? "现场抄表日"
            lines.append("1、《\(lightingName)》：\(install)，经双方人员现场确认，在停车场负一层、负二层共\(zones.count)处照明区域加装电表并记录安装读数；\(copy)，双方现场抄表并记录抄表读数。")
        }
        if brief.sourceMessage.contains("审计资料及停车信息确认表") || brief.sourceMessage.contains("2026.8.25") {
            lines.append("2、阳光海天审计资料及停车信息确认表（2026.8.25）：包含2022年至2026年各季度《职工地下停车场停车信息确认表》及逐月停车记录。")
            if !ledgers.isEmpty {
                let lo = ledgers.first!.year
                let hi = ledgers.last!.year
                lines.append("3、\(lo)年至\(hi)年《阜外华中心血管病医院职工停车信息表》：载明各年度、各月份职工停车费明细及年度汇总金额。")
            }
        } else if ledgers.isEmpty {
            lines.append("2、职工停车信息确认表待双方核对后列示各年金额。")
        } else {
            let lo = ledgers.first!.year
            let hi = ledgers.last!.year
            lines.append("2、\(lo)年至\(hi)年《职工停车信息表》：载明各年度、各月份职工停车费明细及年度汇总金额。")
        }
        return FeeReportVoice.sanitize(lines.joined(separator: "\n"))
    }

    private static func electricity(brief: BriefCard, zones: [LightingZone], lightingText: String) -> String {
        var lines = ["测量概况和实测数据"]
        let source = brief.sourceMessage
        let avg = LightingMeasurementParser.averageWatts(of: zones)
        let counts = BriefFacts.lampCounts(in: source)
        let p = BriefFacts.referencePrice(in: source)

        if zones.isEmpty {
            if lightingText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                lines.append("照明实测读数待双方确认后补列，电费金额暂不填写。")
            } else {
                lines.append(String(lightingText.prefix(800)))
            }
        } else {
            var overview = ""
            if let install = zones.compactMap(\.installDate).first {
                overview += "\(install)，"
            }
            if source.contains("陈金营") || source.contains("刘林学") {
                overview += "经甲方委托第三方参加，乙方有陈金营和刘林学参加，"
            } else {
                overview += "经双方人员现场确认，"
            }
            overview += zoneInstallNarrative(zones)
            if source.contains("拆除") || source.contains("其他耗电") || source.contains("其他负荷") {
                overview += "因地下室照明线路上还连接监控、电梯间照明、餐厅灯箱、消防应急用电等负荷，选定支路后排查并拆除该支路上连接的其他耗电设备。"
            }
            if lightingText.contains("车流量密集") || source.contains("车流量密集") {
                overview += "本次测量区域均为停车场车流量密集、人员流动较大区域。"
            }
            if let start = zones.compactMap(\.installDate).first, let end = zones.compactMap(\.copyDate).first {
                overview += "从\(shortMonthDay(start))到\(shortMonthDay(end))"
                if start.contains("8月17") && end.contains("9月16") {
                    overview += "共计30天整，"
                } else {
                    overview += "，"
                }
            }
            if let avg {
                overview += "平均每个灯能耗是\(ReportNumber.plain(avg, decimals: 2))瓦"
            }
            if let b1 = counts.b1 { overview += "，目前负一层有照明灯\(b1)个" }
            if let b2 = counts.b2 { overview += "，负二层有照明灯\(b2)个" }
            if let n = counts.total {
                overview += "，两层照明灯共计\(n)个"
            }
            if let avg, let n = counts.total {
                let kw = avg * Decimal(n) / 1000
                overview += "，每小时用电量为\(ReportNumber.plain(kw, decimals: 4))千瓦（\(n)×\(ReportNumber.plain(avg, decimals: 2))=\(ReportNumber.plain(avg * Decimal(n), decimals: 1))W）。"
            } else if !overview.hasSuffix("。") && !overview.hasSuffix("，") {
                overview += "。"
            } else if overview.hasSuffix("，") {
                overview = String(overview.dropLast()) + "。"
            }
            lines.append(overview)

            if let p {
                lines.append("平均电价按\(ReportNumber.plain(p, decimals: 2))元/度，最终以双方确认单价为准。")
            } else {
                lines.append("参考电价待双方确认后，再列合作期间电费总额。")
            }

            if let avg, let n = counts.total, let p {
                let kw = avg * Decimal(n) / 1000
                let periods = BriefFacts.electricityPeriods(in: source)
                var fees: [Decimal] = []
                for period in periods {
                    guard let days = period.statedDays else { continue }
                    let kwh = kw * 24 * Decimal(days)
                    let fee = kwh * p
                    fees.append(fee)
                    lines.append("从\(period.startText)至\(period.endText)共\(days)天，电量\(ReportNumber.plain(kwh, decimals: 4))度，电费\(ReportNumber.money(fee))元。")
                }
                if fees.count == periods.count, !fees.isEmpty {
                    let total = fees.reduce(0, +)
                    let feeTexts = fees.map { ReportNumber.money($0) + "元" }.joined(separator: "+")
                    lines.append("则自\(periods.first!.startText)至\(periods.last!.endText)电费总数测算为\(feeTexts)=\(ReportNumber.money(total))元。")
                }
            }

            lines.append("双方记载测量数据如下：")
            for (index, zone) in zones.enumerated() {
                var head = "\(index + 1)、\(zone.displayName)"
                if let lamps = zone.lampCount, !zone.displayName.contains("个灯") {
                    head += "（\(lamps)个灯）"
                }
                lines.append(head)
                var detail = ""
                if let day = zone.installDate, let a = zone.installReading {
                    detail += "\(day)安装表度数\(ReportNumber.plain(a, decimals: 1))度"
                }
                if let day = zone.copyDate, let b = zone.copyReading {
                    if !detail.isEmpty { detail += "，" }
                    detail += "\(day)抄表度数\(ReportNumber.plain(b, decimals: 1))度"
                }
                if let kWh = zone.kWh {
                    if !detail.isEmpty { detail += "，" }
                    detail += "用电合计\(ReportNumber.plain(kWh, decimals: 1))度"
                }
                if let watts = zone.watts {
                    if !detail.isEmpty { detail += "，" }
                    detail += "每个灯\(ReportNumber.plain(watts, decimals: 2))瓦"
                }
                if !detail.isEmpty {
                    lines.append(detail + "。")
                }
            }
        }
        return FeeReportVoice.sanitize(lines.joined(separator: "\n"))
    }

    private static func parking(brief: BriefCard, ledgers: [ParkingYearLedger]) -> String {
        var lines = ["（一）计费方式"]
        let clauses = BriefFacts.contractClauses(in: brief.sourceMessage)
        if let feeClause = clauses.first(where: { $0.contains("3元") || $0.contains("职工停车") }) {
            lines.append(feeClause)
        }
        if let evolution = BriefFacts.billingEvolution(in: brief.sourceMessage) {
            lines.append(evolution)
            lines.append("上述计费方式即以合同约定单价3元/车/天，乘以各日职工停车车次（及按停留天数折算的停车天数）计算得出。")
        } else if clauses.isEmpty {
            lines.append("职工停车收费按双方确认的停车信息表金额列示。")
        }

        lines.append("（二）各年度职工停车费明细")
        if ledgers.isEmpty {
            lines.append("各年度职工停车费金额待停车信息确认表核对后列示。")
            return FeeReportVoice.sanitize(lines.joined(separator: "\n"))
        }

        lines.append("年度 | 金额（元） | 说明")
        var confirmed: [(Int, Decimal)] = []
        for ledger in ledgers {
            if let amount = ledger.reportedAmount {
                confirmed.append((ledger.year, amount))
                lines.append("\(ledger.year)年 | \(ReportNumber.money(amount)) | \(ledger.note)")
            } else {
                lines.append("\(ledger.year)年 | （待确认） | \(ledger.note)")
            }
        }

        let y2022_2025 = confirmed.filter { (2022...2025).contains($0.0) }
        if y2022_2025.count == 4 {
            let subtotal = y2022_2025.map(\.1).reduce(0, +)
            lines.append("小计（2022—2025年） | \(ReportNumber.money(subtotal)) | —")
            if let y2026 = confirmed.first(where: { $0.0 == 2026 }) {
                lines.append("累计（截至2026年7月） | \(ReportNumber.money(subtotal + y2026.1)) | —")
            }
        }

        if BriefFacts.allowsPriorYearEstimate(in: brief.sourceMessage), y2022_2025.count == 4 {
            let subtotal = y2022_2025.map(\.1).reduce(0, +)
            let monthly = subtotal / 48
            let prior = monthly * 40
            var sentence = "2018年9月1日至2021年期间停车费参照2022–2025年已确认金额\(ReportNumber.money(subtotal))元按48个月月均摊，月均\(ReportNumber.money(monthly))元，按40个月计\(ReportNumber.money(prior))元。"
            if let y2026 = confirmed.first(where: { $0.0 == 2026 }) {
                let grand = prior + subtotal + y2026.1
                sentence += "则2018年9月1日至2026年7月停车费共计\(ReportNumber.money(prior))+\(ReportNumber.money(subtotal))+\(ReportNumber.money(y2026.1))=\(ReportNumber.money(grand))元。"
            }
            lines.append(sentence)
        }
        return FeeReportVoice.sanitize(lines.joined(separator: "\n"))
    }

    private static func conclusion(
        brief: BriefCard,
        ledgers: [ParkingYearLedger],
        zones: [LightingZone],
        generatedAt: Date
    ) -> String {
        var lines = ["测算结论汇总"]
        lines.append("序号 | 费用项目 | 测算结果（元） | 说明")

        let source = brief.sourceMessage
        let p = BriefFacts.referencePrice(in: source)
        let n = BriefFacts.lampCounts(in: source).total
        let avg = LightingMeasurementParser.averageWatts(of: zones)
        let periods = BriefFacts.electricityPeriods(in: source)
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
        if let electricityTotal, let p {
            lines.append("1 | 乙方应缴纳停车场电费 | \(ReportNumber.money(electricityTotal)) | 按参考电价\(ReportNumber.plain(p, decimals: 2))元/度测算，最终以双方确认单价为准")
        } else {
            lines.append("1 | 乙方应缴纳停车场电费 | （待补） | 参考电价待双方确认后列示总额")
        }

        let confirmed = ledgers.compactMap { ledger -> (Int, Decimal)? in
            guard let amount = ledger.reportedAmount else { return nil }
            return (ledger.year, amount)
        }
        let y2022_2025 = confirmed.filter { (2022...2025).contains($0.0) }
        var parkingNote = "以双方确认的各年停车费金额为准"
        var parkingTotal: Decimal?
        if y2022_2025.count == 4 {
            let subtotal = y2022_2025.map(\.1).reduce(0, +)
            parkingTotal = subtotal
            if let y2026 = confirmed.first(where: { $0.0 == 2026 }) {
                parkingTotal = subtotal + y2026.1
                parkingNote = "其中2022—2025年\(ReportNumber.money(subtotal))元，2026年1—7月\(ReportNumber.money(y2026.1))元"
            }
            if BriefFacts.allowsPriorYearEstimate(in: source) {
                let prior = subtotal / 48 * 40
                parkingTotal = (parkingTotal ?? 0) + prior
                parkingNote += "，2018年3月16日至2021年\(ReportNumber.money(prior))元"
            }
        }
        if let parkingTotal {
            lines.append("2 | 甲方应向乙方支付职工停车费 | \(ReportNumber.money(parkingTotal)) | \(parkingNote)")
        } else {
            lines.append("2 | 甲方应向乙方支付职工停车费 | （待补） | 各年确认金额待列")
        }

        var summary = "综上：按本报告口径测算，"
        if let electricityTotal {
            summary += "合作期间乙方应缴纳的停车场照明电费约为\(ReportNumber.money(electricityTotal))元（以最终确认的电费单价为准）"
        } else {
            summary += "停车场照明电费待双方确认电价后列示"
        }
        if let parkingTotal {
            summary += "；甲方应向乙方支付的职工停车费，截至2026年7月累计为\(ReportNumber.money(parkingTotal))元。"
        } else {
            summary += "。"
        }
        lines.append(summary)

        if source.contains("海天") || source.contains("阳光海天") {
            lines.append("阳光海天智能科技集团有限公司")
            lines.append("（北京阳光海天停车管理有限公司）")
        }
        lines.append(FeeReportVoice.letterDate(generatedAt))
        return FeeReportVoice.sanitize(lines.joined(separator: "\n"))
    }

    private static func lightingTableTitle(inputs: StructuredCaseInputs) -> String {
        let name = inputs.texts.map(\.locator.relativePath)
            .first(where: { $0.contains("测算") || $0.contains("照明") })
            .map { ($0 as NSString).lastPathComponent } ?? "2026.9.16停车场照明用电测算表"
        return name
            .replacingOccurrences(of: "-新.docx", with: "")
            .replacingOccurrences(of: ".docx", with: "")
    }

    private static func zoneInstallNarrative(_ zones: [LightingZone]) -> String {
        let parts = zones.map { zone -> String in
            var place = zone.displayName
            if let lamps = zone.lampCount, !place.contains("个灯") {
                place += "（\(lamps)个灯）"
            }
            return "在\(place)安装电表一个"
        }
        if parts.isEmpty { return "在停车场照明区域加装电表。" }
        return parts.joined(separator: "；") + "。"
    }

    private static func shortMonthDay(_ date: String) -> String {
        if let range = date.range(of: #"\d{1,2}月\d{1,2}日"#, options: .regularExpression) {
            return String(date[range])
        }
        return date
    }
}
