import SwiftUI

/// 首页已改为对话。此类型保留预览名，避免旧调用处断裂。
struct OnboardingView: View {
    var body: some View {
        HomeChatView()
    }
}

#Preview {
    OnboardingView()
        .environmentObject(AppState())
        .frame(width: 920, height: 640)
}
