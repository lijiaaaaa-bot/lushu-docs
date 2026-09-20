import Foundation

enum DeepSeekError: LocalizedError {
    case missingKey
    case badURL
    case http(Int, String)
    case emptyReply

    var errorDescription: String? {
        switch self {
        case .missingKey:
            return "未找到 DeepSeek 密钥。请到设置粘贴并保存到钥匙串。"
        case .badURL:
            return "DeepSeek 接口地址无效。"
        case .http(let code, let body):
            return "DeepSeek 请求失败（\(code)）：\(body.prefix(160))"
        case .emptyReply:
            return "DeepSeek 没有返回正文。未改写本地稿。"
        }
    }
}

/// OpenAI 兼容 chat/completions。思考链关闭。密钥只从钥匙串读取。
struct DeepSeekClient {
    static let defaultEndpoint = URL(string: "https://api.deepseek.com/chat/completions")!
    static let defaultModel = "deepseek-chat"

    var endpoint: URL = defaultEndpoint
    var model: String = defaultModel
    var session: URLSession = .shared

    func complete(messages: [DeepSeekChatMessage], key: String) async throws -> String {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw DeepSeekError.missingKey }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(trimmed)", forHTTPHeaderField: "Authorization")
        request.httpBody = try Self.encodeRequest(model: model, messages: messages)
        request.timeoutInterval = 45

        let (data, response) = try await session.data(for: request)
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(code) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw DeepSeekError.http(code, body)
        }
        let decoded = try JSONDecoder().decode(DeepSeekResponse.self, from: data)
        let text = decoded.choices.first?.message.content?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if text.isEmpty { throw DeepSeekError.emptyReply }
        return text
    }

    static func encodeRequest(model: String, messages: [DeepSeekChatMessage]) throws -> Data {
        let payload = DeepSeekRequest(
            model: model,
            messages: messages,
            stream: false,
            thinking: DeepSeekThinking(type: "disabled")
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(payload)
    }
}

struct DeepSeekChatMessage: Codable, Hashable {
    var role: String
    var content: String
}

struct DeepSeekThinking: Codable, Hashable {
    var type: String
}

struct DeepSeekRequest: Codable, Hashable {
    var model: String
    var messages: [DeepSeekChatMessage]
    var stream: Bool
    var thinking: DeepSeekThinking
}

struct DeepSeekResponse: Codable {
    var choices: [Choice]

    struct Choice: Codable {
        var message: Message
    }

    struct Message: Codable {
        var content: String?
    }
}

enum GroundedLLM {
    static let systemPrompt = """
    你是律书的撰稿助手，不是通用闲聊。只能复述用户已写要点、已锁定真表读数，以及由这些数字算出的电费/停车费。
    禁止编造法条、未出现的合同条号、未读出的年份金额、未写明的电价P或灯数N。
    已测算数字必须原样保留。不得新增 LegalCitation。思考链关闭，只给正文。
    """

    /// 金标准函件体：只学语气与过渡。数字、条号、日期一律以本地骨架为准。
    static let feeReportStyleNotes = """
    骨架已由本地测算器写好，你只改律师函件语气，禁止从零起草，禁止重算电费或停车费。
    硬锁：每一个数字、金额（含千分位与小数位）、合同条号、日历日期必须在正文中原样出现；改一个即整篇作废。
    删掉「任务卡」「结构化」「本地组装」「已锁定」「本稿」等系统口吻。
    语气接近金标准：标题后「致××：」，用「现就……报告如下」「则」「另」过渡；依据分（一）合同约定（二）事实依据；电费先概况再分区再分段；停车费先计费再年度表再缺年；结论用汇总表 +「综上」+ 乙方落款。
    按原章节标题输出 Markdown（## 抬头与背景 / ## 测算依据 / ## 停车场电费 / ## 职工停车费 / ## 测算结论）。表格行保留「列 | 列 | 列」格式。
    """

    static let goldStyleExcerpt = """
    致贵院：
    现就合作期间停车场电费及职工停车费测算情况报告如下。
    （一）合同约定。已粘贴条款按《合同》原条号转写，不另造条号。
    （二）事实依据。现场加装电表抄录分区读数；职工停车费以各年确认表汇总金额为准，缺年不编行。
    测量概况之后列分区实测，再按已给参数分段测算，段间用「则」「另」。
    综上，电费按参考电价列示、最终以双方确认为准；停车费只加总已读出金额。
    """

    static func replyMessages(card: BriefCard, grounded: String) -> [DeepSeekChatMessage] {
        [
            DeepSeekChatMessage(role: "system", content: systemPrompt),
            DeepSeekChatMessage(
                role: "user",
                content: """
                请把下面的本地任务卡回执改得更顺口，不要增加任何事实或数字。
                立场：\(card.stance.title)
                目的：\(card.documentPurpose)
                范围：\(card.yearsScope)
                缺口：\(card.missingFacts.joined(separator: "、"))
                ——
                \(grounded)
                """
            )
        ]
    }

    static func polishMessages(draft: DraftDocument) -> [DeepSeekChatMessage] {
        if isFeeReportDraft(draft) {
            return feeReportPolishMessages(draft: draft)
        }
        return [
            DeepSeekChatMessage(role: "system", content: systemPrompt),
            DeepSeekChatMessage(
                role: "user",
                content: """
                只改函件措辞，保留全部已写事实、真表金额、测算公式与缺口原句。不要补数字或未粘贴的合同条号。
                按原章节标题输出 Markdown。

                \(draft.markdown)
                """
            )
        ]
    }

    static func feeReportPolishMessages(draft: DraftDocument) -> [DeepSeekChatMessage] {
        let locks = NumberLock.lockedTokens(in: NumberLock.lockSource(of: draft)).joined(separator: "、")
        return [
            DeepSeekChatMessage(role: "system", content: systemPrompt + "\n" + feeReportStyleNotes),
            DeepSeekChatMessage(
                role: "user",
                content: """
                【金标准语气（只学写法，数字以骨架为准，勿抄未出现的金额）】
                \(goldStyleExcerpt)

                【必须原样保留】
                \(locks)

                【本地骨架，只改措辞】
                \(draft.markdown)
                """
            )
        ]
    }

    static func isFeeReportDraft(_ draft: DraftDocument) -> Bool {
        draft.kind == .customReport && draft.sections.contains(where: {
            $0.heading.contains("测算") || $0.heading.contains("电费") || $0.heading.contains("停车")
        })
    }

    static let missingKeyHint = "DeepSeek 密钥未保存。本地任务卡与结构化落稿仍可用。请到设置粘贴 DeepSeek API Key（只进钥匙串，与剧本工厂相同）。"
}
