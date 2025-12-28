import SwiftUI

struct AIRulesView: View {
    @ObservedObject var theme = ThemeManager.shared
    @StateObject private var viewModel = AIRulesViewModel()
    @State private var showAddRule = false
    @State private var searchText = ""

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
                            AIRuleRowView(rule: rule)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 100)
                }
            }
        }
        .navigationTitle("AI Recommendation Rules")
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button(action: { showAddRule = true }) {
                    Label("Add Rule", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showAddRule) {
            Text("Add AI Rule - Coming Soon")
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

            if let priority = rule.priority {
                HStack {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 12))
                    Text("Priority: \(priority)")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundColor(theme.accent)
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
}
