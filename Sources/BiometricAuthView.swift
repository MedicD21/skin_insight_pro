import SwiftUI

/// View shown when biometric authentication is required on app launch
struct BiometricAuthView: View {
    @ObservedObject var theme = ThemeManager.shared
    @StateObject private var biometricManager = BiometricAuthManager.shared
    @Binding var isAuthenticated: Bool
    @State private var authenticationFailed = false
    @State private var errorMessage = ""

    var body: some View {
        ZStack {
            theme.primaryBackground
                .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // Icon
                Image(systemName: biometricManager.biometricIcon)
                    .font(.system(size: 80))
                    .foregroundColor(theme.accent)

                VStack(spacing: 16) {
                    Text("Authentication Required")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(theme.primaryText)

                    Text("Use \(biometricManager.biometricTypeName) to unlock SkinInsight Pro")
                        .font(.system(size: 16))
                        .foregroundColor(theme.secondaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                // Authenticate button
                Button(action: {
                    Task {
                        await authenticate()
                    }
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: biometricManager.biometricIcon)
                            .font(.system(size: 20))
                        Text("Authenticate")
                            .font(.system(size: 18, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(theme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: theme.radiusLarge))
                }
                .padding(.horizontal, 32)

                // Error message
                if authenticationFailed {
                    Text(errorMessage)
                        .font(.system(size: 14))
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                Spacer()

                // Use passcode button
                Button(action: {
                    Task {
                        await authenticateWithPasscode()
                    }
                }) {
                    Text("Use Passcode")
                        .font(.system(size: 16))
                        .foregroundColor(theme.accent)
                }
                .padding(.bottom, 32)
            }
        }
        .onAppear {
            // Automatically prompt for authentication when view appears
            Task {
                await authenticate()
            }
        }
    }

    private func authenticate() async {
        let success = await biometricManager.authenticate()

        await MainActor.run {
            if success {
                isAuthenticated = true
                authenticationFailed = false
            } else {
                authenticationFailed = true
                errorMessage = "Authentication failed. Please try again."
            }
        }
    }

    private func authenticateWithPasscode() async {
        let success = await biometricManager.authenticateWithPasscode()

        await MainActor.run {
            if success {
                isAuthenticated = true
                authenticationFailed = false
            } else {
                authenticationFailed = true
                errorMessage = "Authentication failed. Please try again."
            }
        }
    }
}
