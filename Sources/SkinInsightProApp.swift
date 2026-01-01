import SwiftUI

@main
struct SkinInsightProApp: App {
    @StateObject private var authManager = AuthenticationManager.shared
    @StateObject private var eventManager = SimpleForegroundLogger.shared
    
    var body: some Scene {
        WindowGroup {
            Group {
                if authManager.isLoading {
                    SplashScreen()
                } else if authManager.isAuthenticated {
                    if authManager.needsProfileCompletion {
                        CompleteProfileView()
                    } else {
                        MainTabView()
                    }
                } else {
                    AuthenticationView()
                }
            }
            .preferredColorScheme(.dark)
        }
    }
}