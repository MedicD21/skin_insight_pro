import SwiftUI

struct CompareAnalysesView: View {
    @ObservedObject var theme = ThemeManager.shared
    let client: AppClient
    let analyses: [SkinAnalysisResult]
    @Environment(\.dismiss) var dismiss
    @State private var selectedAnalysis1: SkinAnalysisResult?
    @State private var selectedAnalysis2: SkinAnalysisResult?
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    var body: some View {
        NavigationStack {
            ZStack {
                theme.primaryBackground
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        selectionSection
                        
                        if let analysis1 = selectedAnalysis1, let analysis2 = selectedAnalysis2 {
                            comparisonSection(analysis1: analysis1, analysis2: analysis2)
                        } else {
                            emptyStateView
                        }
                    }
                    .padding(.horizontal, horizontalSizeClass == .regular ? 32 : 16)
                    .padding(.top, 20)
                    .padding(.bottom, horizontalSizeClass == .regular ? 40 : 100)
                }
            }
            .navigationTitle("Compare Analyses")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var selectionSection: some View {
        VStack(spacing: 16) {
            Text("Select Two Analyses to Compare")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(theme.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack(spacing: 16) {
                analysisPicker(
                    title: "Before",
                    selection: $selectedAnalysis1,
                    excluding: selectedAnalysis2
                )
                
                Image(systemName: "arrow.right")
                    .font(.system(size: 20))
                    .foregroundColor(theme.accent)
                
                analysisPicker(
                    title: "After",
                    selection: $selectedAnalysis2,
                    excluding: selectedAnalysis1
                )
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: theme.radiusXL)
                .fill(theme.cardBackground)
                .shadow(color: theme.shadowColor, radius: theme.shadowRadiusMedium, x: 0, y: 8)
        )
    }
    
    private func analysisPicker(
        title: String,
        selection: Binding<SkinAnalysisResult?>,
        excluding: SkinAnalysisResult?
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(theme.secondaryText)
            
            Menu {
                ForEach(analyses.filter { $0.id != excluding?.id }) { analysis in
                    Button(action: { selection.wrappedValue = analysis }) {
                        VStack(alignment: .leading, spacing: 4) {
                            if let date = analysis.createdAt {
                                Text(formatDate(date))
                            }
                            if let skinType = analysis.analysisResults?.skinType {
                                Text(skinType.capitalized)
                                    .font(.caption)
                            }
                        }
                    }
                }
            } label: {
                HStack {
                    if let selected = selection.wrappedValue {
                        VStack(alignment: .leading, spacing: 4) {
                            if let date = selected.createdAt {
                                Text(formatDate(date))
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(theme.primaryText)
                            }
                            if let skinType = selected.analysisResults?.skinType {
                                Text(skinType.capitalized)
                                    .font(.system(size: 12))
                                    .foregroundColor(theme.secondaryText)
                            }
                        }
                    } else {
                        Text("Select...")
                            .font(.system(size: 14))
                            .foregroundColor(theme.tertiaryText)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12))
                        .foregroundColor(theme.tertiaryText)
                }
                .padding(12)
                .background(theme.tertiaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: theme.radiusMedium))
                .overlay(
                    RoundedRectangle(cornerRadius: theme.radiusMedium)
                        .stroke(theme.border, lineWidth: 1)
                )
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    private func comparisonSection(analysis1: SkinAnalysisResult, analysis2: SkinAnalysisResult) -> some View {
        VStack(spacing: 24) {
            imagesComparison(analysis1: analysis1, analysis2: analysis2)
            
            if let results1 = analysis1.analysisResults, let results2 = analysis2.analysisResults {
                metricsComparison(results1: results1, results2: results2)
                
                if let score1 = results1.skinHealthScore, let score2 = results2.skinHealthScore {
                    healthScoreComparison(score1: score1, score2: score2)
                }
                
                concernsComparison(results1: results1, results2: results2)
                
                if !(analysis1.productsUsed?.isEmpty ?? true) || !(analysis2.productsUsed?.isEmpty ?? true) ||
                   !(analysis1.treatmentsPerformed?.isEmpty ?? true) || !(analysis2.treatmentsPerformed?.isEmpty ?? true) {
                    treatmentComparison(analysis1: analysis1, analysis2: analysis2)
                }
            }
        }
    }
    
    private func imagesComparison(analysis1: SkinAnalysisResult, analysis2: SkinAnalysisResult) -> some View {
        VStack(spacing: 16) {
            Text("Visual Comparison")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(theme.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack(spacing: 16) {
                imageView(imageUrl: analysis1.imageUrl, label: "Before")
                imageView(imageUrl: analysis2.imageUrl, label: "After")
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: theme.radiusXL)
                .fill(theme.cardBackground)
                .shadow(color: theme.shadowColor, radius: theme.shadowRadiusSmall, x: 0, y: 4)
        )
    }
    
    private func imageView(imageUrl: String?, label: String) -> some View {
        VStack(spacing: 8) {
            if let imageUrl = imageUrl, let url = URL(string: imageUrl) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        Rectangle()
                            .fill(theme.tertiaryBackground)
                            .overlay(ProgressView())
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure:
                        Rectangle()
                            .fill(theme.tertiaryBackground)
                            .overlay(
                                Image(systemName: "photo")
                                    .foregroundColor(theme.tertiaryText)
                            )
                    @unknown default:
                        EmptyView()
                    }
                }
                .frame(height: 200)
                .clipShape(RoundedRectangle(cornerRadius: theme.radiusMedium))
            }
            
            Text(label)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(theme.secondaryText)
        }
        .frame(maxWidth: .infinity)
    }
    
    private func metricsComparison(results1: AnalysisData, results2: AnalysisData) -> some View {
        VStack(spacing: 16) {
            Text("Metrics Comparison")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(theme.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 12) {
                if let type1 = results1.skinType, let type2 = results2.skinType {
                    comparisonRow(
                        label: "Skin Type",
                        value1: type1.capitalized,
                        value2: type2.capitalized,
                        icon: "drop"
                    )
                }
                
                if let hydration1 = results1.hydrationLevel, let hydration2 = results2.hydrationLevel {
                    comparisonRow(
                        label: "Hydration",
                        value1: "\(hydration1)%",
                        value2: "\(hydration2)%",
                        icon: "humidity",
                        showChange: true,
                        change: hydration2 - hydration1
                    )
                }
                
                if let sensitivity1 = results1.sensitivity, let sensitivity2 = results2.sensitivity {
                    comparisonRow(
                        label: "Sensitivity",
                        value1: sensitivity1.capitalized,
                        value2: sensitivity2.capitalized,
                        icon: "exclamationmark.triangle"
                    )
                }
                
                if let pore1 = results1.poreCondition, let pore2 = results2.poreCondition {
                    comparisonRow(
                        label: "Pore Condition",
                        value1: pore1.capitalized,
                        value2: pore2.capitalized,
                        icon: "circle.grid.3x3"
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
    
    private func healthScoreComparison(score1: Int, score2: Int) -> some View {
        VStack(spacing: 16) {
            Text("Health Score Progress")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(theme.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text("Before")
                        .font(.system(size: 14))
                        .foregroundColor(theme.secondaryText)
                    
                    Text("\(score1)")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(theme.primaryText)
                    
                    Text("/ 10")
                        .font(.system(size: 14))
                        .foregroundColor(theme.secondaryText)
                }
                .frame(maxWidth: .infinity)
                
                VStack(spacing: 8) {
                    let change = score2 - score1
                    Image(systemName: change > 0 ? "arrow.up.circle.fill" : change < 0 ? "arrow.down.circle.fill" : "equal.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(change > 0 ? theme.success : change < 0 ? theme.error : theme.secondaryText)
                    
                    if change != 0 {
                        Text("\(abs(change)) point\(abs(change) == 1 ? "" : "s")")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(theme.secondaryText)
                    }
                }
                
                VStack(spacing: 8) {
                    Text("After")
                        .font(.system(size: 14))
                        .foregroundColor(theme.secondaryText)
                    
                    Text("\(score2)")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(theme.accent)
                    
                    Text("/ 10")
                        .font(.system(size: 14))
                        .foregroundColor(theme.secondaryText)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: theme.radiusXL)
                .fill(theme.cardBackground)
                .shadow(color: theme.shadowColor, radius: theme.shadowRadiusMedium, x: 0, y: 8)
        )
    }
    
    private func concernsComparison(results1: AnalysisData, results2: AnalysisData) -> some View {
        VStack(spacing: 16) {
            Text("Concerns Comparison")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(theme.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            let concerns1 = Set(results1.concerns ?? [])
            let concerns2 = Set(results2.concerns ?? [])
            let resolved = concerns1.subtracting(concerns2)
            let new = concerns2.subtracting(concerns1)
            let ongoing = concerns1.intersection(concerns2)
            
            VStack(spacing: 16) {
                if !resolved.isEmpty {
                    concernsSection(
                        title: "Resolved",
                        icon: "checkmark.circle.fill",
                        color: theme.success,
                        concerns: Array(resolved)
                    )
                }
                
                if !new.isEmpty {
                    concernsSection(
                        title: "New",
                        icon: "exclamationmark.circle.fill",
                        color: theme.warning,
                        concerns: Array(new)
                    )
                }
                
                if !ongoing.isEmpty {
                    concernsSection(
                        title: "Ongoing",
                        icon: "arrow.clockwise.circle.fill",
                        color: theme.secondaryText,
                        concerns: Array(ongoing)
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
    
    private func concernsSection(title: String, icon: String, color: Color, concerns: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(theme.secondaryText)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                ForEach(concerns, id: \.self) { concern in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(color.opacity(0.3))
                            .frame(width: 6, height: 6)
                        
                        Text(concern.capitalized)
                            .font(.system(size: 14))
                            .foregroundColor(theme.primaryText)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func treatmentComparison(analysis1: SkinAnalysisResult, analysis2: SkinAnalysisResult) -> some View {
        VStack(spacing: 16) {
            Text("Treatment History")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(theme.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack(alignment: .top, spacing: 16) {
                treatmentColumn(title: "Before", products: analysis1.productsUsed, treatments: analysis1.treatmentsPerformed)
                treatmentColumn(title: "After", products: analysis2.productsUsed, treatments: analysis2.treatmentsPerformed)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: theme.radiusXL)
                .fill(theme.cardBackground)
                .shadow(color: theme.shadowColor, radius: theme.shadowRadiusSmall, x: 0, y: 4)
        )
    }
    
    private func treatmentColumn(title: String, products: String?, treatments: String?) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(theme.secondaryText)
            
            if let products = products, !products.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "drop.triangle")
                            .font(.system(size: 12))
                        Text("Products")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(theme.accent)
                    
                    Text(products)
                        .font(.system(size: 13))
                        .foregroundColor(theme.primaryText)
                }
            }
            
            if let treatments = treatments, !treatments.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "wand.and.stars")
                            .font(.system(size: 12))
                        Text("Treatments")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(theme.accent)
                    
                    Text(treatments)
                        .font(.system(size: 13))
                        .foregroundColor(theme.primaryText)
                }
            }
            
            if (products?.isEmpty ?? true) && (treatments?.isEmpty ?? true) {
                Text("No data")
                    .font(.system(size: 13))
                    .foregroundColor(theme.tertiaryText)
                    .italic()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(theme.tertiaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: theme.radiusMedium))
    }
    
    private func comparisonRow(
        label: String,
        value1: String,
        value2: String,
        icon: String,
        showChange: Bool = false,
        change: Int = 0
    ) -> some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(theme.accent)
                    .frame(width: 24)
                
                Text(label)
                    .font(.system(size: 15))
                    .foregroundColor(theme.secondaryText)
                
                Spacer()
            }
            
            HStack(spacing: 16) {
                Text(value1)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(theme.primaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Image(systemName: "arrow.right")
                    .font(.system(size: 12))
                    .foregroundColor(theme.tertiaryText)
                
                HStack(spacing: 8) {
                    Text(value2)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(theme.accent)
                    
                    if showChange && change != 0 {
                        HStack(spacing: 4) {
                            Image(systemName: change > 0 ? "arrow.up" : "arrow.down")
                                .font(.system(size: 10))
                            Text("\(abs(change))")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundColor(change > 0 ? theme.success : theme.error)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding(.vertical, 8)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "arrow.left.arrow.right")
                .font(.system(size: 50))
                .foregroundColor(theme.tertiaryText)
            
            Text("Select Two Analyses")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(theme.primaryText)
            
            Text("Choose a before and after analysis to see the comparison")
                .font(.system(size: 15))
                .foregroundColor(theme.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            displayFormatter.timeStyle = .short
            return displayFormatter.string(from: date)
        }
        return dateString
    }
}