import SwiftUI
import PhotosUI

struct CompleteProfileView: View {
    @ObservedObject var theme = ThemeManager.shared
    @StateObject private var authManager = AuthenticationManager.shared
    @Environment(\.dismiss) var dismiss

    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var phoneNumber: String = ""
    @State private var role: String = ""
    @State private var selectedImage: PhotosPickerItem?
    @State private var profileImage: UIImage?
    @State private var isSaving = false
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationStack {
            ZStack {
                theme.primaryBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        headerSection

                        profileImageSection

                        formSection

                        saveButton
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
            .navigationTitle("Complete Your Profile")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
        .interactiveDismissDisabled()
    }

    private var headerSection: some View {
        VStack(spacing: 12) {
            Text("Welcome!")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(theme.primaryText)

            Text("Let's complete your profile to get started")
                .font(.system(size: 16))
                .foregroundColor(theme.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    private var profileImageSection: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(theme.accent.opacity(0.15))
                    .frame(width: 100, height: 100)

                if let profileImage = profileImage {
                    Image(uiImage: profileImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 100, height: 100)
                        .clipShape(Circle())
                } else {
                    Image(systemName: "person.fill")
                        .font(.system(size: 50))
                        .foregroundColor(theme.accent)
                }
            }

            PhotosPicker(selection: $selectedImage, matching: .images) {
                Text("Add Profile Photo")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(theme.accent)
            }
            .onChange(of: selectedImage) { _, newValue in
                Task {
                    if let data = try? await newValue?.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        profileImage = image
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var formSection: some View {
        VStack(spacing: 20) {
            textField(title: "First Name", placeholder: "Enter first name", text: $firstName)
            textField(title: "Last Name", placeholder: "Enter last name", text: $lastName)
            textField(
                title: "Phone Number",
                placeholder: "(555) 123-4567",
                text: Binding(
                    get: { self.phoneNumber.formatPhoneNumber() },
                    set: { self.phoneNumber = $0.unformatPhoneNumber() }
                ),
                keyboardType: .phonePad
            )
            textField(title: "Role/Title", placeholder: "e.g., Esthetician, Dermatologist", text: $role)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: theme.radiusXL)
                .fill(theme.cardBackground)
                .shadow(color: theme.shadowColor, radius: theme.shadowRadiusMedium, x: 0, y: 8)
        )
    }

    private func textField(title: String, placeholder: String, text: Binding<String>, keyboardType: UIKeyboardType = .default) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(theme.secondaryText)

            TextField(placeholder, text: text)
                .font(.system(size: 17))
                .foregroundColor(theme.primaryText)
                .keyboardType(keyboardType)
                .autocapitalization(keyboardType == .emailAddress ? .none : .words)
                .padding(16)
                .background(theme.tertiaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: theme.radiusMedium))
                .overlay(
                    RoundedRectangle(cornerRadius: theme.radiusMedium)
                        .stroke(theme.border, lineWidth: 1)
                )
        }
    }

    private var saveButton: some View {
        Button(action: { saveProfile() }) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                Text("Complete Profile")
            }
            .font(.system(size: 17, weight: .semibold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(isFormValid ? theme.accent : theme.tertiaryText)
            .clipShape(RoundedRectangle(cornerRadius: theme.radiusMedium))
        }
        .disabled(!isFormValid || isSaving)
    }

    private var isFormValid: Bool {
        !firstName.isEmpty && !lastName.isEmpty
    }

    private func saveProfile() {
        guard var user = authManager.currentUser else { return }

        isSaving = true

        Task {
            do {
                // Upload profile image if one was selected
                if let profileImage = profileImage,
                   let userId = user.id {
                    let imageUrl = try await NetworkService.shared.uploadImage(image: profileImage, userId: userId)
                    user.profileImageUrl = imageUrl
                }

                // Update user profile
                user.firstName = firstName
                user.lastName = lastName
                user.phoneNumber = phoneNumber.isEmpty ? nil : phoneNumber
                user.role = role.isEmpty ? nil : role

                let updatedUser = try await NetworkService.shared.updateUserProfile(user)
                authManager.currentUser = updatedUser

                // Mark profile as completed
                authManager.needsProfileCompletion = false
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }

            isSaving = false
        }
    }
}
