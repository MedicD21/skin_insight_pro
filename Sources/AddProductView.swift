import SwiftUI
import PhotosUI

struct AddProductView: View {
    @ObservedObject var theme = ThemeManager.shared
    @ObservedObject var viewModel: ProductCatalogViewModel
    @Environment(\.dismiss) var dismiss

    let editingProduct: Product? // Optional product to edit

    @State private var name = ""
    @State private var brand = ""
    @State private var selectedCategory = "Select Category"
    @State private var customCategory = ""
    @State private var description = ""
    @State private var ingredients = ""
    @State private var allIngredients = ""
    @State private var usageGuidelines = ""
    @State private var priceText = ""
    @State private var selectedSkinTypes: Set<String> = []
    @State private var selectedConcerns: Set<String> = []
    @State private var selectedImage: PhotosPickerItem?
    @State private var productImage: UIImage?
    @State private var imageUrl: String?
    @State private var sourceUrl = ""
    @State private var isScraping = false
    @State private var showScrapeReview = false
    @State private var scrapedResult: ProductScrapeResult?
    @State private var isActive = true
    @State private var isLoading = false
    @State private var showDeleteConfirm = false
    @State private var showError = false
    @State private var errorMessage = ""
    @FocusState private var focusedField: Field?

    enum Field {
        case name, brand, category, description, ingredients, allIngredients, usageGuidelines, price, sourceUrl
    }

    let skinTypes = ["Normal", "Dry", "Oily", "Combination", "Sensitive"]
    let concerns = AppConstants.concernOptions
    let categoryOptions = [
        "Select Category",
        "Cleanser",
        "Toner",
        "Essence",
        "Serum",
        "Moisturizer",
        "Eye Cream",
        "SPF / Sunscreen",
        "Exfoliant",
        "Mask",
        "Treatment",
        "Retinol",
        "Oil",
        "Mist",
        "Spot Treatment",
        "Balm",
        "Makeup Remover",
        "Peel",
        "Scrub",
        "Body Wash",
        "Body Lotion",
        "Hand Cream",
        "Lip Balm",
        "Custom"
    ]

    init(viewModel: ProductCatalogViewModel, editingProduct: Product? = nil) {
        self.viewModel = viewModel
        self.editingProduct = editingProduct
    }

    var body: some View {
        NavigationStack {
            ZStack {
                theme.primaryBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        urlImportSection
                        imageSection
                        basicInfoSection
                        pricingSection
                        detailsSection
                        skinTypesSection
                        concernsSection
                        statusSection
                        if editingProduct != nil {
                            deleteSection
                        }
                    }
                    .padding(20)
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: selectedImage) { oldValue, newValue in
                    Task {
                        if let data = try? await newValue?.loadTransferable(type: Data.self),
                           let uiImage = UIImage(data: data) {
                            productImage = uiImage
                        }
                    }
                }

                if isLoading {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()

                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(theme.accent)
                }

                if isScraping {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()

                    ProgressView("Scanning product page...")
                        .padding(16)
                        .background(theme.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: theme.radiusMedium))
                        .tint(theme.accent)
                }
            }
            .navigationTitle(editingProduct == nil ? "Add Product" : "Edit Product")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showScrapeReview) {
                if let scrapedResult {
                    ProductScrapeReviewView(
                        result: scrapedResult,
                        onApply: { result in
                            applyScrapedResult(result)
                            showScrapeReview = false
                        },
                        onCancel: {
                            showScrapeReview = false
                        }
                    )
                }
            }
            .onAppear {
                if let product = editingProduct {
                    name = product.name ?? ""
                    brand = product.brand ?? ""
                    setCategorySelection(from: product.category)
                    description = product.description ?? ""
                    ingredients = product.ingredients ?? ""
                    allIngredients = product.allIngredients ?? ""
                    usageGuidelines = product.usageGuidelines ?? ""
                    imageUrl = product.imageUrl
                    isActive = product.isActive ?? true

                    if let price = product.price {
                        priceText = String(format: "%.2f", price)
                    }

                    if let skinTypes = product.skinTypes {
                        selectedSkinTypes = Set(skinTypes)
                    }

                    if let concerns = product.concerns {
                        selectedConcerns = Set(AppConstants.normalizeConcerns(concerns))
                    }
                }
            }
            .toolbar {
                ToolbarItemGroup(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItemGroup(placement: .confirmationAction) {
                    Button("Save") {
                        saveProduct()
                    }
                    .fontWeight(.semibold)
                    .disabled(!isFormValid)
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .alert("Delete Product", isPresented: $showDeleteConfirm) {
                Button("Delete", role: .destructive) {
                    deleteProduct()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will permanently remove the product from your catalog.")
            }
        }
    }

    private var urlImportSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Import from URL")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(theme.primaryText)

            ThemedTextField(
                title: "Product URL",
                placeholder: "https://supplier.com/product",
                text: $sourceUrl,
                field: .sourceUrl,
                focusedField: $focusedField,
                theme: theme,
                icon: "link",
                keyboardType: .URL,
                textContentType: .URL,
                autocapitalization: .none
            )
            .submitLabel(.go)
            .onSubmit {
                fetchDetailsTapped()
            }

            ZStack {
                RoundedRectangle(cornerRadius: theme.radiusMedium)
                    .fill(sourceUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? theme.tertiaryBackground : theme.accent)

                HStack {
                    Image(systemName: "sparkles")
                    Text("Fetch Details")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundColor(sourceUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? theme.secondaryText : .white)
                .padding(.vertical, 12)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                fetchDetailsTapped()
            }

            Text("Paste a supplier product URL to auto-fill the fields. You can review and edit before saving.")
                .font(.system(size: 13))
                .foregroundColor(theme.secondaryText)
        }
    }

    private var imageSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Product Image")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(theme.primaryText)

            PhotosPicker(selection: $selectedImage, matching: .images) {
                if let productImage = productImage {
                    Image(uiImage: productImage)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 200)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: theme.radiusMedium))
                        .overlay(
                            RoundedRectangle(cornerRadius: theme.radiusMedium)
                                .stroke(theme.border, lineWidth: 1)
                        )
                } else if let imageUrl, !imageUrl.isEmpty, let url = URL(string: imageUrl) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                        case .failure:
                            Image(systemName: "photo")
                                .font(.system(size: 28))
                                .foregroundColor(theme.tertiaryText)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        @unknown default:
                            EmptyView()
                        }
                    }
                    .frame(height: 200)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: theme.radiusMedium))
                    .overlay(
                        RoundedRectangle(cornerRadius: theme.radiusMedium)
                            .stroke(theme.border, lineWidth: 1)
                    )
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "photo.badge.plus")
                            .font(.system(size: 48))
                            .foregroundColor(theme.tertiaryText)

                        Text("Tap to add product image")
                            .font(.system(size: 15))
                            .foregroundColor(theme.secondaryText)
                    }
                    .frame(height: 200)
                    .frame(maxWidth: .infinity)
                    .background(theme.tertiaryBackground)
                    .clipShape(RoundedRectangle(cornerRadius: theme.radiusMedium))
                    .overlay(
                        RoundedRectangle(cornerRadius: theme.radiusMedium)
                            .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [5]))
                            .foregroundColor(theme.border)
                    )
                }
            }
            .buttonStyle(.plain)
        }
    }

    private var basicInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Basic Information")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(theme.primaryText)

            formField(title: "Product Name", icon: "cube.box", placeholder: "e.g. Hydrating Serum", text: $name, field: .name)
            formField(title: "Brand", icon: "building.2", placeholder: "e.g. CeraVe", text: $brand, field: .brand)

            VStack(alignment: .leading, spacing: 8) {
                Text("Category")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(theme.secondaryText)

                HStack(spacing: 12) {
                    Image(systemName: "tag")
                        .font(.system(size: 18))
                        .foregroundColor(theme.tertiaryText)
                        .frame(width: 24)

                    Picker("Category", selection: $selectedCategory) {
                        ForEach(categoryOptions, id: \.self) { category in
                            Text(category).tag(category)
                        }
                    }
                    .pickerStyle(.menu)
                    .foregroundColor(theme.primaryText)
                }
                .padding(16)
                .background(theme.inputBackground)
                .clipShape(RoundedRectangle(cornerRadius: theme.radiusMedium))
                .overlay(
                    RoundedRectangle(cornerRadius: theme.radiusMedium)
                        .stroke(theme.inputBorder, lineWidth: 1)
                )
            }

            if selectedCategory == "Custom" {
                ThemedTextField(
                    title: "Custom Category",
                    placeholder: "e.g. Ampoule",
                    text: $customCategory,
                    field: .category,
                    focusedField: $focusedField,
                    theme: theme,
                    icon: "pencil",
                    autocapitalization: .words
                )
            }
        }
    }

    private var pricingSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Pricing")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(theme.primaryText)

            ThemedTextField(
                title: "Price",
                placeholder: "0.00",
                text: $priceText,
                field: .price,
                focusedField: $focusedField,
                theme: theme,
                icon: "dollarsign.circle",
                keyboardType: .decimalPad,
                textContentType: nil,
                autocapitalization: .none
            )
        }
    }

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Details")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(theme.primaryText)

            textEditorField(title: "Description", icon: "text.alignleft", placeholder: "Brief description of the product", text: $description, field: .description)
            textEditorField(title: "Key Ingredients", icon: "list.bullet", placeholder: "List main active ingredients (e.g., Vitamin C, Hyaluronic Acid)", text: $ingredients, field: .ingredients)
            textEditorField(title: "All Ingredients", icon: "text.badge.checkmark", placeholder: "Complete ingredient list for allergy checking (e.g., Water, Glycerin, Niacinamide, ...)", text: $allIngredients, field: .allIngredients)
            textEditorField(title: "Usage Guidelines", icon: "lightbulb", placeholder: "How to use this product: frequency, application method, when to apply, tips (e.g., Apply twice daily, morning and night. Use pea-sized amount on clean, damp skin. Pat gently, don't rub.)", text: $usageGuidelines, field: .usageGuidelines)
        }
    }

    private var skinTypesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Suitable for Skin Types")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(theme.primaryText)

            FlowLayout(spacing: 8) {
                ForEach(skinTypes, id: \.self) { type in
                    Toggle(isOn: Binding(
                        get: { selectedSkinTypes.contains(type) },
                        set: { isSelected in
                            if isSelected {
                                selectedSkinTypes.insert(type)
                            } else {
                                selectedSkinTypes.remove(type)
                            }
                        }
                    )) {
                        Text(type)
                    }
                    .toggleStyle(ChipToggleStyle(theme: theme))
                }
            }
        }
    }

    private var concernsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Addresses Concerns")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(theme.primaryText)

            FlowLayout(spacing: 8) {
                ForEach(concerns, id: \.self) { concern in
                    Toggle(isOn: Binding(
                        get: { selectedConcerns.contains(concern) },
                        set: { isSelected in
                            if isSelected {
                                selectedConcerns.insert(concern)
                            } else {
                                selectedConcerns.remove(concern)
                            }
                        }
                    )) {
                        Text(concern)
                    }
                    .toggleStyle(ChipToggleStyle(theme: theme))
                }
            }
        }
    }

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Status")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(theme.primaryText)

            Toggle(isOn: $isActive) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Active")
                        .font(.system(size: 16, weight: .medium))
                    Text("Product will be available for AI recommendations")
                        .font(.system(size: 13))
                        .foregroundColor(theme.secondaryText)
                }
            }
            .tint(theme.accent)
        }
        .padding(16)
        .background(theme.tertiaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: theme.radiusMedium))
    }

    private var deleteSection: some View {
        VStack(spacing: 12) {
            Button(action: { showDeleteConfirm = true }) {
                HStack {
                    Image(systemName: "trash")
                    Text("Delete Product")
                        .font(.system(size: 16, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .foregroundColor(.white)
                .background(Color.red.opacity(0.85))
                .clipShape(RoundedRectangle(cornerRadius: theme.radiusMedium))
            }
            Text("This action cannot be undone.")
                .font(.system(size: 12))
                .foregroundColor(theme.secondaryText)
        }
        .padding(.top, 8)
    }

    private func formField(title: String, icon: String, placeholder: String, text: Binding<String>, field: Field) -> some View {
        ThemedTextField(
            title: title,
            placeholder: placeholder,
            text: text,
            field: field,
            focusedField: $focusedField,
            theme: theme,
            icon: icon,
            autocapitalization: .words
        )
    }

    private func textEditorField(title: String, icon: String, placeholder: String, text: Binding<String>, field: Field) -> some View {
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

    private var isFormValid: Bool {
        !name.isEmpty && !brand.isEmpty && !resolvedCategory.isEmpty
    }

    private var resolvedCategory: String {
        if selectedCategory == "Custom" {
            return customCategory.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if selectedCategory == "Select Category" {
            return ""
        }
        return selectedCategory.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func setCategorySelection(from value: String?) {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if trimmed.isEmpty {
            selectedCategory = "Select Category"
            customCategory = ""
            return
        }
        if categoryOptions.contains(trimmed) {
            selectedCategory = trimmed
            customCategory = ""
            return
        }
        selectedCategory = "Custom"
        customCategory = trimmed
    }

    private func scrapeProductDetails() {
        focusedField = nil
        let trimmedUrl = sourceUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmedUrl), url.scheme?.hasPrefix("http") == true else {
            errorMessage = "Enter a valid product URL starting with http or https."
            showError = true
            return
        }

        isScraping = true
        Task {
            do {
                let result = try await ProductScraper.shared.scrapeProduct(from: url)
                await MainActor.run {
                    scrapedResult = result
                    isScraping = false
                    showScrapeReview = true
                }
            } catch {
                await MainActor.run {
                    isScraping = false
                    errorMessage = "Failed to fetch product details: \(error.localizedDescription)"
                    showError = true
                }
            }
        }
    }

    private func fetchDetailsTapped() {
        guard !isScraping else { return }
        scrapeProductDetails()
    }

    private func applyScrapedResult(_ result: ProductScrapeResult) {
        if let value = result.name { name = value }
        if let value = result.brand { brand = value }
        if let value = result.category { setCategorySelection(from: value) }
        if let value = result.description { description = value }
        if let value = result.ingredients { ingredients = value }
        if let value = result.allIngredients { allIngredients = value }
        if let value = result.usageGuidelines { usageGuidelines = value }
        if let value = result.price { priceText = String(format: "%.2f", value) }
        if productImage == nil, let value = result.imageUrl { imageUrl = value }
    }

    private func saveProduct() {
        focusedField = nil
        isLoading = true

        Task {
            var uploadedImageUrl: String?

            // Upload image if one was selected
            if let productImage = productImage,
               let userId = AuthenticationManager.shared.currentUser?.id {
                do {
                    uploadedImageUrl = try await NetworkService.shared.uploadProductImage(
                        image: productImage,
                        userId: userId
                    )
                } catch {
                    await MainActor.run {
                        isLoading = false
                        errorMessage = "Failed to upload image: \(error.localizedDescription)"
                        showError = true
                    }
                    return
                }
            }

            // Parse price
            let price = Double(priceText.trimmingCharacters(in: .whitespaces))

            let productToSave = Product(
                id: editingProduct?.id,  // Use existing ID if editing
                userId: editingProduct?.userId ?? AuthenticationManager.shared.currentUser?.id,
                name: name,
                brand: brand,
                category: resolvedCategory,
                description: description.isEmpty ? nil : description,
                ingredients: ingredients.isEmpty ? nil : ingredients,
                allIngredients: allIngredients.isEmpty ? nil : allIngredients,
                usageGuidelines: usageGuidelines.isEmpty ? nil : usageGuidelines,
                skinTypes: Array(selectedSkinTypes),
                concerns: Array(selectedConcerns),
                imageUrl: uploadedImageUrl ?? imageUrl,  // Use new upload or keep existing
                price: price,
                isActive: isActive,
                createdAt: editingProduct?.createdAt
            )

            if editingProduct != nil {
                await viewModel.updateProduct(productToSave)
            } else {
                await viewModel.addProduct(productToSave)
            }

            await MainActor.run {
                isLoading = false

                if viewModel.showError {
                    errorMessage = viewModel.errorMessage
                    showError = true
                    viewModel.showError = false
                } else {
                    dismiss()
                }
            }
        }
    }

    private func deleteProduct() {
        guard let productId = editingProduct?.id else { return }
        isLoading = true

        Task {
            await viewModel.deleteProduct(productId: productId)

            await MainActor.run {
                isLoading = false
                if viewModel.showError {
                    errorMessage = viewModel.errorMessage
                    showError = true
                    viewModel.showError = false
                } else {
                    dismiss()
                }
            }
        }
    }
}

struct ChipToggleStyle: ToggleStyle {
    let theme: ThemeManager

    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            configuration.label
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(configuration.isOn ? .white : theme.primaryText)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(configuration.isOn ? theme.accent : theme.tertiaryBackground)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(configuration.isOn ? Color.clear : theme.border, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.replacingUnspecifiedDimensions().width, subviews: subviews, spacing: spacing)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x, y: bounds.minY + result.positions[index].y), proposal: .unspecified)
        }
    }

    struct FlowResult {
        var size: CGSize
        var positions: [CGPoint]

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var positions: [CGPoint] = []
            var size: CGSize = .zero
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0

            for subview in subviews {
                let subviewSize = subview.sizeThatFits(.unspecified)
                if currentX + subviewSize.width > maxWidth && currentX > 0 {
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                }
                positions.append(CGPoint(x: currentX, y: currentY))
                currentX += subviewSize.width + spacing
                lineHeight = max(lineHeight, subviewSize.height)
                size.width = max(size.width, currentX - spacing)
                size.height = currentY + lineHeight
            }
            self.size = size
            self.positions = positions
        }
    }
}
