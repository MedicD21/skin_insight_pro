import SwiftUI

struct AnalysisDetailView: View {
    @ObservedObject var theme = ThemeManager.shared
    let analysis: SkinAnalysisResult
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.dismiss) var dismiss
    
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
                    if let imageUrl = analysis.imageUrl, let url = URL(string: imageUrl) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .empty:
                                Rectangle()
                                    .fill(theme.tertiaryBackground)
                                    .overlay(ProgressView())
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                            case .failure:
                                Rectangle()
                                    .fill(theme.tertiaryBackground)
                                    .overlay(
                                        Image(systemName: "photo")
                                            .font(.system(size: 40))
                                            .foregroundColor(theme.tertiaryText)
                                    )
                            @unknown default:
                                EmptyView()
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(maxHeight: 300)
                        .clipShape(RoundedRectangle(cornerRadius: theme.radiusLarge))
                        .overlay(
                            RoundedRectangle(cornerRadius: theme.radiusLarge)
                                .stroke(theme.border, lineWidth: 1)
                        )
                    }
                    
                    if let results = analysis.analysisResults {
                        overviewCard(results: results)
                        
                        if let concerns = results.concerns, !concerns.isEmpty {
                            concernsCard(concerns: concerns)
                        }
                        
                        if let medicalConsiderations = results.medicalConsiderations, !medicalConsiderations.isEmpty {
                            medicalConsiderationsCard(considerations: medicalConsiderations)
                        }
                        
                        if let recommendations = results.recommendations, !recommendations.isEmpty {
                            recommendationsCard(recommendations: recommendations)
                        }
                    }
                    
                    if let notes = analysis.notes, !notes.isEmpty {
                        notesCard(notes: notes)
                    }
                }
                .padding(.horizontal, horizontalSizeClass == .regular ? 32 : 16)
                .padding(.top, 20)
                .padding(.bottom, horizontalSizeClass == .regular ? 40 : 100)
            }
        }
        .navigationTitle("Analysis Details")
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
        }
    }
    
    private func overviewCard(results: AnalysisData) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Analysis Overview")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(theme.primaryText)
            
            VStack(spacing: 12) {
                if let skinType = results.skinType {
                    infoRow(label: "Skin Type", value: skinType.capitalized, icon: "drop")
                }
                
                if let hydration = results.hydrationLevel {
                    infoRow(label: "Hydration Level", value: "\(hydration)%", icon: "humidity")
                }
                
                if let sensitivity = results.sensitivity {
                    infoRow(label: "Sensitivity", value: sensitivity.capitalized, icon: "exclamationmark.triangle")
                }
                
                if let poreCondition = results.poreCondition {
                    infoRow(label: "Pore Condition", value: poreCondition.capitalized, icon: "circle.grid.3x3")
                }
                
                if let score = results.skinHealthScore {
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
            
            if let date = analysis.createdAt {
                Divider()
                
                HStack {
                    Image(systemName: "calendar")
                        .font(.system(size: 14))
                        .foregroundColor(theme.secondaryText)
                    
                    Text(formatDate(date))
                        .font(.system(size: 14))
                        .foregroundColor(theme.secondaryText)
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
    
    private func concernsCard(concerns: [String]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundColor(theme.warning)
                Text("Skin Concerns")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(theme.primaryText)
            }
            
            VStack(alignment: .leading, spacing: 10) {
                ForEach(concerns, id: \.self) { concern in
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
            
            if hasAnyMedicalConcerns(concerns: concerns) {
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
    
    private func medicalConsiderationsCard(considerations: [String]) -> some View {
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
                ForEach(Array(considerations.enumerated()), id: \.offset) { index, consideration in
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
    
    private func recommendationsCard(recommendations: [String]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(theme.accent)
                Text("Recommendations")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(theme.primaryText)
            }
            
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(recommendations.enumerated()), id: \.offset) { index, recommendation in
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
    
    private func notesCard(notes: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "note.text")
                    .foregroundColor(theme.accent)
                Text("Notes")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(theme.primaryText)
            }
            
            Text(notes)
                .font(.system(size: 15))
                .foregroundColor(theme.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: theme.radiusXL)
                .fill(theme.cardBackground)
                .shadow(color: theme.shadowColor, radius: theme.shadowRadiusSmall, x: 0, y: 4)
        )
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
    
    private func hasAnyMedicalConcerns(concerns: [String]) -> Bool {
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
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .long
            displayFormatter.timeStyle = .short
            return displayFormatter.string(from: date)
        }
        return dateString
    }
}
