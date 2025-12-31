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
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .task {
                await loadTeamMembers()
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
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 100)
        }
    }

    private var companyCodeSection: some View {
        VStack(spacing: 16) {
            Text("Company Code")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(theme.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)

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

            if member.isAdmin == true {
                Text("Admin")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(theme.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(theme.accent.opacity(0.15))
                    .clipShape(Capsule())
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

    private func loadTeamMembers() async {
        guard let companyId = authManager.currentUser?.companyId else {
            errorMessage = "No company associated with your account"
            return
        }

        self.companyId = companyId
        isLoading = true
        defer { isLoading = false }

        do {
            let members = try await NetworkService.shared.fetchTeamMembers(companyId: companyId)
            teamMembers = members
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}
