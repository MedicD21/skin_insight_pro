import SwiftUI

struct HIPAADataManagementView: View {
    @ObservedObject var theme = ThemeManager.shared
    @StateObject private var complianceManager = HIPAAComplianceManager.shared
    @StateObject private var authManager = AuthenticationManager.shared
    @Environment(\.dismiss) var dismiss

    @State private var showingExportConfirmation = false
    @State private var showingDeleteConfirmation = false
    @State private var exportedData: String = ""
    @State private var isExporting = false
    @State private var isDeleting = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showSuccess = false
    @State private var successMessage = ""

    var body: some View {
        NavigationStack {
            ZStack {
                theme.primaryBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        headerSection

                        consentInfoSection

                        dataExportSection

                        dataDeleteSection

                        // Only show audit logs to admins
                        if authManager.currentUser?.isAdmin == true {
                            auditLogSection
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 20)
                }

                if isExporting || isDeleting {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()

                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(theme.accent)
                }
            }
            .navigationTitle("Privacy & Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .alert("Export Data", isPresented: $showingExportConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Export") {
                    exportData()
                }
            } message: {
                Text("Export your personal data including profile information and activity logs?")
            }
            .alert("Delete Account", isPresented: $showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    deleteAllData()
                }
            } message: {
                Text("This will permanently delete your user account and personal activity logs. Client data will be preserved for your company. This action cannot be undone.")
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .alert("Success", isPresented: $showSuccess) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(successMessage)
            }
            .sheet(isPresented: .constant(!exportedData.isEmpty)) {
                ExportDataView(data: $exportedData)
            }
        }
    }

    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 50))
                .foregroundColor(theme.accent)

            Text("Your Privacy Rights")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(theme.primaryText)

            Text("Manage your data and privacy settings")
                .font(.system(size: 15))
                .foregroundColor(theme.secondaryText)
        }
    }

    private var consentInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "checkmark.shield.fill")
                    .foregroundColor(.green)
                Text("Consent Status")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(theme.primaryText)
            }

            if complianceManager.hasGivenConsent() {
                if let consentDate = complianceManager.getConsentDate() {
                    Text("Consent given on \(consentDate.formatted(date: .long, time: .omitted))")
                        .font(.system(size: 14))
                        .foregroundColor(theme.secondaryText)
                }
            } else {
                Text("No consent recorded")
                    .font(.system(size: 14))
                    .foregroundColor(.red)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: theme.radiusMedium)
                .fill(theme.cardBackground)
                .shadow(color: theme.shadowColor, radius: theme.shadowRadiusSmall, x: 0, y: 4)
        )
    }

    private var dataExportSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "square.and.arrow.up.fill")
                    .foregroundColor(theme.accent)
                Text("Export Your Data")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(theme.primaryText)
            }

            // Different text for admins vs regular users
            if authManager.currentUser?.isAdmin == true {
                Text("Download a copy of your data including profile information and activity logs. Client data can be exported by your clients individually.")
                    .font(.system(size: 14))
                    .foregroundColor(theme.secondaryText)
            } else {
                Text("Download a copy of your personal data including profile information and your activity logs. This is your right under HIPAA.")
                    .font(.system(size: 14))
                    .foregroundColor(theme.secondaryText)
            }

            Button(action: { showingExportConfirmation = true }) {
                HStack {
                    Image(systemName: "arrow.down.doc.fill")
                    Text("Export My Data")
                }
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(14)
                .background(theme.accent)
                .clipShape(RoundedRectangle(cornerRadius: theme.radiusMedium))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: theme.radiusMedium)
                .fill(theme.cardBackground)
                .shadow(color: theme.shadowColor, radius: theme.shadowRadiusSmall, x: 0, y: 4)
        )
    }

    private var dataDeleteSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "trash.fill")
                    .foregroundColor(.red)
                Text("Delete Your Data")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(theme.primaryText)
            }

            Text("Permanently delete your user account and personal activity logs. Note: Client data you created will be preserved and remain accessible to your company for continuity of care.")
                .font(.system(size: 14))
                .foregroundColor(theme.secondaryText)

            Button(action: { showingDeleteConfirmation = true }) {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text("Delete All Data")
                }
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(14)
                .background(Color.red)
                .clipShape(RoundedRectangle(cornerRadius: theme.radiusMedium))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: theme.radiusMedium)
                .fill(theme.cardBackground)
                .shadow(color: theme.shadowColor, radius: theme.shadowRadiusSmall, x: 0, y: 4)
        )
    }

    private var auditLogSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "list.clipboard.fill")
                    .foregroundColor(theme.accent)
                Text("Recent Activity")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(theme.primaryText)
            }

            let recentLogs = Array(complianceManager.getAuditLogs().suffix(5))

            if recentLogs.isEmpty {
                Text("No activity recorded yet")
                    .font(.system(size: 14))
                    .foregroundColor(theme.secondaryText)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(recentLogs) { log in
                        HStack {
                            Image(systemName: iconForEventType(log.eventType))
                                .font(.system(size: 12))
                                .foregroundColor(theme.secondaryText)
                                .frame(width: 20)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(log.eventType.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(theme.primaryText)

                                Text(log.formattedTimestamp)
                                    .font(.system(size: 11))
                                    .foregroundColor(theme.secondaryText)
                            }

                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: theme.radiusMedium)
                .fill(theme.cardBackground)
                .shadow(color: theme.shadowColor, radius: theme.shadowRadiusSmall, x: 0, y: 4)
        )
    }

    private func iconForEventType(_ type: HIPAAEventType) -> String {
        switch type {
        case .clientViewed, .analysisViewed:
            return "eye.fill"
        case .clientCreated, .clientUpdated, .analysisCreated:
            return "plus.circle.fill"
        case .clientDeleted, .analysisDeleted:
            return "trash.fill"
        case .userLogin:
            return "arrow.right.circle.fill"
        case .userLogout:
            return "arrow.left.circle.fill"
        case .dataExported:
            return "square.and.arrow.up.fill"
        case .passwordChanged:
            return "lock.rotation.fill"
        case .unauthorizedAccess:
            return "exclamationmark.shield.fill"
        case .sessionTimeout:
            return "clock.fill"
        }
    }

    private func exportData() {
        guard let userId = authManager.currentUser?.id,
              let email = authManager.currentUser?.email else { return }

        isExporting = true

        complianceManager.exportAllUserData(userId: userId) { data in
            Task { @MainActor in
                exportedData = data
                isExporting = false

                // Log export event
                complianceManager.logEvent(
                    eventType: .dataExported,
                    userId: userId,
                    userEmail: email,
                    resourceType: "ALL_DATA",
                    resourceId: userId
                )
            }
        }
    }

    private func deleteAllData() {
        guard let userId = authManager.currentUser?.id else { return }

        isDeleting = true

        Task {
            do {
                // Delete user account (this would cascade delete all related data)
                try await NetworkService.shared.deleteUser(userId: userId)

                await MainActor.run {
                    isDeleting = false
                    successMessage = "All data has been deleted successfully"
                    showSuccess = true

                    // Logout after successful deletion
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        authManager.logout()
                    }
                }
            } catch {
                await MainActor.run {
                    isDeleting = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
}

struct ExportDataView: View {
    @ObservedObject var theme = ThemeManager.shared
    @Environment(\.dismiss) var dismiss
    @Binding var data: String

    var body: some View {
        NavigationStack {
            ZStack {
                theme.primaryBackground
                    .ignoresSafeArea()

                ScrollView {
                    Text(data)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(theme.primaryText)
                        .padding(20)
                        .textSelection(.enabled)
                }
            }
            .navigationTitle("Exported Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        data = ""
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    ShareLink(item: exportedDataAsText) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
    }

    private var exportedDataAsText: String {
        data
    }
}
