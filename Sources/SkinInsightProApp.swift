import SwiftUI

@main
struct SkinInsightProApp: App {
    @StateObject private var authManager = AuthenticationManager.shared
    @StateObject private var eventManager = SimpleForegroundLogger.shared
    @StateObject private var complianceManager = HIPAAComplianceManager.shared
    @StateObject private var biometricManager = BiometricAuthManager.shared
    @State private var showSessionTimeout = false
    @State private var biometricAuthPassed = false
    @State private var requiresBiometricAuth = false

    var body: some Scene {
        WindowGroup {
            ZStack {
                Group {
                    if authManager.isLoading {
                        SplashScreen()
                    } else if authManager.isAuthenticated {
                        // Check if biometric authentication is required
                        if requiresBiometricAuth && !biometricAuthPassed {
                            BiometricAuthView(isAuthenticated: $biometricAuthPassed)
                        } else if !complianceManager.hasUserConsented {
                            // Show consent screen first
                            HIPAAConsentView { }
                        } else if authManager.needsProfileCompletion {
                            CompleteProfileView()
                                .trackHIPAAActivity()
                        } else if authManager.needsCompanySetup {
                            CompanyOnboardingView {
                                authManager.needsCompanySetup = false
                            }
                            .trackHIPAAActivity()
                        } else {
                            MainTabView()
                                .trackHIPAAActivity()
                        }
                    } else {
                        AuthenticationView()
                    }
                }
                .preferredColorScheme(.dark)

                // Session timeout overlay
                if complianceManager.isSessionExpired {
                    SessionTimeoutView(isPresented: $showSessionTimeout)
                }
            }
            .onAppear {
                // Check if biometric auth is required
                checkBiometricRequirement()

                if authManager.isAuthenticated {
                    complianceManager.startSessionMonitoring()

                    // Refresh user profile on app launch to ensure data is current
                    if let userId = authManager.currentUser?.id {
                        print("🚀 SkinInsightProApp.onAppear: Triggering profile refresh")
                        Task {
                            await authManager.refreshUserProfile(userId: userId)
                        }
                    }
                }
            }
            .onChange(of: authManager.isAuthenticated) { _, isAuthenticated in
                if isAuthenticated {
                    // Reset biometric auth when user logs in
                    checkBiometricRequirement()
                    complianceManager.startSessionMonitoring()
                } else {
                    // Reset biometric auth when user logs out
                    biometricAuthPassed = false
                    requiresBiometricAuth = false
                    complianceManager.stopSessionMonitoring()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                // Require biometric auth again when returning to foreground (if enabled)
                if authManager.isAuthenticated && !authManager.isGuestMode {
                    checkBiometricRequirement()
                }

                // Refresh user profile when app returns to foreground
                // This ensures data is always current (e.g., if GOD mode was enabled in Supabase)
                if authManager.isAuthenticated, !authManager.isGuestMode,
                   let userId = authManager.currentUser?.id {
                    print("🔄 App returned to foreground: Triggering profile refresh")
                    Task {
                        await authManager.refreshUserProfile(userId: userId)
                    }
                }
            }
        }
    }

    /// Check if biometric authentication is required
    private func checkBiometricRequirement() {
        let isEnabled = biometricManager.isBiometricEnabled
        let isAvailable = biometricManager.isBiometricAvailable
        let isGuest = authManager.isGuestMode

        // Require biometric auth if:
        // 1. User has enabled it
        // 2. Device supports it
        // 3. User is not in guest mode
        requiresBiometricAuth = isEnabled && isAvailable && !isGuest

        // Reset auth passed state to require re-authentication
        if requiresBiometricAuth {
            biometricAuthPassed = false
        }
    }
}
