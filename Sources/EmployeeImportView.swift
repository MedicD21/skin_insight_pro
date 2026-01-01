import SwiftUI
import UniformTypeIdentifiers

struct EmployeeImportView: View {
    @ObservedObject var theme = ThemeManager.shared
    @StateObject private var authManager = AuthenticationManager.shared
    @Environment(\.dismiss) var dismiss
    @State private var isImporting = false
    @State private var importedEmployees: [EmployeeImportData] = []
    @State private var importErrors: [String] = []
    @State private var showPreview = false
    @State private var csvText = ""
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var defaultPassword = "Welcome123!"

    struct EmployeeImportData: Identifiable {
        let id = UUID()
        let email: String
        let firstName: String
        let lastName: String
        let role: String
        let isAdmin: Bool
    }

    var body: some View {
        NavigationStack {
            ZStack {
                theme.primaryBackground
                    .ignoresSafeArea()

                if isImporting {
                    loadingView
                } else if showPreview {
                    previewView
                } else {
                    uploadView
                }
            }
            .navigationTitle("Import Employees")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }

    private var uploadView: some View {
        ScrollView {
            VStack(spacing: 24) {
                instructionsCard
                defaultPasswordSection
                csvInputSection
                templateSection
            }
            .padding(20)
        }
    }

    private var instructionsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(theme.accent)
                Text("How to Import")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(theme.primaryText)
            }

            VStack(alignment: .leading, spacing: 8) {
                instructionRow(number: "1", text: "Set a default password for all employees")
                instructionRow(number: "2", text: "Download the CSV template below")
                instructionRow(number: "3", text: "Fill in employee data")
                instructionRow(number: "4", text: "Paste the CSV content below")
                instructionRow(number: "5", text: "Review and import")
            }

            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                    .font(.system(size: 14))
                Text("All employees will be asked to reset their password on first login")
                    .font(.system(size: 13))
                    .foregroundColor(theme.secondaryText)
            }
            .padding(.top, 8)
        }
        .padding(16)
        .background(theme.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: theme.radiusMedium))
    }

    private func instructionRow(number: String, text: String) -> some View {
        HStack(spacing: 12) {
            Text(number)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 28, height: 28)
                .background(theme.accent)
                .clipShape(Circle())

            Text(text)
                .font(.system(size: 15))
                .foregroundColor(theme.primaryText)
        }
    }

    private var defaultPasswordSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Default Password")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(theme.primaryText)

            Text("This password will be used for all imported employees")
                .font(.system(size: 14))
                .foregroundColor(theme.secondaryText)

            TextField("Enter default password", text: $defaultPassword)
                .font(.system(size: 17))
                .foregroundColor(theme.primaryText)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .padding(16)
                .background(theme.tertiaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: theme.radiusMedium))
                .overlay(
                    RoundedRectangle(cornerRadius: theme.radiusMedium)
                        .stroke(theme.border, lineWidth: 1)
                )

            Text("Password must have: At least 6 characters, 1 capital letter, and 1 special character")
                .font(.system(size: 12))
                .foregroundColor(theme.secondaryText)
        }
    }

    private var csvInputSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("CSV Content")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(theme.primaryText)

            Text("Paste your CSV data below (including header row)")
                .font(.system(size: 14))
                .foregroundColor(theme.secondaryText)

            TextEditor(text: $csvText)
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(theme.primaryText)
                .frame(minHeight: 200)
                .padding(12)
                .background(theme.tertiaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: theme.radiusMedium))
                .overlay(
                    RoundedRectangle(cornerRadius: theme.radiusMedium)
                        .stroke(theme.border, lineWidth: 1)
                )

            Button(action: { parseCSV() }) {
                HStack {
                    Spacer()
                    Image(systemName: "arrow.right.circle.fill")
                    Text("Preview Import")
                    Spacer()
                }
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)
                .frame(height: 52)
                .background((csvText.isEmpty || !isPasswordValid) ? theme.tertiaryText : theme.accent)
                .clipShape(RoundedRectangle(cornerRadius: theme.radiusMedium))
            }
            .disabled(csvText.isEmpty || !isPasswordValid)
        }
    }

    private var templateSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Template & Documentation")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(theme.primaryText)

            VStack(spacing: 12) {
                Button(action: { copyTemplateToClipboard() }) {
                    HStack {
                        Image(systemName: "doc.on.doc")
                        Text("Copy CSV Template")
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                    .font(.system(size: 15))
                    .foregroundColor(theme.primaryText)
                    .padding(16)
                    .background(theme.secondaryBackground)
                    .clipShape(RoundedRectangle(cornerRadius: theme.radiusMedium))
                }

                Button(action: { pasteExampleData() }) {
                    HStack {
                        Image(systemName: "text.badge.plus")
                        Text("Paste Example Data")
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                    .font(.system(size: 15))
                    .foregroundColor(theme.primaryText)
                    .padding(16)
                    .background(theme.secondaryBackground)
                    .clipShape(RoundedRectangle(cornerRadius: theme.radiusMedium))
                }
            }
        }
    }

    private var previewView: some View {
        ScrollView {
            VStack(spacing: 24) {
                summaryCard

                if !importErrors.isEmpty {
                    errorsCard
                }

                if !importedEmployees.isEmpty {
                    employeesPreviewCard
                }

                actionButtons
            }
            .padding(20)
        }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("Import Preview")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(theme.primaryText)
            }

            HStack(spacing: 32) {
                VStack(spacing: 4) {
                    Text("\(importedEmployees.count)")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(theme.accent)
                    Text("Employees")
                        .font(.system(size: 14))
                        .foregroundColor(theme.secondaryText)
                }

                VStack(spacing: 4) {
                    Text("\(importErrors.count)")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(importErrors.isEmpty ? .green : .red)
                    Text("Errors")
                        .font(.system(size: 14))
                        .foregroundColor(theme.secondaryText)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(16)
        .background(theme.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: theme.radiusMedium))
    }

    private var errorsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
                Text("Import Errors")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(theme.primaryText)
            }

            VStack(alignment: .leading, spacing: 8) {
                ForEach(importErrors.prefix(10), id: \.self) { error in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.red)
                            .padding(.top, 2)

                        Text(error)
                            .font(.system(size: 13))
                            .foregroundColor(theme.primaryText)
                    }
                }

                if importErrors.count > 10 {
                    Text("And \(importErrors.count - 10) more errors...")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(theme.secondaryText)
                        .padding(.top, 4)
                }
            }
        }
        .padding(16)
        .background(Color.red.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: theme.radiusMedium))
    }

    private var employeesPreviewCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Employees to Import")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(theme.primaryText)

            VStack(spacing: 8) {
                ForEach(importedEmployees.prefix(10)) { employee in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(employee.firstName) \(employee.lastName)")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(theme.primaryText)

                            Text(employee.email)
                                .font(.system(size: 13))
                                .foregroundColor(theme.secondaryText)
                        }

                        Spacer()

                        if employee.isAdmin {
                            Text("Admin")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(theme.accent)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(theme.accent.opacity(0.15))
                                .clipShape(Capsule())
                        }
                    }
                    .padding(12)
                    .background(theme.tertiaryBackground)
                    .clipShape(RoundedRectangle(cornerRadius: theme.radiusSmall))
                }

                if importedEmployees.count > 10 {
                    Text("And \(importedEmployees.count - 10) more employees...")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(theme.secondaryText)
                        .padding(.top, 4)
                }
            }
        }
        .padding(16)
        .background(theme.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: theme.radiusMedium))
    }

    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button(action: { performImport() }) {
                HStack {
                    Spacer()
                    Image(systemName: "square.and.arrow.down.fill")
                    Text("Import \(importedEmployees.count) Employees")
                    Spacer()
                }
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)
                .frame(height: 52)
                .background(importedEmployees.isEmpty ? theme.tertiaryText : theme.accent)
                .clipShape(RoundedRectangle(cornerRadius: theme.radiusMedium))
            }
            .disabled(importedEmployees.isEmpty)

            Button(action: {
                showPreview = false
                importedEmployees = []
                importErrors = []
            }) {
                Text("Back to Edit")
                    .font(.system(size: 16))
                    .foregroundColor(theme.accent)
            }
        }
    }

    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(theme.accent)

            Text("Importing employees...")
                .font(.system(size: 17))
                .foregroundColor(theme.primaryText)
        }
    }

    // MARK: - Functions

    private var isPasswordValid: Bool {
        let hasMinLength = defaultPassword.count >= 6
        let hasCapital = defaultPassword.range(of: "[A-Z]", options: .regularExpression) != nil
        let hasSpecial = defaultPassword.range(of: "[!@#$%^&*(),.?\":{}|<>]", options: .regularExpression) != nil
        return hasMinLength && hasCapital && hasSpecial
    }

    private func copyTemplateToClipboard() {
        let template = "email,first_name,last_name,role,is_admin\njohn.doe@example.com,John,Doe,Esthetician,FALSE"
        UIPasteboard.general.string = template

        errorMessage = "CSV template copied to clipboard!"
        showError = true
    }

    private func pasteExampleData() {
        csvText = """
email,first_name,last_name,role,is_admin
sarah.johnson@example.com,Sarah,Johnson,Lead Esthetician,TRUE
mike.chen@example.com,Mike,Chen,Esthetician,FALSE
emma.davis@example.com,Emma,Davis,Spa Manager,TRUE
alex.williams@example.com,Alex,Williams,Esthetician,FALSE
"""
    }

    private func parseCSV() {
        importedEmployees = []
        importErrors = []

        let lines = csvText.components(separatedBy: .newlines)
        guard lines.count > 1 else {
            errorMessage = "CSV file is empty or invalid"
            showError = true
            return
        }

        // Skip header row
        for (index, line) in lines.dropFirst().enumerated() {
            let rowNumber = index + 2

            guard !line.trimmingCharacters(in: .whitespaces).isEmpty else {
                continue
            }

            let columns = parseCSVLine(line)

            guard columns.count >= 4 else {
                importErrors.append("Row \(rowNumber): Not enough columns (need email, first_name, last_name, role)")
                continue
            }

            // Required fields
            let email = columns[0].trimmingCharacters(in: .whitespaces)
            let firstName = columns[1].trimmingCharacters(in: .whitespaces)
            let lastName = columns[2].trimmingCharacters(in: .whitespaces)
            let role = columns[3].trimmingCharacters(in: .whitespaces)

            // Validate email
            if email.isEmpty || !email.contains("@") {
                importErrors.append("Row \(rowNumber): Invalid email address")
                continue
            }
            if firstName.isEmpty {
                importErrors.append("Row \(rowNumber): First name is required")
                continue
            }
            if lastName.isEmpty {
                importErrors.append("Row \(rowNumber): Last name is required")
                continue
            }
            if role.isEmpty {
                importErrors.append("Row \(rowNumber): Role is required")
                continue
            }

            // Parse is_admin
            var isAdmin = false
            if columns.count > 4 {
                let isAdminStr = columns[4].trimmingCharacters(in: .whitespaces).uppercased()
                isAdmin = isAdminStr == "TRUE" || isAdminStr == "1" || isAdminStr == "YES"
            }

            let employee = EmployeeImportData(
                email: email,
                firstName: firstName,
                lastName: lastName,
                role: role,
                isAdmin: isAdmin
            )

            importedEmployees.append(employee)
        }

        showPreview = true
    }

    private func parseCSVLine(_ line: String) -> [String] {
        var columns: [String] = []
        var currentColumn = ""
        var insideQuotes = false

        for char in line {
            if char == "\"" {
                insideQuotes.toggle()
            } else if char == "," && !insideQuotes {
                columns.append(currentColumn)
                currentColumn = ""
            } else {
                currentColumn.append(char)
            }
        }
        columns.append(currentColumn)

        return columns
    }

    private func performImport() {
        guard let companyId = authManager.currentUser?.companyId else {
            errorMessage = "No company associated with your account"
            showError = true
            return
        }

        isImporting = true

        Task {
            var successCount = 0
            var failCount = 0

            for employee in importedEmployees {
                do {
                    _ = try await NetworkService.shared.createEmployeeAccount(
                        email: employee.email,
                        password: defaultPassword,
                        firstName: employee.firstName,
                        lastName: employee.lastName,
                        role: employee.role,
                        isAdmin: employee.isAdmin,
                        companyId: companyId
                    )
                    successCount += 1
                } catch {
                    failCount += 1
                    importErrors.append("Failed to import \(employee.email): \(error.localizedDescription)")
                }
            }

            await MainActor.run {
                isImporting = false

                if failCount == 0 {
                    dismiss()
                } else {
                    errorMessage = "Imported \(successCount) employees successfully. \(failCount) failed."
                    showError = true
                    showPreview = false
                }
            }
        }
    }
}
