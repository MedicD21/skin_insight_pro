import SwiftUI
import Charts

struct TrendingGraphsView: View {
    @ObservedObject var theme = ThemeManager.shared
    @Environment(\.dismiss) var dismiss
    @Environment(\.horizontalSizeClass) var horizontalSizeClass

    let client: Client
    let analyses: [SkinAnalysis]

    @State private var selectedMetric: MetricType = .hydration
    @State private var isExporting = false
    @State private var exportedPDF: Data?
    @State private var showShareSheet = false

    enum MetricType: String, CaseIterable {
        case hydration = "Hydration"
        case oiliness = "Oiliness"
        case texture = "Texture"
        case pores = "Pores"
        case wrinkles = "Wrinkles"
        case redness = "Redness"
        case darkSpots = "Dark Spots"
        case acne = "Acne"
        case all = "All Metrics"

        var icon: String {
            switch self {
            case .hydration: return "drop.fill"
            case .oiliness: return "sparkles"
            case .texture: return "hand.raised.fill"
            case .pores: return "circle.grid.cross.fill"
            case .wrinkles: return "waveform.path"
            case .redness: return "circle.fill"
            case .darkSpots: return "sun.max.fill"
            case .acne: return "exclamationmark.circle.fill"
            case .all: return "chart.line.uptrend.xyaxis"
            }
        }

        var color: Color {
            switch self {
            case .hydration: return .cyan
            case .oiliness: return .yellow
            case .texture: return .purple
            case .pores: return .orange
            case .wrinkles: return .brown
            case .redness: return .red
            case .darkSpots: return .indigo
            case .acne: return .pink
            case .all: return .white
            }
        }
    }

    private var sortedAnalyses: [SkinAnalysis] {
        analyses.sorted { $0.timestamp < $1.timestamp }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                theme.primaryBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        headerSection

                        metricFilterSection

                        if selectedMetric == .all {
                            allMetricsChart
                        } else {
                            singleMetricChart
                        }

                        statisticsSection

                        exportButton
                    }
                    .padding(20)
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
            .navigationTitle("Trending Analysis")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let pdfData = exportedPDF {
                    ShareSheet(items: [pdfData as Any])
                }
            }
        }
    }

    private var headerSection: some View {
        VStack(spacing: 12) {
            Text(client.name)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(theme.primaryText)

            if let firstDate = sortedAnalyses.first?.timestamp,
               let lastDate = sortedAnalyses.last?.timestamp {
                Text("\(firstDate.formatted(date: .abbreviated, time: .omitted)) - \(lastDate.formatted(date: .abbreviated, time: .omitted))")
                    .font(.system(size: 14))
                    .foregroundColor(theme.secondaryText)
            }

            Text("\(sortedAnalyses.count) Scans")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(theme.accent)
        }
    }

    private var metricFilterSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(MetricType.allCases, id: \.self) { metric in
                    Button(action: { selectedMetric = metric }) {
                        HStack(spacing: 8) {
                            Image(systemName: metric.icon)
                                .font(.system(size: 14))
                            Text(metric.rawValue)
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundColor(selectedMetric == metric ? .white : theme.primaryText)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(selectedMetric == metric ? metric.color : theme.cardBackground)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(selectedMetric == metric ? Color.clear : theme.border, lineWidth: 1)
                        )
                    }
                }
            }
        }
    }

    private var singleMetricChart: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(selectedMetric.rawValue + " Over Time")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(theme.primaryText)

            Chart {
                ForEach(Array(sortedAnalyses.enumerated()), id: \.element.id) { index, analysis in
                    LineMark(
                        x: .value("Date", analysis.timestamp),
                        y: .value(selectedMetric.rawValue, getMetricValue(for: analysis, metric: selectedMetric))
                    )
                    .foregroundStyle(selectedMetric.color.gradient)
                    .lineStyle(StrokeStyle(lineWidth: 3))

                    PointMark(
                        x: .value("Date", analysis.timestamp),
                        y: .value(selectedMetric.rawValue, getMetricValue(for: analysis, metric: selectedMetric))
                    )
                    .foregroundStyle(selectedMetric.color)
                    .annotation(position: .top) {
                        Text(String(format: "%.1f", getMetricValue(for: analysis, metric: selectedMetric)))
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(theme.primaryText)
                            .padding(4)
                            .background(theme.cardBackground.opacity(0.9))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }
            }
            .chartYScale(domain: 0...10)
            .chartXAxis {
                AxisMarks(values: .automatic) { value in
                    if let date = value.as(Date.self) {
                        AxisValueLabel {
                            Text(date.formatted(date: .abbreviated, time: .omitted))
                                .font(.system(size: 10))
                                .foregroundColor(theme.secondaryText)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisValueLabel {
                        if let val = value.as(Double.self) {
                            Text(String(format: "%.0f", val))
                                .font(.system(size: 10))
                                .foregroundColor(theme.secondaryText)
                        }
                    }
                }
            }
            .frame(height: 300)
            .padding()
            .background(theme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: theme.radiusLarge))
        }
    }

    private var allMetricsChart: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("All Metrics Over Time")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(theme.primaryText)

            Chart {
                ForEach(MetricType.allCases.filter { $0 != .all }, id: \.self) { metric in
                    ForEach(sortedAnalyses, id: \.id) { analysis in
                        LineMark(
                            x: .value("Date", analysis.timestamp),
                            y: .value("Value", getMetricValue(for: analysis, metric: metric)),
                            series: .value("Metric", metric.rawValue)
                        )
                        .foregroundStyle(by: .value("Metric", metric.rawValue))
                        .lineStyle(StrokeStyle(lineWidth: 2))
                    }
                }
            }
            .chartYScale(domain: 0...10)
            .chartForegroundStyleScale([
                MetricType.hydration.rawValue: MetricType.hydration.color,
                MetricType.oiliness.rawValue: MetricType.oiliness.color,
                MetricType.texture.rawValue: MetricType.texture.color,
                MetricType.pores.rawValue: MetricType.pores.color,
                MetricType.wrinkles.rawValue: MetricType.wrinkles.color,
                MetricType.redness.rawValue: MetricType.redness.color,
                MetricType.darkSpots.rawValue: MetricType.darkSpots.color,
                MetricType.acne.rawValue: MetricType.acne.color
            ])
            .chartXAxis {
                AxisMarks(values: .automatic) { value in
                    if let date = value.as(Date.self) {
                        AxisValueLabel {
                            Text(date.formatted(date: .abbreviated, time: .omitted))
                                .font(.system(size: 10))
                                .foregroundColor(theme.secondaryText)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisValueLabel {
                        if let val = value.as(Double.self) {
                            Text(String(format: "%.0f", val))
                                .font(.system(size: 10))
                                .foregroundColor(theme.secondaryText)
                        }
                    }
                }
            }
            .frame(height: 350)
            .padding()
            .background(theme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: theme.radiusLarge))
        }
    }

    private var statisticsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Statistics")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(theme.primaryText)

            if selectedMetric == .all {
                // Show stats for all metrics
                VStack(spacing: 12) {
                    ForEach(MetricType.allCases.filter { $0 != .all }, id: \.self) { metric in
                        metricStatRow(metric: metric)
                    }
                }
            } else {
                // Show detailed stats for selected metric
                metricDetailedStats(metric: selectedMetric)
            }
        }
        .padding(20)
        .background(theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: theme.radiusLarge))
    }

    private func metricStatRow(metric: MetricType) -> some View {
        let values = sortedAnalyses.map { getMetricValue(for: $0, metric: metric) }
        let avg = values.reduce(0, +) / Double(values.count)
        let latest = values.last ?? 0
        let first = values.first ?? 0
        let change = latest - first

        return HStack {
            HStack(spacing: 8) {
                Image(systemName: metric.icon)
                    .foregroundColor(metric.color)
                Text(metric.rawValue)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(theme.primaryText)
            }

            Spacer()

            HStack(spacing: 16) {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Avg")
                        .font(.system(size: 10))
                        .foregroundColor(theme.secondaryText)
                    Text(String(format: "%.1f", avg))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(theme.primaryText)
                }

                VStack(alignment: .trailing, spacing: 2) {
                    Text("Change")
                        .font(.system(size: 10))
                        .foregroundColor(theme.secondaryText)
                    Text(change >= 0 ? "+\(String(format: "%.1f", change))" : String(format: "%.1f", change))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(change > 0 ? .green : (change < 0 ? .red : theme.secondaryText))
                }
            }
        }
        .padding()
        .background(theme.tertiaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: theme.radiusMedium))
    }

    private func metricDetailedStats(metric: MetricType) -> some View {
        let values = sortedAnalyses.map { getMetricValue(for: $0, metric: metric) }
        let avg = values.reduce(0, +) / Double(values.count)
        let min = values.min() ?? 0
        let max = values.max() ?? 0
        let latest = values.last ?? 0
        let first = values.first ?? 0
        let change = latest - first

        return VStack(spacing: 16) {
            HStack(spacing: 20) {
                statCard(title: "Average", value: String(format: "%.1f", avg), color: .cyan)
                statCard(title: "Minimum", value: String(format: "%.1f", min), color: .orange)
                statCard(title: "Maximum", value: String(format: "%.1f", max), color: .purple)
            }

            HStack(spacing: 20) {
                statCard(title: "Latest", value: String(format: "%.1f", latest), color: .green)
                statCard(title: "First", value: String(format: "%.1f", first), color: .blue)
                statCard(title: "Change", value: change >= 0 ? "+\(String(format: "%.1f", change))" : String(format: "%.1f", change), color: change > 0 ? .green : (change < 0 ? .red : .gray))
            }
        }
    }

    private func statCard(title: String, value: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(theme.secondaryText)
            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(theme.tertiaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: theme.radiusMedium))
    }

    private var exportButton: some View {
        Button(action: exportPDF) {
            HStack {
                Image(systemName: "square.and.arrow.up")
                Text("Export PDF with Trends")
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

    private func getMetricValue(for analysis: SkinAnalysis, metric: MetricType) -> Double {
        switch metric {
        case .hydration: return analysis.hydration
        case .oiliness: return analysis.oiliness
        case .texture: return analysis.texture
        case .pores: return analysis.pores
        case .wrinkles: return analysis.wrinkles
        case .redness: return analysis.redness
        case .darkSpots: return analysis.darkSpots
        case .acne: return analysis.acne
        case .all: return 0
        }
    }

    private func exportPDF() {
        isExporting = true

        Task {
            let pdfData = PDFExportManager.shared.generateTrendingPDF(client: client, analyses: sortedAnalyses)

            await MainActor.run {
                exportedPDF = pdfData
                isExporting = false
                showShareSheet = true
            }
        }
    }
}

