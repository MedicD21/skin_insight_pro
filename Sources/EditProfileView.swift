import SwiftUI
import PhotosUI

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
    @State private var showImagePicker = false
    @State private var selectedImage: UIImage?
    @State private var showPasswordSection = false
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var showPasswordSuccess = false

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

                        passwordSection
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
            .alert("Password Updated", isPresented: $showPasswordSuccess) {
                Button("OK", role: .cancel) {
                    newPassword = ""
                    confirmPassword = ""
                    showPasswordSection = false
                }
            } message: {
                Text("Your password has been updated successfully.")
            }
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(image: $selectedImage, sourceType: .photoLibrary)
            }
        }
    }

    private var profileImageSection: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(theme.accent.opacity(0.15))
                    .frame(width: 100, height: 100)

                if let selectedImage = selectedImage {
                    Image(uiImage: selectedImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 100, height: 100)
                        .clipShape(Circle())
                } else if let imageUrl = authManager.currentUser?.profileImageUrl, let url = URL(string: imageUrl) {
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

            Button(action: { showImagePicker = true }) {
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

    private var passwordSection: some View {
        VStack(spacing: 16) {
            Button(action: { showPasswordSection.toggle() }) {
                HStack {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 16))
                        .foregroundColor(theme.accent)

                    Text("Change Password")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(theme.primaryText)

                    Spacer()

                    Image(systemName: showPasswordSection ? "chevron.up" : "chevron.down")
                        .font(.system(size: 14))
                        .foregroundColor(theme.secondaryText)
                }
                .padding(16)
                .background(theme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: theme.radiusMedium))
                .shadow(color: theme.shadowColor, radius: theme.shadowRadiusSmall, x: 0, y: 4)
            }

            if showPasswordSection {
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("New Password")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(theme.secondaryText)

                        SecureField("Enter new password", text: $newPassword)
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
                        Text("Confirm Password")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(theme.secondaryText)

                        SecureField("Confirm new password", text: $confirmPassword)
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

                    if !isPasswordValid && !newPassword.isEmpty {
                        Text("Password must be at least 6 characters with 1 uppercase and 1 special character")
                            .font(.system(size: 12))
                            .foregroundColor(.red)
                    }

                    Button(action: { updatePassword() }) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Update Password")
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(16)
                        .background(isPasswordValid && newPassword == confirmPassword ? theme.accent : Color.gray)
                        .clipShape(RoundedRectangle(cornerRadius: theme.radiusMedium))
                    }
                    .disabled(!isPasswordValid || newPassword != confirmPassword || isSaving)
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: theme.radiusXL)
                        .fill(theme.cardBackground)
                        .shadow(color: theme.shadowColor, radius: theme.shadowRadiusMedium, x: 0, y: 8)
                )
            }
        }
    }

    private var isPasswordValid: Bool {
        let hasMinLength = newPassword.count >= 6
        let hasCapital = newPassword.range(of: "[A-Z]", options: .regularExpression) != nil
        let hasSpecial = newPassword.range(of: "[!@#$%^&*(),.?\":{}|<>]", options: .regularExpression) != nil
        return hasMinLength && hasCapital && hasSpecial
    }

    private func updatePassword() {
        guard newPassword == confirmPassword else {
            errorMessage = "Passwords do not match"
            showError = true
            return
        }

        guard isPasswordValid else {
            errorMessage = "Password must be at least 6 characters with 1 uppercase and 1 special character"
            showError = true
            return
        }

        isSaving = true

        Task {
            do {
                try await NetworkService.shared.updatePassword(newPassword: newPassword)

                await MainActor.run {
                    isSaving = false
                    showPasswordSuccess = true
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
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

                // Upload profile image if one was selected
                if let selectedImage = selectedImage, let userId = updatedUser?.id {
                    let imageUrl = try await NetworkService.shared.uploadImage(image: selectedImage, userId: userId)
                    updatedUser?.profileImageUrl = imageUrl
                }

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
