import SwiftUI

struct CompanyOnboardingView: View {
    @ObservedObject var theme = ThemeManager.shared
    @StateObject private var viewModel = CompanyOnboardingViewModel()
    @Environment(\.dismiss) var dismiss

    var onComplete: () -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                theme.primaryBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 32) {
                        headerSection

                        if viewModel.mode == .selectMode {
                            modeSelectionSection
                        } else if viewModel.mode == .createCompany {
                            createCompanySection
                        } else if viewModel.mode == .joinCompany {
                            joinCompanySection
                        }

                        if viewModel.errorMessage != nil {
                            errorSection
                        }
                    }
                    .padding(24)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Company Setup")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(theme.primaryText)
                }
            }
        }
        .onAppear {
            viewModel.onComplete = onComplete
        }
    }

    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "building.2.fill")
                .font(.system(size: 60))
                .foregroundColor(theme.accent)

            Text("Set Up Your Company")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(theme.primaryText)

            Text("Create a new company or join an existing one to collaborate with your team")
                .font(.system(size: 16))
                .foregroundColor(theme.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
        }
    }

    private var modeSelectionSection: some View {
        VStack(spacing: 16) {
            Button(action: { viewModel.mode = .createCompany }) {
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 24))
                            Text("Create Company")
                                .font(.system(size: 18, weight: .semibold))
                        }
                        Text("Start a new company and invite team members")
                            .font(.system(size: 14))
                            .foregroundColor(theme.secondaryText)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(theme.tertiaryText)
                }
                .padding(20)
                .background(theme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: theme.radiusLarge))
                .overlay(
                    RoundedRectangle(cornerRadius: theme.radiusLarge)
                        .stroke(theme.cardBorder, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            Button(action: { viewModel.mode = .joinCompany }) {
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "person.2.fill")
                                .font(.system(size: 24))
                            Text("Join Company")
                                .font(.system(size: 18, weight: .semibold))
                        }
                        Text("Enter a company code to join an existing team")
                            .font(.system(size: 14))
                            .foregroundColor(theme.secondaryText)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(theme.tertiaryText)
                }
                .padding(20)
                .background(theme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: theme.radiusLarge))
                .overlay(
                    RoundedRectangle(cornerRadius: theme.radiusLarge)
                        .stroke(theme.cardBorder, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
    }

    private var createCompanySection: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Company Name")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(theme.secondaryText)

                TextField("Enter company name", text: $viewModel.companyName)
                    .textFieldStyle(.plain)
                    .padding(12)
                    .background(theme.tertiaryBackground)
                    .clipShape(RoundedRectangle(cornerRadius: theme.radiusMedium))
                    .overlay(
                        RoundedRectangle(cornerRadius: theme.radiusMedium)
                            .stroke(theme.border, lineWidth: 1)
                    )
            }

            Button(action: { Task { await viewModel.createCompany() } }) {
                if viewModel.isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text("Create Company")
                        .font(.system(size: 17, weight: .semibold))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(viewModel.companyName.isEmpty ? theme.accent.opacity(0.5) : theme.accent)
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: theme.radiusMedium))
            .disabled(viewModel.companyName.isEmpty || viewModel.isLoading)

            Button(action: { viewModel.mode = .selectMode }) {
                Text("Back")
                    .font(.system(size: 16))
                    .foregroundColor(theme.accent)
            }
        }
    }

    private var joinCompanySection: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Company Code")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(theme.secondaryText)

                TextField("Enter company code", text: $viewModel.companyCode)
                    .textFieldStyle(.plain)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .padding(12)
                    .background(theme.tertiaryBackground)
                    .clipShape(RoundedRectangle(cornerRadius: theme.radiusMedium))
                    .overlay(
                        RoundedRectangle(cornerRadius: theme.radiusMedium)
                            .stroke(theme.border, lineWidth: 1)
                    )

                Text("Ask your company admin for the company code")
                    .font(.system(size: 12))
                    .foregroundColor(theme.tertiaryText)
            }

            Button(action: { Task { await viewModel.joinCompany() } }) {
                if viewModel.isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text("Join Company")
                        .font(.system(size: 17, weight: .semibold))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(viewModel.companyCode.isEmpty ? theme.accent.opacity(0.5) : theme.accent)
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: theme.radiusMedium))
            .disabled(viewModel.companyCode.isEmpty || viewModel.isLoading)

            Button(action: { viewModel.mode = .selectMode }) {
                Text("Back")
                    .font(.system(size: 16))
                    .foregroundColor(theme.accent)
            }
        }
    }

    private var errorSection: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
            Text(viewModel.errorMessage ?? "")
                .font(.system(size: 14))
                .foregroundColor(theme.primaryText)
            Spacer()
        }
        .padding(12)
        .background(Color.orange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: theme.radiusMedium))
        .overlay(
            RoundedRectangle(cornerRadius: theme.radiusMedium)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
    }
}

@MainActor
class CompanyOnboardingViewModel: ObservableObject {
    enum OnboardingMode {
        case selectMode
        case createCompany
        case joinCompany
    }

    @Published var mode: OnboardingMode = .selectMode
    @Published var companyName = ""
    @Published var companyCode = ""
    @Published var isLoading = false
    @Published var errorMessage: String?

    var onComplete: (() -> Void)?

    func createCompany() async {
        guard !companyName.isEmpty else { return }

        isLoading = true
        errorMessage = nil

        do {
            // Create company via NetworkService
            _ = try await NetworkService.shared.createCompany(name: companyName)

            // Refresh current user to get updated company_id and admin status
            if let userId = AuthenticationManager.shared.currentUser?.id {
                await AuthenticationManager.shared.refreshUserProfile(userId: userId)

                // Wait a moment for the state to update
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

                #if DEBUG
                print("✅ Company created - User is admin: \(AuthenticationManager.shared.currentUser?.isCompanyAdmin ?? false)")
                #endif
            }

            isLoading = false

            // Call completion handler
            onComplete?()

        } catch {
            isLoading = false
            errorMessage = "Failed to create company: \(error.localizedDescription)"
        }
    }

    func joinCompany() async {
        guard !companyCode.isEmpty else { return }

        isLoading = true
        errorMessage = nil

        do {
            // Join company via NetworkService
            try await NetworkService.shared.joinCompany(code: companyCode)

            // Refresh current user to get updated company_id
            if let userId = AuthenticationManager.shared.currentUser?.id {
                await AuthenticationManager.shared.refreshUserProfile(userId: userId)
            }

            isLoading = false

            // Call completion handler
            onComplete?()

        } catch {
            isLoading = false
            errorMessage = "Failed to join company: \(error.localizedDescription)"
        }
    }
}
