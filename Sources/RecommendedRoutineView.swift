import SwiftUI

struct RecommendedRoutineView: View {
    @ObservedObject var theme = ThemeManager.shared
    @Environment(\.dismiss) var dismiss

    let client: Client
    @Binding var routine: SkinCareRoutine
    let availableProducts: [Product]
    let flaggedProductIds: Set<String>

    @State private var editMode: EditMode = .inactive
    @State private var selectedTab: RoutineTab = .morning
    @State private var isExporting = false
    @State private var exportedPDF: Data?
    @State private var showShareSheet = false
    @State private var showAddStepSheet = false

    enum RoutineTab {
        case morning, evening
    }

    var body: some View {
        NavigationStack {
            ZStack {
                theme.primaryBackground
                    .ignoresSafeArea()

                VStack(spacing: 12) {
                    headerSection
                        .padding(.top, 12)
                        .padding(.horizontal, 20)

                    tabSelector
                        .padding(.horizontal, 20)

                    List {
                        if selectedTab == .morning {
                            routineStepsSection(
                                title: "Morning Routine",
                                icon: "sun.max.fill",
                                steps: $routine.morningSteps,
                                emptyMessage: "No morning routine steps"
                            )
                        } else {
                            routineStepsSection(
                                title: "Evening Routine",
                                icon: "moon.fill",
                                steps: $routine.eveningSteps,
                                emptyMessage: "No evening routine steps"
                            )
                        }

                        if let notes = routine.notes, !notes.isEmpty {
                            notesSection(notes: notes)
                                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                        }

                        exportButton
                            .listRowInsets(EdgeInsets(top: 12, leading: 20, bottom: 20, trailing: 20))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .frame(maxHeight: .infinity)
                }

                if isExporting {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()

                    ProgressView("Generating PDF...")
                        .padding(20)
                        .background(theme.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: theme.radiusMedium))
                }
            }
            .navigationTitle("Recommended Routine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button(editMode == .active ? "Done" : "Edit") {
                        withAnimation {
                            editMode = editMode == .active ? .inactive : .active
                        }
                    }
                    .fontWeight(.semibold)
                }
            }
            .environment(\.editMode, $editMode)
            .sheet(isPresented: $showShareSheet) {
                if let pdfData = exportedPDF {
                    ShareSheet(items: [pdfData as Any])
                }
            }
            .sheet(isPresented: $showAddStepSheet) {
                RoutineStepPickerView(
                    products: availableProducts,
                    flaggedProductIds: flaggedProductIds,
                    onSelect: addRoutineStep
                )
            }
        }
    }

    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 48))
                .foregroundColor(theme.accent)

            Text("Personalized Skincare Routine")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(theme.primaryText)

            Text("For \(client.name)")
                .font(.system(size: 16))
                .foregroundColor(theme.secondaryText)

            if editMode == .active {
                Text("Drag to reorder steps and add new ones below")
                    .font(.system(size: 14))
                    .foregroundColor(theme.accent)
                    .padding(.top, 4)
            }
        }
        .padding(.vertical, 8)
    }

    private var tabSelector: some View {
        HStack(spacing: 12) {
            tabButton(tab: .morning, title: "Morning", icon: "sun.max.fill")
            tabButton(tab: .evening, title: "Evening", icon: "moon.fill")
        }
        .padding(.horizontal, 4)
    }

    private func tabButton(tab: RoutineTab, title: String, icon: String) -> some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTab = tab
            }
        }) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(selectedTab == tab ? .white : theme.primaryText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(selectedTab == tab ? theme.accent : theme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: theme.radiusMedium))
        }
    }

    private func routineStepsSection(title: String, icon: String, steps: Binding<[RoutineStep]>, emptyMessage: String) -> some View {
        Section {
            if steps.wrappedValue.isEmpty {
                emptyStateRow(message: emptyMessage)
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            } else {
                ForEach(steps.wrappedValue.indices, id: \.self) { index in
                    routineStepCard(step: steps[index])
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
                .onMove { source, destination in
                    steps.wrappedValue.move(fromOffsets: source, toOffset: destination)
                    normalizeStepNumbers(&steps.wrappedValue)
                }
            }

            if editMode == .active {
                addStepRow
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
        } header: {
            routineSectionHeader(title: title, icon: icon)
        }
        .textCase(nil)
    }

    private func routineStepCard(step: Binding<RoutineStep>) -> some View {
        HStack(alignment: .top, spacing: 16) {
            // Step number
            ZStack {
                Circle()
                    .fill(theme.accent.opacity(0.15))
                    .frame(width: 40, height: 40)
                Text("\(step.wrappedValue.stepNumber)")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(theme.accent)
            }

            // Product image (if available)
            if let imageUrl = step.wrappedValue.imageUrl, let url = URL(string: imageUrl) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .empty, .failure:
                        placeholderImage
                    @unknown default:
                        placeholderImage
                    }
                }
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                placeholderImage
                    .frame(width: 60, height: 60)
            }

            // Product details
            VStack(alignment: .leading, spacing: 6) {
                Text(step.wrappedValue.productName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(theme.primaryText)

                if editMode == .active {
                    TextField("Amount (e.g., pea-sized)", text: optionalTextBinding(step.amount))
                        .font(.system(size: 14))
                        .foregroundColor(theme.primaryText)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 10)
                        .background(theme.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(theme.border, lineWidth: 1)
                        )
                } else if let amount = step.wrappedValue.amount, !amount.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "drop.fill")
                            .font(.system(size: 12))
                            .foregroundColor(theme.accent)
                        Text(amount)
                            .font(.system(size: 14))
                            .foregroundColor(theme.secondaryText)
                    }
                }

                if editMode == .active {
                    TextField("Instructions", text: optionalTextBinding(step.instructions), axis: .vertical)
                        .font(.system(size: 14))
                        .foregroundColor(theme.primaryText)
                        .lineLimit(2...6)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 10)
                        .background(theme.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(theme.border, lineWidth: 1)
                        )
                } else if let instructions = step.wrappedValue.instructions, !instructions.isEmpty {
                    Text(instructions)
                        .font(.system(size: 14))
                        .foregroundColor(theme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 12) {
                    if let frequency = step.wrappedValue.frequency {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                                .font(.system(size: 11))
                            Text(frequency)
                                .font(.system(size: 12))
                        }
                        .foregroundColor(theme.tertiaryText)
                    }

                    if let waitTime = step.wrappedValue.waitTime, waitTime > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.system(size: 11))
                            Text("Wait \(waitTime)s")
                                .font(.system(size: 12))
                        }
                        .foregroundColor(theme.tertiaryText)
                    }
                }
            }

            Spacer()
        }
        .padding(16)
        .background(theme.tertiaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: theme.radiusMedium))
    }

    private func routineSectionHeader(title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(theme.accent)
            Text(title)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(theme.primaryText)
        }
        .padding(.leading, 4)
        .padding(.top, 8)
    }

    private func emptyStateRow(message: String) -> some View {
        Text(message)
            .font(.system(size: 15))
            .foregroundColor(theme.secondaryText)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 32)
            .padding(.horizontal, 16)
            .background(theme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: theme.radiusLarge))
    }

    private var addStepRow: some View {
        Button(action: { showAddStepSheet = true }) {
            HStack(spacing: 10) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 18))
                Text("Add Step to \(selectedTab == .morning ? "Morning" : "Evening") Routine")
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundColor(theme.accent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(theme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: theme.radiusMedium))
        }
        .buttonStyle(.plain)
    }

    private var placeholderImage: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(theme.tertiaryBackground)
            Image(systemName: "drop.fill")
                .font(.system(size: 24))
                .foregroundColor(theme.tertiaryText)
        }
    }

    private func notesSection(notes: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(theme.accent)
                Text("Routine Tips")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(theme.primaryText)
            }

            Text(notes)
                .font(.system(size: 15))
                .foregroundColor(theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .background(theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: theme.radiusLarge))
    }

    private var exportButton: some View {
        Button(action: exportRoutinePDF) {
            HStack {
                Image(systemName: "square.and.arrow.up")
                Text("Export Routine as PDF")
            }
            .font(.system(size: 17, weight: .semibold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(16)
            .background(theme.accent)
            .clipShape(RoundedRectangle(cornerRadius: theme.radiusMedium))
        }
        .disabled(isExporting)
    }

    private func exportRoutinePDF() {
        isExporting = true

        Task {
            guard let pdfData = PDFExportManager.shared.generateRoutinePDF(
                client: client,
                routine: routine
            ) else {
                await MainActor.run {
                    isExporting = false
                }
                return
            }

            await MainActor.run {
                exportedPDF = pdfData
                isExporting = false
                showShareSheet = true
            }
        }
    }

    private func addRoutineStep(product: Product) {
        let productName = formattedProductName(for: product)
        let newStep = RoutineStep(
            productName: productName,
            productId: product.id,
            stepNumber: 0,
            imageUrl: product.imageUrl
        )

        switch selectedTab {
        case .morning:
            routine.morningSteps.append(newStep)
            normalizeStepNumbers(&routine.morningSteps)
        case .evening:
            routine.eveningSteps.append(newStep)
            normalizeStepNumbers(&routine.eveningSteps)
        }

        showAddStepSheet = false
    }

    private func normalizeStepNumbers(_ steps: inout [RoutineStep]) {
        for index in steps.indices {
            steps[index].stepNumber = index + 1
        }
    }

    private func formattedProductName(for product: Product) -> String {
        let brand = product.brand?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let name = product.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if brand.isEmpty { return name }
        if name.isEmpty { return brand }
        return "\(brand) - \(name)"
    }

    private func optionalTextBinding(_ value: Binding<String?>) -> Binding<String> {
        Binding(
            get: { value.wrappedValue ?? "" },
            set: { newValue in
                let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                value.wrappedValue = trimmed.isEmpty ? nil : newValue
            }
        )
    }
}

private struct RoutineStepPickerView: View {
    @ObservedObject var theme = ThemeManager.shared
    @Environment(\.dismiss) private var dismiss
    let products: [Product]
    let flaggedProductIds: Set<String>
    let onSelect: (Product) -> Void
    @State private var searchText = ""

    private var filteredProducts: [Product] {
        guard !searchText.isEmpty else { return products }
        let query = searchText.lowercased()
        return products.filter { product in
            let name = "\(product.brand ?? "") \(product.name ?? "")".lowercased()
            return name.contains(query)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                theme.primaryBackground
                    .ignoresSafeArea()

                if products.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "shippingbox")
                            .font(.system(size: 48))
                            .foregroundColor(theme.tertiaryText)
                        Text("No products available")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(theme.primaryText)
                        Text("Add products to your catalog to build a routine.")
                            .font(.system(size: 14))
                            .foregroundColor(theme.secondaryText)
                    }
                } else {
                    List {
                        ForEach(filteredProducts) { product in
                            let isFlagged = flaggedProductIds.contains(product.id ?? "")
                            Button {
                                guard !isFlagged else { return }
                                onSelect(product)
                                dismiss()
                            } label: {
                                RoutineProductRow(product: product, isFlagged: isFlagged)
                            }
                            .buttonStyle(.plain)
                            .listRowBackground(theme.secondaryBackground)
                            .listRowSeparator(.hidden)
                            .opacity(isFlagged ? 0.6 : 1.0)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Add Routine Step")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search products")
        }
    }
}

private struct RoutineProductRow: View {
    let product: Product
    let isFlagged: Bool
    @ObservedObject var theme = ThemeManager.shared

    var body: some View {
        HStack(spacing: 14) {
            if let imageUrl = product.imageUrl, let url = URL(string: imageUrl) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .empty, .failure:
                        placeholderImage
                    @unknown default:
                        placeholderImage
                    }
                }
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                placeholderImage
                    .frame(width: 56, height: 56)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("\(product.brand ?? "") \(product.name ?? "")".trimmingCharacters(in: .whitespaces))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(isFlagged ? theme.error : theme.primaryText)

                if let category = product.category, !category.isEmpty {
                    Text(category)
                        .font(.system(size: 13))
                        .foregroundColor(theme.secondaryText)
                }

                if isFlagged {
                    Text("Contains ingredients the client should avoid.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(theme.error)
                }
            }

            Spacer()

            if isFlagged {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(theme.error)
            } else {
                Image(systemName: "plus.circle.fill")
                    .foregroundColor(theme.accent)
            }
        }
        .padding(.vertical, 6)
    }

    private var placeholderImage: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(theme.tertiaryBackground)
            Image(systemName: "drop.fill")
                .font(.system(size: 22))
                .foregroundColor(theme.tertiaryText)
        }
    }
}
