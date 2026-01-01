import SwiftUI

struct TeamMembersView: View {
    @ObservedObject var theme = ThemeManager.shared
    @StateObject private var authManager = AuthenticationManager.shared
    @Environment(\.dismiss) var dismiss

    @State private var teamMembers: [AppUser] = []
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var companyId: String = ""
    @State private var showCopiedConfirmation = false
    @State private var updatingUserId: String?
    @State private var showEditCompanyCode = false
    @State private var showEmployeeImport = false

    var body: some View {
        NavigationStack {
            ZStack {
                theme.primaryBackground
                    .ignoresSafeArea()

                if isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(theme.accent)
                } else {
                    mainContent
                }
            }
            .navigationTitle("Team Members")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }

                if authManager.currentUser?.isAdmin == true {
                    ToolbarItem(placement: .primaryAction) {
                        Button(action: { showEmployeeImport = true }) {
                            Image(systemName: "square.and.arrow.down")
                        }
                    }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .task {
                await loadTeamMembers()
            }
            .refreshable {
                await loadTeamMembers()
            }
            .sheet(isPresented: $showEditCompanyCode) {
                EditCompanyCodeView(companyId: $companyId)
            }
            .sheet(isPresented: $showEmployeeImport, onDismiss: {
                Task {
                    await loadTeamMembers()
                }
            }) {
                EmployeeImportView()
            }
            .overlay(alignment: .bottom) {
                if showCopiedConfirmation {
                    copiedConfirmationToast
                }
            }
        }
    }

    private var mainContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                companyCodeSection

                if !teamMembers.isEmpty {
                    teamMembersListSection
                } else {
                    Text("No team members found")
                        .font(.system(size: 15))
                        .foregroundColor(theme.secondaryText)
                        .padding(40)
                        .onAppear {
                            print("📋 TeamMembersView: Showing 'No team members' - array count is \(teamMembers.count)")
                        }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 100)
        }
    }

    private var companyCodeSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Company Code")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(theme.primaryText)

                Spacer()

                if authManager.currentUser?.isAdmin == true {
                    Button(action: { showEditCompanyCode = true }) {
                        HStack(spacing: 4) {
                            Image(systemName: "pencil")
                                .font(.system(size: 13))
                            Text("Edit")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundColor(theme.accent)
                    }
                }
            }

            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "building.2")
                        .font(.system(size: 20))
                        .foregroundColor(theme.accent)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Share this code")
                            .font(.system(size: 13))
                            .foregroundColor(theme.secondaryText)

                        Text(companyId.isEmpty ? "No company" : companyId)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(theme.primaryText)
                            .textSelection(.enabled)
                    }

                    Spacer()

                    if !companyId.isEmpty {
                        Button {
                            UIPasteboard.general.string = companyId
                            showCopiedConfirmation = true

                            // Hide confirmation after 2 seconds
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                showCopiedConfirmation = false
                            }
                        } label: {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 18))
                                .foregroundColor(theme.accent)
                                .padding(8)
                                .background(theme.accent.opacity(0.1))
                                .clipShape(Circle())
                        }
                    }
                }
                .padding(16)
                .background(theme.tertiaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: theme.radiusMedium))

                Text("Team members can join by going to Profile > Join Company and entering this code")
                    .font(.system(size: 13))
                    .foregroundColor(theme.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: theme.radiusXL)
                .fill(theme.cardBackground)
                .shadow(color: theme.shadowColor, radius: theme.shadowRadiusMedium, x: 0, y: 8)
        )
    }

    private var teamMembersListSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Team Members")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(theme.primaryText)

                Spacer()

                Text("\(teamMembers.count)")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(theme.secondaryText)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(theme.tertiaryBackground)
                    .clipShape(Capsule())
            }

            VStack(spacing: 12) {
                ForEach(teamMembers) { member in
                    teamMemberRow(member: member)

                    if member.id != teamMembers.last?.id {
                        Divider()
                            .padding(.leading, 56)
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: theme.radiusXL)
                .fill(theme.cardBackground)
                .shadow(color: theme.shadowColor, radius: theme.shadowRadiusMedium, x: 0, y: 8)
        )
    }

    private func teamMemberRow(member: AppUser) -> some View {
        HStack(spacing: 12) {
            // Profile image or placeholder
            if let profileImageUrl = member.profileImageUrl,
               !profileImageUrl.isEmpty,
               let url = URL(string: profileImageUrl) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 44, height: 44)
                            .clipShape(Circle())
                    default:
                        Circle()
                            .fill(theme.accent.opacity(0.15))
                            .frame(width: 44, height: 44)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(theme.accent)
                            )
                    }
                }
            } else {
                Circle()
                    .fill(theme.accent.opacity(0.15))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 20))
                            .foregroundColor(theme.accent)
                    )
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text("\(member.firstName ?? "") \(member.lastName ?? "")".trimmingCharacters(in: .whitespaces))
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(theme.primaryText)

                    if member.id == authManager.currentUser?.id {
                        Text("(You)")
                            .font(.system(size: 13))
                            .foregroundColor(theme.secondaryText)
                    }
                }

                if let role = member.role, !role.isEmpty {
                    Text(role)
                        .font(.system(size: 13))
                        .foregroundColor(theme.secondaryText)
                }
            }

            Spacer()

            // Show admin toggle for admins, badge for everyone else
            if member.isAdmin == true {
                // Show admin badge for all users
                Text("Admin")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(theme.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(theme.accent.opacity(0.15))
                    .clipShape(Capsule())
            }

            // Only show toggle if current user is admin
            if authManager.currentUser?.isAdmin == true {
                if updatingUserId == member.id {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Toggle("", isOn: Binding(
                        get: { member.isAdmin ?? false },
                        set: { newValue in
                            toggleAdminStatus(for: member, isAdmin: newValue)
                        }
                    ))
                    .labelsHidden()
                    .tint(theme.accent)
                }
            }
        }
        .padding(.vertical, 8)
    }

    private var copiedConfirmationToast: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.white)
            Text("Code copied to clipboard")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color.green)
        .clipShape(Capsule())
        .padding(.bottom, 100)
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .animation(.spring(), value: showCopiedConfirmation)
    }

    private func toggleAdminStatus(for member: AppUser, isAdmin: Bool) {
        guard let memberId = member.id else { return }

        updatingUserId = memberId

        Task {
            do {
                try await NetworkService.shared.updateUserAdminStatus(userId: memberId, isAdmin: isAdmin)

                // Update local array
                if let index = teamMembers.firstIndex(where: { $0.id == memberId }) {
                    teamMembers[index].isAdmin = isAdmin
                }

                updatingUserId = nil
            } catch {
                updatingUserId = nil
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }

    private func loadTeamMembers() async {
        guard let companyId = authManager.currentUser?.companyId else {
            print("❌ TeamMembersView: No company ID for current user")
            errorMessage = "No company associated with your account"
            return
        }

        print("📋 TeamMembersView: Loading team members for company: \(companyId)")
        self.companyId = companyId
        isLoading = true
        defer { isLoading = false }

        do {
            let members = try await NetworkService.shared.fetchTeamMembers(companyId: companyId)
            print("📋 TeamMembersView: Received \(members.count) members")
            print("📋 TeamMembersView: Members: \(members.map { "\($0.firstName ?? "") \($0.lastName ?? "") (\($0.email ?? ""))" })")
            teamMembers = members
            print("📋 TeamMembersView: teamMembers array updated with \(teamMembers.count) members")
        } catch {
            print("❌ TeamMembersView: Error loading team members: \(error)")
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

struct EditCompanyCodeView: View {
    @ObservedObject var theme = ThemeManager.shared
    @StateObject private var authManager = AuthenticationManager.shared
    @Environment(\.dismiss) var dismiss

    @Binding var companyId: String
    @State private var newCompanyCode: String = ""
    @State private var isSaving = false
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationStack {
            ZStack {
                theme.primaryBackground
                    .ignoresSafeArea()

                VStack(spacing: 24) {
                    VStack(spacing: 16) {
                        Image(systemName: "building.2.fill")
                            .font(.system(size: 50))
                            .foregroundColor(theme.accent)

                        Text("Edit Company Code")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(theme.primaryText)

                        Text("Choose a custom code for your company. This code will be used by team members to join your company.")
                            .font(.system(size: 15))
                            .foregroundColor(theme.secondaryText)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                    }
                    .padding(.top, 40)

                    VStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Company Code")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(theme.secondaryText)

                            TextField("Enter custom code", text: $newCompanyCode)
                                .font(.system(size: 17))
                                .foregroundColor(theme.primaryText)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                                .padding(16)
                                .background(theme.tertiaryBackground)
                                .clipShape(RoundedRectangle(cornerRadius: theme.radiusMedium))
                                .overlay(
                                    RoundedRectangle(cornerRadius: theme.radiusMedium)
                                        .stroke(theme.border, lineWidth: 1)
                                )

                            Text("Use letters, numbers, hyphens, or underscores. Keep it simple and memorable.")
                                .font(.system(size: 13))
                                .foregroundColor(theme.secondaryText)
                        }
                    }
                    .padding(.horizontal, 20)

                    Spacer()
                }

                if isSaving {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()

                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(theme.accent)
                }
            }
            .navigationTitle("Company Code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveCompanyCode()
                    }
                    .disabled(newCompanyCode.isEmpty || isSaving)
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .onAppear {
                newCompanyCode = companyId
            }
        }
    }

    private func saveCompanyCode() {
        guard let currentCompanyId = authManager.currentUser?.companyId else { return }

        isSaving = true

        Task {
            do {
                // Update the company ID in the database
                try await NetworkService.shared.updateCompanyId(oldId: currentCompanyId, newId: newCompanyCode)

                // Update local state
                companyId = newCompanyCode

                // Update current user's company ID
                authManager.currentUser?.companyId = newCompanyCode

                isSaving = false
                dismiss()
            } catch {
                isSaving = false
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}
