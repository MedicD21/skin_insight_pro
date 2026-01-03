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
                }
            }
            .onChange(of: authManager.isAuthenticated) { _, isAuthenticated in
                if isAuthenticated {
                    complianceManager.startSessionMonitoring()
                } else {
                    complianceManager.stopSessionMonitoring()
                }
            }
        }
    }
}
