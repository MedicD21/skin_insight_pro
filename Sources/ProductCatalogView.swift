import SwiftUI

struct ProductCatalogView: View {
    @ObservedObject var theme = ThemeManager.shared
    @StateObject private var viewModel = ProductCatalogViewModel()
    @State private var showAddProduct = false
    @State private var showImportProducts = false
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
                    Menu {
                        Button(action: { showAddProduct = true }) {
                            Label("Add Single Product", systemImage: "plus")
                        }
                        Button(action: { showImportProducts = true }) {
                            Label("Import Products (CSV)", systemImage: "square.and.arrow.down")
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 20))
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search products")
            .sheet(isPresented: $showAddProduct) {
                AddProductView(viewModel: viewModel)
            }
            .sheet(isPresented: $showImportProducts) {
                ProductImportView(viewModel: viewModel)
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
        HStack(spacing: 12) {
            // Product Image
            Group {
                if let imageUrl = product.imageUrl, !imageUrl.isEmpty {
                    AsyncImage(url: URL(string: imageUrl)) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                                .frame(width: 80, height: 80)
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                        case .failure:
                            Image(systemName: "photo")
                                .font(.system(size: 24))
                                .foregroundColor(theme.tertiaryText)
                                .frame(width: 80, height: 80)
                        @unknown default:
                            EmptyView()
                        }
                    }
                    .frame(width: 80, height: 80)
                    .background(theme.tertiaryBackground)
                    .clipShape(RoundedRectangle(cornerRadius: theme.radiusSmall))
                } else {
                    Image(systemName: "photo")
                        .font(.system(size: 24))
                        .foregroundColor(theme.tertiaryText)
                        .frame(width: 80, height: 80)
                        .background(theme.tertiaryBackground)
                        .clipShape(RoundedRectangle(cornerRadius: theme.radiusSmall))
                }
            }

            // Product Details
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(product.name ?? "Unknown")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(theme.primaryText)

                    Spacer()

                    if let price = product.price {
                        Text("$\(String(format: "%.2f", price))")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(theme.accent)
                    }
                }

                if let brand = product.brand, !brand.isEmpty {
                    Text(brand)
                        .font(.system(size: 14))
                        .foregroundColor(theme.secondaryText)
                }

                HStack {
                    if let category = product.category, !category.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "tag")
                                .font(.system(size: 11))
                            Text(category)
                                .font(.system(size: 13))
                        }
                        .foregroundColor(theme.accent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(theme.accent.opacity(0.1))
                        .clipShape(Capsule())
                    }

                    if let isActive = product.isActive {
                        Text(isActive ? "Active" : "Inactive")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(isActive ? .green : .red)
                    }

                    Spacer()
                }

                if let description = product.description, !description.isEmpty {
                    Text(description)
                        .font(.system(size: 13))
                        .foregroundColor(theme.secondaryText)
                        .lineLimit(2)
                }
            }
        }
        .padding(12)
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
