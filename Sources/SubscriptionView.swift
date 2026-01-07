import SwiftUI
import StoreKit

struct SubscriptionView: View {
    @ObservedObject var theme = ThemeManager.shared
    @StateObject private var storeManager = StoreKitManager.shared
    @Environment(\.dismiss) var dismiss

    @State private var selectedProduct: StoreKit.Product?
    @State private var isPurchasing = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showSuccess = false

    var body: some View {
        NavigationStack {
            ZStack {
                theme.primaryBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 32) {
                        headerSection

                        if storeManager.isLoading {
                            ProgressView()
                                .scaleEffect(1.5)
                                .tint(theme.accent)
                                .padding(.vertical, 60)
                        } else if storeManager.products.isEmpty {
                            errorStateView
                        } else {
                            plansSection
                        }

                        featuresSection

                        footerSection
                    }
                    .padding(24)
                }

                if isPurchasing {
                    Color.black.opacity(0.5)
                        .ignoresSafeArea()

                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.white)

                        Text("Processing purchase...")
                            .font(.system(size: 16))
                            .foregroundColor(.white)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Choose Your Plan")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(theme.primaryText)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .foregroundColor(theme.secondaryText)
                    }
                }
            }
            .alert("Purchase Successful", isPresented: $showSuccess) {
                Button("Done") { dismiss() }
            } message: {
                Text("Your subscription is now active. Welcome to SkinInsightPro!")
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "star.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(theme.accent)

            Text("Unlock Full Access")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(theme.primaryText)

            Text("Choose the plan that fits your practice")
                .font(.system(size: 16))
                .foregroundColor(theme.secondaryText)
                .multilineTextAlignment(.center)
        }
    }

    private var plansSection: some View {
        VStack(spacing: 16) {
            ForEach(storeManager.products, id: \.id) { product in
                PlanCard(
                    product: product,
                    isSelected: selectedProduct?.id == product.id,
                    isActive: storeManager.isSubscribed(to: product.id),
                    onSelect: { selectedProduct = product },
                    onPurchase: { purchasePlan(product) }
                )
            }
        }
    }

    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("All plans include:")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(theme.primaryText)

            FeatureRow(icon: "cpu", text: "Apple Vision AI skin analysis")
            FeatureRow(icon: "brain", text: "Claude AI intelligent recommendations")
            FeatureRow(icon: "person.2.fill", text: "Unlimited team members")
            FeatureRow(icon: "chart.bar.fill", text: "Client progress tracking")
            FeatureRow(icon: "lock.shield.fill", text: "HIPAA compliant storage")
            FeatureRow(icon: "arrow.triangle.2.circlepath", text: "Automatic data sync")
        }
        .padding(20)
        .background(theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: theme.radiusLarge))
    }

    private var footerSection: some View {
        VStack(spacing: 12) {
            Button(action: { Task { await storeManager.restorePurchases() } }) {
                Text("Restore Purchases")
                    .font(.system(size: 15))
                    .foregroundColor(theme.accent)
            }

            Text("Subscriptions automatically renew unless cancelled 24 hours before the end of the current period.")
                .font(.system(size: 12))
                .foregroundColor(theme.tertiaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
        }
    }

    private var errorStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.orange)

            Text("Unable to load plans")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(theme.primaryText)

            Text(storeManager.errorMessage ?? "Please try again later")
                .font(.system(size: 14))
                .foregroundColor(theme.secondaryText)
                .multilineTextAlignment(.center)

            Button(action: { Task { await storeManager.loadProducts() } }) {
                Text("Retry")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 40)
                    .padding(.vertical, 12)
                    .background(theme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: theme.radiusMedium))
            }
        }
        .padding(.vertical, 60)
    }

    private func purchasePlan(_ product: StoreKit.Product) {
        guard let user = AuthenticationManager.shared.currentUser else {
            errorMessage = "You must be logged in to purchase"
            showError = true
            return
        }

        guard user.isCompanyAdmin == true else {
            errorMessage = "Only company admins can purchase subscriptions"
            showError = true
            return
        }

        isPurchasing = true

        Task {
            do {
                let transaction = try await storeManager.purchase(product)

                if transaction != nil {
                    showSuccess = true
                }

            } catch StoreError.notAuthorized {
                errorMessage = "Only company admins can purchase subscriptions"
                showError = true

            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }

            isPurchasing = false
        }
    }
}

// MARK: - Plan Card

struct PlanCard: View {
    @ObservedObject var theme = ThemeManager.shared
    let product: StoreKit.Product
    let isSelected: Bool
    let isActive: Bool
    let onSelect: () -> Void
    let onPurchase: () -> Void

    private var planInfo: (name: String, analyses: String, description: String) {
        switch product.id {
        case "com.skininsightpro.solo.monthly":
            return ("Solo", "100", "Individual practitioners")
        case "com.skininsightpro.solo.annual":
            return ("Solo", "100", "Individual practitioners")
        case "com.skininsightpro.starter.monthly":
            return ("Starter", "400", "Small practices (1-2 providers)")
        case "com.skininsightpro.starter.annual":
            return ("Starter", "400", "Small practices (1-2 providers)")
        case "com.skininsightpro.professional.monthly":
            return ("Professional", "1,500", "Growing practices (2-4 providers)")
        case "com.skininsightpro.business.monthly":
            return ("Business", "5,000", "Multi-location (4-6 locations)")
        case "com.skininsightpro.enterprise.monthly":
            return ("Enterprise", "15,000", "Large operations (7+ locations)")
        default:
            return ("Unknown", "0", "")
        }
    }

    private var isAnnual: Bool {
        product.id.contains("annual")
    }

    private var monthlySavings: String? {
        guard isAnnual else { return nil }

        // Calculate approximate monthly cost
        let monthlyPrice = product.price / 12
        let savingsPercent = 17 // 2 months free = ~17% savings

        return "Save \(savingsPercent)% • ~\(monthlyPrice.formatted(.currency(code: product.priceFormatStyle.currencyCode)))/mo"
    }

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(planInfo.name)
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(theme.primaryText)

                            if isActive {
                                Text("ACTIVE")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(theme.accent)
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                            }
                        }

                        Text(planInfo.description)
                            .font(.system(size: 14))
                            .foregroundColor(theme.secondaryText)
                    }

                    Spacer()

                    if isSelected && !isActive {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(theme.accent)
                    }
                }

                Divider()

                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(product.displayPrice)
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(theme.primaryText)

                        if let savings = monthlySavings {
                            Text(savings)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(theme.accent)
                        } else {
                            Text("per month")
                                .font(.system(size: 14))
                                .foregroundColor(theme.secondaryText)
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text(planInfo.analyses)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(theme.accent)

                        Text("analyses/month")
                            .font(.system(size: 12))
                            .foregroundColor(theme.secondaryText)
                    }
                }

                if !isActive {
                    Button(action: onPurchase) {
                        Text("Select Plan")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(theme.accent)
                            .clipShape(RoundedRectangle(cornerRadius: theme.radiusMedium))
                    }
                }
            }
            .padding(20)
            .background(theme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: theme.radiusLarge))
            .overlay(
                RoundedRectangle(cornerRadius: theme.radiusLarge)
                    .stroke(isSelected ? theme.accent : theme.cardBorder, lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Feature Row

struct FeatureRow: View {
    @ObservedObject var theme = ThemeManager.shared
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(theme.accent)
                .frame(width: 24)

            Text(text)
                .font(.system(size: 15))
                .foregroundColor(theme.primaryText)

            Spacer()
        }
    }
}
