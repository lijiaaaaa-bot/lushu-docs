import Foundation

enum BriefStance: String, Codable, Hashable, CaseIterable {
    case plaintiff = "甲方"
    case defendant = "乙方"
    case neutral = "中立"

    var title: String { rawValue }
}

/// 从长要点解析出的任务卡。首页可暂存在 inbox，挂上 CasePack 后并入该案。
struct BriefCard: Identifiable, Hashable, Codable {
    var id: UUID
    var caseID: UUID
    var stance: BriefStance
    var documentPurpose: String
    var requiredSections: [String]
    var calculationRules: [String]
    var yearsScope: String
    var extraConstraints: [String]
    var missingFacts: [String]
    var sourceMessage: String
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        caseID: UUID,
        stance: BriefStance = .neutral,
        documentPurpose: String = "",
        requiredSections: [String] = [],
        calculationRules: [String] = [],
        yearsScope: String = "",
        extraConstraints: [String] = [],
        missingFacts: [String] = [],
        sourceMessage: String = "",
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.caseID = caseID
        self.stance = stance
        self.documentPurpose = documentPurpose
        self.requiredSections = requiredSections
        self.calculationRules = calculationRules
        self.yearsScope = yearsScope
        self.extraConstraints = extraConstraints
        self.missingFacts = missingFacts
        self.sourceMessage = sourceMessage
        self.updatedAt = updatedAt
    }

    var isActionable: Bool {
        !sourceMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !documentPurpose.isEmpty
            || !requiredSections.isEmpty
    }

    var chips: [String] {
        var items = [stance.title]
        if !documentPurpose.isEmpty {
            items.append(String(documentPurpose.prefix(18)))
        }
        if !yearsScope.isEmpty {
            items.append(yearsScope)
        }
        for gap in missingFacts.prefix(4) {
            items.append("缺 \(gap)")
        }
        return items
    }
}

enum BriefChatRole: String, Codable, Hashable {
    case user
    case assistant
}

enum BriefChatAction: String, Codable, Hashable {
    case downloadDraft
    case offerGenerate
}

struct BriefChatMessage: Identifiable, Hashable, Codable {
    var id: UUID
    var role: BriefChatRole
    var text: String
    var createdAt: Date
    var action: BriefChatAction?
    /// 用户消息上方的材料卡片。助手气泡不再挂附件条。
    var attachmentIDs: [UUID]
    /// 生成后的「相关问题」，点选即发出短追问。
    var followUps: [String]

    init(
        id: UUID = UUID(),
        role: BriefChatRole,
        text: String,
        createdAt: Date = Date(),
        action: BriefChatAction? = nil,
        attachmentIDs: [UUID] = [],
        followUps: [String] = []
    ) {
        self.id = id
        self.role = role
        self.text = text
        self.createdAt = createdAt
        self.action = action
        self.attachmentIDs = attachmentIDs
        self.followUps = followUps
    }

    enum CodingKeys: String, CodingKey {
        case id, role, text, createdAt, action, attachmentIDs, followUps
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        role = try container.decode(BriefChatRole.self, forKey: .role)
        text = try container.decode(String.self, forKey: .text)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        action = try container.decodeIfPresent(BriefChatAction.self, forKey: .action)
        attachmentIDs = try container.decodeIfPresent([UUID].self, forKey: .attachmentIDs) ?? []
        followUps = try container.decodeIfPresent([String].self, forKey: .followUps) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(role, forKey: .role)
        try container.encode(text, forKey: .text)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(action, forKey: .action)
        try container.encode(attachmentIDs, forKey: .attachmentIDs)
        try container.encode(followUps, forKey: .followUps)
    }
}

/// 首页左栏话题：home inbox 或已挂 CaseSource。
struct HomeTopic: Identifiable, Hashable {
    var id: UUID
    var title: String
    var caption: String
    var isInbox: Bool
}

/// 案件绑定的撰稿对话。没有选中 CaseSource 时不存在。
struct CaseBriefChat: Identifiable, Hashable, Codable {
    var id: UUID
    var caseID: UUID
    var messages: [BriefChatMessage]
    var card: BriefCard

    init(caseID: UUID) {
        self.id = caseID
        self.caseID = caseID
        self.messages = []
        self.card = BriefCard(caseID: caseID)
    }

    var hasCard: Bool { card.isActionable }
}
