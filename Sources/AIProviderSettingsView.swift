import SwiftUI

struct AIProviderSettingsView: View {
    @ObservedObject var theme = ThemeManager.shared
    @Environment(\.dismiss) var dismiss
    @AppStorage("ai_provider") private var selectedProvider: String = "appleVision"

    var body: some View {
        ZStack {
            theme.primaryBackground
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    infoCard

                    VStack(alignment: .leading, spacing: 16) {
                        Text("Select AI Provider")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(theme.primaryText)

                        providerOption(
                            icon: "apple.logo",
                            title: "Apple Vision",
                            subtitle: "Free • On-device • Basic analysis",
                            provider: "appleVision",
                            badge: "FREE"
                        )

                        Divider()

                        providerOption(
                            icon: "sparkles",
                            title: "Claude Vision",
                            subtitle: "Premium • Cloud-based • Advanced AI",
                            provider: "claude",
                            badge: "PREMIUM"
                        )
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: theme.radiusXL)
                            .fill(theme.cardBackground)
                            .shadow(color: theme.shadowColor, radius: theme.shadowRadiusSmall, x: 0, y: 4)
                    )

                    if selectedProvider == "claude" {
                        claudeInfoCard
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)
                .padding(.bottom, 100)
            }
        }
        .navigationTitle("AI Vision Provider")
        .navigationBarTitleDisplayMode(.inline)
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
        }
    }

    private var infoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(theme.accent)
                Text("About AI Providers")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(theme.primaryText)
            }

            Text("Choose which AI technology powers your skin analysis. Apple Vision is free and runs on your device, while Claude provides more sophisticated analysis using cloud AI.")
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

    private func providerOption(
        icon: String,
        title: String,
        subtitle: String,
        provider: String,
        badge: String
    ) -> some View {
        Button(action: {
            selectedProvider = provider
            updateAppConstantsProvider(provider)
        }) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(selectedProvider == provider ? theme.accent.opacity(0.15) : theme.tertiaryBackground)
                        .frame(width: 50, height: 50)

                    Image(systemName: icon)
                        .font(.system(size: 22))
                        .foregroundColor(selectedProvider == provider ? theme.accent : theme.secondaryText)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(title)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(theme.primaryText)

                        Text(badge)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(provider == "appleVision" ? .green : theme.accent)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(provider == "appleVision" ? Color.green.opacity(0.2) : theme.accent.opacity(0.2))
                            )
                    }

                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundColor(theme.secondaryText)
                }

                Spacer()

                Image(systemName: selectedProvider == provider ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24))
                    .foregroundColor(selectedProvider == provider ? theme.accent : theme.tertiaryText)
            }
        }
        .buttonStyle(.plain)
    }

    private var claudeInfoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "dollarsign.circle.fill")
                    .foregroundColor(.orange)
                Text("Claude Pricing")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(theme.primaryText)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("•")
                    Text("Cost per analysis: ~$0.003")
                }
                HStack {
                    Text("•")
                    Text("100 analyses: ~$0.30")
                }
                HStack {
                    Text("•")
                    Text("1,000 analyses: ~$3.00")
                }
            }
            .font(.system(size: 14))
            .foregroundColor(theme.secondaryText)

            Text("Claude provides superior skin analysis with better understanding of medical context and more accurate recommendations.")
                .font(.system(size: 13))
                .foregroundColor(theme.tertiaryText)
                .italic()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: theme.radiusLarge)
                .fill(Color.orange.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: theme.radiusLarge)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
    }

    private func updateAppConstantsProvider(_ provider: String) {
        // Note: This changes UserDefaults, but AppConstants.aiProvider is a static variable
        // You'll need to restart the app or use UserDefaults in AppConstants
        // For now, this stores the preference and shows the selection
    }
}

#Preview {
    NavigationStack {
        AIProviderSettingsView()
    }
}
