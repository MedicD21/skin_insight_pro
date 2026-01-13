import SwiftUI
import UniformTypeIdentifiers

struct ProductImportView: View {
    @ObservedObject var theme = ThemeManager.shared
    @ObservedObject var viewModel: ProductCatalogViewModel
    @Environment(\.dismiss) var dismiss
    @State private var showFilePicker = false
    @State private var isImporting = false
    @State private var importedProducts: [Product] = []
    @State private var importErrors: [String] = []
    @State private var importNotes: [String] = []
    @State private var showPreview = false
    @State private var csvText = ""
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showShareSheet = false
    @State private var csvFileURL: URL?
    @State private var selectedFileName = ""

    let validSkinTypes = ["Normal", "Dry", "Oily", "Combination", "Sensitive"]
    let validConcerns = AppConstants.concernOptions

    var body: some View {
        NavigationStack {
            ZStack {
                theme.primaryBackground
                    .ignoresSafeArea()

                if isImporting {
                    loadingView
                } else if showPreview {
                    previewView
                } else {
                    uploadView
                }
            }
            .navigationTitle("Import Products")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .sheet(isPresented: $showShareSheet) {
                if let url = csvFileURL {
                    ActivityViewController(activityItems: [url])
                }
            }
            .fileImporter(
                isPresented: $showFilePicker,
                allowedContentTypes: [.commaSeparatedText, .plainText],
                allowsMultipleSelection: false
            ) { result in
                handleFileImport(result)
            }
        }
    }

    private var uploadView: some View {
        ScrollView {
            VStack(spacing: 24) {
                instructionsCard
                csvInputSection
                templateSection
            }
            .padding(20)
        }
    }

    private var instructionsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(theme.accent)
                Text("How to Import")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(theme.primaryText)
            }

            VStack(alignment: .leading, spacing: 8) {
                instructionRow(number: "1", text: "Download the CSV template below")
                instructionRow(number: "2", text: "Fill in your product data")
                instructionRow(number: "3", text: "Upload your CSV file")
                instructionRow(number: "4", text: "Review and import")
            }
        }
        .padding(16)
        .background(theme.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: theme.radiusMedium))
    }

    private func instructionRow(number: String, text: String) -> some View {
        HStack(spacing: 12) {
            Text(number)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 28, height: 28)
                .background(theme.accent)
                .clipShape(Circle())

            Text(text)
                .font(.system(size: 15))
                .foregroundColor(theme.primaryText)
        }
    }

    private var csvInputSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("CSV Upload")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(theme.primaryText)

            Text("Upload a CSV file that includes the header row")
                .font(.system(size: 14))
                .foregroundColor(theme.secondaryText)

            VStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "doc.text")
                        .foregroundColor(theme.secondaryText)
                    Text(selectedFileName.isEmpty ? "No file selected" : selectedFileName)
                        .font(.system(size: 14))
                        .foregroundColor(selectedFileName.isEmpty ? theme.secondaryText : theme.primaryText)
                    Spacer()
                }
                .padding(12)
                .background(theme.tertiaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: theme.radiusMedium))
                .overlay(
                    RoundedRectangle(cornerRadius: theme.radiusMedium)
                        .stroke(theme.border, lineWidth: 1)
                )

                Button(action: { showFilePicker = true }) {
                    HStack {
                        Spacer()
                        Image(systemName: "tray.and.arrow.down.fill")
                        Text("Upload CSV File")
                        Spacer()
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(height: 48)
                    .background(theme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: theme.radiusMedium))
                }
            }

            Button(action: { parseCSV() }) {
                HStack {
                    Spacer()
                    Image(systemName: "arrow.right.circle.fill")
                    Text("Preview Import")
                    Spacer()
                }
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)
                .frame(height: 52)
                .background(csvText.isEmpty ? theme.tertiaryText : theme.accent)
                .clipShape(RoundedRectangle(cornerRadius: theme.radiusMedium))
            }
            .disabled(csvText.isEmpty)
        }
    }

    private var templateSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Template & Documentation")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(theme.primaryText)

            VStack(spacing: 12) {
                Button(action: { downloadCSVTemplate() }) {
                    HStack {
                        Image(systemName: "arrow.down.doc")
                        Text("Download CSV Template")
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                    .font(.system(size: 15))
                    .foregroundColor(theme.primaryText)
                    .padding(16)
                    .background(theme.secondaryBackground)
                    .clipShape(RoundedRectangle(cornerRadius: theme.radiusMedium))
                }

                Button(action: { pasteExampleData() }) {
                    HStack {
                        Image(systemName: "text.badge.plus")
                        Text("Paste Example Data")
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                    .font(.system(size: 15))
                    .foregroundColor(theme.primaryText)
                    .padding(16)
                    .background(theme.secondaryBackground)
                    .clipShape(RoundedRectangle(cornerRadius: theme.radiusMedium))
                }
            }
        }
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            let isAccessing = url.startAccessingSecurityScopedResource()
            defer {
                if isAccessing {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            do {
                let data = try Data(contentsOf: url)
                guard let content = String(data: data, encoding: .utf8) else {
                    errorMessage = "Unable to read the CSV file. Please ensure it's saved as UTF-8."
                    showError = true
                    return
                }
                csvText = content
                selectedFileName = url.lastPathComponent
                parseCSV()
            } catch {
                errorMessage = "Failed to read CSV file: \(error.localizedDescription)"
                showError = true
            }
        case .failure(let error):
            errorMessage = "Failed to select file: \(error.localizedDescription)"
            showError = true
        }
    }

    private var previewView: some View {
        ScrollView {
            VStack(spacing: 24) {
                summaryCard

                if !importErrors.isEmpty {
                    errorsCard
                }

                if !importNotes.isEmpty {
                    notesCard
                }

                if !importedProducts.isEmpty {
                    productsPreviewCard
                }

                actionButtons
            }
            .padding(20)
        }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("Import Preview")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(theme.primaryText)
            }

            HStack(spacing: 32) {
                VStack(spacing: 4) {
                    Text("\(importedProducts.count)")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(theme.accent)
                    Text("Products")
                        .font(.system(size: 14))
                        .foregroundColor(theme.secondaryText)
                }

                VStack(spacing: 4) {
                    Text("\(importErrors.count)")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(importErrors.isEmpty ? .green : .red)
                    Text("Errors")
                        .font(.system(size: 14))
                        .foregroundColor(theme.secondaryText)
                }

                VStack(spacing: 4) {
                    Text("\(importNotes.count)")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.orange)
                    Text("Notes")
                        .font(.system(size: 14))
                        .foregroundColor(theme.secondaryText)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(16)
        .background(theme.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: theme.radiusMedium))
    }

    private var errorsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
                Text("Import Errors")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(theme.primaryText)
            }

            VStack(alignment: .leading, spacing: 8) {
                ForEach(importErrors.prefix(10), id: \.self) { error in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.red)
                            .padding(.top, 2)

                        Text(error)
                            .font(.system(size: 13))
                            .foregroundColor(theme.primaryText)
                    }
                }

                if importErrors.count > 10 {
                    Text("And \(importErrors.count - 10) more errors...")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(theme.secondaryText)
                        .padding(.top, 4)
                }
            }
        }
        .padding(16)
        .background(Color.red.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: theme.radiusMedium))
    }

    private var productsPreviewCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Products to Import")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(theme.primaryText)

            VStack(spacing: 8) {
                ForEach(Array(importedProducts.prefix(5).enumerated()), id: \.offset) { _, product in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(product.name ?? "")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(theme.primaryText)

                            Text(product.brand ?? "")
                                .font(.system(size: 13))
                                .foregroundColor(theme.secondaryText)
                        }

                        Spacer()

                        if let price = product.price {
                            Text("$\(String(format: "%.2f", price))")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(theme.accent)
                        }
                    }
                    .padding(12)
                    .background(theme.tertiaryBackground)
                    .clipShape(RoundedRectangle(cornerRadius: theme.radiusSmall))
                }

                if importedProducts.count > 5 {
                    Text("And \(importedProducts.count - 5) more products...")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(theme.secondaryText)
                        .padding(.top, 4)
                }
            }
        }
        .padding(16)
        .background(theme.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: theme.radiusMedium))
    }

    private var notesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.orange)
                Text("Import Notes")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(theme.primaryText)
            }

            VStack(alignment: .leading, spacing: 8) {
                ForEach(importNotes.prefix(10), id: \.self) { note in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "circle.fill")
                            .font(.system(size: 6))
                            .foregroundColor(.orange)
                            .padding(.top, 6)

                        Text(note)
                            .font(.system(size: 13))
                            .foregroundColor(theme.primaryText)
                    }
                }
            }
        }
        .padding(16)
        .background(theme.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: theme.radiusMedium))
    }

    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button(action: { performImport() }) {
                HStack {
                    Spacer()
                    Image(systemName: "square.and.arrow.down.fill")
                    Text("Import \(importedProducts.count) Products")
                    Spacer()
                }
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)
                .frame(height: 52)
                .background(importedProducts.isEmpty ? theme.tertiaryText : theme.accent)
                .clipShape(RoundedRectangle(cornerRadius: theme.radiusMedium))
            }
            .disabled(importedProducts.isEmpty)

            Button(action: {
                showPreview = false
                importedProducts = []
                importErrors = []
            }) {
                Text("Back to Edit")
                    .font(.system(size: 16))
                    .foregroundColor(theme.accent)
            }
        }
    }

    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(theme.accent)

            Text("Importing products...")
                .font(.system(size: 17))
                .foregroundColor(theme.primaryText)
        }
    }

    // MARK: - Functions

    private func downloadCSVTemplate() {
        let template = "product_image,name,brand,category,price,description,key_ingredients,all_ingredients,usage_guidelines,skin_types,concerns\n,Hydrating Serum,CeraVe,Serum,24.99,Lightweight hydrating serum for all skin types,Hyaluronic Acid,,,Normal,Dryness"

        // Create temporary file
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "product_import_template.csv"
        let fileURL = tempDir.appendingPathComponent(fileName)

        do {
            try template.write(to: fileURL, atomically: true, encoding: .utf8)
            csvFileURL = fileURL
            showShareSheet = true
        } catch {
            errorMessage = "Failed to create CSV template file: \(error.localizedDescription)"
            showError = true
        }
    }

    private func pasteExampleData() {
        csvText = """
product_image,name,brand,category,price,description,key_ingredients,all_ingredients,usage_guidelines,skin_types,concerns
,Hydrating Serum,CeraVe,Serum,24.99,Lightweight hydrating serum for all skin types,Hyaluronic Acid,,,Normal,Dryness
,Gentle Cleanser,La Roche-Posay,Cleanser,18.50,Mild foaming cleanser for sensitive skin,Glycerin,,,Sensitive,Redness
,Retinol Night Cream,The Ordinary,Moisturizer,12.99,Anti-aging night treatment with retinol,Retinol,,,Normal,Aging
,Vitamin C Serum,Skinceuticals,Serum,165.00,Brightening serum with pure vitamin C,L-Ascorbic Acid,,,Normal,Dark Spots
,Niacinamide Solution,The Ordinary,Treatment,6.50,Pore-refining treatment,Niacinamide,,,Oily,Pores
"""
    }

    private func parseCSV() {
        importedProducts = []
        importErrors = []
        importNotes = []

        let lines = csvText.components(separatedBy: .newlines)
        guard lines.count > 1 else {
            errorMessage = "CSV file is empty or invalid"
            showError = true
            return
        }

        // Skip header row
        for (index, line) in lines.dropFirst().enumerated() {
            let rowNumber = index + 2 // +2 because we skip header and arrays are 0-indexed

            guard !line.trimmingCharacters(in: .whitespaces).isEmpty else {
                continue
            }

            let columns = parseCSVLine(line)

            guard columns.count >= 3 else {
                importErrors.append("Row \(rowNumber): Not enough columns (need at least product_image, name, brand)")
                continue
            }

            // Required fields
            let imageUrl = columns[0].trimmingCharacters(in: .whitespaces)
            let name = columns[1].trimmingCharacters(in: .whitespaces)
            let brand = columns[2].trimmingCharacters(in: .whitespaces)
            let category = columns.count > 3 ? columns[3].trimmingCharacters(in: .whitespaces) : ""

            if name.isEmpty {
                importErrors.append("Row \(rowNumber): Product name is required")
                continue
            }
            if brand.isEmpty {
                importErrors.append("Row \(rowNumber): Brand is required")
                continue
            }
            if category.isEmpty {
                importNotes.append("Row \(rowNumber): Category missing, please assign manually")
            }

            // Optional fields
            let priceStr = columns.count > 4 ? columns[4].trimmingCharacters(in: .whitespaces) : ""
            let description = columns.count > 5 ? columns[5].trimmingCharacters(in: .whitespaces) : ""
            let keyIngredients = columns.count > 6 ? columns[6].trimmingCharacters(in: .whitespaces) : ""
            let allIngredients = columns.count > 7 ? columns[7].trimmingCharacters(in: .whitespaces) : ""
            let usageGuidelines = columns.count > 8 ? columns[8].trimmingCharacters(in: .whitespaces) : ""

            // Parse skin types
            var skinTypes: [String] = []
            if columns.count > 9 {
                let skinTypesStr = columns[9].trimmingCharacters(in: .whitespaces)
                if !skinTypesStr.isEmpty {
                    skinTypes = skinTypesStr
                        .components(separatedBy: ",")
                        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                        .filter { !$0.isEmpty }
                    for skinType in skinTypes {
                        if !validSkinTypes.contains(skinType) {
                            importNotes.append("Row \(rowNumber): Invalid skin type '\(skinType)' - please assign manually")
                        }
                    }
                    skinTypes = skinTypes.filter { validSkinTypes.contains($0) }
                }
            }

            // Parse concerns
            var concerns: [String] = []
            if columns.count > 10 {
                let concernsStr = columns[10].trimmingCharacters(in: .whitespaces)
                if !concernsStr.isEmpty {
                    let rawConcerns = concernsStr.components(separatedBy: ",")
                        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                        .filter { !$0.isEmpty }
                    var normalizedConcerns: [String] = []

                    for concern in rawConcerns {
                        if let normalized = AppConstants.normalizeConcernLabel(concern) {
                            if !normalizedConcerns.contains(where: { $0.caseInsensitiveCompare(normalized) == .orderedSame }) {
                                normalizedConcerns.append(normalized)
                            }
                        } else {
                            importNotes.append("Row \(rowNumber): Invalid concern '\(concern)' - please assign manually")
                        }
                    }

                    for concern in normalizedConcerns {
                        if !validConcerns.contains(where: { $0.caseInsensitiveCompare(concern) == .orderedSame }) {
                            importNotes.append("Row \(rowNumber): Invalid concern '\(concern)' - please assign manually")
                        }
                    }

                    concerns = normalizedConcerns.filter { normalized in
                        validConcerns.contains(where: { $0.caseInsensitiveCompare(normalized) == .orderedSame })
                    }
                }
            }

            // Parse price
            var price: Double? = nil
            if !priceStr.isEmpty {
                if let parsedPrice = Double(priceStr) {
                    price = parsedPrice
                } else {
                    importErrors.append("Row \(rowNumber): Invalid price format '\(priceStr)'")
                }
            }

            let isActive = true

            let product = Product(
                id: nil,
                userId: AuthenticationManager.shared.currentUser?.id,
                name: name,
                brand: brand,
                category: category.isEmpty ? nil : category,
                description: description.isEmpty ? nil : description,
                ingredients: keyIngredients.isEmpty ? nil : keyIngredients,
                allIngredients: allIngredients.isEmpty ? nil : allIngredients,
                usageGuidelines: usageGuidelines.isEmpty ? nil : usageGuidelines,
                skinTypes: skinTypes.isEmpty ? nil : skinTypes,
                concerns: concerns.isEmpty ? nil : concerns,
                imageUrl: imageUrl.isEmpty ? nil : imageUrl,
                price: price,
                isActive: isActive,
                createdAt: nil
            )

            importedProducts.append(product)
        }

        showPreview = true
    }

    private func parseCSVLine(_ line: String) -> [String] {
        var columns: [String] = []
        var currentColumn = ""
        var insideQuotes = false

        for char in line {
            if char == "\"" {
                insideQuotes.toggle()
            } else if char == "," && !insideQuotes {
                columns.append(currentColumn)
                currentColumn = ""
            } else {
                currentColumn.append(char)
            }
        }
        columns.append(currentColumn)

        return columns
    }

    private func performImport() {
        isImporting = true

        Task {
            guard let userId = AuthenticationManager.shared.currentUser?.id else {
                await MainActor.run {
                    isImporting = false
                    errorMessage = "User not authenticated"
                    showError = true
                }
                return
            }

            var successCount = 0
            var failCount = 0

            for product in importedProducts {
                do {
                    _ = try await NetworkService.shared.createOrUpdateProduct(product: product, userId: userId)
                    successCount += 1
                } catch {
                    failCount += 1
                }
            }

            await MainActor.run {
                // Reload all products to get the newly imported ones
                Task {
                    await viewModel.loadProducts()
                }
                isImporting = false

                if failCount == 0 {
                    dismiss()
                } else {
                    errorMessage = "Imported \(successCount) products successfully. \(failCount) failed."
                    showError = true
                    showPreview = false
                }
            }
        }
    }
}
