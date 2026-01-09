import SwiftUI

struct SessionTimeoutView: View {
    @ObservedObject var theme = ThemeManager.shared
    @ObservedObject var complianceManager = HIPAAComplianceManager.shared
    @ObservedObject var biometricManager = BiometricAuthManager.shared
    @Binding var isPresented: Bool
    @State private var isAuthenticating = false
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Image(systemName: biometricManager.isBiometricEnabled ? biometricManager.biometricIcon : "lock.fill")
                    .font(.system(size: 60))
                    .foregroundColor(theme.accent)

                VStack(spacing: 12) {
                    Text("Session Locked")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(theme.primaryText)

                    if biometricManager.isBiometricEnabled && biometricManager.isBiometricAvailable {
                        Text("Your session has been locked due to inactivity. Use \(biometricManager.biometricTypeName) to unlock and continue.")
                            .font(.system(size: 15))
                            .foregroundColor(theme.secondaryText)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                    } else {
                        Text("Your session has expired due to inactivity. Please log in again to continue.")
                            .font(.system(size: 15))
                            .foregroundColor(theme.secondaryText)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                    }
                }

                if biometricManager.isBiometricEnabled && biometricManager.isBiometricAvailable {
                    // Biometric unlock button
                    Button(action: { Task { await unlockWithBiometrics() } }) {
                        HStack(spacing: 12) {
                            if isAuthenticating {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Image(systemName: biometricManager.biometricIcon)
                                    .font(.system(size: 20))
                            }
                            Text(isAuthenticating ? "Authenticating..." : "Unlock with \(biometricManager.biometricTypeName)")
                                .font(.system(size: 17, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(16)
                        .background(theme.accent)
                        .clipShape(RoundedRectangle(cornerRadius: theme.radiusMedium))
                    }
                    .disabled(isAuthenticating)
                    .padding(.horizontal, 40)

                    // Alternative: Sign out button
                    Button(action: signOut) {
                        Text("Sign Out")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(theme.secondaryText)
                    }
                    .padding(.top, 8)
                } else {
                    // No biometrics - force logout
                    Button(action: signOut) {
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
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: theme.radiusXL)
                    .fill(theme.cardBackground)
                    .shadow(color: .black.opacity(0.3), radius: 20)
            )
            .padding(.horizontal, 40)
        }
        .onAppear {
            // Auto-trigger biometric auth if enabled
            if biometricManager.isBiometricEnabled && biometricManager.isBiometricAvailable {
                Task {
                    // Small delay to let the view appear
                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                    await unlockWithBiometrics()
                }
            }
        }
        .alert("Authentication Failed", isPresented: $showError) {
            Button("Try Again", role: .cancel) {
                Task {
                    await unlockWithBiometrics()
                }
            }
            Button("Sign Out", role: .destructive) {
                signOut()
            }
        } message: {
            Text(errorMessage)
        }
    }

    private func unlockWithBiometrics() async {
        await MainActor.run {
            isAuthenticating = true
        }

        let success = await biometricManager.authenticate()

        await MainActor.run {
            isAuthenticating = false

            if success {
                // Successfully authenticated - unlock session
                complianceManager.isSessionExpired = false
                complianceManager.startSessionMonitoring()
                isPresented = false
            } else {
                // Authentication failed
                errorMessage = "Failed to authenticate with \(biometricManager.biometricTypeName). Please try again or sign out."
                showError = true
            }
        }
    }

    private func signOut() {
        // Reset session expired flag first
        complianceManager.isSessionExpired = false
        isPresented = false
        // Then logout to return to login screen
        AuthenticationManager.shared.logout()
    }
}
