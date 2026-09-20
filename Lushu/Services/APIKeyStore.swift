import Foundation
#if canImport(Security)
import Security
#endif

/// DeepSeek BYOK。优先对接 LiJiaKit KeychainKit / APIKeyStore（path 可用时替换本实现）。
/// 密钥只进钥匙串，禁止写入 UserDefaults / 仓库。
enum APIKeyStore {
    static let service = "bot.lijiaaaaa.lushu"
    static let account = "deepseek.apiKey"
    static let providerTitle = "DeepSeek"

    enum StoreError: LocalizedError {
        case unavailable
        case unexpectedStatus(Int32)

        var errorDescription: String? {
            switch self {
            case .unavailable:
                return "当前环境不能访问钥匙串。"
            case .unexpectedStatus(let status):
                return "钥匙串操作失败（\(status)）。"
            }
        }
    }

    static func hasDeepSeekKey() -> Bool {
        (try? readDeepSeekKey())?.isEmpty == false
    }

    static func maskedDeepSeekKey() -> String? {
        guard let key = try? readDeepSeekKey(), key.count >= 4 else { return nil }
        return "••••\(key.suffix(4))"
    }

    static func readDeepSeekKey() throws -> String? {
        #if canImport(Security)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw StoreError.unexpectedStatus(Int32(status)) }
        guard let data = item as? Data, let text = String(data: data, encoding: .utf8) else {
            return nil
        }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
        #else
        throw StoreError.unavailable
        #endif
    }

    static func saveDeepSeekKey(_ raw: String) throws {
        let key = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else {
            try clearDeepSeekKey()
            return
        }
        #if canImport(Security)
        try clearDeepSeekKey()
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: Data(key.utf8),
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw StoreError.unexpectedStatus(Int32(status)) }
        #else
        throw StoreError.unavailable
        #endif
    }

    static func clearDeepSeekKey() throws {
        #if canImport(Security)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw StoreError.unexpectedStatus(Int32(status))
        }
        #else
        throw StoreError.unavailable
        #endif
    }
}
