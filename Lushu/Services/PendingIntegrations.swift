import Foundation

/// 仍未接线的系统能力。结构化与法条校验已有正式 API，见 TableStructuringService / LegalCorpus。
enum PendingIntegrations {
    static func openAnxiaFolder() {}

    static func importFiles() {}

    static func extractPlainText(fromRelativePath _: String) -> String? { nil }

    static func extractPlainText(from url: URL) throws -> String {
        try OfficeDocument.extractText(from: url)
    }

    static func readAPIKeyFromKeychain() -> String? {
        try? APIKeyStore.readDeepSeekKey()
    }

    static func writeAPIKeyToKeychain(_ key: String) {
        try? APIKeyStore.saveDeepSeekKey(key)
    }

    static func saveDocument(filename _: String, contents _: String, writeBackToSource _: Bool) {}

    static func openWorkbookInSystem(_: URL) {}

    /// 完整法索包接入点。子集已随 bundle 提供；此处留给全量 LegalKnowledge。
    static func attachFullLegalKnowledgeKit() {}

    /// 润色只改已落稿措辞。不得在此编造法条或台账数字。
    static func polishDraftWording(_: DraftDocument) -> DraftDocument? { nil }
}
