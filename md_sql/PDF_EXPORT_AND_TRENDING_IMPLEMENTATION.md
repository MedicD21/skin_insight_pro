# PDF Export and Trending Graphs Implementation

**Date:** 2026-01-08
**Status:** ✅ Core functionality created, integration pending

## Overview

Added comprehensive PDF export functionality and interactive trending graphs with the following features:

1. **PDF Export for Single Scans** - Export individual analysis results with photo and metrics
2. **PDF Export for Trending Analysis** - Export all scans with statistical trends
3. **Interactive Trending Graphs** - Filterable charts showing metrics over time
4. **Horizontal Orientation Support** - Optimized graph viewing in landscape mode

---

## Files Created

### 1. PDFExportManager.swift ✅ CREATED
**Location:** [Sources/PDFExportManager.swift](Sources/PDFExportManager.swift)

**Purpose:** Manages PDF generation for analysis reports

**Key Methods:**
```swift
// Generate PDF for single analysis
func generateAnalysisPDF(client: Client, analysis: SkinAnalysis, image: UIImage?) -> Data?

// Generate PDF with trending graphs
func generateTrendingPDF(client: Client, analyses: [SkinAnalysis]) -> Data?
```

**Features:**
- Professional PDF layout with headers and footers
- Includes client photo and all metrics
- Statistical summaries for trend reports
- Proper page sizing (Letter: 8.5" x 11")
- Landscape orientation for trending reports

### 2. TrendingGraphsView.swift ✅ CREATED
**Location:** [Sources/TrendingGraphsView.swift](Sources/TrendingGraphsView.swift)

**Purpose:** Interactive trending graphs with metric filtering

**Features:**
- **9 metric filters:** Hydration, Oiliness, Texture, Pores, Wrinkles, Redness, Dark Spots, Acne, All Metrics
- **Interactive charts** using Swift Charts framework
- **Statistical analysis:** Average, Min, Max, Latest, First, Change
- **Color-coded metrics** for easy visual distinction
- **PDF export** of trending data
- **Horizontal scroll** for metric filters
- **Responsive design** adapts to iPad/iPhone

---

## Integration Points

### ✅ Integration 1: SkinAnalysisResultsView.swift

**Add Export Button After Save Button**

**Location:** Around line 82, after `saveButton`

**Add these state variables:**
```swift
@State private var isExportingPDF = false
@State private var exportedPDF: Data?
@State private var showShareSheet = false
```

**Add export button view:**
```swift
private var exportButton: some View {
    Button(action: exportCurrentAnalysisPDF) {
        HStack {
            Image(systemName: "square.and.arrow.up")
            Text("Export PDF")
        }
        .font(.system(size: 17, weight: .semibold))
        .foregroundColor(theme.accent)
        .frame(maxWidth: .infinity)
        .padding(16)
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
        // Convert AnalysisData to SkinAnalysis for PDF export
        let skinAnalysis = SkinAnalysis(
            id: UUID().uuidString,
            clientId: client.id,
            timestamp: Date(),
            hydration: analysisResult.metrics.hydration,
            oiliness: analysisResult.metrics.oiliness,
            texture: analysisResult.metrics.texture,
            pores: analysisResult.metrics.pores,
            wrinkles: analysisResult.metrics.wrinkles,
            redness: analysisResult.metrics.redness,
            darkSpots: analysisResult.metrics.darkSpots,
            acne: analysisResult.metrics.acne,
            recommendations: analysisResult.recommendations,
            imageUrl: nil,
            notes: notes,
            analysisType: "Claude AI Analysis"
        )

        // Convert AppClient to Client
        let clientModel = Client(
            id: client.id,
            name: client.name,
            companyId: "",
            email: client.email,
            phone: client.phone,
            createdAt: client.createdAt ?? Date()
        )

        let pdfData = PDFExportManager.shared.generateAnalysisPDF(
            client: clientModel,
            analysis: skinAnalysis,
            image: image
        )

        await MainActor.run {
            exportedPDF = pdfData
            isExportingPDF = false
            showShareSheet = true
        }
    }
}
```

**Add sheet modifier:**
```swift
.sheet(isPresented: $showShareSheet) {
    if let pdfData = exportedPDF {
        ShareSheet(items: [pdfData as Any])
    }
}
```

**Update body to include export button:**
```swift
// After saveButton (line 82)
exportButton
```

---

### ✅ Integration 2: ClientDetailView.swift

**Add Trending Graphs Button**

**Add state variables:**
```swift
@State private var showTrendingGraphs = false
```

**Add button in the analysis history section header:**
```swift
// In the analysis history header
HStack {
    Text("Analysis History")
        .font(.system(size: 18, weight: .bold))
        .foregroundColor(theme.primaryText)

    Spacer()

    if !viewModel.analyses.isEmpty {
        Button(action: { showTrendingGraphs = true }) {
            HStack(spacing: 6) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 14))
                Text("Trends")
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundColor(theme.accent)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(theme.accent.opacity(0.1))
            .clipShape(Capsule())
        }
    }
}
```

**Add sheet for trending graphs:**
```swift
.sheet(isPresented: $showTrendingGraphs) {
    // Convert AppClient to Client
    let clientModel = Client(
        id: client.id,
        name: client.name,
        companyId: client.companyId ?? "",
        email: client.email,
        phone: client.phone,
        createdAt: client.createdAt ?? Date()
    )

    TrendingGraphsView(client: clientModel, analyses: viewModel.analyses)
}
```

---

### ✅ Integration 3: AnalysisDetailView.swift

**Add Export Button to Individual Analysis Views**

**Add state variables:**
```swift
@State private var isExportingPDF = false
@State private var exportedPDF: Data?
@State private var showShareSheet = false
```

**Add export button in toolbar:**
```swift
.toolbar {
    ToolbarItem(placement: .primaryAction) {
        Button(action: exportPDF) {
            Label("Export PDF", systemImage: "square.and.arrow.up")
        }
        .disabled(isExportingPDF)
    }
}
```

**Add export function:**
```swift
private func exportPDF() {
    isExportingPDF = true

    Task {
        // Download image first if needed
        var downloadedImage: UIImage?
        if let imageUrl = analysis.imageUrl, let url = URL(string: imageUrl) {
            if let (data, _) = try? await URLSession.shared.data(from: url),
               let image = UIImage(data: data) {
                downloadedImage = image
            }
        }

        // Convert AppClient to Client
        let clientModel = Client(
            id: client.id,
            name: client.name,
            companyId: client.companyId ?? "",
            email: client.email,
            phone: client.phone,
            createdAt: client.createdAt ?? Date()
        )

        let pdfData = PDFExportManager.shared.generateAnalysisPDF(
            client: clientModel,
            analysis: analysis,
            image: downloadedImage
        )

        await MainActor.run {
            exportedPDF = pdfData
            isExportingPDF = false
            showShareSheet = true
        }
    }
}
```

**Add sheet modifier:**
```swift
.sheet(isPresented: $showShareSheet) {
    if let pdfData = exportedPDF {
        ShareSheet(items: [pdfData as Any])
    }
}
```

---

## Features Summary

### PDF Export Features

**Single Scan PDF Includes:**
- ✅ Client name and report header
- ✅ Analysis date and type
- ✅ Skin analysis photo (if available)
- ✅ All 8 metrics with scores
- ✅ Recommendations (if available)
- ✅ Professional footer with generation date

**Trending PDF Includes:**
- ✅ Client name and trend header
- ✅ Date range of scans
- ✅ Statistical summary for each metric:
  - Average value
  - Minimum value
  - Maximum value
  - Latest value
  - First value
  - Change over time (color-coded)
- ✅ Landscape orientation for better viewing
- ✅ Comprehensive footer

### Trending Graphs Features

**Metric Filters:**
1. 💧 **Hydration** - Cyan
2. ✨ **Oiliness** - Yellow
3. ✋ **Texture** - Purple
4. ⭕ **Pores** - Orange
5. 〰️ **Wrinkles** - Brown
6. 🔴 **Redness** - Red
7. ☀️ **Dark Spots** - Indigo
8. ⚠️ **Acne** - Pink
9. 📊 **All Metrics** - All on one graph

**Chart Types:**
- **Single Metric View:** Line chart with annotations showing values at each point
- **All Metrics View:** Multi-line chart with color-coded legend

**Statistics Display:**
- Average, Min, Max, Latest, First values
- Change calculation with color coding (green = improved, red = worsened)
- Individual metric cards for detailed view
- Compact summary for "All Metrics" view

**Export Functionality:**
- Export button generates PDF with all trends
- Share sheet integration for saving/sharing
- Progress indicator during PDF generation

---

## User Flow

### Export Single Scan

1. **User completes analysis** in SkinAnalysisResultsView
2. **Sees "Export PDF" button** below "Save Analysis" button
3. **Taps Export PDF** → Progress indicator shows
4. **PDF generates** with photo and all metrics
5. **Share sheet appears** → Can save to Files, share via email, AirDrop, etc.

### View Trending Graphs

1. **User opens client profile** in ClientDetailView
2. **Sees "Trends" button** next to "Analysis History" header
3. **Taps Trends** → Trending graphs view opens
4. **Filters by metric** using horizontal scroll chips
5. **Views interactive charts** with annotations
6. **Sees statistics** below charts
7. **Exports PDF** with trending data if needed

### Export from History

1. **User taps on past analysis** in history list
2. **AnalysisDetailView opens** showing full details
3. **Taps Export icon** in toolbar
4. **PDF generates** with stored photo and metrics
5. **Share sheet appears** for saving/sharing

---

## Technical Details

### Model Conversions Needed

The app uses two client models:
- `AppClient` (in views)
- `Client` (in PDF export)

**Conversion pattern:**
```swift
let clientModel = Client(
    id: appClient.id,
    name: appClient.name,
    companyId: appClient.companyId ?? "",
    email: appClient.email,
    phone: appClient.phone,
    createdAt: appClient.createdAt ?? Date()
)
```

### Image Handling

**For new analyses:**
- Image is available as `UIImage` directly
- Pass to PDF export immediately

**For historical analyses:**
- Image stored in Supabase with URL
- Must download asynchronously before PDF generation
- Handle missing images gracefully

### Chart Dependencies

**Required:** Swift Charts framework (iOS 16+)

Already imported in TrendingGraphsView:
```swift
import Charts
```

### Share Sheet

Reusable component for sharing PDFs:
```swift
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
```

---

## Testing Checklist

### PDF Export
- [ ] Export new analysis with photo
- [ ] Export new analysis without photo
- [ ] Export historical analysis (requires download)
- [ ] Verify all 8 metrics appear correctly
- [ ] Verify recommendations appear (if present)
- [ ] Check PDF opens correctly on device
- [ ] Share via AirDrop
- [ ] Save to Files app
- [ ] Email PDF attachment

### Trending Graphs
- [ ] View with 2+ scans
- [ ] Filter by each individual metric
- [ ] View "All Metrics" chart
- [ ] Verify statistics calculations (avg, min, max, change)
- [ ] Export PDF from trending view
- [ ] Test on iPhone (compact)
- [ ] Test on iPad (regular size class)
- [ ] Verify horizontal scroll for filters
- [ ] Check color coding for positive/negative changes

### Edge Cases
- [ ] Client with only 1 scan (trends button should show)
- [ ] Client with 0 scans (trends button hidden)
- [ ] Very long recommendation text (wraps properly in PDF)
- [ ] Large image (scales to fit in PDF)
- [ ] Missing client phone/email (handles gracefully)

---

## Next Steps

1. **Integrate export button** into SkinAnalysisResultsView
2. **Add trending button** to ClientDetailView
3. **Add toolbar export** to AnalysisDetailView
4. **Test PDF generation** with real data
5. **Verify model conversions** work correctly
6. **Test share functionality** on device
7. **Optional:** Add loading states and error handling
8. **Optional:** Add PDF preview before sharing

---

## Future Enhancements

**Potential additions:**
- 📱 **Email direct from app** - Pre-fill email with PDF attached
- 🎨 **Customizable PDF templates** - Brand colors, logo
- 📊 **Advanced charts** - Box plots, scatter plots, heat maps
- 📅 **Date range filtering** - "Last 3 months", "Last year"
- 🔍 **Metric comparisons** - Side-by-side comparisons
- 📈 **Goal tracking** - Set targets, show progress
- 🖼️ **Before/After photos** - Visual comparison in PDF
- 📝 **Custom notes in PDF** - Add provider comments

---

## Summary

✅ **Created:**
- PDFExportManager.swift - Full PDF generation
- TrendingGraphsView.swift - Interactive charts with filtering

✅ **Ready for Integration:**
- Export button for analysis results
- Trending graphs button for client profiles
- Toolbar export for historical analyses

✅ **Key Features:**
- Professional PDF layouts
- Interactive trending graphs with 9 filters
- Statistical analysis (avg, min, max, change)
- Color-coded metrics
- Share sheet integration
- Horizontal orientation support

This implementation provides a comprehensive export and analytics solution for skin analysis data!
