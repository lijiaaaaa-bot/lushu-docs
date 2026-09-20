import Foundation

/// 下一轮功能接线入口。界面先行轮只保留方法签名与说明，避免半成品解析器进入主路径。
enum PendingIntegrations {
    /// 系统选档 + security-scoped bookmark 持久化。
    static func openAnxiaFolder() {}

    /// 多文件导入。
    static func importFiles() {}

    /// txt / md 读取；pdf / docx 解析器下一轮再展开。
    static func extractPlainText(fromRelativePath _: String) -> String? {
        nil
    }

    /// 钥匙串读写。禁止把密钥写入 UserDefaults 或仓库文件。
    static func readAPIKeyFromKeychain() -> String? { nil }

    static func writeAPIKeyToKeychain(_: String) {}

    /// NSSavePanel 导出；可选写回已授权的案匣目录。
    static func saveDocument(filename _: String, contents _: String, writeBackToSource _: Bool) {}
}
