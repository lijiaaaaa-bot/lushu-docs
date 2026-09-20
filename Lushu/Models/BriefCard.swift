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

struct BriefChatMessage: Identifiable, Hashable, Codable {
    var id: UUID
    var role: BriefChatRole
    var text: String
    var createdAt: Date

    init(id: UUID = UUID(), role: BriefChatRole, text: String, createdAt: Date = Date()) {
        self.id = id
        self.role = role
        self.text = text
        self.createdAt = createdAt
    }
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
