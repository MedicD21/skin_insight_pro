import SwiftUI
import AuthenticationServices

struct SignInWithAppleButton: View {
    @ObservedObject var theme = ThemeManager.shared
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Spacer()
                Image(systemName: "applelogo")
                    .font(.system(size: 18, weight: .semibold))
                Text("Continue with Apple")
                Spacer()
            }
            .font(.system(size: 17, weight: .semibold))
            .foregroundColor(.white)
            .frame(height: 52)
            .background(Color.black)
            .clipShape(RoundedRectangle(cornerRadius: theme.radiusMedium))
        }
    }
}
