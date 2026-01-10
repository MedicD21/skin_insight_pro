import SwiftUI
import PDFKit
import UIKit

struct PDFPreviewView: UIViewRepresentable {
    let data: Data

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        return pdfView
    }

    func updateUIView(_ pdfView: PDFView, context: Context) {
        pdfView.document = PDFDocument(data: data)
    }
}


#Preview {
    let client = Client(
        id: UUID().uuidString,
        name: "Preview Client",
        companyId: "preview-company",
        email: "preview@skininsightpro.com",
        phone: "555-555-5555",
        createdAt: Date()
    )

    let analysisData = AnalysisData(
        skinType: "Combination",
        hydrationLevel: 65,
        sensitivity: "Moderate",
        concerns: ["Redness", "Dehydrated Skin"],
        poreCondition: "Enlarged",
        skinHealthScore: 82,
        recommendations: ["Barrier repair", "Daily SPF"],
        productRecommendations: ["Gentle Cleanser", "SPF 30+"],
        medicalConsiderations: ["Avoid retinoids"],
        progressNotes: nil,
        analysisNotice: nil,
        oilinessScore: nil,
        textureScore: nil,
        poresScore: nil,
        wrinklesScore: nil,
        rednessScore: nil,
        darkSpotsScore: nil,
        acneScore: nil,
        sensitivityScore: nil,
        recommendedRoutine: nil
    )

    let data = PDFExportManager.shared.generateDetailedAnalysisPDF(
        client: client,
        analysisData: analysisData,
        image: UIImage(systemName: "person.crop.square"),
        notes: "Preview-only notes",
        productsUsed: "Hydrating Cleanser",
        treatmentsPerformed: "Hydrafacial",
        timestamp: Date()
    )

    return Group {
        if let data {
            PDFPreviewView(data: data)
        } else {
            Text("Failed to generate PDF")
        }
    }
}
