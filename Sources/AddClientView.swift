import SwiftUI

struct AddClientView: View {
    @ObservedObject var theme = ThemeManager.shared
    @ObservedObject var viewModel: ClientDashboardViewModel
    @Environment(\.dismiss) var dismiss
    @State private var name = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var notes = ""
    @State private var medicalHistory = ""
    @State private var allergies = ""
    @State private var knownSensitivities = ""
    @State private var medications = ""
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    @FocusState private var focusedField: Field?

    enum Field {
        case name, email, phone, notes, medicalHistory, allergies, knownSensitivities, medications
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                theme.primaryBackground
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        basicInfoSection
                        medicalInfoSection
                    }
                    .padding(20)
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
            .navigationTitle("Add Client")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItemGroup(placement: .confirmationAction) {
                    Button("Save") {
                        saveClient()
                    }
                    .fontWeight(.semibold)
                    .disabled(!isFormValid)
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }

    private var basicInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Basic Information")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(theme.primaryText)
            
            VStack(spacing: 16) {
                formField(
                    title: "Name",
                    icon: "person",
                    placeholder: "Client name",
                    text: $name,
                    field: .name
                )
                
                formField(
                    title: "Email",
                    icon: "envelope",
                    placeholder: "client@example.com",
                    text: $email,
                    field: .email,
                    keyboardType: .emailAddress
                )
                
                formField(
                    title: "Phone",
                    icon: "phone",
                    placeholder: "+1 (555) 123-4567",
                    text: $phone,
                    field: .phone,
                    keyboardType: .phonePad
                )
                
                textEditorField(
                    title: "Notes",
                    icon: "note.text",
                    placeholder: "Additional notes about the client",
                    text: $notes,
                    field: .notes
                )
            }
        }
    }
    
    private var medicalInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "cross.case")
                    .foregroundColor(theme.accent)
                Text("Medical Information")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(theme.primaryText)
            }
            
            Text("This information will be considered during skin analysis")
                .font(.system(size: 13))
                .foregroundColor(theme.secondaryText)
            
            VStack(spacing: 16) {
                textEditorField(
                    title: "Medical History",
                    icon: "heart.text.square",
                    placeholder: "Any relevant medical conditions, medications, or treatments",
                    text: $medicalHistory,
                    field: .medicalHistory
                )
                
                textEditorField(
                    title: "Allergies",
                    icon: "exclamationmark.triangle",
                    placeholder: "Known allergies to products, ingredients, or substances",
                    text: $allergies,
                    field: .allergies
                )
                
                textEditorField(
                    title: "Known Sensitivities",
                    icon: "hand.raised",
                    placeholder: "Skin sensitivities or reactions to specific treatments",
                    text: $knownSensitivities,
                    field: .knownSensitivities
                )

                textEditorField(
                    title: "Medications and/or Supplements",
                    icon: "pills",
                    placeholder: "List any medications or supplements the client is currently taking",
                    text: $medications,
                    field: .medications
                )
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: theme.radiusXL)
                .fill(theme.cardBackground)
                .shadow(color: theme.shadowColor, radius: theme.shadowRadiusSmall, x: 0, y: 4)
        )
    }
    
    private func formField(
        title: String,
        icon: String,
        placeholder: String,
        text: Binding<String>,
        field: Field,
        keyboardType: UIKeyboardType = .default
    ) -> some View {
        ThemedTextField(
            title: title,
            placeholder: placeholder,
            text: text,
            field: field,
            focusedField: $focusedField,
            theme: theme,
            icon: icon,
            keyboardType: keyboardType,
            textContentType: keyboardType == .emailAddress ? .emailAddress : nil,
            autocapitalization: keyboardType == .emailAddress ? .none : .words
        )
    }
    
    private func textEditorField(
        title: String,
        icon: String,
        placeholder: String,
        text: Binding<String>,
        field: Field
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(theme.secondaryText)
            
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(theme.tertiaryText)
                    .frame(width: 24)
                    .padding(.top, 12)
                
                ZStack(alignment: .topLeading) {
                    if text.wrappedValue.isEmpty {
                        Text(placeholder)
                            .font(.system(size: 17))
                            .foregroundColor(theme.tertiaryText)
                            .padding(.top, 8)
                            .padding(.leading, 4)
                    }
                    
                    TextEditor(text: text)
                        .font(.system(size: 17))
                        .foregroundColor(theme.primaryText)
                        .frame(minHeight: 80)
                        .focused($focusedField, equals: field)
                        .scrollContentBackground(.hidden)
                }
            }
            .padding(16)
            .background(theme.tertiaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: theme.radiusMedium))
            .overlay(
                RoundedRectangle(cornerRadius: theme.radiusMedium)
                    .stroke(focusedField == field ? theme.accent : theme.border, lineWidth: focusedField == field ? 2 : 1)
            )
        }
    }
    
    private var isFormValid: Bool {
        !name.isEmpty && !email.isEmpty && email.contains("@")
    }
    
    private func saveClient() {
        focusedField = nil
        isLoading = true

        let newClient = AppClient(
            id: nil,
            userId: AuthenticationManager.shared.currentUser?.id,
            companyId: AuthenticationManager.shared.currentUser?.companyId,
            name: name,
            phone: phone,
            email: email,
            notes: notes,
            medicalHistory: medicalHistory.isEmpty ? nil : medicalHistory,
            allergies: allergies.isEmpty ? nil : allergies,
            knownSensitivities: knownSensitivities.isEmpty ? nil : knownSensitivities,
            medications: medications.isEmpty ? nil : medications,
            profileImageUrl: nil
        )

        Task {
            await viewModel.addClient(newClient)
            isLoading = false

            if viewModel.showError {
                errorMessage = viewModel.errorMessage
                showError = true
                viewModel.showError = false
            } else {
                dismiss()
            }
        }
    }
}
