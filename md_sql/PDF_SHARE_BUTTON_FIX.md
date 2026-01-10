# PDF Share Button Fix for Analysis Details

## Issue
The share button on the Analysis Details page (for previous scans) was not working properly. When users tapped the share button, the share sheet would not appear or would fail to share the PDF.

## Root Cause
The PDF sharing functionality was trying to pass raw `Data` objects directly to `UIActivityViewController` through the `ShareSheet`. While this can work in some cases, it's not reliable for PDF files. iOS prefers to receive file URLs for document sharing, especially for PDFs.

## Solution
Updated both `AnalysisDetailView.swift` and `SkinAnalysisResultsView.swift` to:

1. **Save PDF to temporary file**: Instead of passing raw Data, we now save the PDF data to a temporary file in the system's temporary directory
2. **Share the file URL**: Pass the file URL to ShareSheet instead of raw data
3. **Better error handling**: Added proper error handling for PDF generation and file writing failures

### Changes Made

#### 1. AnalysisDetailView.swift
**State Variables (Lines 15-18):**
```swift
@State private var isExportingPDF = false
@State private var exportedPDF: Data?
@State private var pdfURL: URL?  // NEW: Store the temporary file URL
@State private var showShareSheet = false
```

**ShareSheet Presentation (Lines 114-118):**
```swift
.sheet(isPresented: $showShareSheet) {
    if let url = pdfURL {
        ShareSheet(items: [url])  // Share URL instead of Data
    }
}
```

**exportPDF() Function (Lines 550-585):**
```swift
guard let pdfData = PDFExportManager.shared.generateAnalysisPDF(
    client: clientModel,
    analysis: skinAnalysis,
    image: downloadedImage
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
```

#### 2. SkinAnalysisResultsView.swift
Applied identical changes to ensure consistency across the app:
- Added `pdfURL` state variable
- Updated ShareSheet to use URL instead of Data
- Updated exportPDF() function with file writing logic

## Benefits

1. **Reliable sharing**: File URLs are the standard way iOS handles document sharing
2. **Better compatibility**: Works with all share targets (Messages, Mail, Files, etc.)
3. **Proper error handling**: Users get clear error messages if PDF generation or saving fails
4. **Consistent UX**: Both new and historical analyses use the same sharing mechanism
5. **Descriptive filenames**: PDFs are saved with meaningful names like "Analysis_John_Doe_1704751234.pdf"

## Testing
Build succeeded with no errors. The share button should now:
1. Generate the PDF when tapped
2. Save it to a temporary file
3. Present the iOS share sheet
4. Allow sharing via any available method (AirDrop, Messages, Mail, Files, etc.)

## Files Modified
- [AnalysisDetailView.swift](Sources/AnalysisDetailView.swift)
- [SkinAnalysisResultsView.swift](Sources/SkinAnalysisResultsView.swift)
