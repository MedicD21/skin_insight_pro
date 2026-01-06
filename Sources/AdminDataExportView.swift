import SwiftUI

struct AdminDataExportView: View {
    @ObservedObject var theme = ThemeManager.shared
    @StateObject private var complianceManager = HIPAAComplianceManager.shared
    @StateObject private var authManager = AuthenticationManager.shared
    @Environment(\.dismiss) var dismiss

    @State private var includeUserProfile = true
    @State private var includeClients = true
    @State private var includeAnalyses = true
    @State private var includeAuditLogs = true
    @State private var isExporting = false
    @State private var exportedData: String = ""
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationStack {
            ZStack {
                theme.primaryBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        headerSection

                        exportOptionsSection

                        exportButtonSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 20)
                }

                if isExporting {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()

                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(theme.accent)

                        Text("Exporting Data...")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                    }
                }
            }
            .navigationTitle("Export Company Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .sheet(isPresented: .constant(!exportedData.isEmpty)) {
                ExportDataView(data: $exportedData)
            }
        }
    }

    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "square.and.arrow.down.fill")
                .font(.system(size: 50))
                .foregroundColor(theme.accent)

            Text("Company Data Export")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(theme.primaryText)

            Text("Select the data you want to export. This export is for administrative and compliance purposes only.")
                .font(.system(size: 15))
                .foregroundColor(theme.secondaryText)
                .multilineTextAlignment(.center)
        }
    }

    private var exportOptionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Select Data to Export")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(theme.primaryText)

            VStack(spacing: 12) {
                exportOption(
                    title: "User Profile",
                    description: "Your account information and settings",
                    icon: "person.fill",
                    isSelected: $includeUserProfile
                )

                exportOption(
                    title: "Client Data",
                    description: "All client profiles, medical information, and consent records",
                    icon: "person.2.fill",
                    isSelected: $includeClients
                )

                exportOption(
                    title: "Analysis Data",
                    description: "All skin analyses, results, and recommendations",
                    icon: "doc.text.fill",
                    isSelected: $includeAnalyses
                )

                exportOption(
                    title: "Audit Logs",
                    description: "Activity logs and access records for compliance",
                    icon: "list.clipboard.fill",
                    isSelected: $includeAuditLogs
                )
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: theme.radiusXL)
                .fill(theme.cardBackground)
                .shadow(color: theme.shadowColor, radius: theme.shadowRadiusSmall, x: 0, y: 4)
        )
    }

    private func exportOption(
        title: String,
        description: String,
        icon: String,
        isSelected: Binding<Bool>
    ) -> some View {
        Button(action: {
            isSelected.wrappedValue.toggle()
        }) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(theme.accent)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(theme.primaryText)

                    Text(description)
                        .font(.system(size: 13))
                        .foregroundColor(theme.secondaryText)
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                Image(systemName: isSelected.wrappedValue ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24))
                    .foregroundColor(isSelected.wrappedValue ? theme.accent : theme.tertiaryText)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: theme.radiusMedium)
                    .fill(isSelected.wrappedValue ? theme.accent.opacity(0.1) : theme.tertiaryBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: theme.radiusMedium)
                    .stroke(isSelected.wrappedValue ? theme.accent : theme.border, lineWidth: isSelected.wrappedValue ? 2 : 1)
            )
        }
    }

    private var exportButtonSection: some View {
        VStack(spacing: 16) {
            Button(action: exportData) {
                HStack {
                    Image(systemName: "arrow.down.doc.fill")
                    Text("Export Selected Data")
                }
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(hasSelection ? theme.accent : theme.tertiaryText)
                .clipShape(RoundedRectangle(cornerRadius: theme.radiusMedium))
            }
            .disabled(!hasSelection)

            Text("Exported data will be provided in text format that you can save or share securely.")
                .font(.system(size: 13))
                .foregroundColor(theme.secondaryText)
                .multilineTextAlignment(.center)
        }
    }

    private var hasSelection: Bool {
        includeUserProfile || includeClients || includeAnalyses || includeAuditLogs
    }

    private func exportData() {
        guard let userId = authManager.currentUser?.id else { return }

        isExporting = true

        let options = HIPAAComplianceManager.ExportOptions(
            includeUserProfile: includeUserProfile,
            includeClients: includeClients,
            includeAnalyses: includeAnalyses,
            includeAuditLogs: includeAuditLogs
        )

        complianceManager.exportUserData(userId: userId, options: options) { data in
            Task { @MainActor in
                exportedData = data
                isExporting = false

                // Log export event
                if let email = authManager.currentUser?.email {
                    complianceManager.logEvent(
                        eventType: .dataExported,
                        userId: userId,
                        userEmail: email,
                        resourceType: "COMPANY_DATA",
                        resourceId: userId
                    )
                }
            }
        }
    }
}
