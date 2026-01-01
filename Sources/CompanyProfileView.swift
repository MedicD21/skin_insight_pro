import SwiftUI

struct CompanyProfileView: View {
    @ObservedObject var theme = ThemeManager.shared
    @StateObject private var authManager = AuthenticationManager.shared
    @Environment(\.dismiss) var dismiss

    @State private var company: Company?
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showCreateCompany = false
    @State private var showTeamMembers = false

    var body: some View {
        NavigationStack {
            ZStack {
                theme.primaryBackground
                    .ignoresSafeArea()

                if isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(theme.accent)
                } else if let company = company {
                    companyDetailsView(company: company)
                } else {
                    emptyStateView
                }
            }
            .navigationTitle("Company Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }

                if company != nil && authManager.currentUser?.isAdmin == true {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Edit") {
                            showCreateCompany = true
                        }
                    }
                }
            }
            .sheet(isPresented: $showCreateCompany) {
                EditCompanyView(company: company)
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .task {
                await loadCompany()
            }
        }
    }

    private func companyDetailsView(company: Company) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                companyLogoSection(company: company)

                companyInfoSection(company: company)

                teamMembersSection
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 100)
        }
    }

    private func companyLogoSection(company: Company) -> some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(theme.accent.opacity(0.15))
                    .frame(width: 100, height: 100)

                if let logoUrl = company.logoUrl, let url = URL(string: logoUrl) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: 100, height: 100)
                                .clipShape(Circle())
                        default:
                            Image(systemName: "building.2.fill")
                                .font(.system(size: 50))
                                .foregroundColor(theme.accent)
                        }
                    }
                } else {
                    Image(systemName: "building.2.fill")
                        .font(.system(size: 50))
                        .foregroundColor(theme.accent)
                }
            }

            VStack(spacing: 6) {
                Text(company.name ?? "Company")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(theme.primaryText)

                if let website = company.website, !website.isEmpty {
                    Link(website, destination: URL(string: website) ?? URL(string: "https://example.com")!)
                        .font(.system(size: 15))
                        .foregroundColor(theme.accent)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func companyInfoSection(company: Company) -> some View {
        VStack(spacing: 16) {
            Text("Company Information")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(theme.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 12) {
                if let address = company.address, !address.isEmpty {
                    infoRow(icon: "mappin.circle.fill", label: "Address", value: address)
                }

                if let phone = company.phone, !phone.isEmpty {
                    infoRow(icon: "phone.circle.fill", label: "Phone", value: phone)
                }

                if let email = company.email, !email.isEmpty {
                    infoRow(icon: "envelope.circle.fill", label: "Email", value: email)
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

    private func infoRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(theme.accent)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.system(size: 13))
                    .foregroundColor(theme.secondaryText)

                Text(value)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(theme.primaryText)
            }

            Spacer()
        }
        .padding(.vertical, 8)
    }

    private var teamMembersSection: some View {
        VStack(spacing: 16) {
            Text("Team Members")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(theme.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: { showTeamMembers = true }) {
                HStack {
                    Image(systemName: "person.2.fill")
                    Text("Manage Team")
                }
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(theme.accent)
                .clipShape(RoundedRectangle(cornerRadius: theme.radiusMedium))
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: theme.radiusXL)
                .fill(theme.cardBackground)
                .shadow(color: theme.shadowColor, radius: theme.shadowRadiusMedium, x: 0, y: 8)
        )
        .sheet(isPresented: $showTeamMembers) {
            TeamMembersView()
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "building.2")
                .font(.system(size: 60))
                .foregroundColor(theme.tertiaryText)

            Text("No Company Profile")
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(theme.primaryText)

            Text("Create a company profile to share clients across your team")
                .font(.system(size: 16))
                .foregroundColor(theme.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button(action: { showCreateCompany = true }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Create Company Profile")
                }
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 32)
                .padding(.vertical, 16)
                .background(theme.accent)
                .clipShape(RoundedRectangle(cornerRadius: theme.radiusMedium))
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 100)
    }

    private func loadCompany() async {
        guard let companyId = authManager.currentUser?.companyId else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            let fetchedCompany = try await NetworkService.shared.fetchCompany(id: companyId)
            company = fetchedCompany
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

struct EditCompanyView: View {
    @ObservedObject var theme = ThemeManager.shared
    @Environment(\.dismiss) var dismiss

    let company: Company?

    @State private var name: String
    @State private var address: String
    @State private var phone: String
    @State private var email: String
    @State private var website: String
    @State private var isSaving = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showImagePicker = false
    @State private var selectedImage: UIImage?

    init(company: Company?) {
        self.company = company
        _name = State(initialValue: company?.name ?? "")
        _address = State(initialValue: company?.address ?? "")
        _phone = State(initialValue: company?.phone ?? "")
        _email = State(initialValue: company?.email ?? "")
        _website = State(initialValue: company?.website ?? "")
    }

    var body: some View {
        NavigationStack {
            ZStack {
                theme.primaryBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        logoSection

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
            .navigationTitle(company == nil ? "Create Company" : "Edit Company")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveCompany()
                    }
                    .disabled(!isFormValid || isSaving)
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(image: $selectedImage, sourceType: .photoLibrary)
            }
        }
    }

    private var logoSection: some View {
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
                } else if let logoUrl = company?.logoUrl, let url = URL(string: logoUrl) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: 100, height: 100)
                                .clipShape(Circle())
                        default:
                            Image(systemName: "building.2.fill")
                                .font(.system(size: 50))
                                .foregroundColor(theme.accent)
                        }
                    }
                } else {
                    Image(systemName: "building.2.fill")
                        .font(.system(size: 50))
                        .foregroundColor(theme.accent)
                }
            }

            Button(action: { showImagePicker = true }) {
                Text("Upload Logo")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(theme.accent)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var formSection: some View {
        VStack(spacing: 20) {
            textField(title: "Company Name", placeholder: "Enter company name", text: $name)
            textField(title: "Address", placeholder: "Enter address", text: $address)
            textField(title: "Phone", placeholder: "Enter phone number", text: $phone, keyboardType: .phonePad)
            textField(title: "Email", placeholder: "Enter email", text: $email, keyboardType: .emailAddress)
            textField(title: "Website", placeholder: "Enter website URL", text: $website, keyboardType: .URL)
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
                .autocapitalization(keyboardType == .emailAddress || keyboardType == .URL ? .none : .sentences)
                .padding(16)
                .background(theme.tertiaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: theme.radiusMedium))
                .overlay(
                    RoundedRectangle(cornerRadius: theme.radiusMedium)
                        .stroke(theme.border, lineWidth: 1)
                )
        }
    }

    private var isFormValid: Bool {
        !name.isEmpty && !email.isEmpty && !phone.isEmpty
    }

    private func saveCompany() {
        isSaving = true

        Task {
            do {
                // Create or update company
                var companyToSave = company ?? Company()
                companyToSave.name = name
                companyToSave.address = address
                companyToSave.phone = phone
                companyToSave.email = email
                companyToSave.website = website

                // Upload logo image if one was selected
                if let selectedImage = selectedImage {
                    // Use a temporary company ID for upload path
                    let uploadId = companyToSave.id ?? UUID().uuidString
                    let imageUrl = try await NetworkService.shared.uploadImage(image: selectedImage, userId: uploadId)
                    companyToSave.logoUrl = imageUrl
                }

                let savedCompany = try await NetworkService.shared.createOrUpdateCompany(companyToSave)

                // Update user's company_id if creating a new company
                if company == nil, let companyId = savedCompany.id {
                    var updatedUser = AuthenticationManager.shared.currentUser
                    updatedUser?.companyId = companyId
                    if let user = updatedUser {
                        let savedUser = try await NetworkService.shared.updateUserProfile(user)
                        AuthenticationManager.shared.currentUser = savedUser
                    }
                }

                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
            isSaving = false
        }
    }
}
