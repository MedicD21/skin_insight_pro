import SwiftUI

struct AIProviderSettingsView: View {
    @ObservedObject var theme = ThemeManager.shared
    @ObservedObject var authManager = AuthenticationManager.shared
    @StateObject private var storeManager = StoreKitManager.shared
    @Environment(\.dismiss) var dismiss
    @AppStorage("ai_provider") private var selectedProvider: String = "appleVision"
    @State private var showSubscriptionRequired = false

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
                            subtitle: storeManager.hasActiveSubscription()
                                ? "Premium • Cloud-based • Advanced AI"
                                : "Requires active subscription",
                            provider: "claude",
                            badge: "PREMIUM",
                            isDisabled: !storeManager.hasActiveSubscription()
                        )
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: theme.radiusXL)
                            .fill(theme.cardBackground)
                            .shadow(color: theme.shadowColor, radius: theme.shadowRadiusSmall, x: 0, y: 4)
                    )
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)
                .padding(.bottom, 100)
            }
        }
        .navigationTitle("AI Vision Provider")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .alert("Subscription Required", isPresented: $showSubscriptionRequired) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("An active subscription is required to use Claude Vision. Please contact your company admin to purchase a subscription.")
        }
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
        badge: String,
        isDisabled: Bool = false
    ) -> some View {
        Button(action: {
            if isDisabled {
                showSubscriptionRequired = true
            } else {
                selectedProvider = provider
                updateAppConstantsProvider(provider)
            }
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
        .opacity(isDisabled ? 0.5 : 1.0)
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
