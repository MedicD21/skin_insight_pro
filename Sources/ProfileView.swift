import SwiftUI

struct ProfileView: View {
    @ObservedObject var theme = ThemeManager.shared
    @StateObject private var authManager = AuthenticationManager.shared
    @State private var showLogoutConfirmation = false
    @State private var showDeleteConfirmation = false
    @State private var isDeleting = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showAbout = false
    @State private var showUpgradePrompt = false
    @State private var showEditProfile = false
    @State private var showCompanyProfile = false
    @State private var showJoinCompany = false
    @State private var showPrivacySettings = false
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    var body: some View {
        ZStack {
            theme.primaryBackground
                .ignoresSafeArea()

            mainContent

            if isDeleting {
                deletingOverlay
            }
        }
        .navigationTitle("Profile")
        .sheet(isPresented: $showAbout) {
            AboutView()
        }
        .sheet(isPresented: $showUpgradePrompt) {
            UpgradePromptView()
        }
        .sheet(isPresented: $showEditProfile) {
            EditProfileView()
        }
        .sheet(isPresented: $showCompanyProfile) {
            CompanyProfileView()
        }
        .sheet(isPresented: $showJoinCompany) {
            JoinCompanyView()
        }
        .sheet(isPresented: $showPrivacySettings) {
            HIPAADataManagementView()
        }
        .alert("Logout", isPresented: $showLogoutConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Logout", role: .destructive) {
                authManager.logout()
            }
        } message: {
            Text("Are you sure you want to logout?")
        }
        .alert("Delete Account", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                deleteAccount()
            }
        } message: {
            Text("This action cannot be undone. All your data will be permanently deleted.")
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    private var mainContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                profileHeader

                if authManager.isGuestMode {
                    guestModeCard
                }

                if authManager.currentUser?.isAdmin == true && !authManager.isGuestMode {
                    adminSection
                }

                accountSection

                aboutSection

                logoutButton

                if !authManager.isGuestMode {
                    deleteAccountButton
                }
            }
            .padding(.horizontal, horizontalSizeClass == .regular ? 32 : 16)
            .padding(.top, 20)
            .padding(.bottom, horizontalSizeClass == .regular ? 40 : 100)
        }
    }

    private var deletingOverlay: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)

                Text("Deleting account...")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(.white)
            }
        }
    }
    
    private var profileHeader: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(theme.accent.opacity(0.15))
                    .frame(width: 100, height: 100)

                if let profileImageUrl = authManager.currentUser?.profileImageUrl,
                   !profileImageUrl.isEmpty,
                   let url = URL(string: profileImageUrl) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: 100, height: 100)
                                .clipShape(Circle())
                        default:
                            Image(systemName: authManager.isGuestMode ? "person.fill.questionmark" : "person.fill")
                                .font(.system(size: 50))
                                .foregroundColor(theme.accent)
                        }
                    }
                } else {
                    Image(systemName: authManager.isGuestMode ? "person.fill.questionmark" : "person.fill")
                        .font(.system(size: 50))
                        .foregroundColor(theme.accent)
                }
            }

            VStack(spacing: 6) {
                if let firstName = authManager.currentUser?.firstName,
                   let lastName = authManager.currentUser?.lastName,
                   !firstName.isEmpty || !lastName.isEmpty {
                    Text("\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces))
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(theme.primaryText)
                } else {
                    Text(authManager.currentUser?.email ?? "User")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(theme.primaryText)
                }

                if let role = authManager.currentUser?.role, !role.isEmpty {
                    Text(role)
                        .font(.system(size: 15))
                        .foregroundColor(theme.secondaryText)
                } else {
                    Text(authManager.isGuestMode ? "Guest User" : "Esthetician")
                        .font(.system(size: 15))
                        .foregroundColor(theme.secondaryText)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
    
    private var guestModeCard: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(theme.accent)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("You're in Guest Mode")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(theme.primaryText)
                    
                    Text("Create an account to sync your data across devices")
                        .font(.system(size: 14))
                        .foregroundColor(theme.secondaryText)
                }
                
                Spacer()
            }
            
            Button(action: { showUpgradePrompt = true }) {
                HStack {
                    Spacer()
                    Text("Create Account")
                    Spacer()
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
                .frame(height: 44)
                .background(theme.accent)
                .clipShape(RoundedRectangle(cornerRadius: theme.radiusMedium))
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: theme.radiusXL)
                .fill(theme.accent.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: theme.radiusXL)
                .stroke(theme.accent.opacity(0.3), lineWidth: 1)
        )
    }

    private var adminSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Admin Tools")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(theme.primaryText)

                Spacer()

                Image(systemName: "checkmark.shield.fill")
                    .foregroundColor(theme.accent)
            }

            VStack(spacing: 0) {
                NavigationLink(destination: ProductCatalogView()) {
                    navigationRow(icon: "shippingbox.fill", title: "Product Catalog", subtitle: "Manage spa products")
                }

                Divider()
                    .padding(.leading, 56)

                NavigationLink(destination: AIRulesView()) {
                    navigationRow(icon: "brain", title: "AI Rules", subtitle: "Configure AI product suggestions")
                }

                Divider()
                    .padding(.leading, 56)

                NavigationLink(destination: AIProviderSettingsView()) {
                    navigationRow(icon: "eye.fill", title: "AI Vision Provider", subtitle: "Switch between Apple Vision and Claude")
                }
            }
            .background(
                RoundedRectangle(cornerRadius: theme.radiusLarge)
                    .fill(theme.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: theme.radiusLarge)
                    .stroke(theme.cardBorder, lineWidth: 1)
            )
        }
    }

    private var accountSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Account")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(theme.primaryText)

            VStack(spacing: 0) {
                if !authManager.isGuestMode {
                    Button(action: { showEditProfile = true }) {
                        navigationRow(icon: "person.circle", title: "Edit Profile", subtitle: "Update your personal information")
                    }

                    Divider()
                        .padding(.leading, 56)

                    Button(action: { showCompanyProfile = true }) {
                        navigationRow(icon: "building.2", title: "Company Profile", subtitle: "Manage company information")
                    }

                    Divider()
                        .padding(.leading, 56)

                    Button(action: { showJoinCompany = true }) {
                        navigationRow(icon: "person.2.badge.gearshape", title: "Join Company", subtitle: "Enter a company code to join a team")
                    }

                    Divider()
                        .padding(.leading, 56)

                    Button(action: { showPrivacySettings = true }) {
                        navigationRow(icon: "hand.raised.fill", title: "Privacy & Data", subtitle: "Manage your privacy rights and data")
                    }

                    Divider()
                        .padding(.leading, 56)
                }

                settingRow(
                    icon: "envelope",
                    title: "Email",
                    value: authManager.currentUser?.email ?? "Not available"
                )

                Divider()
                    .padding(.leading, 56)

                settingRow(
                    icon: "key",
                    title: "Provider",
                    value: authManager.isGuestMode ? "Guest" : "Email"
                )
            }
            .background(
                RoundedRectangle(cornerRadius: theme.radiusLarge)
                    .fill(theme.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: theme.radiusLarge)
                    .stroke(theme.cardBorder, lineWidth: 1)
            )
        }
    }
    
    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("About")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(theme.primaryText)
            
            Button(action: { showAbout = true }) {
                HStack(spacing: 16) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 20))
                        .foregroundColor(theme.accent)
                        .frame(width: 24)
                    
                    Text("App Information")
                        .font(.system(size: 16))
                        .foregroundColor(theme.primaryText)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(theme.tertiaryText)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: theme.radiusLarge)
                        .fill(theme.cardBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: theme.radiusLarge)
                        .stroke(theme.cardBorder, lineWidth: 1)
                )
            }
        }
    }
    
    private var logoutButton: some View {
        Button(action: { showLogoutConfirmation = true }) {
            HStack {
                Spacer()
                Image(systemName: "arrow.right.square")
                Text(authManager.isGuestMode ? "Exit Guest Mode" : "Logout")
                Spacer()
            }
            .font(.system(size: 17, weight: .semibold))
            .foregroundColor(.white)
            .frame(height: 52)
            .background(theme.accent)
            .clipShape(RoundedRectangle(cornerRadius: theme.radiusMedium))
        }
    }
    
    private var deleteAccountButton: some View {
        Button(action: { showDeleteConfirmation = true }) {
            HStack {
                Spacer()
                Image(systemName: "trash")
                Text("Delete Account")
                Spacer()
            }
            .font(.system(size: 17, weight: .semibold))
            .foregroundColor(.white)
            .frame(height: 52)
            .background(theme.error)
            .clipShape(RoundedRectangle(cornerRadius: theme.radiusMedium))
        }
    }
    
    private func navigationRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(theme.accent)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(theme.primaryText)

                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundColor(theme.secondaryText)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(theme.tertiaryText)
        }
        .padding(16)
    }

    private func settingRow(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(theme.accent)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14))
                    .foregroundColor(theme.secondaryText)

                Text(value)
                    .font(.system(size: 16))
                    .foregroundColor(theme.primaryText)
            }

            Spacer()
        }
        .padding(16)
    }
    
    private func deleteAccount() {
        isDeleting = true
        
        Task {
            do {
                try await authManager.deleteAccount()
                isDeleting = false
            } catch is CancellationError {
                isDeleting = false
                return
            } catch {
                isDeleting = false
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}

struct UpgradePromptView: View {
    @ObservedObject var theme = ThemeManager.shared
    @StateObject private var authManager = AuthenticationManager.shared
    @Environment(\.dismiss) var dismiss
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    @FocusState private var focusedField: Field?
    
    enum Field {
        case email, password
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                theme.primaryBackground
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(theme.accent)
                            .padding(.top, 20)
                        
                        Text("Create Your Account")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(theme.primaryText)
                        
                        Text("Sync your data across devices and never lose your client information")
                            .font(.system(size: 16))
                            .foregroundColor(theme.secondaryText)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                        
                        VStack(spacing: 16) {
                            ThemedTextField(
                                title: "Email",
                                placeholder: "Enter your email",
                                text: $email,
                                field: .email,
                                focusedField: $focusedField,
                                theme: theme,
                                icon: "envelope",
                                keyboardType: .emailAddress,
                                textContentType: .emailAddress,
                                autocapitalization: .none
                            )
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Password")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(theme.secondaryText)
                                
                                HStack(spacing: 12) {
                                    Image(systemName: "lock")
                                        .font(.system(size: 18))
                                        .foregroundColor(theme.tertiaryText)
                                        .frame(width: 24)
                                    
                                    SecureField("Create a password", text: $password)
                                        .font(.system(size: 17))
                                        .foregroundColor(theme.primaryText)
                                        .textContentType(.newPassword)
                                        .focused($focusedField, equals: .password)
                                }
                                .padding(16)
                                .background(theme.tertiaryBackground)
                                .clipShape(RoundedRectangle(cornerRadius: theme.radiusMedium))
                                .overlay(
                                    RoundedRectangle(cornerRadius: theme.radiusMedium)
                                        .stroke(focusedField == .password ? theme.accent : theme.border, lineWidth: focusedField == .password ? 2 : 1)
                                )
                                
                                Text("Password must contain: At least 6 characters, 1 capital letter, and 1 special character.")
                                    .font(.system(size: 12))
                                    .foregroundColor(theme.secondaryText)
                                    .padding(.top, 4)
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        Button(action: createAccount) {
                            HStack {
                                Spacer()
                                Text("Create Account")
                                Spacer()
                            }
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(height: 52)
                            .background(theme.accent)
                            .clipShape(RoundedRectangle(cornerRadius: theme.radiusMedium))
                        }
                        .disabled(!isFormValid)
                        .opacity(isFormValid ? 1.0 : 0.5)
                        .padding(.horizontal, 20)
                    }
                    .padding(.bottom, 40)
                }
                .scrollDismissesKeyboard(.interactively)
                
                if isLoading {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(theme.accent)
                }
            }
            .navigationTitle("Upgrade Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .cancellationAction) {
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
        }
    }
    
    private var isFormValid: Bool {
        !email.isEmpty && !password.isEmpty && email.contains("@") && isPasswordValid
    }
    
    private var isPasswordValid: Bool {
        let hasMinLength = password.count >= 6
        let hasCapital = password.range(of: "[A-Z]", options: .regularExpression) != nil
        let hasSpecial = password.range(of: "[!@#$%^&*(),.?\":{}|<>]", options: .regularExpression) != nil
        return hasMinLength && hasCapital && hasSpecial
    }
    
    private func createAccount() {
        focusedField = nil
        isLoading = true
        
        Task {
            do {
                try await authManager.createAccount(email: email, password: password)
                isLoading = false
                dismiss()
            } catch is CancellationError {
                isLoading = false
                return
            } catch {
                isLoading = false
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}

struct AboutView: View {
    @ObservedObject var theme = ThemeManager.shared
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                theme.primaryBackground
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 60, weight: .light))
                            .foregroundColor(theme.accent)
                            .padding(.top, 20)
                        
                        Text("Skin Insight Pro")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(theme.primaryText)
                        
                        Text("Version 1.0.0")
                            .font(.system(size: 15))
                            .foregroundColor(theme.secondaryText)
                        
                        VStack(alignment: .leading, spacing: 16) {
                            Text("About")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(theme.primaryText)
                            
                            Text("Skin Insight Pro is a professional skin analysis tool powered by AI. Designed for estheticians to track and analyze client skin health over time.")
                                .font(.system(size: 15))
                                .foregroundColor(theme.primaryText)
                                .multilineTextAlignment(.leading)
                        }
                        .padding(20)
                        .background(
                            RoundedRectangle(cornerRadius: theme.radiusXL)
                                .fill(theme.cardBackground)
                        )
                        
                        VStack(spacing: 12) {
                            if let homepageURL = Bundle.main.infoDictionary?["AppMetadataURLs"] as? [String: String],
                               let homepage = homepageURL["HomepageURL"],
                               let url = URL(string: homepage) {
                                Link(destination: url) {
                                    linkRow(icon: "house", title: "Homepage")
                                }
                            }
                            
                            if let supportURL = Bundle.main.infoDictionary?["AppMetadataURLs"] as? [String: String],
                               let support = supportURL["SupportURL"],
                               let url = URL(string: support) {
                                Link(destination: url) {
                                    linkRow(icon: "questionmark.circle", title: "Support")
                                }
                            }
                            
                            if let privacyURL = Bundle.main.infoDictionary?["AppMetadataURLs"] as? [String: String],
                               let privacy = privacyURL["PrivacyPolicyURL"],
                               let url = URL(string: privacy) {
                                Link(destination: url) {
                                    linkRow(icon: "lock.shield", title: "Privacy Policy")
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func linkRow(icon: String, title: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(theme.accent)
                .frame(width: 24)
            
            Text(title)
                .font(.system(size: 16))
                .foregroundColor(theme.primaryText)
            
            Spacer()
            
            Image(systemName: "arrow.up.right")
                .font(.system(size: 14))
                .foregroundColor(theme.tertiaryText)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: theme.radiusLarge)
                .fill(theme.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: theme.radiusLarge)
                .stroke(theme.cardBorder, lineWidth: 1)
        )
    }
}
