import UIKit
import PDFKit

/// Manages PDF generation for skin analysis reports
class PDFExportManager {
    static let shared = PDFExportManager()

    private init() {}

    /// Generate PDF for a single skin analysis (legacy method for trending)
    func generateAnalysisPDF(client: Client, analysis: SkinAnalysis, image: UIImage?) -> Data? {
        // This is kept for backward compatibility with trending PDF
        return generateBasicAnalysisPDF(client: client, analysis: analysis, image: image)
    }

    /// Generate PDF with full analysis details
    func generateDetailedAnalysisPDF(
        client: Client,
        analysisData: AnalysisData,
        image: UIImage?,
        notes: String?,
        productsUsed: String?,
        treatmentsPerformed: String?,
        timestamp: Date
    ) -> Data? {
        let pdfMetaData = [
            kCGPDFContextCreator: "SkinInsight Pro",
            kCGPDFContextAuthor: "SkinInsight Pro",
            kCGPDFContextTitle: "Skin Analysis Report - \(client.name)"
        ]
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData as [String: Any]

        // Letter size: 8.5" x 11" at 72 DPI
        let pageWidth: CGFloat = 8.5 * 72.0
        let pageHeight: CGFloat = 11.0 * 72.0
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        let margin: CGFloat = 40

        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)

        let data = renderer.pdfData { context in
            context.beginPage()
            let cgContext = context.cgContext
            var yPosition: CGFloat = margin

            // Draw header with background
            cgContext.setFillColor(UIColor.systemCyan.cgColor)
            cgContext.fill(CGRect(x: 0, y: 0, width: pageWidth, height: 80))

            let headerAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 28, weight: .bold),
                .foregroundColor: UIColor.white
            ]
            "SkinInsight Pro".draw(at: CGPoint(x: margin, y: 25), withAttributes: headerAttributes)

            let subtitleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 14, weight: .medium),
                .foregroundColor: UIColor.white.withAlphaComponent(0.9)
            ]
            "Skin Analysis Report".draw(at: CGPoint(x: margin, y: 52), withAttributes: subtitleAttributes)

            yPosition = 100

            // Client name
            let clientNameAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 20, weight: .semibold),
                .foregroundColor: UIColor.black
            ]
            "Client: \(client.name)".draw(at: CGPoint(x: margin, y: yPosition), withAttributes: clientNameAttributes)
            yPosition += 35

            // Analysis date
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .long
            dateFormatter.timeStyle = .short

            let dateAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12, weight: .medium),
                .foregroundColor: UIColor.darkGray
            ]
            "Date: \(dateFormatter.string(from: timestamp))".draw(at: CGPoint(x: margin, y: yPosition), withAttributes: dateAttributes)
            yPosition += 25

            // Divider line
            cgContext.setStrokeColor(UIColor.lightGray.cgColor)
            cgContext.setLineWidth(1)
            cgContext.move(to: CGPoint(x: margin, y: yPosition))
            cgContext.addLine(to: CGPoint(x: pageWidth - margin, y: yPosition))
            cgContext.strokePath()
            yPosition += 25

            // Draw image if available
            if let image = image {
                let maxImageWidth: CGFloat = pageWidth - (margin * 2)
                let maxImageHeight: CGFloat = 180

                let imageSize = image.size
                let aspectRatio = imageSize.width / imageSize.height

                var drawWidth = maxImageWidth
                var drawHeight = drawWidth / aspectRatio

                if drawHeight > maxImageHeight {
                    drawHeight = maxImageHeight
                    drawWidth = drawHeight * aspectRatio
                }

                let imageX = (pageWidth - drawWidth) / 2
                let imageRect = CGRect(x: imageX, y: yPosition, width: drawWidth, height: drawHeight)

                cgContext.setStrokeColor(UIColor.lightGray.cgColor)
                cgContext.setLineWidth(1)
                cgContext.stroke(imageRect)

                image.draw(in: imageRect)
                yPosition += drawHeight + 25
            }

            let sectionTitleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 16, weight: .bold),
                .foregroundColor: UIColor.black
            ]
            let metricLabelAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12, weight: .semibold),
                .foregroundColor: UIColor.black
            ]
            let metricValueAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12, weight: .regular),
                .foregroundColor: UIColor.darkGray
            ]

            // Check if we need a new page
            func checkNewPage() {
                if yPosition > pageHeight - 100 {
                    context.beginPage()
                    yPosition = margin
                }
            }

            // Analysis Overview
            checkNewPage()
            "Analysis Overview".draw(at: CGPoint(x: margin, y: yPosition), withAttributes: sectionTitleAttributes)
            yPosition += 25

            if let skinType = analysisData.skinType {
                "Skin Type:".draw(at: CGPoint(x: margin, y: yPosition), withAttributes: metricLabelAttributes)
                skinType.capitalized.draw(at: CGPoint(x: margin + 150, y: yPosition), withAttributes: metricValueAttributes)
                yPosition += 20
            }

            if let hydration = analysisData.hydrationLevel {
                "Hydration Level:".draw(at: CGPoint(x: margin, y: yPosition), withAttributes: metricLabelAttributes)
                "\(hydration)%".draw(at: CGPoint(x: margin + 150, y: yPosition), withAttributes: metricValueAttributes)
                yPosition += 20
            }

            if let sensitivity = analysisData.sensitivity {
                "Sensitivity:".draw(at: CGPoint(x: margin, y: yPosition), withAttributes: metricLabelAttributes)
                sensitivity.capitalized.draw(at: CGPoint(x: margin + 150, y: yPosition), withAttributes: metricValueAttributes)
                yPosition += 20
            }

            if let poreCondition = analysisData.poreCondition {
                "Pore Condition:".draw(at: CGPoint(x: margin, y: yPosition), withAttributes: metricLabelAttributes)
                poreCondition.capitalized.draw(at: CGPoint(x: margin + 150, y: yPosition), withAttributes: metricValueAttributes)
                yPosition += 20
            }

            if let score = analysisData.skinHealthScore {
                "Skin Health Score:".draw(at: CGPoint(x: margin, y: yPosition), withAttributes: metricLabelAttributes)
                "\(score)/100".draw(at: CGPoint(x: margin + 150, y: yPosition), withAttributes: metricValueAttributes)
                yPosition += 20
            }

            yPosition += 15

            // Concerns Section
            if let concerns = analysisData.concerns, !concerns.isEmpty {
                checkNewPage()
                "Skin Concerns".draw(at: CGPoint(x: margin, y: yPosition), withAttributes: sectionTitleAttributes)
                yPosition += 25

                let bulletAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 12, weight: .regular),
                    .foregroundColor: UIColor.black
                ]

                for concern in concerns {
                    "• \(concern.capitalized)".draw(at: CGPoint(x: margin + 10, y: yPosition), withAttributes: bulletAttributes)
                    yPosition += 18
                }

                yPosition += 15
            }

            // Medical Considerations
            if let medicalConsiderations = analysisData.medicalConsiderations, !medicalConsiderations.isEmpty {
                checkNewPage()
                "Medical Considerations".draw(at: CGPoint(x: margin, y: yPosition), withAttributes: sectionTitleAttributes)
                yPosition += 25

                let medicalAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 11, weight: .regular),
                    .foregroundColor: UIColor.black
                ]

                for consideration in medicalConsiderations {
                    let textWidth = pageWidth - (margin * 2) - 20
                    let text = "• \(consideration)"
                    let textRect = CGRect(x: margin + 10, y: yPosition, width: textWidth, height: 1000)
                    let boundingRect = (text as NSString).boundingRect(
                        with: CGSize(width: textWidth, height: CGFloat.greatestFiniteMagnitude),
                        options: [.usesLineFragmentOrigin],
                        attributes: medicalAttributes,
                        context: nil
                    )

                    text.draw(in: textRect, withAttributes: medicalAttributes)
                    yPosition += boundingRect.height + 8
                }

                yPosition += 15
            }

            // Recommendations Section
            if let recommendations = analysisData.recommendations, !recommendations.isEmpty {
                checkNewPage()
                "Recommendations".draw(at: CGPoint(x: margin, y: yPosition), withAttributes: sectionTitleAttributes)
                yPosition += 25

                let recAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 11, weight: .regular),
                    .foregroundColor: UIColor.black
                ]

                for (index, recommendation) in recommendations.enumerated() {
                    checkNewPage()
                    let textWidth = pageWidth - (margin * 2) - 30
                    let text = "\(index + 1). \(recommendation)"
                    let textRect = CGRect(x: margin + 10, y: yPosition, width: textWidth, height: 1000)
                    let boundingRect = (text as NSString).boundingRect(
                        with: CGSize(width: textWidth, height: CGFloat.greatestFiniteMagnitude),
                        options: [.usesLineFragmentOrigin],
                        attributes: recAttributes,
                        context: nil
                    )

                    text.draw(in: textRect, withAttributes: recAttributes)
                    yPosition += boundingRect.height + 8
                }

                yPosition += 15
            }

            // Product Recommendations
            if let productRecs = analysisData.productRecommendations, !productRecs.isEmpty {
                checkNewPage()
                "Product Recommendations".draw(at: CGPoint(x: margin, y: yPosition), withAttributes: sectionTitleAttributes)
                yPosition += 25

                let productAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 11, weight: .regular),
                    .foregroundColor: UIColor.black
                ]

                for (index, product) in productRecs.enumerated() {
                    checkNewPage()
                    let textWidth = pageWidth - (margin * 2) - 30
                    let text = "\(index + 1). \(product)"
                    let textRect = CGRect(x: margin + 10, y: yPosition, width: textWidth, height: 1000)
                    let boundingRect = (text as NSString).boundingRect(
                        with: CGSize(width: textWidth, height: CGFloat.greatestFiniteMagnitude),
                        options: [.usesLineFragmentOrigin],
                        attributes: productAttributes,
                        context: nil
                    )

                    text.draw(in: textRect, withAttributes: productAttributes)
                    yPosition += boundingRect.height + 8
                }

                yPosition += 15
            }

            // Products Used
            if let products = productsUsed, !products.isEmpty {
                checkNewPage()
                "Products Used".draw(at: CGPoint(x: margin, y: yPosition), withAttributes: sectionTitleAttributes)
                yPosition += 25

                let textAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 11, weight: .regular),
                    .foregroundColor: UIColor.black
                ]

                let textWidth = pageWidth - (margin * 2)
                let textRect = CGRect(x: margin, y: yPosition, width: textWidth, height: 1000)
                let boundingRect = (products as NSString).boundingRect(
                    with: CGSize(width: textWidth, height: CGFloat.greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin],
                    attributes: textAttributes,
                    context: nil
                )

                products.draw(in: textRect, withAttributes: textAttributes)
                yPosition += boundingRect.height + 15
            }

            // Treatments Performed
            if let treatments = treatmentsPerformed, !treatments.isEmpty {
                checkNewPage()
                "Treatments Performed".draw(at: CGPoint(x: margin, y: yPosition), withAttributes: sectionTitleAttributes)
                yPosition += 25

                let textAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 11, weight: .regular),
                    .foregroundColor: UIColor.black
                ]

                let textWidth = pageWidth - (margin * 2)
                let textRect = CGRect(x: margin, y: yPosition, width: textWidth, height: 1000)
                let boundingRect = (treatments as NSString).boundingRect(
                    with: CGSize(width: textWidth, height: CGFloat.greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin],
                    attributes: textAttributes,
                    context: nil
                )

                treatments.draw(in: textRect, withAttributes: textAttributes)
                yPosition += boundingRect.height + 15
            }

            // Notes Section
            if let notes = notes, !notes.isEmpty {
                checkNewPage()
                "Notes".draw(at: CGPoint(x: margin, y: yPosition), withAttributes: sectionTitleAttributes)
                yPosition += 25

                let notesAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 11, weight: .regular),
                    .foregroundColor: UIColor.black
                ]

                let textWidth = pageWidth - (margin * 2)
                let textRect = CGRect(x: margin, y: yPosition, width: textWidth, height: 1000)
                let boundingRect = (notes as NSString).boundingRect(
                    with: CGSize(width: textWidth, height: CGFloat.greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin],
                    attributes: notesAttributes,
                    context: nil
                )

                notes.draw(in: textRect, withAttributes: notesAttributes)
                yPosition += boundingRect.height
            }

            // Footer on last page
            let footerY = pageHeight - 50

            cgContext.setStrokeColor(UIColor.lightGray.cgColor)
            cgContext.setLineWidth(1)
            cgContext.move(to: CGPoint(x: margin, y: footerY))
            cgContext.addLine(to: CGPoint(x: pageWidth - margin, y: footerY))
            cgContext.strokePath()

            let footerAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 9, weight: .regular),
                .foregroundColor: UIColor.darkGray
            ]

            let footerFormatter = DateFormatter()
            footerFormatter.dateStyle = .long
            let footerText = "Generated by SkinInsight Pro on \(footerFormatter.string(from: Date()))"
            footerText.draw(at: CGPoint(x: margin, y: footerY + 10), withAttributes: footerAttributes)

            "This report is confidential and intended for professional use only.".draw(
                at: CGPoint(x: margin, y: footerY + 25),
                withAttributes: footerAttributes
            )
        }

        return data
    }

    /// Generate a PDF for a recommended morning/evening routine
    func generateRoutinePDF(client: Client, routine: SkinCareRoutine) -> Data? {
        let pdfMetaData = [
            kCGPDFContextCreator: "SkinInsight Pro",
            kCGPDFContextAuthor: "SkinInsight Pro",
            kCGPDFContextTitle: "Recommended Routine - \(client.name)"
        ]
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData as [String: Any]

        let pageWidth: CGFloat = 8.5 * 72.0
        let pageHeight: CGFloat = 11.0 * 72.0
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        let margin: CGFloat = 40

        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)

        let data = renderer.pdfData { context in
            context.beginPage()
            let cgContext = context.cgContext
            var yPosition: CGFloat = margin

            cgContext.setFillColor(UIColor.systemTeal.cgColor)
            cgContext.fill(CGRect(x: 0, y: 0, width: pageWidth, height: 80))

            let headerAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 26, weight: .bold),
                .foregroundColor: UIColor.white
            ]
            "Recommended Routine".draw(at: CGPoint(x: margin, y: 26), withAttributes: headerAttributes)

            let subtitleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 13, weight: .medium),
                .foregroundColor: UIColor.white.withAlphaComponent(0.9)
            ]
            "Personalized morning and evening steps".draw(at: CGPoint(x: margin, y: 54), withAttributes: subtitleAttributes)

            yPosition = 100

            let clientNameAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 18, weight: .semibold),
                .foregroundColor: UIColor.black
            ]
            "Client: \(client.name)".draw(at: CGPoint(x: margin, y: yPosition), withAttributes: clientNameAttributes)
            yPosition += 26

            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .long
            dateFormatter.timeStyle = .short

            let dateAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 11, weight: .medium),
                .foregroundColor: UIColor.darkGray
            ]
            "Generated: \(dateFormatter.string(from: Date()))".draw(at: CGPoint(x: margin, y: yPosition), withAttributes: dateAttributes)
            yPosition += 22

            cgContext.setStrokeColor(UIColor.lightGray.cgColor)
            cgContext.setLineWidth(1)
            cgContext.move(to: CGPoint(x: margin, y: yPosition))
            cgContext.addLine(to: CGPoint(x: pageWidth - margin, y: yPosition))
            cgContext.strokePath()
            yPosition += 20

            let sectionTitleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 16, weight: .bold),
                .foregroundColor: UIColor.black
            ]
            let stepTitleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12, weight: .semibold),
                .foregroundColor: UIColor.black
            ]
            let detailAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 11, weight: .regular),
                .foregroundColor: UIColor.darkGray
            ]
            let bodyAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 11, weight: .regular),
                .foregroundColor: UIColor.black
            ]

            func checkNewPage() {
                if yPosition > pageHeight - 120 {
                    context.beginPage()
                    yPosition = margin
                }
            }

            func drawWrappedText(_ text: String, attributes: [NSAttributedString.Key: Any], indent: CGFloat = 0, spacing: CGFloat = 6) {
                let textWidth = pageWidth - (margin * 2) - indent
                let textRect = CGRect(x: margin + indent, y: yPosition, width: textWidth, height: 1000)
                let boundingRect = (text as NSString).boundingRect(
                    with: CGSize(width: textWidth, height: CGFloat.greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin],
                    attributes: attributes,
                    context: nil
                )
                (text as NSString).draw(in: textRect, withAttributes: attributes)
                yPosition += boundingRect.height + spacing
            }

            func drawRoutineSection(title: String, steps: [RoutineStep]) {
                checkNewPage()
                title.draw(at: CGPoint(x: margin, y: yPosition), withAttributes: sectionTitleAttributes)
                yPosition += 22

                if steps.isEmpty {
                    drawWrappedText("No steps provided.", attributes: detailAttributes, indent: 10)
                    yPosition += 10
                    return
                }

                for (index, step) in steps.enumerated() {
                    checkNewPage()
                    let stepNumber = step.stepNumber > 0 ? step.stepNumber : index + 1
                    let stepTitle = "\(stepNumber). \(step.productName)"
                    drawWrappedText(stepTitle, attributes: stepTitleAttributes)

                    var details: [String] = []
                    if let amount = step.amount, !amount.isEmpty {
                        details.append("Amount: \(amount)")
                    }
                    if let frequency = step.frequency, !frequency.isEmpty {
                        details.append("Frequency: \(frequency)")
                    }
                    if let waitTime = step.waitTime, waitTime > 0 {
                        details.append("Wait: \(waitTime)s")
                    }
                    if !details.isEmpty {
                        drawWrappedText(details.joined(separator: " • "), attributes: detailAttributes, indent: 12, spacing: 4)
                    }
                    if let instructions = step.instructions, !instructions.isEmpty {
                        drawWrappedText(instructions, attributes: bodyAttributes, indent: 12)
                    }
                    yPosition += 6
                }
                yPosition += 10
            }

            drawRoutineSection(title: "Morning Routine", steps: routine.morningSteps)
            drawRoutineSection(title: "Evening Routine", steps: routine.eveningSteps)

            if let notes = routine.notes, !notes.isEmpty {
                checkNewPage()
                "Routine Tips".draw(at: CGPoint(x: margin, y: yPosition), withAttributes: sectionTitleAttributes)
                yPosition += 22
                drawWrappedText(notes, attributes: bodyAttributes)
            }

            let footerY = pageHeight - 50
            cgContext.setStrokeColor(UIColor.lightGray.cgColor)
            cgContext.setLineWidth(1)
            cgContext.move(to: CGPoint(x: margin, y: footerY))
            cgContext.addLine(to: CGPoint(x: pageWidth - margin, y: footerY))
            cgContext.strokePath()

            let footerAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 9, weight: .regular),
                .foregroundColor: UIColor.darkGray
            ]

            let footerText = "Generated by SkinInsight Pro on \(dateFormatter.string(from: Date()))"
            footerText.draw(at: CGPoint(x: margin, y: footerY + 10), withAttributes: footerAttributes)
            "Routine guidance only. Adjust based on professional assessment.".draw(
                at: CGPoint(x: margin, y: footerY + 25),
                withAttributes: footerAttributes
            )
        }

        return data
    }

    /// Generate basic PDF (used for trending and backward compatibility)
    private func generateBasicAnalysisPDF(client: Client, analysis: SkinAnalysis, image: UIImage?) -> Data? {
        let pdfMetaData = [
            kCGPDFContextCreator: "SkinInsight Pro",
            kCGPDFContextAuthor: "SkinInsight Pro",
            kCGPDFContextTitle: "Skin Analysis Report - \(client.name)"
        ]
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData as [String: Any]

        // Letter size: 8.5" x 11" at 72 DPI
        let pageWidth: CGFloat = 8.5 * 72.0
        let pageHeight: CGFloat = 11.0 * 72.0
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        let margin: CGFloat = 40

        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)

        let data = renderer.pdfData { context in
            context.beginPage()
            let cgContext = context.cgContext

            var yPosition: CGFloat = margin

            // Draw header with background
            cgContext.setFillColor(UIColor.systemCyan.cgColor)
            cgContext.fill(CGRect(x: 0, y: 0, width: pageWidth, height: 80))

            let headerAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 28, weight: .bold),
                .foregroundColor: UIColor.white
            ]
            "SkinInsight Pro".draw(at: CGPoint(x: margin, y: 25), withAttributes: headerAttributes)

            let subtitleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 14, weight: .medium),
                .foregroundColor: UIColor.white.withAlphaComponent(0.9)
            ]
            "Skin Analysis Report".draw(at: CGPoint(x: margin, y: 52), withAttributes: subtitleAttributes)

            yPosition = 100

            // Client name
            let clientNameAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 20, weight: .semibold),
                .foregroundColor: UIColor.black
            ]
            "Client: \(client.name)".draw(at: CGPoint(x: margin, y: yPosition), withAttributes: clientNameAttributes)
            yPosition += 35

            // Analysis date
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .long
            dateFormatter.timeStyle = .short

            let dateAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12, weight: .medium),
                .foregroundColor: UIColor.darkGray
            ]
            "Date: \(dateFormatter.string(from: analysis.timestamp))".draw(at: CGPoint(x: margin, y: yPosition), withAttributes: dateAttributes)
            yPosition += 25

            // Divider line
            cgContext.setStrokeColor(UIColor.lightGray.cgColor)
            cgContext.setLineWidth(1)
            cgContext.move(to: CGPoint(x: margin, y: yPosition))
            cgContext.addLine(to: CGPoint(x: pageWidth - margin, y: yPosition))
            cgContext.strokePath()
            yPosition += 25

            // Draw image if available
            if let image = image {
                let maxImageWidth: CGFloat = pageWidth - (margin * 2)
                let maxImageHeight: CGFloat = 200

                let imageSize = image.size
                let aspectRatio = imageSize.width / imageSize.height

                var drawWidth = maxImageWidth
                var drawHeight = drawWidth / aspectRatio

                if drawHeight > maxImageHeight {
                    drawHeight = maxImageHeight
                    drawWidth = drawHeight * aspectRatio
                }

                let imageX = (pageWidth - drawWidth) / 2
                let imageRect = CGRect(x: imageX, y: yPosition, width: drawWidth, height: drawHeight)

                // Draw border around image
                cgContext.setStrokeColor(UIColor.lightGray.cgColor)
                cgContext.setLineWidth(1)
                cgContext.stroke(imageRect)

                image.draw(in: imageRect)
                yPosition += drawHeight + 30
            }

            // Analysis Results Section
            let sectionTitleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 16, weight: .bold),
                .foregroundColor: UIColor.black
            ]
            "Analysis Results".draw(at: CGPoint(x: margin, y: yPosition), withAttributes: sectionTitleAttributes)
            yPosition += 25

            // Metrics - only show hydration if we have it
            let metricLabelAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 13, weight: .semibold),
                .foregroundColor: UIColor.black
            ]
            let metricValueAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 13, weight: .regular),
                .foregroundColor: UIColor.darkGray
            ]

            if analysis.hydration > 0 {
                "Hydration Level:".draw(at: CGPoint(x: margin, y: yPosition), withAttributes: metricLabelAttributes)
                let valueText = String(format: "%.0f%%", analysis.hydration)
                valueText.draw(at: CGPoint(x: margin + 150, y: yPosition), withAttributes: metricValueAttributes)
                yPosition += 20
            }

            yPosition += 10

            // Recommendations Section
            if let recommendations = analysis.recommendations, !recommendations.isEmpty {
                yPosition += 10

                "Recommendations".draw(at: CGPoint(x: margin, y: yPosition), withAttributes: sectionTitleAttributes)
                yPosition += 25

                let paragraphStyle = NSMutableParagraphStyle()
                paragraphStyle.lineSpacing = 6
                paragraphStyle.alignment = .left

                let recAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 12, weight: .regular),
                    .foregroundColor: UIColor.black,
                    .paragraphStyle: paragraphStyle
                ]

                let textWidth = pageWidth - (margin * 2)
                let recText = NSAttributedString(string: recommendations, attributes: recAttributes)
                let textRect = CGRect(x: margin, y: yPosition, width: textWidth, height: pageHeight - yPosition - 80)
                recText.draw(in: textRect)

                let textHeight = recText.boundingRect(
                    with: CGSize(width: textWidth, height: CGFloat.greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin],
                    context: nil
                ).height
                yPosition += textHeight + 20
            }

            // Notes Section
            if let notes = analysis.notes, !notes.isEmpty {
                yPosition += 10

                if yPosition > pageHeight - 150 {
                    context.beginPage()
                    yPosition = margin
                }

                "Notes".draw(at: CGPoint(x: margin, y: yPosition), withAttributes: sectionTitleAttributes)
                yPosition += 25

                let paragraphStyle = NSMutableParagraphStyle()
                paragraphStyle.lineSpacing = 6

                let notesAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 12, weight: .regular),
                    .foregroundColor: UIColor.black,
                    .paragraphStyle: paragraphStyle
                ]

                let textWidth = pageWidth - (margin * 2)
                let notesText = NSAttributedString(string: notes, attributes: notesAttributes)
                let textRect = CGRect(x: margin, y: yPosition, width: textWidth, height: pageHeight - yPosition - 80)
                notesText.draw(in: textRect)
            }

            // Footer
            let footerY = pageHeight - 50

            cgContext.setStrokeColor(UIColor.lightGray.cgColor)
            cgContext.setLineWidth(1)
            cgContext.move(to: CGPoint(x: margin, y: footerY))
            cgContext.addLine(to: CGPoint(x: pageWidth - margin, y: footerY))
            cgContext.strokePath()

            let footerAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 9, weight: .regular),
                .foregroundColor: UIColor.darkGray
            ]

            let footerFormatter = DateFormatter()
            footerFormatter.dateStyle = .long
            let footerText = "Generated by SkinInsight Pro on \(footerFormatter.string(from: Date()))"
            footerText.draw(at: CGPoint(x: margin, y: footerY + 10), withAttributes: footerAttributes)

            "This report is confidential and intended for professional use only.".draw(
                at: CGPoint(x: margin, y: footerY + 25),
                withAttributes: footerAttributes
            )
        }

        return data
    }

    /// Generate PDF with trending graphs for all client scans
    func generateTrendingPDF(client: Client, analyses: [SkinAnalysis]) -> Data? {
        guard !analyses.isEmpty else { return nil }

        let pdfMetaData = [
            kCGPDFContextCreator: "SkinInsight Pro",
            kCGPDFContextAuthor: "SkinInsight Pro",
            kCGPDFContextTitle: "Skin Analysis Trends - \(client.name)"
        ]
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData as [String: Any]

        // Landscape orientation for graphs
        let pageWidth: CGFloat = 11.0 * 72.0
        let pageHeight: CGFloat = 8.5 * 72.0
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        let margin: CGFloat = 40

        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)

        let data = renderer.pdfData { context in
            context.beginPage()
            let cgContext = context.cgContext

            var yPosition: CGFloat = margin

            // Draw header with background
            cgContext.setFillColor(UIColor.systemCyan.cgColor)
            cgContext.fill(CGRect(x: 0, y: 0, width: pageWidth, height: 70))

            let headerAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 24, weight: .bold),
                .foregroundColor: UIColor.white
            ]
            "SkinInsight Pro - Trending Analysis".draw(at: CGPoint(x: margin, y: 20), withAttributes: headerAttributes)

            yPosition = 90

            // Client name
            let clientNameAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 18, weight: .semibold),
                .foregroundColor: UIColor.black
            ]
            "Client: \(client.name)".draw(at: CGPoint(x: margin, y: yPosition), withAttributes: clientNameAttributes)
            yPosition += 30

            // Date range
            let sortedAnalyses = analyses.sorted { $0.timestamp < $1.timestamp }
            if let firstDate = sortedAnalyses.first?.timestamp,
               let lastDate = sortedAnalyses.last?.timestamp {
                let dateFormatter = DateFormatter()
                dateFormatter.dateStyle = .medium

                let dateAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 12, weight: .medium),
                    .foregroundColor: UIColor.darkGray
                ]
                let dateRangeText = "Period: \(dateFormatter.string(from: firstDate)) - \(dateFormatter.string(from: lastDate))"
                dateRangeText.draw(at: CGPoint(x: margin, y: yPosition), withAttributes: dateAttributes)
                yPosition += 20
            }

            let countAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12, weight: .medium),
                .foregroundColor: UIColor.darkGray
            ]
            "Total Scans: \(analyses.count)".draw(at: CGPoint(x: margin, y: yPosition), withAttributes: countAttributes)
            yPosition += 35

            // Divider
            cgContext.setStrokeColor(UIColor.lightGray.cgColor)
            cgContext.setLineWidth(1)
            cgContext.move(to: CGPoint(x: margin, y: yPosition))
            cgContext.addLine(to: CGPoint(x: pageWidth - margin, y: yPosition))
            cgContext.strokePath()
            yPosition += 25

            // Statistics Section
            let sectionTitleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 14, weight: .bold),
                .foregroundColor: UIColor.black
            ]
            "Hydration Statistics".draw(at: CGPoint(x: margin, y: yPosition), withAttributes: sectionTitleAttributes)
            yPosition += 25

            let values = analyses.map { $0.hydration }
            let avg = values.reduce(0, +) / Double(values.count)
            let min = values.min() ?? 0
            let max = values.max() ?? 0
            let latest = values.last ?? 0
            let first = values.first ?? 0
            let change = latest - first

            let statsLabelAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 11, weight: .semibold),
                .foregroundColor: UIColor.black
            ]
            let statsValueAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 11, weight: .regular),
                .foregroundColor: UIColor.darkGray
            ]

            let stats = [
                ("Average:", String(format: "%.1f%%", avg)),
                ("Minimum:", String(format: "%.1f%%", min)),
                ("Maximum:", String(format: "%.1f%%", max)),
                ("Latest:", String(format: "%.1f%%", latest)),
                ("First:", String(format: "%.1f%%", first)),
                ("Change:", (change >= 0 ? "+" : "") + String(format: "%.1f%%", change))
            ]

            for (index, stat) in stats.enumerated() {
                let xOffset: CGFloat = margin + CGFloat((index % 3) * 220)
                let yOffset = yPosition + CGFloat((index / 3) * 25)

                stat.0.draw(at: CGPoint(x: xOffset, y: yOffset), withAttributes: statsLabelAttributes)
                stat.1.draw(at: CGPoint(x: xOffset + 80, y: yOffset), withAttributes: statsValueAttributes)
            }

            yPosition += 70

            // Scan History
            "Scan History".draw(at: CGPoint(x: margin, y: yPosition), withAttributes: sectionTitleAttributes)
            yPosition += 25

            let historyLabelAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 10, weight: .semibold),
                .foregroundColor: UIColor.black
            ]
            let historyValueAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 10, weight: .regular),
                .foregroundColor: UIColor.darkGray
            ]

            // Table headers
            "Date".draw(at: CGPoint(x: margin, y: yPosition), withAttributes: historyLabelAttributes)
            "Hydration".draw(at: CGPoint(x: margin + 200, y: yPosition), withAttributes: historyLabelAttributes)
            yPosition += 20

            let shortDateFormatter = DateFormatter()
            shortDateFormatter.dateStyle = .short
            shortDateFormatter.timeStyle = .short

            for analysis in sortedAnalyses.prefix(15) {
                let dateStr = shortDateFormatter.string(from: analysis.timestamp)
                dateStr.draw(at: CGPoint(x: margin, y: yPosition), withAttributes: historyValueAttributes)

                let hydrationStr = String(format: "%.1f%%", analysis.hydration)
                hydrationStr.draw(at: CGPoint(x: margin + 200, y: yPosition), withAttributes: historyValueAttributes)

                yPosition += 18

                if yPosition > pageHeight - 60 {
                    break
                }
            }

            // Footer
            let footerY = pageHeight - 40

            cgContext.setStrokeColor(UIColor.lightGray.cgColor)
            cgContext.setLineWidth(1)
            cgContext.move(to: CGPoint(x: margin, y: footerY))
            cgContext.addLine(to: CGPoint(x: pageWidth - margin, y: footerY))
            cgContext.strokePath()

            let footerAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 9, weight: .regular),
                .foregroundColor: UIColor.darkGray
            ]

            let footerFormatter = DateFormatter()
            footerFormatter.dateStyle = .long
            let footerText = "Generated by SkinInsight Pro on \(footerFormatter.string(from: Date()))"
            footerText.draw(at: CGPoint(x: margin, y: footerY + 8), withAttributes: footerAttributes)
        }

        return data
    }
}
