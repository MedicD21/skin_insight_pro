import SwiftUI

struct ProductCatalogView: View {
    @ObservedObject var theme = ThemeManager.shared
    @StateObject private var viewModel = ProductCatalogViewModel()
    @State private var showAddProduct = false
    @State private var showImportProducts = false
    @State private var searchText = ""
    @State private var productToEdit: Product?
    @State private var showFilters = false
    @State private var selectedBrands: Set<String> = []
    @State private var selectedCategories: Set<String> = []
    @State private var selectedSkinTypes: Set<String> = []
    @State private var selectedConcerns: Set<String> = []
    @Environment(\.dismiss) var dismiss

    var body: some View {
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
                    VStack(spacing: 12) {
                        searchBar
                        filterBar

                        if filteredProducts.isEmpty {
                            filteredEmptyState
                        } else {
                            LazyVStack(spacing: 12) {
                                ForEach(filteredProducts) { product in
                                    ProductRowView(product: product)
                                        .onTapGesture {
                                            productToEdit = product
                                        }
                                }
                            }
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
        .sheet(isPresented: $showAddProduct) {
            AddProductView(viewModel: viewModel)
        }
        .sheet(item: $productToEdit) { product in
            AddProductView(viewModel: viewModel, editingProduct: product)
        }
        .sheet(isPresented: $showImportProducts) {
            ProductImportView(viewModel: viewModel)
        }
        .sheet(isPresented: $showFilters) {
            ProductFilterSheet(
                brandOptions: brandOptions,
                categoryOptions: categoryOptions,
                skinTypeOptions: skinTypeOptions,
                concernOptions: concernOptions,
                selectedBrands: $selectedBrands,
                selectedCategories: $selectedCategories,
                selectedSkinTypes: $selectedSkinTypes,
                selectedConcerns: $selectedConcerns,
                onClear: clearFilters
            )
        }
        .task {
            await viewModel.loadProducts()
        }
    }

    private var filteredProducts: [Product] {
        let filteredBySearch = viewModel.products.filter { product in
            guard !searchText.isEmpty else { return true }
            return matchesSearch(product)
        }

        return filteredBySearch.filter { product in
            matchesFilters(product)
        }
    }

    private func matchesFilters(_ product: Product) -> Bool {
        if !selectedBrands.isEmpty {
            let brand = product.brand?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if brand.isEmpty || !selectedBrands.contains(where: { $0.caseInsensitiveCompare(brand) == .orderedSame }) {
                return false
            }
        }

        if !selectedCategories.isEmpty {
            let category = product.category?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if category.isEmpty || !selectedCategories.contains(where: { $0.caseInsensitiveCompare(category) == .orderedSame }) {
                return false
            }
        }

        if !selectedSkinTypes.isEmpty {
            guard let skinTypes = product.skinTypes, !skinTypes.isEmpty else { return false }
            let match = skinTypes.contains { type in
                selectedSkinTypes.contains { $0.caseInsensitiveCompare(type) == .orderedSame }
            }
            if !match { return false }
        }

        if !selectedConcerns.isEmpty {
            guard let concerns = product.concerns, !concerns.isEmpty else { return false }
            let match = concerns.contains { concern in
                selectedConcerns.contains { $0.caseInsensitiveCompare(concern) == .orderedSame }
            }
            if !match { return false }
        }

        return true
    }

    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(theme.tertiaryText)

            TextField("Search products", text: $searchText)
                .font(.system(size: 16))
                .foregroundColor(theme.primaryText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(theme.inputBackground)
        .clipShape(RoundedRectangle(cornerRadius: theme.radiusMedium))
        .overlay(
            RoundedRectangle(cornerRadius: theme.radiusMedium)
                .stroke(theme.inputBorder, lineWidth: 1)
        )
    }

    private func matchesSearch(_ product: Product) -> Bool {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return true }

        let searchable = [
            product.name,
            product.brand,
            product.category,
            product.ingredients,
            product.allIngredients
        ]
        .compactMap { $0?.lowercased() }
        .joined(separator: " ")

        let tokens = query
            .lowercased()
            .components(separatedBy: CharacterSet(charactersIn: ", "))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if tokens.isEmpty {
            return searchable.contains(query.lowercased())
        }

        return tokens.allSatisfy { searchable.contains($0) }
    }

    private var filterBar: some View {
        HStack(spacing: 12) {
            Button(action: { showFilters = true }) {
                HStack(spacing: 6) {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                    Text("Filter")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(theme.primaryText)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(theme.cardBackground)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(theme.cardBorder, lineWidth: 1)
                )
            }

            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    HStack(spacing: 4) {
                        Image(systemName: "xmark.circle.fill")
                        Text("Clear Search")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(theme.secondaryText)
                }
            }

            if activeFiltersCount > 0 {
                Text("\(activeFiltersCount) active")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(theme.secondaryText)

                Button("Clear") {
                    clearFilters()
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(theme.accent)
            }

            Spacer()
        }
    }

    private var filteredEmptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 32))
                .foregroundColor(theme.tertiaryText)

            Text("No matching products")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(theme.primaryText)

            Text("Try adjusting your search or filters.")
                .font(.system(size: 13))
                .foregroundColor(theme.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    private var activeFiltersCount: Int {
        selectedBrands.count + selectedCategories.count + selectedSkinTypes.count + selectedConcerns.count
    }

    private func clearFilters() {
        selectedBrands.removeAll()
        selectedCategories.removeAll()
        selectedSkinTypes.removeAll()
        selectedConcerns.removeAll()
    }

    private var brandOptions: [String] {
        let brands = viewModel.products.compactMap { $0.brand?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return Array(Set(brands)).sorted()
    }

    private var categoryOptions: [String] {
        let categories = viewModel.products.compactMap { $0.category?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return Array(Set(categories)).sorted()
    }

    private var skinTypeOptions: [String] {
        let values = viewModel.products.flatMap { $0.skinTypes ?? [] }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return Array(Set(values)).sorted()
    }

    private var concernOptions: [String] {
        let values = viewModel.products.flatMap { $0.concerns ?? [] }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return Array(Set(values)).sorted()
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
        guard let user = AuthenticationManager.shared.currentUser,
              let userId = user.id else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            let fetchedProducts = try await NetworkService.shared.fetchProductsForUser(
                userId: userId,
                companyId: user.companyId
            )
            let normalizedProducts = fetchedProducts.map { product in
                var normalizedProduct = product
                normalizedProduct.concerns = AppConstants.normalizeConcerns(product.concerns)
                return normalizedProduct
            }
            products = normalizedProducts.sorted { ($0.name ?? "") < ($1.name ?? "") }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    func addProduct(_ product: Product) async {
        guard let userId = AuthenticationManager.shared.currentUser?.id else { return }

        do {
            let savedProduct = try await NetworkService.shared.createOrUpdateProduct(product: product, userId: userId)
            var normalizedProduct = savedProduct
            normalizedProduct.concerns = AppConstants.normalizeConcerns(savedProduct.concerns)
            products.append(normalizedProduct)
            products.sort { ($0.name ?? "") < ($1.name ?? "") }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    func updateProduct(_ product: Product) async {
        guard let userId = AuthenticationManager.shared.currentUser?.id,
              let productId = product.id else { return }

        do {
            let updatedProduct = try await NetworkService.shared.createOrUpdateProduct(product: product, userId: userId)
            var normalizedProduct = updatedProduct
            normalizedProduct.concerns = AppConstants.normalizeConcerns(updatedProduct.concerns)

            // Replace the product in the list
            if let index = products.firstIndex(where: { $0.id == productId }) {
                products[index] = normalizedProduct
                products.sort { ($0.name ?? "") < ($1.name ?? "") }
            }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    func deleteProduct(productId: String) async {
        do {
            try await NetworkService.shared.deleteProduct(productId: productId)
            products.removeAll { $0.id == productId }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

private struct ProductFilterSheet: View {
    @ObservedObject var theme = ThemeManager.shared
    let brandOptions: [String]
    let categoryOptions: [String]
    let skinTypeOptions: [String]
    let concernOptions: [String]
    @Binding var selectedBrands: Set<String>
    @Binding var selectedCategories: Set<String>
    @Binding var selectedSkinTypes: Set<String>
    @Binding var selectedConcerns: Set<String>
    let onClear: () -> Void
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    filterSection(title: "Brand", options: brandOptions, selection: $selectedBrands)
                    filterSection(title: "Category", options: categoryOptions, selection: $selectedCategories)
                    filterSection(title: "Skin Type", options: skinTypeOptions, selection: $selectedSkinTypes)
                    filterSection(title: "Concerns", options: concernOptions, selection: $selectedConcerns)
                }
                .padding(20)
            }
            .background(theme.primaryBackground.ignoresSafeArea())
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Clear") {
                        onClear()
                    }
                    .foregroundColor(theme.accent)
                }
            }
        }
    }

    private func filterSection(title: String, options: [String], selection: Binding<Set<String>>) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(theme.primaryText)

            if options.isEmpty {
                Text("No options available")
                    .font(.system(size: 13))
                    .foregroundColor(theme.secondaryText)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 8)], spacing: 8) {
                    ForEach(options, id: \.self) { option in
                        FilterOptionChip(
                            title: option,
                            isSelected: selection.wrappedValue.contains(option)
                        ) {
                            if selection.wrappedValue.contains(option) {
                                selection.wrappedValue.remove(option)
                            } else {
                                selection.wrappedValue.insert(option)
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct FilterOptionChip: View {
    @ObservedObject var theme = ThemeManager.shared
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(isSelected ? .white : theme.primaryText)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background(isSelected ? theme.accent : theme.tertiaryBackground)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(isSelected ? Color.clear : theme.border, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}
