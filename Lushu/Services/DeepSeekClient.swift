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

    /// 金标准函件体：只学连接语气。数字、条号、日期一律以本地骨架为准。
    static let feeReportStyleNotes = """
    你只改函件连接词与句序，禁止从零起草，禁止重算电费或停车费。
    硬锁：每一个数字、金额（含千分位与小数位）、合同条号、日历日期必须原样出现；改一个即整篇作废。
    禁止出现并须删掉：任务卡、结构化、本地组装、已锁定、未入库、不编造、不假装、已粘贴、转写、汇总页、不编行、已写明、DeepSeek、润色稿、抬头与背景、测算步骤：、本稿、案件包、委托对照范围。
    正文只保留律师会寄给医院的函件：致××：、合同全称与期限、装表与确认表、电费叙事、停车费计费沿革、结论与落款。
    按原章节标题输出 Markdown（## 测算依据 / ## 停车场电费测算 / ## 职工停车费 / ## 测算结论）。不要输出「## 抬头与背景」。表格行保留「列 | 列 | 列」。
    """

    static let goldStyleExcerpt = """
    致河南省人民医院：
    我司名称变更及《合同》委托经营管理期限写在函首，接着说明共用计量回路、加装电表与停车确认表，再写「形成本报告」。
    （一）合同约定只列《合同》原条。
    （二）事实依据列测算表现场确认日期与停车信息确认表。
    电费先写装表人员、拆除其他负荷与分区抄表，再写分段电费，不用工程师公式行。
    停车费写2022年与2023年3月计费沿革，缺年只用一句估算方法。
    综上之后落款公司名称一次，日期一行。
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
