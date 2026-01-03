import Foundation
import SwiftUI

// MARK: - HIPAA Audit Event Types
enum HIPAAEventType: String, Codable {
    case clientViewed = "CLIENT_VIEWED"
    case clientCreated = "CLIENT_CREATED"
    case clientUpdated = "CLIENT_UPDATED"
    case clientDeleted = "CLIENT_DELETED"
    case analysisViewed = "ANALYSIS_VIEWED"
    case analysisCreated = "ANALYSIS_CREATED"
    case analysisDeleted = "ANALYSIS_DELETED"
    case userLogin = "USER_LOGIN"
    case userLogout = "USER_LOGOUT"
    case dataExported = "DATA_EXPORTED"
    case passwordChanged = "PASSWORD_CHANGED"
    case unauthorizedAccess = "UNAUTHORIZED_ACCESS_ATTEMPT"
    case sessionTimeout = "SESSION_TIMEOUT"
}

// MARK: - Audit Log Entry
struct HIPAAAuditLog: Codable, Identifiable {
    let id: String
    let userId: String
    let userEmail: String
    let eventType: HIPAAEventType
    let resourceType: String?
    let resourceId: String?
    let timestamp: Date
    let ipAddress: String?
    let deviceInfo: String

    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter.string(from: timestamp)
    }
}

// MARK: - HIPAA Compliance Manager
class HIPAAComplianceManager: ObservableObject {
    static let shared = HIPAAComplianceManager()

    @Published var sessionExpiryTime: Date?
    @Published var isSessionExpired = false
    @Published var hasUserConsented: Bool

    private let sessionTimeout: TimeInterval = 15 * 60 // 15 minutes
    private var inactivityTimer: Timer?
    private let userDefaults = UserDefaults.standard

    // Keys for UserDefaults
    private let lastActivityKey = "HIPAA_LastActivityTime"
    private let auditLogsKey = "HIPAA_AuditLogs"
    private let consentGivenKey = "HIPAA_ConsentGiven"
    private let consentDateKey = "HIPAA_ConsentDate"

    private init() {
        self.hasUserConsented = userDefaults.bool(forKey: consentGivenKey)
        setupInactivityMonitoring()
    }

    // MARK: - Session Management

    func setupInactivityMonitoring() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(userActivityDetected),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
    }

    func startSessionMonitoring() {
        updateLastActivity()
        startInactivityTimer()
    }

    func stopSessionMonitoring() {
        inactivityTimer?.invalidate()
        inactivityTimer = nil
    }

    @objc private func userActivityDetected() {
        updateLastActivity()
        checkSessionExpiry()
    }

    @objc private func appDidEnterBackground() {
        updateLastActivity()
    }

    private func updateLastActivity() {
        let now = Date()
        userDefaults.set(now, forKey: lastActivityKey)
        sessionExpiryTime = now.addingTimeInterval(sessionTimeout)
        isSessionExpired = false

        // Reset timer
        startInactivityTimer()
    }

    private func startInactivityTimer() {
        inactivityTimer?.invalidate()
        inactivityTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.checkSessionExpiry()
        }
    }

    private func checkSessionExpiry() {
        guard let lastActivity = userDefaults.object(forKey: lastActivityKey) as? Date else {
            return
        }

        let timeSinceLastActivity = Date().timeIntervalSince(lastActivity)

        if timeSinceLastActivity >= sessionTimeout {
            handleSessionExpiry()
        }
    }

    private func handleSessionExpiry() {
        isSessionExpired = true
        stopSessionMonitoring()

        // Log session timeout
        Task { @MainActor in
            if let userId = AuthenticationManager.shared.currentUser?.id,
               let email = AuthenticationManager.shared.currentUser?.email {
                logEvent(
                    eventType: .sessionTimeout,
                    userId: userId,
                    userEmail: email,
                    resourceType: nil,
                    resourceId: nil
                )
            }
        }

        // Clear session
        Task { @MainActor in
            AuthenticationManager.shared.logout()
        }
    }

    func resetSessionTimer() {
        updateLastActivity()
    }

    // MARK: - Audit Logging

    func logEvent(
        eventType: HIPAAEventType,
        userId: String,
        userEmail: String,
        resourceType: String? = nil,
        resourceId: String? = nil
    ) {
        let deviceInfo = "\(UIDevice.current.model) - iOS \(UIDevice.current.systemVersion)"

        let auditLog = HIPAAAuditLog(
            id: UUID().uuidString,
            userId: userId,
            userEmail: userEmail,
            eventType: eventType,
            resourceType: resourceType,
            resourceId: resourceId,
            timestamp: Date(),
            ipAddress: nil, // Could be enhanced with actual IP detection
            deviceInfo: deviceInfo
        )

        saveAuditLog(auditLog)

        #if DEBUG
        print("🔒 HIPAA Audit: \(eventType.rawValue) - User: \(userEmail) - Resource: \(resourceType ?? "N/A")")
        #endif
    }

    private func saveAuditLog(_ log: HIPAAAuditLog) {
        var logs = getAuditLogs()
        logs.append(log)

        // Keep only last 1000 logs locally (send to server for permanent storage)
        if logs.count > 1000 {
            logs = Array(logs.suffix(1000))
        }

        if let encoded = try? JSONEncoder().encode(logs) {
            userDefaults.set(encoded, forKey: auditLogsKey)
        }
    }

    func getAuditLogs() -> [HIPAAAuditLog] {
        guard let data = userDefaults.data(forKey: auditLogsKey),
              let logs = try? JSONDecoder().decode([HIPAAAuditLog].self, from: data) else {
            return []
        }
        return logs
    }

    func exportAuditLogs() -> String {
        let logs = getAuditLogs()
        var csv = "Timestamp,User ID,User Email,Event Type,Resource Type,Resource ID,Device Info\n"

        for log in logs {
            csv += "\(log.formattedTimestamp),\(log.userId),\(log.userEmail),\(log.eventType.rawValue),\(log.resourceType ?? ""),\(log.resourceId ?? ""),\(log.deviceInfo)\n"
        }

        return csv
    }

    // MARK: - Privacy Consent

    func hasGivenConsent() -> Bool {
        return hasUserConsented
    }

    func recordConsent() {
        userDefaults.set(true, forKey: consentGivenKey)
        userDefaults.set(Date(), forKey: consentDateKey)
        hasUserConsented = true
    }

    func getConsentDate() -> Date? {
        return userDefaults.object(forKey: consentDateKey) as? Date
    }

    func revokeConsent() {
        userDefaults.set(false, forKey: consentGivenKey)
        userDefaults.removeObject(forKey: consentDateKey)
        hasUserConsented = false
    }

    // MARK: - Data Export (Right of Access)

    func exportAllUserData(userId: String, completion: @escaping @Sendable (String) -> Void) {
        Task {
            let exportData = buildExportData(userId: userId)

            await MainActor.run {
                completion(exportData)
            }
        }
    }

    private func buildExportData(userId: String) -> String {
        var exportData = "=== HIPAA DATA EXPORT ===\n"
        exportData += "Export Date: \(Date())\n"
        exportData += "User ID: \(userId)\n\n"

        // Export audit logs
        exportData += "=== AUDIT LOGS ===\n"
        exportData += exportAuditLogs()
        exportData += "\n"

        // Note: In a full implementation, you would also export:
        // - All client data
        // - All analysis data
        // - User profile data
        // This would require additional NetworkService methods

        return exportData
    }

    // MARK: - Encryption Helper (For local storage)

    func encryptSensitiveData(_ data: String) -> String? {
        // Basic encryption for local storage
        // In production, use proper encryption like CryptoKit
        guard let data = data.data(using: .utf8) else { return nil }
        return data.base64EncodedString()
    }

    func decryptSensitiveData(_ encrypted: String) -> String? {
        guard let data = Data(base64Encoded: encrypted) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - View Modifier for Activity Tracking
struct HIPAAActivityTracker: ViewModifier {
    func body(content: Content) -> some View {
        content
            .onAppear {
                HIPAAComplianceManager.shared.resetSessionTimer()
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        HIPAAComplianceManager.shared.resetSessionTimer()
                    }
            )
            .onTapGesture {
                HIPAAComplianceManager.shared.resetSessionTimer()
            }
    }
}

extension View {
    func trackHIPAAActivity() -> some View {
        modifier(HIPAAActivityTracker())
    }
}
