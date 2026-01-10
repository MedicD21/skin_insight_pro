import Foundation
import SwiftUI
import AuthenticationServices

@MainActor
class AuthenticationManager: NSObject, ObservableObject {
    static let shared = AuthenticationManager()
    
    @Published var isAuthenticated = false
    @Published var isLoading = true
    @Published var currentUser: AppUser?
    @Published var isGuestMode = false
    @Published var needsProfileCompletion = false
    @Published var needsCompanySetup = false
    @Published var needsPINSetup = false
    
    private let userIdKey = "user_id"
    private let userEmailKey = "user_email"
    private let loginProviderKey = "login_provider"
    private let guestModeKey = "guest_mode"
    private let guestUserIdKey = "guest_user_id"
    private let appleUserIdKey = "apple_user_id"

    private override init() {
        super.init()
        checkAuthStatus()
    }
    
    private func checkAuthStatus() {
        if UserDefaults.standard.bool(forKey: guestModeKey) {
            let guestUserId = UserDefaults.standard.string(forKey: guestUserIdKey) ?? UUID().uuidString
            UserDefaults.standard.set(guestUserId, forKey: guestUserIdKey)
            currentUser = AppUser(id: guestUserId, email: "Guest User", provider: "guest", createdAt: nil)
            isGuestMode = true
            isAuthenticated = true
            isLoading = false
        } else if let _ = UserDefaults.standard.string(forKey: AppConstants.accessTokenKey),
                  let userId = UserDefaults.standard.string(forKey: AppConstants.userIdKey),
                  let email = UserDefaults.standard.string(forKey: userEmailKey) {
            // User has valid Supabase tokens - fetch full profile from database
            print("📱 checkAuthStatus: Found cached tokens, creating minimal user object")
            print("   User ID: \(userId)")
            print("   Email: \(email)")
            currentUser = AppUser(id: userId, email: email, provider: "email", createdAt: nil)
            isAuthenticated = true
            isGuestMode = false

            // Fetch full user profile including company_id
            Task {
                await self.refreshUserProfile(userId: userId)
            }
        } else {
            print("📱 checkAuthStatus: No cached tokens found")
            isLoading = false
        }
    }

    func refreshUserProfile(userId: String) async {
        do {
            print("🔄 Starting user profile refresh for userId: \(userId)")
            let fullUser = try await NetworkService.shared.fetchUser(userId: userId)
            await MainActor.run {
                self.currentUser = fullUser
                print("✅ Refreshed user profile")
                print("   User ID: \(fullUser.id ?? "nil")")
                print("   Email: \(fullUser.email ?? "nil")")
                print("   Company ID: \(fullUser.companyId ?? "nil")")
                print("   Is Company Admin: \(fullUser.isCompanyAdmin ?? false)")
                print("   GOD Mode: \(fullUser.godMode ?? false)")

                // Check if user needs to set up company
                if fullUser.companyId == nil || fullUser.companyId?.isEmpty == true {
                    self.needsCompanySetup = true
                } else {
                    self.needsCompanySetup = false
                }

                self.isLoading = false
            }
        } catch {
            print("❌ Failed to refresh user profile: \(error)")
            await MainActor.run {
                self.isLoading = false
            }
        }
    }
    
    func loginAsGuest() {
        let guestUserId = UUID().uuidString
        UserDefaults.standard.set(true, forKey: guestModeKey)
        UserDefaults.standard.set(guestUserId, forKey: guestUserIdKey)
        
        currentUser = AppUser(id: guestUserId, email: "Guest User", provider: "guest", createdAt: nil)
        isGuestMode = true
        isAuthenticated = true
    }
    
    func login(email: String, password: String) async throws {
        do {
            let user = try await NetworkService.shared.login(email: email, password: password)

            if let userId = user.id {
                UserDefaults.standard.set(userId, forKey: userIdKey)
                UserDefaults.standard.set(email, forKey: userEmailKey)
                UserDefaults.standard.set("email", forKey: loginProviderKey)
                UserDefaults.standard.removeObject(forKey: guestModeKey)
                UserDefaults.standard.removeObject(forKey: guestUserIdKey)

                currentUser = user
                isGuestMode = false
                isAuthenticated = true

                // Save user profile to device login manager
                let fullName = user.firstName != nil && user.lastName != nil ? "\(user.firstName!) \(user.lastName!)" : nil
                DeviceLoginManager.shared.saveUserProfile(
                    userId: userId,
                    email: email,
                    name: fullName,
                    profileImageUrl: user.profileImageUrl
                )

                cacheRefreshToken(for: userId)
            }
        } catch let error as NetworkError where error.localizedDescription.contains("400") {
            throw NetworkError.invalidCredentials
        } catch {
            throw error
        }
    }
    
    func createAccount(email: String, password: String) async throws {
        let user = try await NetworkService.shared.createUser(email: email, password: password)

        if let userId = user.id {
            UserDefaults.standard.set(userId, forKey: userIdKey)
            UserDefaults.standard.set(email, forKey: userEmailKey)
            UserDefaults.standard.set("email", forKey: loginProviderKey)
            UserDefaults.standard.removeObject(forKey: guestModeKey)
            UserDefaults.standard.removeObject(forKey: guestUserIdKey)

            currentUser = user
            isGuestMode = false
            isAuthenticated = true

            // Check if user needs PIN setup (new user on this device)
            if !DeviceLoginManager.shared.hasPIN(for: userId) {
                needsPINSetup = true
            }

            // Check if profile needs completion (no first/last name)
            if user.firstName == nil || user.firstName?.isEmpty == true ||
               user.lastName == nil || user.lastName?.isEmpty == true {
                needsProfileCompletion = true
            } else if user.companyId == nil || user.companyId?.isEmpty == true {
                // Profile complete but no company - needs company setup
                needsCompanySetup = true
            }

            cacheRefreshToken(for: userId)
        }
    }
    
    func logout() {
        UserDefaults.standard.removeObject(forKey: userIdKey)
        UserDefaults.standard.removeObject(forKey: userEmailKey)
        UserDefaults.standard.removeObject(forKey: loginProviderKey)
        UserDefaults.standard.removeObject(forKey: guestModeKey)
        UserDefaults.standard.removeObject(forKey: guestUserIdKey)

        // Clear Supabase tokens
        UserDefaults.standard.removeObject(forKey: AppConstants.accessTokenKey)
        UserDefaults.standard.removeObject(forKey: AppConstants.refreshTokenKey)
        UserDefaults.standard.removeObject(forKey: AppConstants.userIdKey)

        currentUser = nil
        isGuestMode = false
        isAuthenticated = false
    }
    
    func deleteAccount() async throws {
        guard let userId = currentUser?.id, !isGuestMode else { return }

        try await NetworkService.shared.deleteUser(userId: userId)
        logout()
    }

    func loginWithPIN(userId: String, email: String) async throws {
        let accessToken = UserDefaults.standard.string(forKey: AppConstants.accessTokenKey)
        if let storedUserId = UserDefaults.standard.string(forKey: AppConstants.userIdKey),
           storedUserId != userId,
           accessToken != nil,
           accessToken?.isEmpty == false {
            throw NSError(domain: "Authentication", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Please sign in with your password to continue."
            ])
        } else if let storedUserId = UserDefaults.standard.string(forKey: AppConstants.userIdKey),
                  storedUserId != userId,
                  accessToken == nil || accessToken?.isEmpty == true {
            UserDefaults.standard.removeObject(forKey: AppConstants.userIdKey)
        }

        if accessToken == nil || accessToken?.isEmpty == true {
            var refreshToken = UserDefaults.standard.string(forKey: AppConstants.refreshTokenKey)
            if refreshToken?.isEmpty ?? true {
                refreshToken = DeviceLoginManager.shared.getRefreshToken(for: userId)
            }

            guard let refreshToken, !refreshToken.isEmpty else {
                throw NSError(domain: "Authentication", code: 2, userInfo: [
                    NSLocalizedDescriptionKey: "Please sign in with your password to continue."
                ])
            }

            _ = try await NetworkService.shared.refreshAccessToken(using: refreshToken)
        }

        if let refreshedUserId = UserDefaults.standard.string(forKey: AppConstants.userIdKey),
           !refreshedUserId.isEmpty,
           refreshedUserId != userId {
            throw NSError(domain: "Authentication", code: 3, userInfo: [
                NSLocalizedDescriptionKey: "Please sign in with your password to continue."
            ])
        }

        UserDefaults.standard.set(userId, forKey: userIdKey)
        UserDefaults.standard.set(email, forKey: userEmailKey)
        UserDefaults.standard.set("email", forKey: loginProviderKey)
        UserDefaults.standard.removeObject(forKey: guestModeKey)
        UserDefaults.standard.removeObject(forKey: guestUserIdKey)

        currentUser = AppUser(id: userId, email: email, provider: "email", createdAt: nil)
        isGuestMode = false
        isAuthenticated = true
        isLoading = true

        await refreshUserProfile(userId: userId)
        cacheRefreshToken(for: userId)
    }

    func signInWithApple() async throws {
        let appleIDProvider = ASAuthorizationAppleIDProvider()
        let request = appleIDProvider.createRequest()
        request.requestedScopes = [.fullName, .email]

        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        authorizationController.delegate = self
        authorizationController.presentationContextProvider = self
        authorizationController.performRequests()
    }

    private func handleAppleSignIn(userId: String, email: String?, fullName: PersonNameComponents?) async throws {
        let displayEmail = email ?? ""

        let user = try await NetworkService.shared.createOrLoginAppleUser(
            appleUserId: userId,
            email: displayEmail,
            fullName: fullName
        )

        if let serverUserId = user.id {
            UserDefaults.standard.set(serverUserId, forKey: userIdKey)
            UserDefaults.standard.set(displayEmail, forKey: userEmailKey)
            UserDefaults.standard.set("apple", forKey: loginProviderKey)
            UserDefaults.standard.set(userId, forKey: appleUserIdKey)
            UserDefaults.standard.removeObject(forKey: guestModeKey)
            UserDefaults.standard.removeObject(forKey: guestUserIdKey)

            currentUser = user
            isGuestMode = false
            isAuthenticated = true

            // Check if user needs PIN setup (new user on this device)
            if !DeviceLoginManager.shared.hasPIN(for: serverUserId) {
                needsPINSetup = true
            }

            // Save user profile to device login manager
            let fullName = user.firstName != nil && user.lastName != nil ? "\(user.firstName!) \(user.lastName!)" : nil
            DeviceLoginManager.shared.saveUserProfile(
                userId: serverUserId,
                email: displayEmail,
                name: fullName,
                profileImageUrl: user.profileImageUrl
            )

            cacheRefreshToken(for: serverUserId)
        }
    }

    private func cacheRefreshToken(for userId: String) {
        guard let refreshToken = UserDefaults.standard.string(forKey: AppConstants.refreshTokenKey),
              !refreshToken.isEmpty else { return }
        _ = DeviceLoginManager.shared.saveRefreshToken(refreshToken, for: userId)
    }
}

extension AuthenticationManager: ASAuthorizationControllerDelegate {
    nonisolated func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        Task { @MainActor in
            if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
                let userId = appleIDCredential.user
                let email = appleIDCredential.email
                let fullName = appleIDCredential.fullName

                do {
                    try await handleAppleSignIn(userId: userId, email: email, fullName: fullName)
                } catch {
                    print("Apple Sign In error: \(error)")
                }
            }
        }
    }

    nonisolated func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        Task { @MainActor in
            print("Apple Sign In failed: \(error.localizedDescription)")
        }
    }
}

extension AuthenticationManager: ASAuthorizationControllerPresentationContextProviding {
    @MainActor func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        // Get the key window from the connected scenes
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            fatalError("No window available for Sign in with Apple")
        }
        return window
    }
}
