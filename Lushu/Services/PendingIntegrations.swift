import Foundation

/// 仍未接线的系统能力。结构化与法条校验已有正式 API，见 TableStructuringService / LegalCorpus。
enum PendingIntegrations {
    static func openAnxiaFolder() {}

    static func importFiles() {}

    static func extractPlainText(fromRelativePath _: String) -> String? { nil }

    static func readAPIKeyFromKeychain() -> String? { nil }

    static func writeAPIKeyToKeychain(_: String) {}

    static func saveDocument(filename _: String, contents _: String, writeBackToSource _: Bool) {}

    static func openWorkbookInSystem(_: URL) {}

    /// 接入点：LiJiaKit path 产品 LegalKnowledge。未接线前 LegalCorpus 拒绝任何条文。
    static func attachLegalKnowledgeKit() {}
}
