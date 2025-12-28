import SwiftUI

struct ProductCatalogView: View {
    @ObservedObject var theme = ThemeManager.shared
    @StateObject private var viewModel = ProductCatalogViewModel()
    @State private var showAddProduct = false
    @State private var searchText = ""
    @Environment(\.horizontalSizeClass) var horizontalSizeClass

    var body: some View {
        NavigationStack {
            ZStack {
                theme.primaryBackground
                    .ignoresSafeArea()

                if viewModel.isLoading && viewModel.products.isEmpty {
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(theme.accent)
                } else if viewModel.products.isEmpty {
                    emptyStateView
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(filteredProducts) { product in
                                ProductRowView(product: product)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, 100)
                    }
                    .refreshable {
                        await viewModel.loadProducts()
                    }
                }
            }
            .navigationTitle("Product Catalog")
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button(action: { showAddProduct = true }) {
                        Label("Add Product", systemImage: "plus")
                    }
                    .keyboardShortcut("n", modifiers: .command)
                }
            }
            .searchable(text: $searchText, prompt: "Search products")
            .sheet(isPresented: $showAddProduct) {
                AddProductView(viewModel: viewModel)
            }
            .task {
                await viewModel.loadProducts()
            }
        }
    }

    private var filteredProducts: [Product] {
        if searchText.isEmpty {
            return viewModel.products
        }
        return viewModel.products.filter { product in
            (product.name?.localizedCaseInsensitiveContains(searchText) ?? false) ||
            (product.brand?.localizedCaseInsensitiveContains(searchText) ?? false) ||
            (product.category?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "shippingbox")
                .font(.system(size: 60))
                .foregroundColor(theme.tertiaryText)

            Text("No Products Yet")
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(theme.primaryText)

            Text("Add products to your catalog to use them in AI recommendations")
                .font(.system(size: 16))
                .foregroundColor(theme.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button(action: { showAddProduct = true }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Product")
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
}

struct ProductRowView: View {
    @ObservedObject var theme = ThemeManager.shared
    let product: Product

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(product.name ?? "Unknown")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(theme.primaryText)

                    if let brand = product.brand, !brand.isEmpty {
                        Text(brand)
                            .font(.system(size: 14))
                            .foregroundColor(theme.secondaryText)
                    }
                }

                Spacer()

                if let isActive = product.isActive {
                    Text(isActive ? "Active" : "Inactive")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(isActive ? theme.accent : theme.tertiaryText)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(isActive ? theme.accentSubtle.opacity(0.2) : theme.tertiaryBackground)
                        .clipShape(Capsule())
                }
            }

            if let category = product.category, !category.isEmpty {
                HStack {
                    Image(systemName: "tag")
                        .font(.system(size: 12))
                    Text(category)
                        .font(.system(size: 14))
                }
                .foregroundColor(theme.secondaryText)
            }

            if let description = product.description, !description.isEmpty {
                Text(description)
                    .font(.system(size: 14))
                    .foregroundColor(theme.secondaryText)
                    .lineLimit(2)
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
class ProductCatalogViewModel: ObservableObject {
    @Published private(set) var products: [Product] = []
    @Published private(set) var isLoading = false
    @Published var showError = false
    @Published var errorMessage = ""

    func loadProducts() async {
        guard let userId = AuthenticationManager.shared.currentUser?.id else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            let fetchedProducts = try await NetworkService.shared.fetchProducts(userId: userId)
            products = fetchedProducts.sorted { ($0.name ?? "") < ($1.name ?? "") }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    func addProduct(_ product: Product) async {
        guard let userId = AuthenticationManager.shared.currentUser?.id else { return }

        do {
            let savedProduct = try await NetworkService.shared.createOrUpdateProduct(product: product, userId: userId)
            products.append(savedProduct)
            products.sort { ($0.name ?? "") < ($1.name ?? "") }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}
