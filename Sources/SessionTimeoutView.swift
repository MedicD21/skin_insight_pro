import SwiftUI

struct SessionTimeoutView: View {
    @ObservedObject var theme = ThemeManager.shared
    @Binding var isPresented: Bool

    var body: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 60))
                    .foregroundColor(theme.accent)

                VStack(spacing: 12) {
                    Text("Session Expired")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(theme.primaryText)

                    Text("Your session has expired due to inactivity. Please log in again to continue.")
                        .font(.system(size: 15))
                        .foregroundColor(theme.secondaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }

                Button(action: {
                    isPresented = false
                    AuthenticationManager.shared.logout()
                }) {
                    Text("Return to Login")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(16)
                        .background(theme.accent)
                        .clipShape(RoundedRectangle(cornerRadius: theme.radiusMedium))
                }
                .padding(.horizontal, 40)
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: theme.radiusXL)
                    .fill(theme.cardBackground)
                    .shadow(color: .black.opacity(0.3), radius: 20)
            )
            .padding(.horizontal, 40)
        }
    }
}
