import SwiftUI
import UIKit

#if DEBUG
struct PDFExportPreview: View {

    let pdfData: Data?

    init() {
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



        pdfData = PDFExportManager.shared.generateDetailedAnalysisPDF(
            client: client,
            analysisData: analysisData,
            image: UIImage(systemName: "person.crop.square"),
            notes: "Preview-only notes",
            productsUsed: "Hydrating Cleanser",
            treatmentsPerformed: "Hydrafacial",
            timestamp: Date()
        )
    }

    var body: some View {
        if let pdfData {
            PDFPreviewView(data: pdfData)
        } else {
            Text("Failed to generate PDF")
        }
    }
}

#Preview("PDF Export Preview") {
    PDFExportPreview()
}
#endif
