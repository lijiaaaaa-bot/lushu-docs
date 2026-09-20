import SwiftUI

struct EmptyStateView: View {
    let title: String
    let detail: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(LushuType.section())
                .foregroundStyle(LushuTheme.ink)
            Text(detail)
                .font(LushuType.body())
                .foregroundStyle(LushuTheme.softInk)
                .fixedSize(horizontal: false, vertical: true)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .padding(.top, 6)
            }
        }
        .padding(28)
        .frame(maxWidth: 480, alignment: .leading)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(LushuTheme.sky)
    }
}
