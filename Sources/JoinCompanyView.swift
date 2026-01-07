import SwiftUI

struct JoinCompanyView: View {
    @ObservedObject var theme = ThemeManager.shared
    @StateObject private var authManager = AuthenticationManager.shared
    @Environment(\.dismiss) var dismiss

    @State private var companyCode: String = ""
    @State private var isJoining = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showSuccess = false

    var body: some View {
        NavigationStack {
            ZStack {
                theme.primaryBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        headerSection

                        instructionsSection

                        codeInputSection

                        joinButton
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 100)
                }

                if isJoining {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()

                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(theme.accent)
                }
            }
            .navigationTitle("Join Company")
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
            .alert("Success", isPresented: $showSuccess) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("You have successfully joined the company!")
            }
        }
    }

    private var headerSection: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(theme.accent.opacity(0.15))
                    .frame(width: 100, height: 100)

                Image(systemName: "building.2.fill")
                    .font(.system(size: 50))
                    .foregroundColor(theme.accent)
            }

            Text("Join a Company")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(theme.primaryText)
        }
        .frame(maxWidth: .infinity)
    }

    private var instructionsSection: some View {
        VStack(spacing: 12) {
            Text("How it works")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(theme.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 12) {
                instructionRow(number: 1, text: "Get the company code from your team administrator")
                instructionRow(number: 2, text: "Enter the code below")
                instructionRow(number: 3, text: "Access shared clients and collaborate with your team")
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: theme.radiusXL)
                .fill(theme.cardBackground)
                .shadow(color: theme.shadowColor, radius: theme.shadowRadiusMedium, x: 0, y: 8)
        )
    }

    private func instructionRow(number: Int, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(theme.accent)
                    .frame(width: 24, height: 24)

                Text("\(number)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
            }

            Text(text)
                .font(.system(size: 15))
                .foregroundColor(theme.primaryText)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
        }
    }


    private var codeInputSection: some View {
        VStack(spacing: 16) {
            Text("Company Code")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(theme.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)

            TextField("Enter company code", text: $companyCode)
                .font(.system(size: 17))
                .foregroundColor(theme.primaryText)
                .autocapitalization(.none)
                .autocorrectionDisabled()
                .padding(16)
                .background(theme.tertiaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: theme.radiusMedium))
                .overlay(
                    RoundedRectangle(cornerRadius: theme.radiusMedium)
                        .stroke(theme.border, lineWidth: 1)
                )
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: theme.radiusXL)
                .fill(theme.cardBackground)
                .shadow(color: theme.shadowColor, radius: theme.shadowRadiusMedium, x: 0, y: 8)
        )
    }

    private var joinButton: some View {
        Button(action: { joinCompany() }) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                Text("Join Company")
            }
            .font(.system(size: 17, weight: .semibold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(companyCode.isEmpty ? theme.tertiaryText : theme.accent)
            .clipShape(RoundedRectangle(cornerRadius: theme.radiusMedium))
        }
        .disabled(companyCode.isEmpty || isJoining)
    }

    private func joinCompany() {
        let trimmedCode = companyCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedCode.isEmpty else { return }

        isJoining = true

        Task {
            do {
                let company = try await NetworkService.shared.fetchCompanyByCode(trimmedCode)
                guard let company else {
                    errorMessage = "Company code not found. Please check the code and try again."
                    showError = true
                    isJoining = false
                    return
                }

                // Update user's company_id
                guard var user = authManager.currentUser else {
                    errorMessage = "User not found. Please log in again."
                    showError = true
                    isJoining = false
                    return
                }

                guard let companyId = company.id else {
                    errorMessage = "Company details are unavailable. Please try again later."
                    showError = true
                    isJoining = false
                    return
                }

                user.companyId = companyId
                if let companyName = company.name, !companyName.isEmpty {
                    user.companyName = companyName
                }
                let updatedUser = try await NetworkService.shared.updateUserProfile(user)

                // Update local user state
                authManager.currentUser = updatedUser

                showSuccess = true
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }

            isJoining = false
        }
    }
}
