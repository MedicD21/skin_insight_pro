import SwiftUI

struct AuthenticationView: View {
    @ObservedObject var theme = ThemeManager.shared
    @StateObject private var authManager = AuthenticationManager.shared
    @State private var email = ""
    @State private var password = ""
    @State private var isLogin = true
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var storedProfiles: [UserProfile] = []
    @State private var selectedProfile: UserProfile?
    @State private var showPINEntry = false
    @State private var showFullLoginForm = false
    @State private var showPINSetup = false
    @FocusState private var focusedField: Field?

    enum Field {
        case email, password
    }

    var body: some View {
        ZStack {
            theme.primaryBackground
                .ignoresSafeArea()

            if showPINSetup, let userId = authManager.currentUser?.id {
                PINSetupView(userId: userId) {
                    // PIN setup complete - save user profile and reset flag
                    if let user = authManager.currentUser {
                        DeviceLoginManager.shared.saveUserProfile(
                            userId: user.id ?? "",
                            email: user.email ?? "",
                            name: user.firstName != nil && user.lastName != nil ? "\(user.firstName!) \(user.lastName!)" : nil,
                            profileImageUrl: user.profileImageUrl
                        )
                    }
                    authManager.needsPINSetup = false
                    showPINSetup = false
                }
            } else if showPINEntry, let profile = selectedProfile {
                PINEntryView(
                    userProfile: profile,
                    onSuccess: {
                        // Login with saved credentials
                        Task {
                            await quickLoginWithProfile(profile)
                        }
                    },
                    onCancel: {
                        showPINEntry = false
                        selectedProfile = nil
                        showFullLoginForm = true
                    }
                )
            } else if showFullLoginForm || storedProfiles.isEmpty {
                fullLoginView
            } else {
                storedProfilesView
            }

            if isLoading {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()

                ProgressView()
                    .scaleEffect(1.5)
                    .tint(theme.accent)
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            loadStoredProfiles()
        }
        .onChange(of: authManager.needsPINSetup) { _, needsSetup in
            if needsSetup {
                showPINSetup = true
            }
        }
    }

    // MARK: - Stored Profiles View

    private var storedProfilesView: some View {
        ScrollView {
            VStack(spacing: 0) {
                headerSection
                    .padding(.top, 60)
                    .padding(.bottom, 40)

                VStack(spacing: 20) {
                    Text("Select Account")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(theme.primaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    ForEach(storedProfiles) { profile in
                        profileButton(profile)
                    }

                    Divider()
                        .padding(.vertical, 8)

                    Button(action: { showFullLoginForm = true }) {
                        HStack {
                            Image(systemName: "plus.circle")
                            Text("Use Different Account")
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(theme.accent)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(theme.secondaryBackground)
                        .clipShape(RoundedRectangle(cornerRadius: theme.radiusMedium))
                    }
                }
                .padding(.horizontal, 20)
                .frame(maxWidth: 450)
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func profileButton(_ profile: UserProfile) -> some View {
        Button(action: {
            selectedProfile = profile
            if DeviceLoginManager.shared.hasPIN(for: profile.id) {
                showPINEntry = true
            } else {
                // No PIN, go to full login
                email = profile.email
                showFullLoginForm = true
            }
        }) {
            HStack(spacing: 16) {
                // Profile Image/Initial
                if let imageUrl = profile.profileImageUrl, let url = URL(string: imageUrl) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                        case .empty, .failure:
                            Text(profile.initials)
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.white)
                        @unknown default:
                            EmptyView()
                        }
                    }
                    .frame(width: 50, height: 50)
                    .background(theme.accent)
                    .clipShape(Circle())
                } else {
                    Text(profile.initials)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 50, height: 50)
                        .background(theme.accent)
                        .clipShape(Circle())
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(profile.name ?? profile.email)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(theme.primaryText)

                    Text(profile.email)
                        .font(.system(size: 13))
                        .foregroundColor(theme.secondaryText)
                }

                Spacer()

                if DeviceLoginManager.shared.hasPIN(for: profile.id) {
                    Image(systemName: "lock.fill")
                        .foregroundColor(theme.tertiaryText)
                }

                Image(systemName: "chevron.right")
                    .foregroundColor(theme.tertiaryText)
            }
            .padding(16)
            .background(theme.secondaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: theme.radiusMedium))
        }
        .contextMenu {
            Button(role: .destructive) {
                removeProfile(profile)
            } label: {
                Label("Remove from This Device", systemImage: "trash")
            }
        }
    }

    // MARK: - Full Login View

    private var fullLoginView: some View {
        ScrollView {
            VStack(spacing: 0) {
                headerSection
                    .padding(.top, 60)
                    .padding(.bottom, 40)

                formSection

                guestSection
                    .padding(.top, 32)
            }
            .frame(maxWidth: 450)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 20)
        }
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            if !storedProfiles.isEmpty {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showFullLoginForm = false }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                    }
                }
            }
        }
    }

    private var headerSection: some View {
        VStack(spacing: 16) {
            Image("logoWithText")
                .resizable()
                .scaledToFit()
                .frame(width: 200)

            Text("Professional Skin Analysis")
                .font(.system(size: 16))
                .foregroundColor(theme.secondaryText)
        }
    }

    private var formSection: some View {
        VStack(spacing: 24) {
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

                        SecureField("Enter your password", text: $password)
                            .font(.system(size: 17))
                            .foregroundColor(theme.primaryText)
                            .textContentType(isLogin ? .password : .newPassword)
                            .focused($focusedField, equals: .password)
                            .submitLabel(.go)
                            .onSubmit {
                                if isFormValid {
                                    handleAuthentication()
                                }
                            }
                    }
                    .padding(.horizontal, 16)
                    .frame(height: 52)
                    .background(theme.secondaryBackground)
                    .clipShape(RoundedRectangle(cornerRadius: theme.radiusMedium))
                    .overlay(
                        RoundedRectangle(cornerRadius: theme.radiusMedium)
                            .stroke(focusedField == .password ? theme.accent : theme.border, lineWidth: focusedField == .password ? 2 : 1)
                    )

                    if !isLogin {
                        VStack(alignment: .leading, spacing: 4) {
                            passwordRequirement("At least 6 characters", met: password.count >= 6)
                            passwordRequirement("One uppercase letter", met: password.range(of: "[A-Z]", options: .regularExpression) != nil)
                            passwordRequirement("One special character", met: password.range(of: "[!@#$%^&*(),.?\":{}|<>]", options: .regularExpression) != nil)
                        }
                        .padding(.top, 8)
                    }
                }
            }

            Button(action: handleAuthentication) {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text(isLogin ? "Sign In" : "Create Account")
                }
            }
            .font(.system(size: 17, weight: .semibold))
            .foregroundColor(.white)
            .frame(height: 52)
            .frame(maxWidth: .infinity)
            .background(isFormValid ? theme.accent : theme.accent.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: theme.radiusMedium))
            .disabled(!isFormValid || isLoading)

            Button(action: { isLogin.toggle() }) {
                Text(isLogin ? "Don't have an account? Sign up" : "Already have an account? Sign in")
                    .font(.system(size: 15))
                    .foregroundColor(theme.accent)
            }
        }
    }

    private func passwordRequirement(_ text: String, met: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: met ? "checkmark.circle.fill" : "circle")
                .foregroundColor(met ? theme.success : theme.tertiaryText)
                .font(.system(size: 12))

            Text(text)
                .font(.system(size: 13))
                .foregroundColor(theme.secondaryText)
        }
    }

    private var guestSection: some View {
        VStack(spacing: 16) {
            HStack {
                Rectangle()
                    .fill(theme.border)
                    .frame(height: 1)
                Text("or")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(theme.tertiaryText)
                Rectangle()
                    .fill(theme.border)
                    .frame(height: 1)
            }

            SignInWithAppleButton {
                Task {
                    do {
                        try await authManager.signInWithApple()
                    } catch {
                        errorMessage = error.localizedDescription
                        showError = true
                    }
                }
            }

            Button(action: {
                authManager.loginAsGuest()
            }) {
                HStack {
                    Spacer()
                    Image(systemName: "person.fill")
                    Text("Continue as Guest")
                    Spacer()
                }
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(theme.primaryText)
                .frame(height: 52)
                .background(theme.tertiaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: theme.radiusMedium))
                .overlay(
                    RoundedRectangle(cornerRadius: theme.radiusMedium)
                        .stroke(theme.border, lineWidth: 1)
                )
            }

            Text("Guest mode allows you to explore the app. Your data will be stored locally.")
                .font(.system(size: 13))
                .foregroundColor(theme.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
    }

    private var isFormValid: Bool {
        !email.isEmpty && !password.isEmpty && email.contains("@") && (!isLogin ? isPasswordValid : true)
    }

    private var isPasswordValid: Bool {
        let hasMinLength = password.count >= 6
        let hasCapital = password.range(of: "[A-Z]", options: .regularExpression) != nil
        let hasSpecial = password.range(of: "[!@#$%^&*(),.?\":{}|<>]", options: .regularExpression) != nil
        return hasMinLength && hasCapital && hasSpecial
    }

    // MARK: - Actions

    private func loadStoredProfiles() {
        storedProfiles = DeviceLoginManager.shared.getStoredProfiles()
    }

    private func removeProfile(_ profile: UserProfile) {
        DeviceLoginManager.shared.removeUserProfile(userId: profile.id)
        loadStoredProfiles()
    }

    private func handleAuthentication() {
        focusedField = nil
        isLoading = true

        Task {
            do {
                if isLogin {
                    try await authManager.login(email: email, password: password)
                } else {
                    try await authManager.createAccount(email: email, password: password)

                    // Show PIN setup for new account if needed
                    if authManager.needsPINSetup {
                        await MainActor.run {
                            isLoading = false
                            showPINSetup = true
                        }
                        return
                    }
                }
            } catch is CancellationError {
                return
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
            isLoading = false
        }
    }

    private func quickLoginWithProfile(_ profile: UserProfile) async {
        await MainActor.run {
            isLoading = true
        }

        do {
            try await authManager.loginWithPIN(userId: profile.id, email: profile.email)

            DeviceLoginManager.shared.saveUserProfile(
                userId: profile.id,
                email: profile.email,
                name: profile.name,
                profileImageUrl: profile.profileImageUrl
            )

            await MainActor.run {
                isLoading = false
                showPINEntry = false
                selectedProfile = nil
                showFullLoginForm = false
            }
        } catch {
            await MainActor.run {
                isLoading = false
                email = profile.email
                showPINEntry = false
                selectedProfile = nil
                errorMessage = error.localizedDescription
                showError = true
                showFullLoginForm = true
            }
        }
    }
}
