import SwiftUI

struct ProductScrapeReviewView: View {
    @ObservedObject var theme = ThemeManager.shared
    let result: ProductScrapeResult
    let onApply: (ProductScrapeResult) -> Void
    let onCancel: () -> Void

    @FocusState private var focusedField: String?

    @State private var name: String
    @State private var brand: String
    @State private var category: String
    @State private var descriptionText: String
    @State private var ingredients: String
    @State private var allIngredients: String
    @State private var usageGuidelines: String
    @State private var priceText: String
    @State private var imageUrl: String

    init(result: ProductScrapeResult, onApply: @escaping (ProductScrapeResult) -> Void, onCancel: @escaping () -> Void) {
        self.result = result
        self.onApply = onApply
        self.onCancel = onCancel
        _name = State(initialValue: result.name ?? "")
        _brand = State(initialValue: result.brand ?? "")
        _category = State(initialValue: result.category ?? "")
        _descriptionText = State(initialValue: result.description ?? "")
        _ingredients = State(initialValue: result.ingredients ?? "")
        _allIngredients = State(initialValue: result.allIngredients ?? "")
        _usageGuidelines = State(initialValue: result.usageGuidelines ?? "")
        if let price = result.price {
            _priceText = State(initialValue: String(format: "%.2f", price))
        } else {
            _priceText = State(initialValue: "")
        }
        _imageUrl = State(initialValue: result.imageUrl ?? "")
    }

    var body: some View {
        NavigationStack {
            ZStack {
                theme.primaryBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        headerSection
                        previewImageSection
                        basicSection
                        detailsSection
                        notesSection
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Review Scrape")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Use Details") {
                        onApply(buildResult())
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Source URL")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(theme.secondaryText)

            Text(result.sourceURL.absoluteString)
                .font(.system(size: 14))
                .foregroundColor(theme.primaryText)
                .lineLimit(2)
                .truncationMode(.middle)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: theme.radiusMedium))
    }

    private var previewImageSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Product Image")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(theme.primaryText)

            if let url = URL(string: imageUrl), !imageUrl.isEmpty {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .empty:
                        ProgressView()
                    case .failure:
                        Image(systemName: "photo")
                            .font(.system(size: 28))
                            .foregroundColor(theme.tertiaryText)
                    @unknown default:
                        EmptyView()
                    }
                }
                .frame(height: 180)
                .frame(maxWidth: .infinity)
                .background(theme.tertiaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: theme.radiusMedium))
            } else {
                Text("No image found")
                    .font(.system(size: 14))
                    .foregroundColor(theme.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 12)
            }

            ThemedTextField(
                title: "Image URL",
                placeholder: "https://...",
                text: $imageUrl,
                field: "imageUrl",
                focusedField: $focusedField,
                theme: theme,
                icon: "link",
                keyboardType: .URL,
                textContentType: .URL,
                autocapitalization: .none
            )
        }
    }

    private var basicSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Basic Information")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(theme.primaryText)

            ThemedTextField(
                title: "Product Name",
                placeholder: "",
                text: $name,
                field: "name",
                focusedField: $focusedField,
                theme: theme,
                icon: "cube.box",
                autocapitalization: .words
            )

            ThemedTextField(
                title: "Brand",
                placeholder: "",
                text: $brand,
                field: "brand",
                focusedField: $focusedField,
                theme: theme,
                icon: "building.2",
                autocapitalization: .words
            )

            ThemedTextField(
                title: "Category",
                placeholder: "",
                text: $category,
                field: "category",
                focusedField: $focusedField,
                theme: theme,
                icon: "tag",
                autocapitalization: .words
            )

            ThemedTextField(
                title: "Price",
                placeholder: "0.00",
                text: $priceText,
                field: "price",
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
        VStack(alignment: .leading, spacing: 12) {
            Text("Details")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(theme.primaryText)

            textEditor(title: "Description", text: $descriptionText)
            textEditor(title: "Key Ingredients", text: $ingredients)
            textEditor(title: "All Ingredients", text: $allIngredients)
            textEditor(title: "Usage Guidelines", text: $usageGuidelines)
        }
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !result.notes.isEmpty {
                Text("Missing fields")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(theme.secondaryText)

                ForEach(result.notes, id: \.self) { note in
                    Text("- \(note)")
                        .font(.system(size: 13))
                        .foregroundColor(theme.secondaryText)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
    }

    private func textEditor(title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(theme.secondaryText)

            TextEditor(text: text)
                .font(.system(size: 15))
                .foregroundColor(theme.primaryText)
                .frame(minHeight: 70)
                .padding(10)
                .background(theme.tertiaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: theme.radiusSmall))
        }
    }

    private func buildResult() -> ProductScrapeResult {
        var updated = result
        updated.name = name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : name
        updated.brand = brand.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : brand
        updated.category = category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : category
        updated.description = descriptionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : descriptionText
        updated.ingredients = ingredients.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : ingredients
        updated.allIngredients = allIngredients.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : allIngredients
        updated.usageGuidelines = usageGuidelines.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : usageGuidelines
        updated.imageUrl = imageUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : imageUrl

        let priceValue = priceText.trimmingCharacters(in: .whitespacesAndNewlines)
        if priceValue.isEmpty {
            updated.price = nil
        } else {
            let cleaned = priceValue.replacingOccurrences(of: "[^0-9\\.]", with: "", options: .regularExpression)
            updated.price = Double(cleaned)
        }

        return updated
    }
}
