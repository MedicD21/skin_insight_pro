import SwiftUI

struct EditProfileView: View {
    @ObservedObject var theme = ThemeManager.shared
    @StateObject private var authManager = AuthenticationManager.shared
    @Environment(\.dismiss) var dismiss

    @State private var firstName: String
    @State private var lastName: String
    @State private var phoneNumber: String
    @State private var role: String
    @State private var isSaving = false
    @State private var showError = false
    @State private var errorMessage = ""

    init() {
        _firstName = State(initialValue: AuthenticationManager.shared.currentUser?.firstName ?? "")
        _lastName = State(initialValue: AuthenticationManager.shared.currentUser?.lastName ?? "")
        _phoneNumber = State(initialValue: AuthenticationManager.shared.currentUser?.phoneNumber ?? "")
        _role = State(initialValue: AuthenticationManager.shared.currentUser?.role ?? "")
    }

    var body: some View {
        NavigationStack {
            ZStack {
                theme.primaryBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        profileImageSection

                        formSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 100)
                }

                if isSaving {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()

                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(theme.accent)
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveProfile()
                    }
                    .disabled(isSaving)
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    private var profileImageSection: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(theme.accent.opacity(0.15))
                    .frame(width: 100, height: 100)

                if let imageUrl = authManager.currentUser?.profileImageUrl, let url = URL(string: imageUrl) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: 100, height: 100)
                                .clipShape(Circle())
                        default:
                            Image(systemName: "person.fill")
                                .font(.system(size: 50))
                                .foregroundColor(theme.accent)
                        }
                    }
                } else {
                    Image(systemName: "person.fill")
                        .font(.system(size: 50))
                        .foregroundColor(theme.accent)
                }
            }

            Button(action: {}) {
                Text("Change Photo")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(theme.accent)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var formSection: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("First Name")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(theme.secondaryText)

                TextField("First name", text: $firstName)
                    .font(.system(size: 17))
                    .foregroundColor(theme.primaryText)
                    .padding(16)
                    .background(theme.tertiaryBackground)
                    .clipShape(RoundedRectangle(cornerRadius: theme.radiusMedium))
                    .overlay(
                        RoundedRectangle(cornerRadius: theme.radiusMedium)
                            .stroke(theme.border, lineWidth: 1)
                    )
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Last Name")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(theme.secondaryText)

                TextField("Last name", text: $lastName)
                    .font(.system(size: 17))
                    .foregroundColor(theme.primaryText)
                    .padding(16)
                    .background(theme.tertiaryBackground)
                    .clipShape(RoundedRectangle(cornerRadius: theme.radiusMedium))
                    .overlay(
                        RoundedRectangle(cornerRadius: theme.radiusMedium)
                            .stroke(theme.border, lineWidth: 1)
                    )
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Phone Number")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(theme.secondaryText)

                TextField("Phone number", text: $phoneNumber)
                    .font(.system(size: 17))
                    .foregroundColor(theme.primaryText)
                    .keyboardType(.phonePad)
                    .padding(16)
                    .background(theme.tertiaryBackground)
                    .clipShape(RoundedRectangle(cornerRadius: theme.radiusMedium))
                    .overlay(
                        RoundedRectangle(cornerRadius: theme.radiusMedium)
                            .stroke(theme.border, lineWidth: 1)
                    )
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Role")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(theme.secondaryText)

                TextField("Role (e.g., Esthetician, Manager)", text: $role)
                    .font(.system(size: 17))
                    .foregroundColor(theme.primaryText)
                    .padding(16)
                    .background(theme.tertiaryBackground)
                    .clipShape(RoundedRectangle(cornerRadius: theme.radiusMedium))
                    .overlay(
                        RoundedRectangle(cornerRadius: theme.radiusMedium)
                            .stroke(theme.border, lineWidth: 1)
                    )
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Email")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(theme.secondaryText)

                Text(authManager.currentUser?.email ?? "")
                    .font(.system(size: 17))
                    .foregroundColor(theme.tertiaryText)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(theme.tertiaryBackground.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: theme.radiusMedium))
                    .overlay(
                        RoundedRectangle(cornerRadius: theme.radiusMedium)
                            .stroke(theme.border, lineWidth: 1)
                    )

                Text("Email cannot be changed")
                    .font(.system(size: 12))
                    .foregroundColor(theme.secondaryText)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: theme.radiusXL)
                .fill(theme.cardBackground)
                .shadow(color: theme.shadowColor, radius: theme.shadowRadiusMedium, x: 0, y: 8)
        )
    }

    private func saveProfile() {
        isSaving = true

        Task {
            do {
                // Update user profile via NetworkService
                var updatedUser = authManager.currentUser
                updatedUser?.firstName = firstName
                updatedUser?.lastName = lastName
                updatedUser?.phoneNumber = phoneNumber
                updatedUser?.role = role

                guard let user = updatedUser else {
                    throw NetworkError.invalidResponse
                }

                // Call network service to update user profile
                let savedUser = try await NetworkService.shared.updateUserProfile(user)
                authManager.currentUser = savedUser

                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
            isSaving = false
        }
    }
}
