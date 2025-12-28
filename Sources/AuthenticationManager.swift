import Foundation
import SwiftUI

@MainActor
class AuthenticationManager: ObservableObject {
    static let shared = AuthenticationManager()
    
    @Published var isAuthenticated = false
    @Published var isLoading = true
    @Published var currentUser: AppUser?
    @Published var isGuestMode = false
    
    private let userIdKey = "user_id"
    private let userEmailKey = "user_email"
    private let loginProviderKey = "login_provider"
    private let guestModeKey = "guest_mode"
    private let guestUserIdKey = "guest_user_id"
    
    private init() {
        checkAuthStatus()
    }
    
    private func checkAuthStatus() {
        if UserDefaults.standard.bool(forKey: guestModeKey) {
            let guestUserId = UserDefaults.standard.string(forKey: guestUserIdKey) ?? UUID().uuidString
            UserDefaults.standard.set(guestUserId, forKey: guestUserIdKey)
            currentUser = AppUser(id: guestUserId, email: "Guest User", provider: "guest", createdAt: nil)
            isGuestMode = true
            isAuthenticated = true
        } else if let userId = UserDefaults.standard.string(forKey: userIdKey),
                  let email = UserDefaults.standard.string(forKey: userEmailKey) {
            currentUser = AppUser(id: userId, email: email, provider: "email", createdAt: nil)
            isAuthenticated = true
            isGuestMode = false
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.isLoading = false
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
        }
    }
    
    func logout() {
        UserDefaults.standard.removeObject(forKey: userIdKey)
        UserDefaults.standard.removeObject(forKey: userEmailKey)
        UserDefaults.standard.removeObject(forKey: loginProviderKey)
        UserDefaults.standard.removeObject(forKey: guestModeKey)
        UserDefaults.standard.removeObject(forKey: guestUserIdKey)
        
        currentUser = nil
        isGuestMode = false
        isAuthenticated = false
    }
    
    func deleteAccount() async throws {
        guard let userId = currentUser?.id, !isGuestMode else { return }
        
        try await NetworkService.shared.deleteUser(userId: userId)
        logout()
    }
}