import SwiftUI

extension Notification.Name {
    static let dismissAnalysisInput = Notification.Name("dismissAnalysisInput")
}

struct SkinAnalysisResultsView: View {
    @ObservedObject var theme = ThemeManager.shared
    let client: AppClient
    let image: UIImage
    let analysisResult: AnalysisData
    @ObservedObject var viewModel: ClientDetailViewModel
    let productsUsed: String
    let treatmentsPerformed: String
    @Environment(\.dismiss) var dismiss
    @State private var notes = ""
    @State private var isSaving = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var activeMetricInfo: MetricInfo?
    @State private var isExportingPDF = false
    @State private var exportedPDF: Data?
    @State private var pdfURL: URL?
    @State private var showShareSheet = false
    @State private var companyProducts: [Product] = []
    @State private var isLoadingProducts = false
    @State private var showRecommendedRoutine = false
    @State private var recommendedRoutine: SkinCareRoutine
    @State private var editedRecommendations: [String]
    @State private var isEditingRecommendations = false
    @State private var newRecommendationDrafts: [String]
    @FocusState private var notesFieldFocused: Bool
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    private var flaggedProducts: [Product] { viewModel.flaggedProducts }
    
    private let medicalConditionKeywords = [
        "rosacea", "eczema", "psoriasis", "dermatitis", "acne", "melasma",
        "hyperpigmentation", "vitiligo", "keratosis", "lesion", "cyst",
        "mole", "nevus", "carcinoma", "melanoma", "infection", "fungal",
        "bacterial", "viral", "wart", "herpes", "shingles", "lupus",
        "scleroderma", "cellulitis", "abscess", "ulcer", "tumor"
    ]

    init(
        client: AppClient,
        image: UIImage,
        analysisResult: AnalysisData,
        viewModel: ClientDetailViewModel,
        productsUsed: String,
        treatmentsPerformed: String
    ) {
        self.client = client
        self.image = image
        self.analysisResult = analysisResult
        self.viewModel = viewModel
        self.productsUsed = productsUsed
        self.treatmentsPerformed = treatmentsPerformed
        _recommendedRoutine = State(initialValue: analysisResult.recommendedRoutine ?? SkinCareRoutine())
        _editedRecommendations = State(initialValue: analysisResult.recommendations ?? [])
        _newRecommendationDrafts = State(initialValue: [""])
    }
    
    var body: some View {
        ZStack {
            theme.primaryBackground
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    imagePreview

                    if let notice = analysisResult.analysisNotice, !notice.isEmpty {
                        analysisNoticeBanner(notice)
                    }
                    
                    overviewCard

                    if let previousAnalysis = viewModel.analyses.first {
                        comparisonCard(previousAnalysis: previousAnalysis)
                    }

                    if let concerns = analysisResult.concerns, !concerns.isEmpty {
                        concernsCard
                    }
                    
                    if let medicalConsiderations = analysisResult.medicalConsiderations, !medicalConsiderations.isEmpty {
                        medicalConsiderationsCard
                    }

                    if !flaggedProducts.isEmpty {
                        productsToAvoidCard
                    }
                    
                    if !productsUsed.isEmpty || !treatmentsPerformed.isEmpty {
                        treatmentCard
                    }
                    
                    if hasRecommendationsSection {
                        recommendationsCard
                    }

                    if let productRecommendations = analysisResult.productRecommendations, !productRecommendations.isEmpty {
                        productRecommendationsCard
                    }

                    if let progressNotes = analysisResult.progressNotes, !progressNotes.isEmpty {
                        progressCard
                    }
                    
                    notesSection

                    saveButton

                    exportButton
                }
                .padding(.horizontal, horizontalSizeClass == .regular ? 32 : 16)
                .padding(.top, 20)
                .padding(.bottom, horizontalSizeClass == .regular ? 40 : 100)
            }
            .scrollDismissesKeyboard(.interactively)
            .sheet(isPresented: $showShareSheet) {
                if let url = pdfURL {
                    ShareSheet(items: [url])
                }
            }
            
            if isSaving {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(.white)
                    
                    Text("Saving analysis...")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(.white)
                }
            }
        }
        .navigationTitle("Analysis Results")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(false)
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .alert(item: $activeMetricInfo) { info in
            Alert(
                title: Text(info.title),
                message: Text(info.description),
                dismissButton: .default(Text("OK"))
            )
        }
        .sheet(isPresented: $showRecommendedRoutine) {
            RecommendedRoutineView(
                client: routineClient,
                routine: $recommendedRoutine,
                availableProducts: routineProducts,
                flaggedProductIds: flaggedProductIds
            )
        }
        .onAppear {
            Task {
                await loadCompanyProducts()
            }
        }
        .task {
            await viewModel.loadFlaggedProducts(for: client)
        }
    }
    
    private var imagePreview: some View {
        Image(uiImage: image)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(maxWidth: .infinity)
            .frame(maxHeight: 300)
            .clipShape(RoundedRectangle(cornerRadius: theme.radiusLarge))
            .overlay(
                RoundedRectangle(cornerRadius: theme.radiusLarge)
                    .stroke(theme.border, lineWidth: 1)
            )
    }

    private func analysisNoticeBanner(_ notice: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(theme.accent)

            Text(notice)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(theme.primaryText)

            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: theme.radiusLarge)
                .fill(theme.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: theme.radiusLarge)
                .stroke(theme.cardBorder, lineWidth: 1)
        )
    }
    
    private var overviewCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Skin Analysis Overview")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(theme.primaryText)

            VStack(spacing: 12) {
                if let skinType = analysisResult.skinType {
                    infoRow(label: "Skin Type", value: skinType.capitalized, icon: "drop")
                }

                if let hydration = analysisResult.hydrationLevel {
                    infoRow(label: "Hydration Level", value: "\(hydration)%", icon: "humidity")
                }

                if let sensitivity = analysisResult.sensitivity {
                    infoRow(label: "Sensitivity", value: sensitivity.capitalized, icon: "exclamationmark.triangle")
                }

                if let poreCondition = analysisResult.poreCondition {
                    infoRow(label: "Pore Condition", value: poreCondition.capitalized, icon: "circle.grid.3x3")
                }

                if let score = analysisResult.skinHealthScore {
                    Divider()

                    HStack {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 20))
                            .foregroundColor(theme.accent)

                        Button {
                            showMetricInfo(title: "Skin Health Score")
                        } label: {
                            HStack(spacing: 6) {
                                Text("Skin Health Score")
                                Image(systemName: "info.circle")
                                    .font(.system(size: 12))
                            }
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(theme.primaryText)

                        Spacer()

                        Text("\(score)/100")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(theme.accent)
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: theme.radiusXL)
                .fill(theme.cardBackground)
                .shadow(color: theme.shadowColor, radius: theme.shadowRadiusMedium, x: 0, y: 8)
        )
    }

    private func comparisonCard(previousAnalysis: SkinAnalysisResult) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.left.arrow.right.circle.fill")
                    .foregroundColor(theme.accent)
                Text("Comparison with Previous Analysis")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(theme.primaryText)
            }

            if let previousDate = previousAnalysis.createdAt {
                Text("Compared to analysis from \(formatComparisonDate(previousDate))")
                    .font(.system(size: 13))
                    .foregroundColor(theme.secondaryText)
            }

            VStack(spacing: 12) {
                if let currentScore = analysisResult.skinHealthScore,
                   let previousScore = previousAnalysis.analysisResults?.skinHealthScore {
                    comparisonRow(
                        label: "Skin Health Score",
                        icon: "heart.fill",
                        currentValue: "\(currentScore)/100",
                        previousValue: "\(previousScore)/100",
                        change: currentScore - previousScore
                    )
                }

                if let currentHydration = analysisResult.hydrationLevel,
                   let previousHydration = previousAnalysis.analysisResults?.hydrationLevel {
                    comparisonRow(
                        label: "Hydration Level",
                        icon: "humidity",
                        currentValue: "\(currentHydration)%",
                        previousValue: "\(previousHydration)%",
                        change: currentHydration - previousHydration
                    )
                }

                if let currentSkinType = analysisResult.skinType,
                   let previousSkinType = previousAnalysis.analysisResults?.skinType {
                    if currentSkinType != previousSkinType {
                        HStack {
                            Image(systemName: "drop")
                                .font(.system(size: 16))
                                .foregroundColor(theme.accent)
                                .frame(width: 24)

                            Text("Skin Type")
                                .font(.system(size: 15))
                                .foregroundColor(theme.secondaryText)

                            Spacer()

                            VStack(alignment: .trailing, spacing: 4) {
                                Text(currentSkinType.capitalized)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(theme.primaryText)
                                Text("was: \(previousSkinType.capitalized)")
                                    .font(.system(size: 13))
                                    .foregroundColor(theme.secondaryText)
                            }
                        }
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: theme.radiusXL)
                .fill(theme.accent.opacity(0.05))
                .shadow(color: theme.shadowColor, radius: theme.shadowRadiusSmall, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: theme.radiusXL)
                .stroke(theme.accent.opacity(0.2), lineWidth: 1)
        )
    }

    private func comparisonRow(label: String, icon: String, currentValue: String, previousValue: String, change: Int) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(theme.accent)
                .frame(width: 24)

            Button {
                showMetricInfo(title: label)
            } label: {
                HStack(spacing: 6) {
                    Text(label)
                    Image(systemName: "info.circle")
                        .font(.system(size: 12))
                }
            }
            .buttonStyle(.plain)
            .font(.system(size: 15))
            .foregroundColor(theme.secondaryText)

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(currentValue)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(theme.primaryText)

                HStack(spacing: 4) {
                    if change > 0 {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 12))
                            .foregroundColor(theme.success)
                        Text("+\(change)")
                            .font(.system(size: 13))
                            .foregroundColor(theme.success)
                    } else if change < 0 {
                        Image(systemName: "arrow.down")
                            .font(.system(size: 12))
                            .foregroundColor(theme.error)
                        Text("\(change)")
                            .font(.system(size: 13))
                            .foregroundColor(theme.error)
                    } else {
                        Text("No change")
                            .font(.system(size: 13))
                            .foregroundColor(theme.secondaryText)
                    }
                }
            }
        }
    }

    private func formatComparisonDate(_ dateString: String) -> String {
        // Try ISO8601DateFormatter with fractional seconds
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        if let date = isoFormatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateFormat = "MM/dd/yyyy"
            return displayFormatter.string(from: date)
        }

        // Fallback: Try without fractional seconds
        isoFormatter.formatOptions = [.withInternetDateTime]
        if let date = isoFormatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateFormat = "MM/dd/yyyy"
            return displayFormatter.string(from: date)
        }

        return dateString
    }
    
    private var concernsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundColor(theme.warning)
                Text("Skin Concerns")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(theme.primaryText)
            }
            
            VStack(alignment: .leading, spacing: 10) {
                ForEach(analysisResult.concerns ?? [], id: \.self) { concern in
                    HStack(spacing: 12) {
                        Circle()
                            .fill(theme.warning.opacity(0.3))
                            .frame(width: 8, height: 8)
                        
                        Text(formatConcernWithAsterisk(concern))
                            .font(.system(size: 15))
                            .foregroundColor(theme.primaryText)
                        
                        Spacer()
                    }
                }
            }
            
            if hasAnyMedicalConcerns() {
                Divider()
                    .padding(.vertical, 8)
                
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top, spacing: 8) {
                        Text("*")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(theme.error)
                        
                        Text("May indicate a medical skin condition that requires professional evaluation.")
                            .font(.system(size: 13))
                            .foregroundColor(theme.secondaryText)
                    }
                    
                    HStack(spacing: 8) {
                        Image(systemName: "stethoscope")
                            .font(.system(size: 14))
                            .foregroundColor(theme.accent)
                        
                        Text("Please consult a dermatologist for proper diagnosis and treatment.")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(theme.accent)
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: theme.radiusMedium)
                            .fill(theme.accent.opacity(0.1))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: theme.radiusMedium)
                            .stroke(theme.accent.opacity(0.3), lineWidth: 1)
                    )
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: theme.radiusXL)
                .fill(theme.cardBackground)
                .shadow(color: theme.shadowColor, radius: theme.shadowRadiusSmall, x: 0, y: 4)
        )
    }
    
    private var medicalConsiderationsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "cross.case.fill")
                    .foregroundColor(theme.accent)
                Text("Medical Considerations")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(theme.primaryText)
            }
            
            Text("Based on the client's medical history and known sensitivities")
                .font(.system(size: 13))
                .foregroundColor(theme.secondaryText)
            
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array((analysisResult.medicalConsiderations ?? []).enumerated()), id: \.offset) { index, consideration in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(theme.accent)
                        
                        Text(consideration)
                            .font(.system(size: 15))
                            .foregroundColor(theme.primaryText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: theme.radiusXL)
                .fill(theme.accent.opacity(0.05))
                .shadow(color: theme.shadowColor, radius: theme.shadowRadiusSmall, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: theme.radiusXL)
                .stroke(theme.accent.opacity(0.2), lineWidth: 1)
        )
    }
    
    private var treatmentCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "wand.and.stars")
                    .foregroundColor(theme.accent)
                Text("Products & Treatments")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(theme.primaryText)
            }
            
            VStack(alignment: .leading, spacing: 16) {
                if !productsUsed.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: "drop.triangle")
                                .font(.system(size: 16))
                                .foregroundColor(theme.accent)
                            Text("Products Used")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(theme.secondaryText)
                        }
                        
                        Text(productsUsed)
                            .font(.system(size: 15))
                            .foregroundColor(theme.primaryText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                
                if !productsUsed.isEmpty && !treatmentsPerformed.isEmpty {
                    Divider()
                }
                
                if !treatmentsPerformed.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: "cross.case")
                                .font(.system(size: 16))
                                .foregroundColor(theme.accent)
                            Text("Treatments Performed")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(theme.secondaryText)
                        }
                        
                        Text(treatmentsPerformed)
                            .font(.system(size: 15))
                            .foregroundColor(theme.primaryText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: theme.radiusXL)
                .fill(theme.cardBackground)
                .shadow(color: theme.shadowColor, radius: theme.shadowRadiusSmall, x: 0, y: 4)
        )
    }
    
    private var progressCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundColor(theme.success)
                Text("Progress & Changes")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(theme.primaryText)
            }
            
            Text("Comparison with previous analyses")
                .font(.system(size: 13))
                .foregroundColor(theme.secondaryText)
            
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array((analysisResult.progressNotes ?? []).enumerated()), id: \.offset) { index, note in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 16))
                            .foregroundColor(theme.success)
                        
                        Text(note)
                            .font(.system(size: 15))
                            .foregroundColor(theme.primaryText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: theme.radiusXL)
                .fill(theme.success.opacity(0.05))
                .shadow(color: theme.shadowColor, radius: theme.shadowRadiusSmall, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: theme.radiusXL)
                .stroke(theme.success.opacity(0.2), lineWidth: 1)
        )
    }
    
    private var recommendationsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(theme.accent)
                Text("Recommendations")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(theme.primaryText)

                Spacer()

                Button(action: { toggleRecommendationsEdit() }) {
                    if isEditingRecommendations {
                        Text("Save")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(theme.accent)
                            .clipShape(Capsule())
                    } else {
                        Image(systemName: "pencil")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(theme.accent)
                            .padding(6)
                            .background(theme.accent.opacity(0.12))
                            .clipShape(Circle())
                    }
                }
            }
            
            VStack(alignment: .leading, spacing: 12) {
                if isEditingRecommendations {
                    ForEach(editedRecommendations.indices, id: \.self) { index in
                        HStack(alignment: .top, spacing: 12) {
                            Text("\(index + 1).")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(theme.accent)
                                .frame(width: 24, alignment: .leading)

                            TextField("Recommendation", text: Binding(
                                get: { editedRecommendations[index] },
                                set: { editedRecommendations[index] = $0 }
                            ), axis: .vertical)
                            .font(.system(size: 15))
                            .foregroundColor(theme.primaryText)
                            .lineLimit(2...6)

                            VStack(spacing: 6) {
                                Button(action: {
                                    moveRecommendation(at: index, direction: -1)
                                }) {
                                    Image(systemName: "chevron.up")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(theme.primaryText)
                                        .frame(width: 22, height: 22)
                                        .background(theme.accent.opacity(0.12))
                                        .clipShape(Circle())
                                }
                                .disabled(index == 0)
                                .opacity(index == 0 ? 0.4 : 1.0)

                                Button(action: {
                                    moveRecommendation(at: index, direction: 1)
                                }) {
                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(theme.primaryText)
                                        .frame(width: 22, height: 22)
                                        .background(theme.accent.opacity(0.12))
                                        .clipShape(Circle())
                                }
                                .disabled(index == editedRecommendations.count - 1)
                                .opacity(index == editedRecommendations.count - 1 ? 0.4 : 1.0)
                            }

                            Button(action: {
                                editedRecommendations.remove(at: index)
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(theme.secondaryText)
                                    .font(.system(size: 16))
                            }
                        }
                    }

                    ForEach(newRecommendationDrafts.indices, id: \.self) { index in
                        HStack(alignment: .top, spacing: 12) {
                            Text("\(editedRecommendations.count + index + 1).")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(theme.accent)
                                .frame(width: 24, alignment: .leading)

                            TextField("Add recommendation", text: Binding(
                                get: { newRecommendationDrafts[index] },
                                set: { newRecommendationDrafts[index] = $0 }
                            ), axis: .vertical)
                            .font(.system(size: 15))
                            .foregroundColor(theme.primaryText)
                            .lineLimit(2...6)
                            .onChange(of: newRecommendationDrafts[index]) { _, value in
                                handleRecommendationDraftChange(value, at: index)
                            }
                        }
                    }
                } else {
                    ForEach(Array(displayRecommendations.enumerated()), id: \.offset) { index, recommendation in
                        HStack(alignment: .top, spacing: 12) {
                            Text("\(index + 1).")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(theme.accent)
                                .frame(width: 24, alignment: .leading)

                            Text(recommendation)
                                .font(.system(size: 15))
                                .foregroundColor(theme.primaryText)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: theme.radiusXL)
                .fill(theme.cardBackground)
                .shadow(color: theme.shadowColor, radius: theme.shadowRadiusSmall, x: 0, y: 4)
        )
    }

    private var productRecommendationsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "cart.fill")
                    .foregroundColor(theme.accent)
                Text("Product Recommendations")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(theme.primaryText)
            }

            // Safety reminder if client has allergies, sensitivities, or products to avoid
            if hasClientSafetyRestrictions {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "exclamationmark.shield.fill")
                        .font(.system(size: 16))
                        .foregroundColor(theme.warning)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Safety Check Reminder")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(theme.warning)

                        Text(safetyReminderText)
                            .font(.system(size: 13))
                            .foregroundColor(theme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(12)
                .background(theme.warning.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: theme.radiusMedium))
                .overlay(
                    RoundedRectangle(cornerRadius: theme.radiusMedium)
                        .stroke(theme.warning.opacity(0.3), lineWidth: 1)
                )
            }

            VStack(alignment: .leading, spacing: 12) {
                // AI-generated recommendations
                ForEach(Array((analysisResult.productRecommendations ?? []).enumerated()), id: \.offset) { index, product in
                    HStack(alignment: .top, spacing: 12) {
                        Text("\(index + 1).")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(theme.accent)
                            .frame(width: 24, alignment: .leading)

                        Text(product)
                            .font(.system(size: 15))
                            .foregroundColor(theme.primaryText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

            }

            Button(action: { openRecommendedRoutine() }) {
                HStack {
                    Image(systemName: hasRoutineSteps ? "list.bullet.rectangle" : "sparkles")
                    Text(hasRoutineSteps ? "Recommended Routine" : "Create Recommended Routine")
                        .fontWeight(.semibold)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(theme.secondaryText)
                }
                .font(.system(size: 15))
                .foregroundColor(theme.primaryText)
                .padding(12)
                .background(theme.tertiaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: theme.radiusMedium))
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: theme.radiusXL)
                .fill(theme.cardBackground)
                .shadow(color: theme.shadowColor, radius: theme.shadowRadiusSmall, x: 0, y: 4)
        )
    }

    private var productsToAvoidCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "hand.raised.fill")
                    .foregroundColor(theme.warning)
                Text("Do NOT Use (Allergies/Sensitivities)")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(theme.primaryText)
            }

            Text("The following products contain ingredients that match this client's allergies, sensitivities, or products-to-avoid list.")
                .font(.system(size: 13))
                .foregroundColor(theme.secondaryText)

            VStack(alignment: .leading, spacing: 10) {
                ForEach(flaggedProducts) { product in
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(product.brand ?? "") \(product.name ?? "")".trimmingCharacters(in: .whitespaces))
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(theme.primaryText)

                        if let ingredients = product.allIngredients, !ingredients.isEmpty {
                            Text(ingredients)
                                .font(.system(size: 13))
                                .foregroundColor(theme.secondaryText)
                                .lineLimit(2)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    if product.id != flaggedProducts.last?.id {
                        Divider()
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: theme.radiusXL)
                .fill(theme.cardBackground)
                .shadow(color: theme.shadowColor, radius: theme.shadowRadiusSmall, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: theme.radiusXL)
                .stroke(theme.warning.opacity(0.2), lineWidth: 1)
        )
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Additional Notes")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(theme.primaryText)
            
            TextEditor(text: $notes)
                .font(.system(size: 15))
                .foregroundColor(theme.primaryText)
                .frame(minHeight: 100)
                .padding(12)
                .background(theme.tertiaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: theme.radiusMedium))
                .overlay(
                    RoundedRectangle(cornerRadius: theme.radiusMedium)
                        .stroke(notesFieldFocused ? theme.accent : theme.border, lineWidth: notesFieldFocused ? 2 : 1)
                )
                .focused($notesFieldFocused)
                .scrollContentBackground(.hidden)
        }
    }
    
    private var hasClientSafetyRestrictions: Bool {
        (client.allergies != nil && !client.allergies!.isEmpty) ||
        (client.knownSensitivities != nil && !client.knownSensitivities!.isEmpty) ||
        (client.productsToAvoid != nil && !client.productsToAvoid!.isEmpty)
    }

    private var safetyReminderText: String {
        var restrictions: [String] = []

        if let allergies = client.allergies, !allergies.isEmpty {
            restrictions.append("Allergies: \(allergies)")
        }
        if let sensitivities = client.knownSensitivities, !sensitivities.isEmpty {
            restrictions.append("Sensitivities: \(sensitivities)")
        }
        if let productsToAvoid = client.productsToAvoid, !productsToAvoid.isEmpty {
            restrictions.append("Products to Avoid: \(productsToAvoid)")
        }

        let restrictionText = restrictions.joined(separator: " • ")
        return "AI has filtered recommendations based on: \(restrictionText). Always verify ingredient lists before use."
    }

    private var saveButton: some View {
        Button(action: saveAnalysis) {
            HStack {
                Spacer()
                Image(systemName: "checkmark.circle.fill")
                Text("Save Analysis")
                Spacer()
            }
            .font(.system(size: 17, weight: .semibold))
            .foregroundColor(.white)
            .frame(height: 52)
            .background(theme.accent)
            .clipShape(RoundedRectangle(cornerRadius: theme.radiusMedium))
        }
    }

    private var exportButton: some View {
        Button(action: exportCurrentAnalysisPDF) {
            HStack {
                Spacer()
                Image(systemName: "square.and.arrow.up")
                Text("Export PDF")
                Spacer()
            }
            .font(.system(size: 17, weight: .semibold))
            .foregroundColor(theme.accent)
            .frame(height: 52)
            .background(theme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: theme.radiusMedium))
            .overlay(
                RoundedRectangle(cornerRadius: theme.radiusMedium)
                    .stroke(theme.border, lineWidth: 1)
            )
        }
        .disabled(isExportingPDF)
    }

    private func exportCurrentAnalysisPDF() {
        isExportingPDF = true

        Task {
            // Convert AppClient to Client
            let clientModel = Client(
                id: client.id ?? "",
                name: client.name ?? "",
                companyId: client.companyId ?? "",
                email: client.email,
                phone: client.phone,
                createdAt: Date()
            )

            var pdfAnalysisResult = analysisResult
            pdfAnalysisResult.recommendedRoutine = recommendedRoutine
            pdfAnalysisResult.recommendations = displayRecommendations

            // Use the new detailed PDF export method
            guard let pdfData = PDFExportManager.shared.generateDetailedAnalysisPDF(
                client: clientModel,
                analysisData: pdfAnalysisResult,
                image: image,
                notes: notes.isEmpty ? nil : notes,
                productsUsed: productsUsed.isEmpty ? nil : productsUsed,
                treatmentsPerformed: treatmentsPerformed.isEmpty ? nil : treatmentsPerformed,
                timestamp: Date()
            ) else {
                await MainActor.run {
                    isExportingPDF = false
                    errorMessage = "Failed to generate PDF"
                    showError = true
                }
                return
            }

            // Save PDF to temporary file
            let tempDir = FileManager.default.temporaryDirectory
            let fileName = "Analysis_\(client.name?.replacingOccurrences(of: " ", with: "_") ?? "Client")_\(Date().timeIntervalSince1970).pdf"
            let fileURL = tempDir.appendingPathComponent(fileName)

            do {
                try pdfData.write(to: fileURL)

                await MainActor.run {
                    exportedPDF = pdfData
                    pdfURL = fileURL
                    isExportingPDF = false
                    showShareSheet = true
                }
            } catch {
                await MainActor.run {
                    isExportingPDF = false
                    errorMessage = "Failed to save PDF: \(error.localizedDescription)"
                    showError = true
                }
            }
        }
    }

    private func infoRow(label: String, value: String, icon: String) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(theme.accent)
                .frame(width: 24)

            Button {
                showMetricInfo(title: label)
            } label: {
                HStack(spacing: 6) {
                    Text(label)
                    Image(systemName: "info.circle")
                        .font(.system(size: 12))
                }
            }
            .buttonStyle(.plain)
            .font(.system(size: 15))
            .foregroundColor(theme.secondaryText)
            
            Spacer()
            
            Text(value)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(theme.primaryText)
        }
    }
    
    private func formatConcernWithAsterisk(_ concern: String) -> String {
        let lowercasedConcern = concern.lowercased()
        for keyword in medicalConditionKeywords {
            if lowercasedConcern.contains(keyword) {
                return "\(concern.capitalized) *"
            }
        }
        return concern.capitalized
    }
    
    private func hasAnyMedicalConcerns() -> Bool {
        guard let concerns = analysisResult.concerns else { return false }
        
        for concern in concerns {
            let lowercasedConcern = concern.lowercased()
            for keyword in medicalConditionKeywords {
                if lowercasedConcern.contains(keyword) {
                    return true
                }
            }
        }
        return false
    }
    
    private func saveAnalysis() {
        guard let userId = AuthenticationManager.shared.currentUser?.id,
              let clientId = client.id else { return }

        notesFieldFocused = false
        isSaving = true

        Task {
            do {
                let imageUrl = try await NetworkService.shared.uploadImage(image: image, userId: userId)

                var updatedAnalysisResult = analysisResult
                updatedAnalysisResult.recommendedRoutine = recommendedRoutine
                updatedAnalysisResult.recommendations = displayRecommendations

                let savedAnalysis = try await NetworkService.shared.saveAnalysis(
                    clientId: clientId,
                    userId: userId,
                    imageUrl: imageUrl,
                    analysisResults: updatedAnalysisResult,
                    notes: notes,
                    clientMedicalHistory: client.medicalHistory,
                    clientAllergies: client.allergies,
                    clientKnownSensitivities: client.knownSensitivities,
                    clientMedications: client.medications,
                    productsUsed: productsUsed.isEmpty ? nil : productsUsed,
                    treatmentsPerformed: treatmentsPerformed.isEmpty ? nil : treatmentsPerformed
                )

                viewModel.addAnalysis(savedAnalysis)

                // Update client's profile image with the latest analysis image
                var updatedClient = client
                updatedClient.profileImageUrl = imageUrl
                _ = try await NetworkService.shared.createOrUpdateClient(client: updatedClient, userId: userId)

                isSaving = false
                // Dismiss the results view first
                dismiss()
                // Then dismiss the input sheet by posting a notification
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    NotificationCenter.default.post(name: .dismissAnalysisInput, object: nil)
                }
            } catch is CancellationError {
                isSaving = false
                return
            } catch {
                isSaving = false
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }

    private func showMetricInfo(title: String) {
        guard let description = metricDescriptions[title] else { return }
        activeMetricInfo = MetricInfo(title: title, description: description)
    }

    private var metricDescriptions: [String: String] {
        [
            "Skin Type": "Estimated from oiliness, dryness, and texture cues in the photo.",
            "Hydration Level": "Photo-based moisture appearance estimate (0-100). Higher means more hydrated-looking skin.",
            "Sensitivity": "Based on visible redness or irritation patterns.",
            "Pore Condition": "Estimated from pore visibility and texture detail.",
            "Skin Health Score": "Overall score (0-100) combining concerns, hydration, and sensitivity."
        ]
    }

    private var hasRoutineSteps: Bool {
        !(recommendedRoutine.morningSteps.isEmpty && recommendedRoutine.eveningSteps.isEmpty)
    }

    private var hasRecommendationsSection: Bool {
        !displayRecommendations.isEmpty || isEditingRecommendations
    }

    private var displayRecommendations: [String] {
        editedRecommendations
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func openRecommendedRoutine() {
        if !hasRoutineSteps {
            recommendedRoutine = generateRoutineFromRecommendations()
        }
        showRecommendedRoutine = true
    }

    private func toggleRecommendationsEdit() {
        if isEditingRecommendations {
            commitRecommendationEdits()
        } else {
            isEditingRecommendations = true
            if newRecommendationDrafts.isEmpty {
                newRecommendationDrafts = [""]
            }
        }
    }

    private func commitRecommendationEdits() {
        var combined = editedRecommendations + newRecommendationDrafts
        combined = combined
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var seen = Set<String>()
        let unique = combined.filter { recommendation in
            let key = recommendation.lowercased()
            if seen.contains(key) { return false }
            seen.insert(key)
            return true
        }

        editedRecommendations = unique
        newRecommendationDrafts = [""]
        isEditingRecommendations = false
    }

    private func handleRecommendationDraftChange(_ value: String, at index: Int) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if index == newRecommendationDrafts.count - 1, !trimmed.isEmpty {
            newRecommendationDrafts.append("")
        }
    }

    private func moveRecommendation(at index: Int, direction: Int) {
        let newIndex = index + direction
        guard editedRecommendations.indices.contains(index),
              editedRecommendations.indices.contains(newIndex) else { return }
        editedRecommendations.swapAt(index, newIndex)
    }


    private func generateRoutineFromRecommendations() -> SkinCareRoutine {
        let allRecommendations = combinedProductRecommendations()
        let availableProducts = routineProducts
        var morningSteps: [RoutineStep] = []
        var eveningSteps: [RoutineStep] = []

        for recommendation in allRecommendations {
            if let product = matchProduct(for: recommendation, products: availableProducts) {
                let instructions = product.usageGuidelines?.trimmingCharacters(in: .whitespacesAndNewlines)
                let baseStep = RoutineStep(
                    productName: formattedProductName(for: product),
                    productId: product.id,
                    stepNumber: 0,
                    instructions: instructions?.isEmpty == true ? nil : instructions,
                    imageUrl: product.imageUrl
                )

                let targets = routineTargets(for: product)
                if targets.includeMorning {
                    morningSteps.append(baseStep)
                }
                if targets.includeEvening {
                    eveningSteps.append(baseStep)
                }
            } else {
                let baseStep = RoutineStep(productName: recommendation, stepNumber: 0)
                morningSteps.append(baseStep)
                if !isMorningOnlyProduct(recommendation) {
                    eveningSteps.append(baseStep)
                }
            }
        }

        morningSteps = normalizeAndSortRoutineSteps(morningSteps, products: availableProducts)
        eveningSteps = normalizeAndSortRoutineSteps(eveningSteps, products: availableProducts)

        let notes = recommendedRoutine.notes
        return SkinCareRoutine(morningSteps: morningSteps, eveningSteps: eveningSteps, notes: notes)
    }

    private func mergeRoutineWithRecommendations(current: SkinCareRoutine) -> SkinCareRoutine {
        let recommendations = combinedProductRecommendations()
        let normalizedRecommendations = Set(recommendations.map(normalizeProductName).filter { !$0.isEmpty })
        let availableProducts = routineProducts

        var morningSteps = current.morningSteps.filter {
            normalizedRecommendations.contains(normalizeProductName($0.productName))
        }
        var eveningSteps = current.eveningSteps.filter {
            normalizedRecommendations.contains(normalizeProductName($0.productName))
        }

        var existingSet = Set(morningSteps.map { normalizeProductName($0.productName) })
        existingSet.formUnion(eveningSteps.map { normalizeProductName($0.productName) })

        for recommendation in recommendations {
            let normalized = normalizeProductName(recommendation)
            guard !normalized.isEmpty, !existingSet.contains(normalized) else { continue }

            if let product = matchProduct(for: recommendation, products: availableProducts) {
                let baseStep = RoutineStep(
                    productName: formattedProductName(for: product),
                    productId: product.id,
                    stepNumber: 0,
                    imageUrl: product.imageUrl
                )

                let targets = routineTargets(for: product)
                if targets.includeMorning {
                    morningSteps.append(baseStep)
                }
                if targets.includeEvening {
                    eveningSteps.append(baseStep)
                }
            } else {
                let baseStep = RoutineStep(productName: recommendation, stepNumber: 0)
                morningSteps.append(baseStep)
                if !isMorningOnlyProduct(recommendation) {
                    eveningSteps.append(baseStep)
                }
            }

            existingSet.insert(normalized)
        }

        normalizeStepNumbers(&morningSteps)
        normalizeStepNumbers(&eveningSteps)

        return SkinCareRoutine(
            morningSteps: morningSteps,
            eveningSteps: eveningSteps,
            notes: current.notes
        )
    }

    private func combinedProductRecommendations() -> [String] {
        let recommendations = analysisResult.productRecommendations ?? []

        var seen = Set<String>()
        var uniqueRecommendations: [String] = []
        for recommendation in recommendations {
            let normalized = normalizeProductName(recommendation)
            guard !normalized.isEmpty else { continue }
            if seen.insert(normalized).inserted {
                uniqueRecommendations.append(recommendation)
            }
        }

        return uniqueRecommendations
    }

    private func normalizeAndSortRoutineSteps(_ steps: [RoutineStep], products: [Product]) -> [RoutineStep] {
        let sortedSteps = steps.sorted { lhs, rhs in
            let lhsOrder = categoryOrder(for: lhs, products: products)
            let rhsOrder = categoryOrder(for: rhs, products: products)
            if lhsOrder == rhsOrder {
                return lhs.productName.localizedCaseInsensitiveCompare(rhs.productName) == .orderedAscending
            }
            return lhsOrder < rhsOrder
        }

        return sortedSteps.enumerated().map { index, step in
            var updated = step
            updated.stepNumber = index + 1
            return updated
        }
    }

    private func normalizeStepNumbers(_ steps: inout [RoutineStep]) {
        for index in steps.indices {
            steps[index].stepNumber = index + 1
        }
    }

    private func categoryOrder(for step: RoutineStep, products: [Product]) -> Int {
        if let product = matchProduct(for: step.productName, products: products) {
            return categoryOrder(for: product)
        }
        return categoryOrder(forText: step.productName)
    }

    private func categoryOrder(for product: Product) -> Int {
        let combined = "\(product.category ?? "") \(product.name ?? "")"
        return categoryOrder(forText: combined)
    }

    private func categoryOrder(forText value: String) -> Int {
        let text = value.lowercased()
        if text.contains("cleanser") || text.contains("cleanse") {
            return 1
        }
        if text.contains("toner") || text.contains("essence") || text.contains("mist") {
            return 2
        }
        if text.contains("serum") || text.contains("treatment") || text.contains("retinol") || text.contains("exfol") || text.contains("acid") || text.contains("mask") {
            return 3
        }
        if text.contains("eye") {
            return 4
        }
        if text.contains("moistur") || text.contains("cream") || text.contains("lotion") {
            return 5
        }
        if text.contains("oil") {
            return 6
        }
        if text.contains("spf") || text.contains("sunscreen") {
            return 7
        }
        return 99
    }

    private func routineTargets(for product: Product) -> (includeMorning: Bool, includeEvening: Bool) {
        let combined = "\(product.category ?? "") \(product.name ?? "")".lowercased()
        if combined.contains("spf") || combined.contains("sunscreen") {
            return (true, false)
        }
        if combined.contains("retinol") || combined.contains("night") || combined.contains("pm") {
            return (false, true)
        }
        return (true, true)
    }

    private func isMorningOnlyProduct(_ name: String) -> Bool {
        let text = name.lowercased()
        return text.contains("spf") || text.contains("sunscreen")
    }

    private func matchProduct(for stepName: String, products: [Product]) -> Product? {
        let normalizedStepName = normalizeProductName(stepName)
        guard !normalizedStepName.isEmpty else { return nil }

        return products.first { product in
            let displayName = formattedProductName(for: product)
            let normalizedDisplay = normalizeProductName(displayName)
            let normalizedProductName = normalizeProductName(product.name ?? "")
            return normalizedDisplay == normalizedStepName || normalizedProductName == normalizedStepName
        }
    }

    private func formattedProductName(for product: Product) -> String {
        let brand = product.brand?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let name = product.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if brand.isEmpty { return name }
        if name.isEmpty { return brand }
        return "\(brand) - \(name)"
    }

    private func normalizeProductName(_ value: String) -> String {
        value
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .joined()
    }

    private var clientDisplayName: String {
        if let name = client.name, !name.isEmpty {
            return name
        }

        let firstName = client.firstName ?? ""
        let lastName = client.lastName ?? ""
        let combined = "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
        return combined.isEmpty ? "Client" : combined
    }

    private var routineClient: Client {
        Client(
            id: client.id ?? "",
            name: clientDisplayName,
            companyId: client.companyId ?? "",
            email: client.email,
            phone: client.phone,
            createdAt: Date()
        )
    }

    private var routineProducts: [Product] {
        companyProducts.filter { $0.isActive == true }
    }

    private var flaggedProductIds: Set<String> {
        Set(flaggedProducts.compactMap { $0.id })
    }

    private struct MetricInfo: Identifiable {
        let title: String
        let description: String
        var id: String { title }
    }

    // MARK: - Helper Functions

    private func loadCompanyProducts() async {
        guard !isLoadingProducts else { return }
        isLoadingProducts = true

        do {
            let userId = await MainActor.run { AuthenticationManager.shared.currentUser?.id ?? "" }
            let companyId = client.companyId

            companyProducts = try await NetworkService.shared.fetchProductsForUser(
                userId: userId,
                companyId: companyId
            )
        } catch {
            errorMessage = "Failed to load products: \(error.localizedDescription)"
            showError = true
        }

        isLoadingProducts = false
    }

}
