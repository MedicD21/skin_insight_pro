import SwiftUI

struct AddTeamMemberView: View {
    @ObservedObject var theme = ThemeManager.shared
    @Environment(\.dismiss) var dismiss
    var onComplete: (() -> Void)? = nil

    @State private var email = ""
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var role = ""
    @State private var isAdmin = false
    @State private var password = "Welcome123!"
    @State private var isSaving = false
    @State private var showError = false
    @State private var errorMessage = ""

    private var isFormValid: Bool {
        !email.isEmpty && email.contains("@") && !firstName.isEmpty && !lastName.isEmpty && password.count >= 6
    }

    var body: some View {
        NavigationStack {
            ZStack {
                theme.primaryBackground
                    .ignoresSafeArea()

                Form {
                    Section(header: Text("Account").foregroundColor(theme.secondaryText)) {
                        TextField("Email", text: $email)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .disableAutocorrection(true)

                        SecureField("Temporary Password", text: $password)
                    }

                    Section(header: Text("Profile").foregroundColor(theme.secondaryText)) {
                        TextField("First Name", text: $firstName)
                        TextField("Last Name", text: $lastName)
                        TextField("Role (e.g., Esthetician)", text: $role)
                    }

                    Section {
                        Toggle("Admin", isOn: $isAdmin)
                    }

                    Section(footer: Text("New users will be asked to reset their password on first login.").foregroundColor(theme.secondaryText)) {
                        EmptyView()
                    }
                }

                if isSaving {
                    Color.black.opacity(0.3).ignoresSafeArea()
                    ProgressView("Creating user...")
                        .tint(theme.accent)
                        .scaleEffect(1.2)
                }
            }
            .navigationTitle("Add Team Member")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveUser() }
                        .disabled(!isFormValid || isSaving)
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    private func saveUser() {
        guard let companyRef = AuthenticationManager.shared.currentUser?.companyId else {
            errorMessage = "No company associated with your account."
            showError = true
            return
        }

        isSaving = true
        Task {
            do {
                let resolvedCompany = try await NetworkService.shared.resolveCompanyAssociation(from: companyRef)
                let companyName = resolvedCompany.name ?? AuthenticationManager.shared.currentUser?.companyName

                _ = try await NetworkService.shared.createEmployeeAccount(
                    email: email,
                    password: password,
                    firstName: firstName,
                    lastName: lastName,
                    role: role,
                    isAdmin: isAdmin,
                    companyId: resolvedCompany.id,
                    companyName: companyName
                )
                onComplete?()
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
            isSaving = false
        }
    }
}
