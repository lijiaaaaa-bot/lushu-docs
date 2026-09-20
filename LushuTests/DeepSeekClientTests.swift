import XCTest
@testable import Lushu

final class DeepSeekClientTests: XCTestCase {
    func testEncodeRequestDisablesThinkingAndDoesNotEmbedKey() throws {
        let messages = [
            DeepSeekChatMessage(role: "system", content: GroundedLLM.systemPrompt),
            DeepSeekChatMessage(role: "user", content: "只改措辞，不要补数字。")
        ]
        let data = try DeepSeekClient.encodeRequest(model: DeepSeekClient.defaultModel, messages: messages)
        let json = String(data: data, encoding: .utf8) ?? ""

        XCTAssertTrue(json.contains("\"thinking\""))
        XCTAssertTrue(json.contains("\"disabled\""))
        XCTAssertTrue(json.contains("\"deepseek-chat\""))
        XCTAssertTrue(json.contains("\"stream\""))
        XCTAssertFalse(json.contains("sk-"))
        XCTAssertFalse(json.contains("Bearer"))
        XCTAssertFalse(json.contains("Authorization"))
        XCTAssertFalse(json.contains("api.deepseek.com"))

        let decoded = try JSONDecoder().decode(DeepSeekRequest.self, from: data)
        XCTAssertEqual(decoded.thinking.type, "disabled")
        XCTAssertFalse(decoded.stream)
        XCTAssertEqual(decoded.model, "deepseek-chat")
        XCTAssertEqual(decoded.messages.count, 2)
    }

    func testCompleteRejectsEmptyKeyWithoutNetwork() async {
        do {
            _ = try await DeepSeekClient().complete(
                messages: [DeepSeekChatMessage(role: "user", content: "hi")],
                key: "   "
            )
            XCTFail("空密钥不应发请求")
        } catch DeepSeekError.missingKey {
            // expected
        } catch {
            XCTFail("应抛 DeepSeekError.missingKey，得到 \(error)")
        }
    }

    func testGroundedPromptForbidsInventedFacts() {
        XCTAssertTrue(GroundedLLM.systemPrompt.contains("禁止编造"))
        XCTAssertTrue(GroundedLLM.systemPrompt.contains("电价P"))
        XCTAssertTrue(GroundedLLM.missingKeyHint.contains("设置"))
        XCTAssertTrue(GroundedLLM.missingKeyHint.contains("钥匙串"))
        XCTAssertFalse(GroundedLLM.missingKeyHint.contains("0.85"))
    }

    func testKeychainAccountIsNotASecret() {
        XCTAssertEqual(APIKeyStore.service, "bot.lijiaaaaa.lushu")
        XCTAssertEqual(APIKeyStore.account, "deepseek.apiKey")
        XCTAssertEqual(APIKeyStore.providerTitle, "DeepSeek")
        XCTAssertFalse(APIKeyStore.account.hasPrefix("sk-"))
    }
}
