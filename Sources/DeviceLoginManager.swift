import Foundation
import Security

/// Stores user profile information for device-specific quick login
struct UserProfile: Codable, Identifiable {
    let id: String
    let email: String
    var name: String?
    var lastLogin: Date
    var profileImageUrl: String?

    var initials: String {
        guard let name = name else { return "?" }
        let components = name.split(separator: " ")
        if components.count >= 2 {
            return "\(components[0].prefix(1))\(components[1].prefix(1))".uppercased()
        } else if let first = components.first {
            return String(first.prefix(1)).uppercased()
        }
        return "?"
    }
}

/// Manages device-specific user login history and PIN storage
class DeviceLoginManager {
    static let shared = DeviceLoginManager()

    private let userDefaultsKey = "deviceLoginProfiles"
    private let maxProfiles = 5

    private init() {}

    // MARK: - User Profile Management

    /// Get all stored user profiles, sorted by last login
    func getStoredProfiles() -> [UserProfile] {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let profiles = try? JSONDecoder().decode([UserProfile].self, from: data) else {
            return []
        }
        return profiles.sorted { $0.lastLogin > $1.lastLogin }
    }

    /// Save or update a user profile
    func saveUserProfile(userId: String, email: String, name: String?, profileImageUrl: String?) {
        var profiles = getStoredProfiles()

        // Update existing or create new
        if let index = profiles.firstIndex(where: { $0.id == userId }) {
            profiles[index].lastLogin = Date()
            if let name = name {
                profiles[index].name = name
            }
            if let imageUrl = profileImageUrl {
                profiles[index].profileImageUrl = imageUrl
            }
        } else {
            let newProfile = UserProfile(
                id: userId,
                email: email,
                name: name,
                lastLogin: Date(),
                profileImageUrl: profileImageUrl
            )
            profiles.append(newProfile)
        }

        // Keep only the most recent profiles
        if profiles.count > maxProfiles {
            profiles = Array(profiles.sorted { $0.lastLogin > $1.lastLogin }.prefix(maxProfiles))
        }

        // Save to UserDefaults
        if let data = try? JSONEncoder().encode(profiles) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
    }

    /// Remove a user profile
    func removeUserProfile(userId: String) {
        var profiles = getStoredProfiles()
        profiles.removeAll { $0.id == userId }

        if let data = try? JSONEncoder().encode(profiles) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }

        // Also remove PIN
        deletePIN(for: userId)
        deleteRefreshToken(for: userId)
    }

    // MARK: - PIN Management (Keychain)

    /// Save PIN to Keychain
    func savePIN(_ pin: String, for userId: String) -> Bool {
        let pinData = pin.data(using: .utf8)!

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "pin_\(userId)",
            kSecAttrService as String: "com.skininsightpro.pin",
            kSecValueData as String: pinData
        ]

        // Delete existing first
        SecItemDelete(query as CFDictionary)

        // Add new
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    /// Verify PIN from Keychain
    func verifyPIN(_ pin: String, for userId: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "pin_\(userId)",
            kSecAttrService as String: "com.skininsightpro.pin",
            kSecReturnData as String: true
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let storedPIN = String(data: data, encoding: .utf8) else {
            return false
        }

        return storedPIN == pin
    }

    /// Check if user has a PIN set
    func hasPIN(for userId: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "pin_\(userId)",
            kSecAttrService as String: "com.skininsightpro.pin",
            kSecReturnData as String: false
        ]

        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    /// Delete PIN from Keychain
    func deletePIN(for userId: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "pin_\(userId)",
            kSecAttrService as String: "com.skininsightpro.pin"
        ]

        SecItemDelete(query as CFDictionary)
    }

    /// Update PIN for a user
    func updatePIN(_ newPIN: String, for userId: String) -> Bool {
        deletePIN(for: userId)
        return savePIN(newPIN, for: userId)
    }

    // MARK: - Refresh Token Management (Keychain)

    func saveRefreshToken(_ token: String, for userId: String) -> Bool {
        let tokenData = token.data(using: .utf8)!

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "refresh_\(userId)",
            kSecAttrService as String: "com.skininsightpro.refresh",
            kSecValueData as String: tokenData
        ]

        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    func getRefreshToken(for userId: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "refresh_\(userId)",
            kSecAttrService as String: "com.skininsightpro.refresh",
            kSecReturnData as String: true
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let token = String(data: data, encoding: .utf8) else {
            return nil
        }

        return token
    }

    func deleteRefreshToken(for userId: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "refresh_\(userId)",
            kSecAttrService as String: "com.skininsightpro.refresh"
        ]

        SecItemDelete(query as CFDictionary)
    }
}
