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
    private let lastSyncedLogIdKey = "HIPAA_LastSyncedLogId"

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

        // Sync audit logs when app returns to foreground
        Task {
            await syncAuditLogsToSupabase()
        }
    }

    @objc private func appDidEnterBackground() {
        updateLastActivity()

        // Sync audit logs when app goes to background
        Task {
            await syncAuditLogsToSupabase()
        }
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

        // Trigger background sync after saving new log
        Task {
            await syncAuditLogsToSupabase()
        }
    }

    // MARK: - Audit Log Sync to Supabase

    func syncAuditLogsToSupabase() async {
        let logs = getAuditLogs()
        guard !logs.isEmpty else { return }

        // Get the last synced log ID
        let lastSyncedId = userDefaults.string(forKey: lastSyncedLogIdKey)

        // Find logs that haven't been synced yet
        var unsyncedLogs: [HIPAAAuditLog] = []
        var foundLastSynced = lastSyncedId == nil // If no last sync, sync all logs

        for log in logs {
            if foundLastSynced {
                unsyncedLogs.append(log)
            } else if log.id == lastSyncedId {
                foundLastSynced = true
            }
        }

        guard !unsyncedLogs.isEmpty else {
            #if DEBUG
            print("🔒 [HIPAAComplianceManager] No unsynced logs to upload")
            #endif
            return
        }

        #if DEBUG
        print("🔒 [HIPAAComplianceManager] Syncing \(unsyncedLogs.count) unsynced logs")
        #endif

        do {
            try await NetworkService.shared.syncAuditLogs(unsyncedLogs)

            // Update the last synced log ID to the most recent one
            if let lastLog = unsyncedLogs.last {
                userDefaults.set(lastLog.id, forKey: lastSyncedLogIdKey)
                #if DEBUG
                print("🔒 [HIPAAComplianceManager] Successfully synced logs. Last synced ID: \(lastLog.id)")
                #endif
            }
        } catch {
            #if DEBUG
            print("🔒 [HIPAAComplianceManager] Failed to sync audit logs: \(error)")
            #endif
            // Don't throw - we'll retry on next sync opportunity
        }
    }

    func forceSyncAuditLogs() async {
        // Force sync all logs by clearing the last synced ID
        userDefaults.removeObject(forKey: lastSyncedLogIdKey)
        await syncAuditLogsToSupabase()
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

    struct ExportOptions {
        var includeUserProfile: Bool = true
        var includeClients: Bool = false
        var includeAnalyses: Bool = false
        var includeAuditLogs: Bool = true
    }

    func exportUserData(userId: String, options: ExportOptions = ExportOptions(), completion: @escaping @Sendable (String) -> Void) {
        Task {
            let exportData = await buildExportData(userId: userId, options: options)

            await MainActor.run {
                completion(exportData)
            }
        }
    }

    // Legacy method for backwards compatibility
    func exportAllUserData(userId: String, completion: @escaping @Sendable (String) -> Void) {
        exportUserData(userId: userId, options: ExportOptions(), completion: completion)
    }

    private func buildExportData(userId: String, options: ExportOptions) async -> String {
        var exportData = "=== HIPAA DATA EXPORT ===\n"
        exportData += "Export Date: \(Date())\n"
        exportData += "User ID: \(userId)\n\n"

        // Export user profile
        if options.includeUserProfile {
            exportData += "=== USER PROFILE ===\n"
            let user = await MainActor.run { AuthenticationManager.shared.currentUser }
            if let user = user {
                exportData += "Name: \(user.firstName ?? "") \(user.lastName ?? "")\n"
                exportData += "Email: \(user.email ?? "")\n"
                exportData += "Phone: \(user.phoneNumber ?? "")\n"
                exportData += "Role: \(user.role ?? "")\n"
                exportData += "Company ID: \(user.companyId ?? "")\n"
                exportData += "Created: \(user.createdAt ?? "")\n"
            }
            exportData += "\n"
        }

        // Export client data
        if options.includeClients {
            exportData += "=== CLIENT DATA ===\n"
            do {
                let companyId = await MainActor.run { AuthenticationManager.shared.currentUser?.companyId ?? "" }
                let clients = try await NetworkService.shared.fetchClientsByCompany(companyId: companyId)
                for client in clients {
                    exportData += "Client ID: \(client.id ?? "")\n"
                    exportData += "Name: \(client.name ?? "")\n"
                    exportData += "Email: \(client.email ?? "")\n"
                    exportData += "Phone: \(client.phone ?? "")\n"

                    // Medical Information (PHI)
                    if let medicalHistory = client.medicalHistory, !medicalHistory.isEmpty {
                        exportData += "Medical History: \(medicalHistory)\n"
                    }
                    if let allergies = client.allergies, !allergies.isEmpty {
                        exportData += "Allergies: \(allergies)\n"
                    }
                    if let sensitivities = client.knownSensitivities, !sensitivities.isEmpty {
                        exportData += "Known Sensitivities: \(sensitivities)\n"
                    }
                    if let medications = client.medications, !medications.isEmpty {
                        exportData += "Medications/Supplements: \(medications)\n"
                    }
                    if let productsToAvoid = client.productsToAvoid, !productsToAvoid.isEmpty {
                        exportData += "Products to Avoid: \(productsToAvoid)\n"
                    }

                    // Injectable History
                    if let fillersDate = client.fillersDate {
                        exportData += "Last Fillers: \(fillersDate)\n"
                    }
                    if let biostimulatorsDate = client.biostimulatorsDate {
                        exportData += "Last Biostimulators: \(biostimulatorsDate)\n"
                    }

                    // Consent Information
                    if let consentDate = client.consentDate {
                        exportData += "HIPAA Consent Date: \(consentDate)\n"
                    }
                    if let consentSignature = client.consentSignature, !consentSignature.isEmpty {
                        exportData += "Consent Signature: [SIGNED]\n"
                    }

                    // Notes
                    if let notes = client.notes, !notes.isEmpty {
                        exportData += "Notes: \(notes)\n"
                    }

                    exportData += "---\n"
                }
            } catch {
                exportData += "Error fetching clients: \(error.localizedDescription)\n"
            }
            exportData += "\n"
        }

        // Export analysis data
        if options.includeAnalyses {
            exportData += "=== ANALYSIS DATA ===\n"
            do {
                let companyId = await MainActor.run { AuthenticationManager.shared.currentUser?.companyId ?? "" }
                let clients = try await NetworkService.shared.fetchClientsByCompany(companyId: companyId)
                for client in clients {
                    if let clientId = client.id {
                        let analyses = try await NetworkService.shared.fetchAnalyses(clientId: clientId)
                        for analysis in analyses {
                            exportData += "Analysis ID: \(analysis.id ?? "")\n"
                            exportData += "Client: \(client.name ?? "")\n"
                            exportData += "Date: \(analysis.createdAt ?? "")\n"

                            // Image Reference
                            if let imageUrl = analysis.imageUrl {
                                exportData += "Image URL: \(imageUrl)\n"
                            }

                            // Analysis Results
                            if let results = analysis.analysisResults {
                                exportData += "\nAnalysis Results:\n"
                                exportData += "  Skin Type: \(results.skinType ?? "N/A")\n"
                                exportData += "  Hydration Level: \(results.hydrationLevel ?? 0)%\n"
                                exportData += "  Sensitivity: \(results.sensitivity ?? "N/A")\n"
                                exportData += "  Pore Condition: \(results.poreCondition ?? "N/A")\n"
                                exportData += "  Health Score: \(results.skinHealthScore ?? 0)/10\n"

                                if let concerns = results.concerns, !concerns.isEmpty {
                                    exportData += "  Concerns: \(concerns.joined(separator: ", "))\n"
                                }

                                if let recommendations = results.recommendations, !recommendations.isEmpty {
                                    exportData += "  Recommendations:\n"
                                    for rec in recommendations {
                                        exportData += "    - \(rec)\n"
                                    }
                                }

                                if let productRecs = results.productRecommendations, !productRecs.isEmpty {
                                    exportData += "  Product Recommendations:\n"
                                    for product in productRecs {
                                        exportData += "    - \(product)\n"
                                    }
                                }

                                if let medicalConsiderations = results.medicalConsiderations, !medicalConsiderations.isEmpty {
                                    exportData += "  Medical Considerations:\n"
                                    for consideration in medicalConsiderations {
                                        exportData += "    - \(consideration)\n"
                                    }
                                }

                                if let progressNotes = results.progressNotes, !progressNotes.isEmpty {
                                    exportData += "  Progress Notes:\n"
                                    for note in progressNotes {
                                        exportData += "    - \(note)\n"
                                    }
                                }
                            }

                            // Treatment Information
                            if let productsUsed = analysis.productsUsed, !productsUsed.isEmpty {
                                exportData += "\nProducts Used: \(productsUsed)\n"
                            }
                            if let treatments = analysis.treatmentsPerformed, !treatments.isEmpty {
                                exportData += "Treatments Performed: \(treatments)\n"
                            }

                            // Provider Notes
                            if let notes = analysis.notes, !notes.isEmpty {
                                exportData += "Provider Notes: \(notes)\n"
                            }

                            exportData += "---\n"
                        }
                    }
                }
            } catch {
                exportData += "Error fetching analyses: \(error.localizedDescription)\n"
            }
            exportData += "\n"
        }

        // Export audit logs
        if options.includeAuditLogs {
            exportData += "=== AUDIT LOGS ===\n"
            exportData += exportAuditLogs()
            exportData += "\n"
        }

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
