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
    @FocusState private var notesFieldFocused: Bool
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    private let medicalConditionKeywords = [
        "rosacea", "eczema", "psoriasis", "dermatitis", "acne", "melasma",
        "hyperpigmentation", "vitiligo", "keratosis", "lesion", "cyst",
        "mole", "nevus", "carcinoma", "melanoma", "infection", "fungal",
        "bacterial", "viral", "wart", "herpes", "shingles", "lupus",
        "scleroderma", "cellulitis", "abscess", "ulcer", "tumor"
    ]
    
    var body: some View {
        ZStack {
            theme.primaryBackground
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    imagePreview
                    
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
                    
                    if !productsUsed.isEmpty || !treatmentsPerformed.isEmpty {
                        treatmentCard
                    }
                    
                    if let recommendations = analysisResult.recommendations, !recommendations.isEmpty {
                        recommendationsCard
                    }
                    
                    if let progressNotes = analysisResult.progressNotes, !progressNotes.isEmpty {
                        progressCard
                    }
                    
                    notesSection
                    
                    saveButton
                }
                .padding(.horizontal, horizontalSizeClass == .regular ? 32 : 16)
                .padding(.top, 20)
                .padding(.bottom, horizontalSizeClass == .regular ? 40 : 100)
            }
            .scrollDismissesKeyboard(.interactively)
            
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
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
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

                        Text("Skin Health Score")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(theme.primaryText)

                        Spacer()

                        Text("\(score)/10")
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
                        currentValue: "\(currentScore)/10",
                        previousValue: "\(previousScore)/10",
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

            Text(label)
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
            }
            
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array((analysisResult.recommendations ?? []).enumerated()), id: \.offset) { index, recommendation in
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
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: theme.radiusXL)
                .fill(theme.cardBackground)
                .shadow(color: theme.shadowColor, radius: theme.shadowRadiusSmall, x: 0, y: 4)
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
    
    private func infoRow(label: String, value: String, icon: String) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(theme.accent)
                .frame(width: 24)
            
            Text(label)
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
                
                let savedAnalysis = try await NetworkService.shared.saveAnalysis(
                    clientId: clientId,
                    userId: userId,
                    imageUrl: imageUrl,
                    analysisResults: analysisResult,
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
}