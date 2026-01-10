import SwiftUI

struct SessionTimeoutView: View {
    @ObservedObject var theme = ThemeManager.shared
    @ObservedObject var complianceManager = HIPAAComplianceManager.shared
    @ObservedObject var authManager = AuthenticationManager.shared
    @Binding var isPresented: Bool
    @State private var pin = ""
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var attempts = 0
    @State private var userProfile: UserProfile?
    private let maxAttempts = 3

    var body: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()

            VStack(spacing: 32) {
                // User Profile
                VStack(spacing: 16) {
                    if let profile = userProfile {
                        if let imageUrl = profile.profileImageUrl, let url = URL(string: imageUrl) {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .success(let image):
                                    image
                                        .resizable()
                                        .scaledToFill()
                                case .empty, .failure:
                                    Text(profile.initials)
                                        .font(.system(size: 32, weight: .semibold))
                                        .foregroundColor(.white)
                                @unknown default:
                                    EmptyView()
                                }
                            }
                            .frame(width: 80, height: 80)
                            .background(theme.accent)
                            .clipShape(Circle())
                        } else {
                            Text(profile.initials)
                                .font(.system(size: 32, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 80, height: 80)
                                .background(theme.accent)
                                .clipShape(Circle())
                        }

                        Text(profile.name ?? profile.email)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(theme.primaryText)
                    } else {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 60))
                            .foregroundColor(theme.accent)
                    }

                    Text("Session Locked")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(theme.primaryText)

                    Text(userProfile != nil && DeviceLoginManager.shared.hasPIN(for: userProfile!.id) ? "Enter your PIN to unlock" : "Your session has expired due to inactivity. Please log in again to continue.")
                        .font(.system(size: 15))
                        .foregroundColor(theme.secondaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }

                if let profile = userProfile, DeviceLoginManager.shared.hasPIN(for: profile.id) {
                    // PIN Display
                    HStack(spacing: 20) {
                        ForEach(0..<4, id: \.self) { index in
                            Circle()
                                .fill(pin.count > index ? theme.accent : theme.tertiaryBackground)
                                .frame(width: 20, height: 20)
                                .overlay(
                                    Circle()
                                        .stroke(showError ? theme.error : theme.border, lineWidth: 2)
                                )
                        }
                    }
                    .padding(.vertical, 24)
                    .animation(.easeInOut(duration: 0.2), value: showError)

                    // Number Pad
                    VStack(spacing: 16) {
                        ForEach(0..<3) { row in
                            HStack(spacing: 16) {
                                ForEach(1...3, id: \.self) { col in
                                    let number = row * 3 + col
                                    numberButton(number)
                                }
                            }
                        }

                        HStack(spacing: 16) {
                            // Empty space
                            Color.clear
                                .frame(width: 70, height: 70)

                            numberButton(0)

                            // Delete button
                            Button(action: deleteDigit) {
                                Image(systemName: "delete.left")
                                    .font(.system(size: 20))
                                    .foregroundColor(theme.primaryText)
                                    .frame(width: 70, height: 70)
                                    .background(theme.secondaryBackground)
                                    .clipShape(Circle())
                            }
                        }
                    }

                    if showError {
                        Text(errorMessage)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(theme.error)
                            .padding(.horizontal, 32)
                            .multilineTextAlignment(.center)
                    }

                    Button(action: signOut) {
                        Text("Sign Out")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(theme.secondaryText)
                    }
                    .padding(.top, 8)
                } else {
                    // No PIN - force logout
                    Button(action: signOut) {
                        Text("Return to Login")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(16)
                            .background(theme.accent)
                            .clipShape(RoundedRectangle(cornerRadius: theme.radiusMedium))
                    }
                    .padding(.horizontal, 40)
                }
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: theme.radiusXL)
                    .fill(theme.cardBackground)
                    .shadow(color: .black.opacity(0.3), radius: 20)
            )
            .padding(.horizontal, 40)
        }
        .onAppear {
            loadUserProfile()
        }
    }

    private func numberButton(_ number: Int) -> some View {
        Button(action: { addDigit(number) }) {
            Text("\(number)")
                .font(.system(size: 24, weight: .medium))
                .foregroundColor(theme.primaryText)
                .frame(width: 70, height: 70)
                .background(theme.secondaryBackground)
                .clipShape(Circle())
        }
    }

    private func addDigit(_ digit: Int) {
        guard pin.count < 4 else { return }
        pin += "\(digit)"

        if pin.count == 4 {
            // Verify PIN
            verifyPIN()
        }
    }

    private func deleteDigit() {
        if !pin.isEmpty {
            pin.removeLast()
            showError = false
        }
    }

    private func verifyPIN() {
        guard let profile = userProfile else {
            signOut()
            return
        }

        let isValid = DeviceLoginManager.shared.verifyPIN(pin, for: profile.id)

        if isValid {
            Task {
                do {
                    try await authManager.loginWithPIN(userId: profile.id, email: profile.email)

                    complianceManager.isSessionExpired = false
                    complianceManager.startSessionMonitoring()

                    DeviceLoginManager.shared.saveUserProfile(
                        userId: profile.id,
                        email: profile.email,
                        name: profile.name,
                        profileImageUrl: profile.profileImageUrl
                    )

                    await MainActor.run {
                        isPresented = false
                    }
                } catch {
                    await MainActor.run {
                        errorMessage = error.localizedDescription
                        showError = true
                        pin = ""
                    }
                }
            }
        } else {
            attempts += 1

            if attempts >= maxAttempts {
                errorMessage = "Too many attempts. Signing out for security."
                showError = true

                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    signOut()
                }
            } else {
                errorMessage = "Incorrect PIN. \(maxAttempts - attempts) attempt(s) remaining."
                showError = true
                pin = ""

                // Shake animation
                withAnimation(.easeInOut(duration: 0.1).repeatCount(3, autoreverses: true)) {
                    showError = true
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    showError = false
                }
            }
        }
    }

    private func loadUserProfile() {
        // Try to load the current user's profile from device login manager
        if let currentUser = authManager.currentUser, let userId = currentUser.id {
            let profiles = DeviceLoginManager.shared.getStoredProfiles()
            userProfile = profiles.first(where: { $0.id == userId })

            // If not found in stored profiles, create one
            if userProfile == nil {
                let fullName = currentUser.firstName != nil && currentUser.lastName != nil ? "\(currentUser.firstName!) \(currentUser.lastName!)" : nil
                DeviceLoginManager.shared.saveUserProfile(
                    userId: userId,
                    email: currentUser.email ?? "",
                    name: fullName,
                    profileImageUrl: currentUser.profileImageUrl
                )
                userProfile = DeviceLoginManager.shared.getStoredProfiles().first(where: { $0.id == userId })
            }
        }
    }

    private func signOut() {
        // Reset session expired flag first
        complianceManager.isSessionExpired = false
        isPresented = false
        // Then logout to return to login screen
        authManager.logout()
    }
}
