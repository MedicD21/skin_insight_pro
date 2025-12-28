import SwiftUI

struct AddProductView: View {
    @ObservedObject var theme = ThemeManager.shared
    @ObservedObject var viewModel: ProductCatalogViewModel
    @Environment(\.dismiss) var dismiss
    @State private var name = ""
    @State private var brand = ""
    @State private var category = ""
    @State private var description = ""
    @State private var ingredients = ""
    @State private var selectedSkinTypes: Set<String> = []
    @State private var selectedConcerns: Set<String> = []
    @State private var isActive = true
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    @FocusState private var focusedField: Field?

    enum Field {
        case name, brand, category, description, ingredients
    }

    let skinTypes = ["Normal", "Dry", "Oily", "Combination", "Sensitive"]
    let concerns = ["Acne", "Aging", "Dark Spots", "Redness", "Dryness", "Oiliness", "Fine Lines", "Pores"]

    var body: some View {
        NavigationStack {
            ZStack {
                theme.primaryBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        basicInfoSection
                        detailsSection
                        skinTypesSection
                        concernsSection
                        statusSection
                    }
                    .padding(20)
                }
                .scrollDismissesKeyboard(.interactively)

                if isLoading {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()

                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(theme.accent)
                }
            }
            .navigationTitle("Add Product")
            .navigationBarTitleDisplayMode(.inline)
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
        }
    }

    private var basicInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Basic Information")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(theme.primaryText)

            formField(title: "Product Name", icon: "cube.box", placeholder: "e.g. Hydrating Serum", text: $name, field: .name)
            formField(title: "Brand", icon: "building.2", placeholder: "e.g. CeraVe", text: $brand, field: .brand)
            formField(title: "Category", icon: "tag", placeholder: "e.g. Serum, Cleanser, Moisturizer", text: $category, field: .category)
        }
    }

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Details")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(theme.primaryText)

            textEditorField(title: "Description", icon: "text.alignleft", placeholder: "Brief description of the product", text: $description, field: .description)
            textEditorField(title: "Key Ingredients", icon: "list.bullet", placeholder: "List main active ingredients", text: $ingredients, field: .ingredients)
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

    private func formField(title: String, icon: String, placeholder: String, text: Binding<String>, field: Field) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(theme.secondaryText)

            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(theme.tertiaryText)
                    .frame(width: 24)

                TextField(placeholder, text: text)
                    .font(.system(size: 17))
                    .foregroundColor(theme.primaryText)
                    .focused($focusedField, equals: field)
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
        !name.isEmpty && !brand.isEmpty && !category.isEmpty
    }

    private func saveProduct() {
        focusedField = nil
        isLoading = true

        let newProduct = Product(
            id: nil,
            userId: AuthenticationManager.shared.currentUser?.id,
            name: name,
            brand: brand,
            category: category,
            description: description.isEmpty ? nil : description,
            ingredients: ingredients.isEmpty ? nil : ingredients,
            skinTypes: Array(selectedSkinTypes),
            concerns: Array(selectedConcerns),
            isActive: isActive,
            createdAt: nil
        )

        Task {
            await viewModel.addProduct(newProduct)
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
