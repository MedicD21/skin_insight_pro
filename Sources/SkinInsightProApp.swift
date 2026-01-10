import SwiftUI

@main
struct SkinInsightProApp: App {
    @StateObject private var authManager = AuthenticationManager.shared
    @StateObject private var eventManager = SimpleForegroundLogger.shared
    @StateObject private var complianceManager = HIPAAComplianceManager.shared
    @State private var showSessionTimeout = false

    var body: some Scene {
        WindowGroup {
            ZStack {
                Group {
                    if authManager.isLoading {
                        SplashScreen()
                    } else if authManager.isAuthenticated {
                        if !complianceManager.hasUserConsented {
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
                    complianceManager.startSessionMonitoring()
                } else {
                    complianceManager.stopSessionMonitoring()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
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
}
