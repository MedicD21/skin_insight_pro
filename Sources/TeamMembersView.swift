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
    @State private var companyCode: String = ""
    @State private var showCopiedConfirmation = false
    @State private var updatingUserId: String?
    @State private var showEditCompanyCode = false
    @State private var showEmployeeImport = false
    @State private var pendingAdminChanges: [String: Bool] = [:] // userId -> isAdmin
    @State private var isSavingChanges = false

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
                    if !pendingAdminChanges.isEmpty {
                        ToolbarItem(placement: .primaryAction) {
                            Button(action: {
                                #if DEBUG
                                print("💾 Save button clicked")
                                #endif
                                saveAdminChanges()
                            }) {
                                if isSavingChanges {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                } else {
                                    HStack(spacing: 4) {
                                        Image(systemName: "checkmark.circle.fill")
                                        Text("Save")
                                    }
                                    .foregroundColor(.green)
                                }
                            }
                            .disabled(isSavingChanges)
                        }
                    } else {
                        ToolbarItem(placement: .primaryAction) {
                            Button(action: { showEmployeeImport = true }) {
                                Image(systemName: "square.and.arrow.down")
                            }
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
                EditCompanyCodeView(companyId: companyId, companyCode: $companyCode)
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
                            #if DEBUG
                            print("📋 TeamMembersView: Showing 'No team members' - array count is \(teamMembers.count)")
                            #endif
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

                        Text(companyCode.isEmpty ? "No company" : companyCode)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(theme.primaryText)
                            .textSelection(.enabled)
                    }

                    Spacer()

                    if !companyCode.isEmpty {
                        Button {
                            UIPasteboard.general.string = companyCode
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

            // Show pending change indicator
            if let memberId = member.id, pendingAdminChanges[memberId] != nil {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 8, height: 8)
                    Text("Unsaved")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color.orange)
                }
            }

            // Show admin toggle for admins, badge for everyone else
            if let memberId = member.id, let pendingValue = pendingAdminChanges[memberId] {
                // Show pending admin status
                if pendingValue {
                    Text("Admin")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(theme.accent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(theme.accent.opacity(0.15))
                        .clipShape(Capsule())
                }
            } else if member.isAdmin == true {
                // Show current admin badge
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
                Toggle("", isOn: Binding(
                    get: {
                        // Check pending changes first, then fall back to member's current status
                        if let memberId = member.id, let pendingValue = pendingAdminChanges[memberId] {
                            return pendingValue
                        }
                        return member.isAdmin ?? false
                    },
                    set: { newValue in
                        if let memberId = member.id {
                            pendingAdminChanges[memberId] = newValue
                        }
                    }
                ))
                .labelsHidden()
                .tint(theme.accent)
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

    private func saveAdminChanges() {
        isSavingChanges = true

        Task {
            var successCount = 0
            var failedUsers: [String] = []

            #if DEBUG
            print("🔄 Saving admin changes for \(pendingAdminChanges.count) users")
            #endif

            for (userId, isAdmin) in pendingAdminChanges {
                do {
                    #if DEBUG
                    print("🔄 Updating user \(userId) isAdmin to \(isAdmin)")
                    #endif

                    try await NetworkService.shared.updateUserAdminStatus(userId: userId, isAdmin: isAdmin)

                    #if DEBUG
                    print("✅ Successfully updated user \(userId)")
                    #endif

                    // Update local array
                    await MainActor.run {
                        if let index = teamMembers.firstIndex(where: { $0.id == userId }) {
                            var updatedMember = teamMembers[index]
                            updatedMember.isAdmin = isAdmin
                            teamMembers[index] = updatedMember
                        }
                    }
                    successCount += 1
                } catch {
                    // Track failed user
                    #if DEBUG
                    print("❌ Failed to update user \(userId): \(error)")
                    #endif

                    if let member = teamMembers.first(where: { $0.id == userId }) {
                        let name = "\(member.firstName ?? "") \(member.lastName ?? "")".trimmingCharacters(in: .whitespaces)
                        failedUsers.append(name)
                    }
                }
            }

            await MainActor.run {
                isSavingChanges = false

                #if DEBUG
                print("📊 Save complete: \(successCount) succeeded, \(failedUsers.count) failed")
                #endif

                if failedUsers.isEmpty {
                    // All succeeded - clear pending changes
                    #if DEBUG
                    print("✅ All admin changes saved successfully")
                    #endif
                    pendingAdminChanges.removeAll()
                } else {
                    // Some failed - show error and keep failed changes pending
                    #if DEBUG
                    print("⚠️ Some updates failed: \(failedUsers)")
                    #endif
                    errorMessage = "Failed to update: \(failedUsers.joined(separator: ", "))"
                    showError = true

                    // Remove successful changes from pending
                    let failedUserIds = teamMembers.filter { member in
                        let name = "\(member.firstName ?? "") \(member.lastName ?? "")".trimmingCharacters(in: .whitespaces)
                        return !name.isEmpty && failedUsers.contains(name)
                    }.compactMap { $0.id }

                    pendingAdminChanges = pendingAdminChanges.filter { failedUserIds.contains($0.key) }
                }
            }
        }
    }

    @MainActor
    private func loadTeamMembers() async {
        guard let companyId = authManager.currentUser?.companyId else {
            #if DEBUG
            print("❌ TeamMembersView: No company ID for current user")
            #endif
            errorMessage = "No company associated with your account"
            return
        }

        #if DEBUG
        print("📋 TeamMembersView: Loading team members for company: \(companyId)")
        #endif
        self.companyId = companyId
        isLoading = true
        defer { isLoading = false }

        do {
            // Fetch company to get the company_code
            let company = try await NetworkService.shared.fetchCompany(id: companyId)
            companyCode = company.companyCode ?? companyId // Fallback to ID if no code set

            #if DEBUG
            print("📋 TeamMembersView: Company code: \(companyCode)")
            #endif

            let members = try await NetworkService.shared.fetchTeamMembers(companyId: companyId)
            #if DEBUG
            print("📋 TeamMembersView: Received \(members.count) members")
            print("📋 TeamMembersView: Members: \(members.map { "\($0.firstName ?? "") \($0.lastName ?? "") (\($0.email ?? ""))" })")
            #endif

            teamMembers = members
            #if DEBUG
            print("📋 TeamMembersView: teamMembers array updated with \(teamMembers.count) members")
            #endif
        } catch {
            #if DEBUG
            print("❌ TeamMembersView: Error loading team members: \(error)")
            #endif
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

struct EditCompanyCodeView: View {
    @ObservedObject var theme = ThemeManager.shared
    @StateObject private var authManager = AuthenticationManager.shared
    @Environment(\.dismiss) var dismiss

    let companyId: String
    @Binding var companyCode: String
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
                newCompanyCode = companyCode
            }
        }
    }

    private func saveCompanyCode() {
        isSaving = true

        Task {
            do {
                // Update only the company_code field (not the company ID)
                try await NetworkService.shared.updateCompanyCode(companyId: companyId, newCode: newCompanyCode)

                // Update local state
                companyCode = newCompanyCode

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
