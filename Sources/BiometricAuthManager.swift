import Foundation
import LocalAuthentication

/// Manages biometric authentication (Face ID / Touch ID) for the app
class BiometricAuthManager: ObservableObject {
    static let shared = BiometricAuthManager()

    @Published var isBiometricEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isBiometricEnabled, forKey: biometricEnabledKey)
        }
    }

    private let biometricEnabledKey = "BiometricAuthEnabled"
    private let context = LAContext()

    private init() {
        self.isBiometricEnabled = UserDefaults.standard.bool(forKey: biometricEnabledKey)
    }

    /// Check if biometric authentication is available on this device
    var biometricType: BiometricType {
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return .none
        }

        switch context.biometryType {
        case .faceID:
            return .faceID
        case .touchID:
            return .touchID
        case .opticID:
            return .opticID
        case .none:
            return .none
        @unknown default:
            return .none
        }
    }

    /// Check if biometric authentication is available
    var isBiometricAvailable: Bool {
        return biometricType != .none
    }

    /// Authenticate user with biometrics
    func authenticate() async -> Bool {
        let context = LAContext()
        var error: NSError?

        // Check if biometric authentication is available
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            print("❌ Biometric authentication not available: \(error?.localizedDescription ?? "Unknown error")")
            return false
        }

        do {
            let reason = "Authenticate to access your patient data"
            let success = try await context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason)

            if success {
                print("✅ Biometric authentication succeeded")
            }

            return success
        } catch let error {
            print("❌ Biometric authentication failed: \(error.localizedDescription)")
            return false
        }
    }

    /// Authenticate user with device passcode fallback
    func authenticateWithPasscode() async -> Bool {
        let context = LAContext()
        context.localizedFallbackTitle = "Use Passcode"

        do {
            let reason = "Authenticate to access your patient data"
            let success = try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)

            if success {
                print("✅ Authentication succeeded")
            }

            return success
        } catch let error {
            print("❌ Authentication failed: \(error.localizedDescription)")
            return false
        }
    }

    /// Get user-friendly name for biometric type
    var biometricTypeName: String {
        switch biometricType {
        case .faceID:
            return "Face ID"
        case .touchID:
            return "Touch ID"
        case .opticID:
            return "Optic ID"
        case .none:
            return "Biometric Authentication"
        }
    }

    /// Get icon for biometric type
    var biometricIcon: String {
        switch biometricType {
        case .faceID:
            return "faceid"
        case .touchID:
            return "touchid"
        case .opticID:
            return "opticid"
        case .none:
            return "lock.fill"
        }
    }
}

enum BiometricType {
    case faceID
    case touchID
    case opticID
    case none
}
