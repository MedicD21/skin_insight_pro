import SwiftUI

struct EditClientView: View {
    @ObservedObject var theme = ThemeManager.shared
    let client: AppClient
    let onUpdate: (AppClient) -> Void
    var onDelete: ((AppClient) -> Void)? = nil
    @Environment(\.dismiss) var dismiss
    @State private var name: String
    @State private var email: String
    @State private var phone: String
    @State private var notes: String
    @State private var medicalHistory: String
    @State private var allergies: String
    @State private var knownSensitivities: String
    @State private var medications: String
    @State private var productsToAvoid: String
    @State private var fillersDate: Date?
    @State private var biostimulatorsDate: Date?
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showDeleteConfirm = false
    @FocusState private var focusedField: Field?

    enum Field {
        case name, email, phone, notes, medicalHistory, allergies, knownSensitivities, medications, productsToAvoid
    }

    init(client: AppClient, onUpdate: @escaping (AppClient) -> Void, onDelete: ((AppClient) -> Void)? = nil) {
        self.client = client
        self.onUpdate = onUpdate
        self.onDelete = onDelete
        _name = State(initialValue: client.name ?? "")
        _email = State(initialValue: client.email ?? "")
        _phone = State(initialValue: client.phone ?? "")
        _notes = State(initialValue: client.notes ?? "")
        _medicalHistory = State(initialValue: client.medicalHistory ?? "")
        _allergies = State(initialValue: client.allergies ?? "")
        _knownSensitivities = State(initialValue: client.knownSensitivities ?? "")
        _medications = State(initialValue: client.medications ?? "")
        _productsToAvoid = State(initialValue: client.productsToAvoid ?? "")

        // Parse dates from ISO strings if they exist
        if let fillersDateString = client.fillersDate,
           let date = ISO8601DateFormatter().date(from: fillersDateString) {
            _fillersDate = State(initialValue: date)
        }
        if let biostimulatorsDateString = client.biostimulatorsDate,
           let date = ISO8601DateFormatter().date(from: biostimulatorsDateString) {
            _biostimulatorsDate = State(initialValue: date)
        }
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
                        deleteSection
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
            .navigationTitle("Edit Client")
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
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .alert("Delete Client", isPresented: $showDeleteConfirm) {
                Button("Delete", role: .destructive) {
                    Task { await deleteClient() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to delete this client? This action cannot be undone.")
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
                    placeholder: "(555) 123-4567",
                    text: Binding(
                        get: { phone.formatPhoneNumber() },
                        set: { phone = $0.unformatPhoneNumber() }
                    ),
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

                textEditorField(
                    title: "Products to Avoid",
                    icon: "exclamationmark.shield",
                    placeholder: "Specific products or ingredients this client should NOT use",
                    text: $productsToAvoid,
                    field: .productsToAvoid
                )

                Divider()
                    .padding(.vertical, 8)

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "cross.vial.fill")
                            .font(.system(size: 16))
                            .foregroundColor(theme.accent)
                        Text("Injectables History")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(theme.secondaryText)
                    }

                    HStack(spacing: 12) {
                        compactDatePickerField(
                            title: "Last Fillers",
                            date: $fillersDate
                        )

                        compactDatePickerField(
                            title: "Last Biostimulators",
                            date: $biostimulatorsDate
                        )
                    }
                }
            }
        }
    }

    private var deleteSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(role: .destructive) {
                showDeleteConfirm = true
            } label: {
                HStack {
                    Spacer()
                    Image(systemName: "trash")
                    Text("Delete Client")
                    Spacer()
                }
                .font(.system(size: 16, weight: .semibold))
                .padding()
                .background(theme.tertiaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: theme.radiusMedium))
            }

            Text("This will remove the client and their data from your workspace.")
                .font(.system(size: 13))
                .foregroundColor(theme.secondaryText)
                .frame(maxWidth: .infinity, alignment: .center)
        }
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

    private func compactDatePickerField(
        title: String,
        date: Binding<Date?>
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(theme.secondaryText)

            VStack(spacing: 0) {
                if let selectedDate = date.wrappedValue {
                    DatePicker(
                        "",
                        selection: Binding(
                            get: { selectedDate },
                            set: { date.wrappedValue = $0 }
                        ),
                        displayedComponents: .date
                    )
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .frame(maxWidth: .infinity)
                    .padding(12)
                    .background(theme.tertiaryBackground)

                    Button(action: {
                        date.wrappedValue = nil
                    }) {
                        HStack {
                            Image(systemName: "xmark.circle.fill")
                            Text("Clear")
                        }
                        .font(.system(size: 13))
                        .foregroundColor(theme.tertiaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    .background(theme.tertiaryBackground.opacity(0.5))
                } else {
                    Button(action: {
                        date.wrappedValue = Date()
                    }) {
                        HStack {
                            Image(systemName: "calendar.badge.plus")
                            Text("Set Date")
                        }
                        .font(.system(size: 14))
                        .foregroundColor(theme.accent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                    }
                    .background(theme.tertiaryBackground)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: theme.radiusMedium))
            .overlay(
                RoundedRectangle(cornerRadius: theme.radiusMedium)
                    .stroke(theme.border, lineWidth: 1)
            )
        }
        .frame(maxWidth: .infinity)
    }
    
    private var isFormValid: Bool {
        !name.isEmpty && !email.isEmpty && email.contains("@")
    }
    
    private func saveClient() {
        focusedField = nil
        isLoading = true

        // Convert dates to ISO8601 strings
        let isoFormatter = ISO8601DateFormatter()
        let fillersDateString = fillersDate.map { isoFormatter.string(from: $0) }
        let biostimulatorsDateString = biostimulatorsDate.map { isoFormatter.string(from: $0) }

        let updatedClient = AppClient(
            id: client.id,
            userId: client.userId,
            companyId: client.companyId,
            name: name,
            phone: phone,
            email: email,
            notes: notes.isEmpty ? nil : notes,
            medicalHistory: medicalHistory.isEmpty ? nil : medicalHistory,
            allergies: allergies.isEmpty ? nil : allergies,
            knownSensitivities: knownSensitivities.isEmpty ? nil : knownSensitivities,
            medications: medications.isEmpty ? nil : medications,
            productsToAvoid: productsToAvoid.isEmpty ? nil : productsToAvoid,
            profileImageUrl: client.profileImageUrl,
            fillersDate: fillersDateString,
            biostimulatorsDate: biostimulatorsDateString,
            consentSignature: client.consentSignature,
            consentDate: client.consentDate
        )
        
        Task {
            do {
                guard let userId = AuthenticationManager.shared.currentUser?.id else {
                    isLoading = false
                    return
                }
                
                let savedClient = try await NetworkService.shared.createOrUpdateClient(client: updatedClient, userId: userId)
                isLoading = false
                onUpdate(savedClient)
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

    private func deleteClient() async {
        guard let clientId = client.id else {
            errorMessage = "Client ID not found"
            showError = true
            return
        }

        isLoading = true
        do {
            try await NetworkService.shared.deleteClient(clientId: clientId)
            await MainActor.run {
                onDelete?(client)
                dismiss()
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
        isLoading = false
    }
}
