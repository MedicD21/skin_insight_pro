import SwiftUI

struct AIRulesView: View {
    @ObservedObject var theme = ThemeManager.shared
    @StateObject private var viewModel = AIRulesViewModel()
    @State private var showAddRule = false
    @State private var selectedRule: AIRule?
    @State private var searchText = ""
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack {
            theme.primaryBackground
                .ignoresSafeArea()

            if viewModel.isLoading && viewModel.rules.isEmpty {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(theme.accent)
            } else if viewModel.rules.isEmpty {
                emptyStateView
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.rules.sorted(by: { ($0.priority ?? 0) > ($1.priority ?? 0) })) { rule in
                            Button(action: { selectedRule = rule }) {
                                AIRuleRowView(rule: rule)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 100)
                }
            }
        }
        .navigationTitle("AI Rules")
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(action: { dismiss() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                }
            }
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button(action: { showAddRule = true }) {
                    Label("Add Rule", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showAddRule) {
            AddAIRuleView(viewModel: viewModel)
        }
        .sheet(item: $selectedRule) { rule in
            EditAIRuleView(rule: rule, viewModel: viewModel)
        }
        .task {
            await viewModel.loadRules()
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "brain")
                .font(.system(size: 60))
                .foregroundColor(theme.tertiaryText)

            Text("No AI Rules Yet")
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(theme.primaryText)

            Text("Create rules to teach the AI which products to recommend for specific skin conditions")
                .font(.system(size: 16))
                .foregroundColor(theme.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button(action: { showAddRule = true }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Rule")
                }
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 32)
                .padding(.vertical, 16)
                .background(theme.accent)
                .clipShape(RoundedRectangle(cornerRadius: theme.radiusMedium))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 100)
    }
}

struct AIRuleRowView: View {
    @ObservedObject var theme = ThemeManager.shared
    let rule: AIRule

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(rule.name ?? "Unnamed Rule")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(theme.primaryText)

                Spacer()

                if let isActive = rule.isActive {
                    Text(isActive ? "Active" : "Inactive")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(isActive ? theme.accent : theme.tertiaryText)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(isActive ? theme.accentSubtle.opacity(0.2) : theme.tertiaryBackground)
                        .clipShape(Capsule())
                }
            }

            if let condition = rule.condition, !condition.isEmpty {
                Text("When: \(condition)")
                    .font(.system(size: 14))
                    .foregroundColor(theme.secondaryText)
            }

            HStack {
                if let priority = rule.priority {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 12))
                        Text("Priority: \(priority)")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundColor(theme.accent)
                }

                if rule.companyId != nil {
                    Spacer()
                    HStack(spacing: 4) {
                        Image(systemName: "building.2.fill")
                            .font(.system(size: 11))
                        Text("Company Rule")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(theme.secondaryText)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: theme.radiusLarge)
                .fill(theme.cardBackground)
                .shadow(color: theme.shadowColor, radius: theme.shadowRadiusSmall, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: theme.radiusLarge)
                .stroke(theme.cardBorder, lineWidth: 1)
        )
    }
}

@MainActor
class AIRulesViewModel: ObservableObject {
    @Published private(set) var rules: [AIRule] = []
    @Published private(set) var isLoading = false
    @Published var showError = false
    @Published var errorMessage = ""

    func loadRules() async {
        guard let userId = AuthenticationManager.shared.currentUser?.id else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            let fetchedRules = try await NetworkService.shared.fetchAIRules(userId: userId)
            rules = fetchedRules
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    func addRule(_ rule: AIRule) {
        rules.append(rule)
    }

    func updateRule(_ rule: AIRule) {
        if let index = rules.firstIndex(where: { $0.id == rule.id }) {
            rules[index] = rule
        }
    }

    func deleteRule(_ rule: AIRule) {
        rules.removeAll { $0.id == rule.id }
    }
}

// MARK: - Add AI Rule View
struct AddAIRuleView: View {
    @ObservedObject var theme = ThemeManager.shared
    @ObservedObject var viewModel: AIRulesViewModel
    @Environment(\.dismiss) var dismiss
    @State private var name = ""
    @State private var condition = ""
    @State private var action = ""
    @State private var priority = 5
    @State private var isActive = true
    @State private var isSaving = false
    @State private var showError = false
    @State private var errorMessage = ""
    @FocusState private var focusedField: Field?

    enum Field {
        case name, condition, action
    }

    var body: some View {
        NavigationStack {
            ZStack {
                theme.primaryBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        infoCard

                        VStack(alignment: .leading, spacing: 16) {
                            ThemedTextField(
                                title: "Rule Name",
                                placeholder: "e.g., Acne Treatment Protocol",
                                text: $name,
                                field: .name,
                                focusedField: $focusedField,
                                theme: theme,
                                autocapitalization: .words
                            )

                            VStack(alignment: .leading, spacing: 8) {
                                Text("When (Condition)")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(theme.secondaryText)

                                Text("Describe the skin condition or analysis result that triggers this rule")
                                    .font(.system(size: 12))
                                    .foregroundColor(theme.tertiaryText)
                                    

                                TextEditor(text: $condition)
                                    .font(.system(size: 15))
                                    .foregroundColor(theme.primaryText)
                                    .frame(minHeight: 100)
                                    .padding(12)
                                    .background(theme.inputBackground)
                                    .clipShape(RoundedRectangle(cornerRadius: theme.radiusMedium))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: theme.radiusMedium)
                                            .stroke(focusedField == .condition ? theme.inputBorderFocused : theme.inputBorder, lineWidth: focusedField == .condition ? 2 : 1)
                                    )
                                    .focused($focusedField, equals: .condition)
                                    .scrollContentBackground(.hidden)

                                if condition.isEmpty {
                                    Text("Example: Client has acne-prone skin with high oil production")
                                        .font(.system(size: 12))
                                        .foregroundColor(theme.tertiaryText)
                                        .italic()
                                }
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Then (Action/Recommendation)")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(theme.secondaryText)

                                Text("Specify what the AI should recommend")
                                    .font(.system(size: 12))
                                    .foregroundColor(theme.tertiaryText)

                                TextEditor(text: $action)
                                    .font(.system(size: 15))
                                    .foregroundColor(theme.primaryText)
                                    .frame(minHeight: 100)
                                    .padding(12)
                                    .background(theme.inputBackground)
                                    .clipShape(RoundedRectangle(cornerRadius: theme.radiusMedium))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: theme.radiusMedium)
                                            .stroke(focusedField == .action ? theme.inputBorderFocused : theme.inputBorder, lineWidth: focusedField == .action ? 2 : 1)
                                    )
                                    .focused($focusedField, equals: .action)
                                    .scrollContentBackground(.hidden)

                                if action.isEmpty {
                                    Text("Example: Recommend salicylic acid cleanser and niacinamide serum")
                                        .font(.system(size: 12))
                                        .foregroundColor(theme.tertiaryText)
                                        .italic()
                                }
                            }

                            VStack(alignment: .leading, spacing: 12) {
                                Text("Priority")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(theme.secondaryText)

                                Text("Higher priority rules override lower priority rules")
                                    .font(.system(size: 12))
                                    .foregroundColor(theme.tertiaryText)

                                HStack {
                                    Text("Low")
                                        .font(.system(size: 13))
                                        .foregroundColor(theme.secondaryText)

                                    Slider(value: Binding(
                                        get: { Double(priority) },
                                        set: { priority = Int($0) }
                                    ), in: 1...10, step: 1)
                                    .tint(theme.accent)

                                    Text("High")
                                        .font(.system(size: 13))
                                        .foregroundColor(theme.secondaryText)

                                    Text("\(priority)")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(theme.accent)
                                        .frame(width: 30)
                                }
                            }

                            Toggle(isOn: $isActive) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Active")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(theme.primaryText)

                                    Text("Rule will be applied to new analyses")
                                        .font(.system(size: 13))
                                        .foregroundColor(theme.secondaryText)
                                }
                            }
                            .tint(theme.accent)
                        }
                        .padding(20)
                        .background(
                            RoundedRectangle(cornerRadius: theme.radiusXL)
                                .fill(theme.cardBackground)
                        )
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 20)
                    .padding(.bottom, 100)
                }
                .scrollDismissesKeyboard(.interactively)

                if isSaving {
                    Color.black.opacity(0.5)
                        .ignoresSafeArea()

                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.white)

                        Text("Saving rule...")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(.white)
                    }
                }
            }
            .navigationTitle("Add AI Rule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItemGroup(placement: .confirmationAction) {
                    Button("Save") {
                        saveRule()
                    }
                    .disabled(!isFormValid)
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    private var infoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(theme.accent)
                Text("How AI Rules Work")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(theme.primaryText)
            }

            Text("Create rules to teach the AI your professional expertise. When the AI analyzes skin, it will follow your rules to make recommendations that match your spa's protocols and product preferences.")
                .font(.system(size: 14))
                .foregroundColor(theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: theme.radiusLarge)
                .fill(theme.accent.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: theme.radiusLarge)
                .stroke(theme.accent.opacity(0.3), lineWidth: 1)
        )
    }

    private var isFormValid: Bool {
        !name.isEmpty && !condition.isEmpty && !action.isEmpty
    }

    private func saveRule() {
        guard let userId = AuthenticationManager.shared.currentUser?.id else { return }

        focusedField = nil
        isSaving = true

        Task {
            do {
                let savedRule = try await NetworkService.shared.createAIRule(
                    userId: userId,
                    name: name,
                    condition: condition,
                    action: action,
                    priority: priority,
                    isActive: isActive
                )

                viewModel.addRule(savedRule)
                isSaving = false
                dismiss()
            } catch {
                isSaving = false
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}

// MARK: - Edit AI Rule View
struct EditAIRuleView: View {
    @ObservedObject var theme = ThemeManager.shared
    let rule: AIRule
    @ObservedObject var viewModel: AIRulesViewModel
    @Environment(\.dismiss) var dismiss
    @State private var name = ""
    @State private var condition = ""
    @State private var action = ""
    @State private var priority = 5
    @State private var isActive = true
    @State private var isSaving = false
    @State private var showDeleteConfirmation = false
    @State private var isDeleting = false
    @State private var showError = false
    @State private var errorMessage = ""
    @FocusState private var focusedField: Field?

    enum Field {
        case name, condition, action
    }

    var body: some View {
        NavigationStack {
            ZStack {
                theme.primaryBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        VStack(alignment: .leading, spacing: 16) {
                            ThemedTextField(
                                title: "Rule Name",
                                placeholder: "Rule name",
                                text: $name,
                                field: .name,
                                focusedField: $focusedField,
                                theme: theme,
                                autocapitalization: .words
                            )

                            VStack(alignment: .leading, spacing: 8) {
                                Text("When (Condition)")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(theme.secondaryText)

                                TextEditor(text: $condition)
                                    .font(.system(size: 15))
                                    .foregroundColor(theme.primaryText)
                                    .frame(minHeight: 100)
                                    .padding(12)
                                    .background(theme.inputBackground)
                                    .clipShape(RoundedRectangle(cornerRadius: theme.radiusMedium))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: theme.radiusMedium)
                                            .stroke(
                                                focusedField == .condition
                                                    ? theme.inputBorderFocused
                                                    : theme.inputBorder,
                                                lineWidth: focusedField == .condition ? 2 : 1
                                            )
                                    )

                                    .focused($focusedField, equals: .condition)
                                    .scrollContentBackground(.hidden)
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Then (Action/Recommendation)")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(theme.secondaryText)

                                TextEditor(text: $action)
                                    .font(.system(size: 15))
                                    .foregroundColor(theme.primaryText)
                                    .frame(minHeight: 100)
                                    .padding(12)
                                    .background(theme.inputBackground)
                                    .clipShape(RoundedRectangle(cornerRadius: theme.radiusMedium))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: theme.radiusMedium)
                                            .stroke(focusedField == .action ? theme.inputBorderFocused : theme.inputBorder, lineWidth: focusedField == .action ? 2 : 1)
                                    )
                                    .focused($focusedField, equals: .action)
                                    .scrollContentBackground(.hidden)
                            }

                            VStack(alignment: .leading, spacing: 12) {
                                Text("Priority")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(theme.secondaryText)

                                HStack {
                                    Text("Low")
                                        .font(.system(size: 13))
                                        .foregroundColor(theme.secondaryText)

                                    Slider(value: Binding(
                                        get: { Double(priority) },
                                        set: { priority = Int($0) }
                                    ), in: 1...10, step: 1)
                                    .tint(theme.accent)

                                    Text("High")
                                        .font(.system(size: 13))
                                        .foregroundColor(theme.secondaryText)

                                    Text("\(priority)")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(theme.accent)
                                        .frame(width: 30)
                                }
                            }

                            Toggle(isOn: $isActive) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Active")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(theme.primaryText)

                                    Text("Rule will be applied to new analyses")
                                        .font(.system(size: 13))
                                        .foregroundColor(theme.secondaryText)
                                }
                            }
                            .tint(theme.accent)
                        }
                        .padding(20)
                        .background(
                            RoundedRectangle(cornerRadius: theme.radiusXL)
                                .fill(theme.cardBackground)
                        )

                        Button(action: { showDeleteConfirmation = true }) {
                            HStack {
                                Spacer()
                                Image(systemName: "trash")
                                Text("Delete Rule")
                                Spacer()
                            }
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(height: 52)
                            .background(theme.error)
                            .clipShape(RoundedRectangle(cornerRadius: theme.radiusMedium))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 20)
                    .padding(.bottom, 100)
                }
                .scrollDismissesKeyboard(.interactively)

                if isSaving || isDeleting {
                    Color.black.opacity(0.5)
                        .ignoresSafeArea()

                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.white)

                        Text(isSaving ? "Saving rule..." : "Deleting rule...")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(.white)
                    }
                }
            }
            .navigationTitle("Edit Rule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItemGroup(placement: .confirmationAction) {
                    Button("Save") {
                        saveRule()
                    }
                    .disabled(!isFormValid)
                }
            }
            .alert("Delete Rule", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    deleteRule()
                }
            } message: {
                Text("Are you sure you want to delete this rule? This action cannot be undone.")
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .onAppear {
                name = rule.name ?? ""
                condition = rule.condition ?? ""
                action = rule.action ?? ""
                priority = rule.priority ?? 5
                isActive = rule.isActive ?? true
            }
        }
    }

    private var isFormValid: Bool {
        !name.isEmpty && !condition.isEmpty
    }

    private func saveRule() {
        guard let userId = AuthenticationManager.shared.currentUser?.id,
              let ruleId = rule.id else { return }

        focusedField = nil
        isSaving = true

        Task {
            do {
                let updatedRule = try await NetworkService.shared.updateAIRule(
                    ruleId: ruleId,
                    userId: userId,
                    name: name,
                    condition: condition,
                    action: action,
                    priority: priority,
                    isActive: isActive
                )

                viewModel.updateRule(updatedRule)
                isSaving = false
                dismiss()
            } catch {
                isSaving = false
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }

    private func deleteRule() {
        guard let ruleId = rule.id else { return }

        isDeleting = true

        Task {
            do {
                try await NetworkService.shared.deleteAIRule(ruleId: ruleId)
                viewModel.deleteRule(rule)
                isDeleting = false
                dismiss()
            } catch {
                isDeleting = false
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}

#Preview("Add AI Rule") {
    NavigationStack {
        AddAIRuleView(viewModel: AIRulesViewModel())
    }
}


#Preview("Add AI Rule") {
    NavigationStack {
        AddAIRuleView(viewModel: AIRulesViewModel())
    }
}
