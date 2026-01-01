import Foundation

extension AppClient {
    /// HIPAA consent forms are typically valid for 1 year
    static let consentValidityPeriod: TimeInterval = 365 * 24 * 60 * 60 // 1 year in seconds

    /// Returns true if the client has a valid HIPAA consent (signed and not expired)
    var hasValidConsent: Bool {
        guard let consentDateString = consentDate,
              consentSignature != nil else {
            return false
        }

        // Parse the ISO8601 consent date
        let formatter = ISO8601DateFormatter()
        guard let consentDate = formatter.date(from: consentDateString) else {
            return false
        }

        // Check if consent is still within 1 year validity period
        let expirationDate = consentDate.addingTimeInterval(AppClient.consentValidityPeriod)
        return Date() < expirationDate
    }

    /// Returns true if consent exists but has expired
    var hasExpiredConsent: Bool {
        guard let consentDateString = consentDate,
              consentSignature != nil else {
            return false
        }

        let formatter = ISO8601DateFormatter()
        guard let consentDate = formatter.date(from: consentDateString) else {
            return false
        }

        let expirationDate = consentDate.addingTimeInterval(AppClient.consentValidityPeriod)
        return Date() >= expirationDate
    }

    /// Returns the expiration date of the consent, or nil if no consent exists
    var consentExpirationDate: Date? {
        guard let consentDateString = consentDate else {
            return nil
        }

        let formatter = ISO8601DateFormatter()
        guard let consentDate = formatter.date(from: consentDateString) else {
            return nil
        }

        return consentDate.addingTimeInterval(AppClient.consentValidityPeriod)
    }

    /// Returns a human-readable status for the consent
    var consentStatus: ConsentStatus {
        if hasValidConsent {
            return .valid
        } else if hasExpiredConsent {
            return .expired
        } else {
            return .missing
        }
    }
}

enum ConsentStatus {
    case valid
    case expired
    case missing

    var displayText: String {
        switch self {
        case .valid:
            return "Valid Consent"
        case .expired:
            return "Expired Consent"
        case .missing:
            return "No Consent"
        }
    }

    var icon: String {
        switch self {
        case .valid:
            return "checkmark.seal.fill"
        case .expired:
            return "exclamationmark.triangle.fill"
        case .missing:
            return "xmark.seal.fill"
        }
    }

    var color: (red: Double, green: Double, blue: Double) {
        switch self {
        case .valid:
            return (0.0, 0.8, 0.0) // Green
        case .expired:
            return (1.0, 0.6, 0.0) // Orange
        case .missing:
            return (1.0, 0.3, 0.3) // Red
        }
    }
}
