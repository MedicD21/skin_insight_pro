import PDFKit
import UIKit

/// Manages PDF generation for skin analysis reports
class PDFExportManager {
    static let shared = PDFExportManager()
    private let logoCache = NSCache<NSString, UIImage>()
    private let productImageCache = NSCache<NSString, UIImage>()

    private init() {}

    /// Generate PDF for a single skin analysis (legacy method for trending)
    func generateAnalysisPDF(
        client: Client,
        analysis: SkinAnalysis,
        image: UIImage?,
        company: Company? = nil
    ) -> Data? {
        // This is kept for backward compatibility with trending PDF
        return generateBasicAnalysisPDF(
            client: client, analysis: analysis, image: image, company: company)
    }

    /// Generate PDF with full analysis details
    func generateDetailedAnalysisPDF(
        client: Client,
        analysisData: AnalysisData,
        image: UIImage?,
        notes: String?,
        productsUsed: String?,
        treatmentsPerformed: String?,
        timestamp: Date,
        company: Company? = nil
    ) -> Data? {
        let pdfMetaData = [
            kCGPDFContextCreator: "SkinInsight Pro",
            kCGPDFContextAuthor: "SkinInsight Pro",
            kCGPDFContextTitle: "Skin Analysis Report - \(client.name)",
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

            // Draw light gray background for entire page
            // cgContext.setFillColor(UIColor(white: 0.85, alpha: 1.0).cgColor)
            // cgContext.fill(pageRect)

            // Draw header with gradient background
            let headerRect = CGRect(x: 0, y: 0, width: pageWidth, height: 90)

            cgContext.saveGState()
            cgContext.addRect(headerRect)
            cgContext.clip()

            // Simple vertical gradient from dark gray to black
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let gradientColors: [CGColor] = [
                UIColor(white: 0.2, alpha: 1.0).cgColor,
                UIColor.black.cgColor,
            ]
            let locations: [CGFloat] = [0.0, 1.0]
            if let gradient = CGGradient(
                colorsSpace: colorSpace, colors: gradientColors as CFArray, locations: locations)
            {
                let startPoint = CGPoint(x: 0, y: 0)
                let endPoint = CGPoint(x: 0, y: headerRect.maxY)
                cgContext.drawLinearGradient(
                    gradient, start: startPoint, end: endPoint, options: [])
            } else {
                // Fallback fill if gradient fails
                cgContext.setFillColor(UIColor.black.cgColor)
                cgContext.fill(headerRect)
            }

            cgContext.restoreGState()

            let headerFont =
                UIFont(name: "AvenirNext-DemiBold", size: 28)
                ?? UIFont.systemFont(ofSize: 28, weight: .semibold)
            let headerAttributes: [NSAttributedString.Key: Any] = [
                .font: headerFont,
                .foregroundColor: UIColor.white,
            ]
            let companyName = companyDisplayName(company)
            companyName.draw(
                at: CGPoint(x: margin, y: 15), withAttributes: headerAttributes)

            let subtitleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 14, weight: .medium),
                .foregroundColor: UIColor.white.withAlphaComponent(0.9),
            ]
            "Skin Analysis Report".draw(
                at: CGPoint(x: margin, y: 50), withAttributes: subtitleAttributes)

            let poweredByAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 9, weight: .regular),
                .foregroundColor: UIColor.white.withAlphaComponent(0.7),
            ]
            "Powered by Skin Insight Pro".draw(
                at: CGPoint(x: margin, y: 70),
                withAttributes: poweredByAttributes)

            yPosition = 100

            // Draw company logo or default app logo
            var logoCircleRect: CGRect?
            let logoImage = getLogoImage(company: company)
            if let logoImage = logoImage {
                let logoSize: CGFloat = 100
                let padding: CGFloat = 1  // space between logo and circle edge
                let circleDiameter = logoSize + (padding * 2)

                let circleRect = CGRect(
                    x: pageWidth - margin - circleDiameter,
                    y: (120 - circleDiameter) / 2,  // vertically center in header
                    width: circleDiameter,
                    height: circleDiameter
                )
                logoCircleRect = circleRect

                // Draw black circle background
                cgContext.setFillColor(UIColor.black.withAlphaComponent(0.85).cgColor)
                cgContext.fillEllipse(in: circleRect)

                // Clip to circle for logo
                cgContext.saveGState()
                cgContext.addEllipse(in: circleRect)
                cgContext.clip()

                // Draw logo centered inside circle with proper aspect ratio
                let logoRect = CGRect(
                    x: circleRect.origin.x + padding,
                    y: circleRect.origin.y + padding,
                    width: logoSize,
                    height: logoSize
                )

                drawImageCentered(logoImage, in: logoRect)
                cgContext.restoreGState()
            }

            // Client name
            let clientNameAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 25, weight: .semibold),
                .foregroundColor: UIColor.black,
            ]
            let clientLineY = (yPosition + 20)
            "Client: \(client.name)".draw(
                at: CGPoint(x: margin, y: clientLineY), withAttributes: clientNameAttributes)

            var headerContentBottomY = clientLineY + 35

            // Skin Health Score pill

            if let score = analysisData.skinHealthScore {
                let scoreText = "Score: \(score)/100"
                let scoreFont = UIFont.systemFont(ofSize: 22, weight: .bold)
                let scoreAttributes: [NSAttributedString.Key: Any] = [
                    .font: scoreFont,
                    .foregroundColor: UIColor.white,
                ]

                let pillColor: UIColor
                if score <= 50 {
                    pillColor = UIColor.red
                } else if score <= 80 {
                    pillColor = UIColor.orange
                } else {
                    pillColor = UIColor.systemGreen
                }

                let textSize = (scoreText as NSString).size(withAttributes: [.font: scoreFont])
                let pillPaddingX: CGFloat = 10
                let pillPaddingY: CGFloat = 6
                let pillWidth = textSize.width + (pillPaddingX * 2)
                let pillHeight = textSize.height + (pillPaddingY * 2)
                let pillX: CGFloat
                let pillY: CGFloat
                if let circleRect = logoCircleRect {
                    pillX = circleRect.midX - (pillWidth / 2)
                    pillY = circleRect.maxY + 10
                } else {
                    pillX = pageWidth - margin - pillWidth
                    pillY = clientLineY - 2
                }
                let pillRect = CGRect(
                    x: pillX,
                    y: pillY,
                    width: pillWidth,
                    height: pillHeight
                )
                let pillPath = UIBezierPath(
                    roundedRect: pillRect, cornerRadius: pillRect.height / 2)
                cgContext.setFillColor(pillColor.cgColor)
                cgContext.addPath(pillPath.cgPath)
                cgContext.fillPath()

                scoreText.draw(
                    at: CGPoint(
                        x: pillRect.origin.x + pillPaddingX, y: pillRect.origin.y + pillPaddingY),
                    withAttributes: scoreAttributes
                )
                headerContentBottomY = max(headerContentBottomY, pillRect.maxY + 3)
            }
            yPosition = headerContentBottomY

            // Analysis date
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .long
            dateFormatter.timeStyle = .short

            let dateAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 14, weight: .medium),
                .foregroundColor: UIColor.black,
            ]
            "Date: \(dateFormatter.string(from: timestamp))".draw(
                at: CGPoint(x: margin, y: clientLineY + 45), withAttributes: dateAttributes)
            yPosition += 25

            // Divider line
            cgContext.setStrokeColor(UIColor.black.cgColor)
            cgContext.setLineWidth(3)
            cgContext.move(to: CGPoint(x: margin, y: yPosition))
            cgContext.addLine(to: CGPoint(x: pageWidth - margin, y: yPosition))
            cgContext.strokePath()
            yPosition += 25

            let sectionTitleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 20, weight: .bold),
                .foregroundColor: UIColor.black,
                .underlineStyle: NSUnderlineStyle.single.rawValue,

            ]
            let metricLabelAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 16, weight: .semibold),
                .foregroundColor: UIColor.black,
            ]
            let metricValueAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 16, weight: .regular),
                .foregroundColor: UIColor.black,
            ]
            // let sectionBackgroundColor = UIColor(white: 0.96, alpha: 1.0)
            // let sectionBorderColor = UIColor.lightGray
            // let sectionCornerRadius: CGFloat = 14

            // Check if we need a new page
            func checkNewPage() {
                if yPosition > pageHeight - 100 {
                    context.beginPage()
                    yPosition = margin
                }
            }

            // func drawSectionBackground(startY: CGFloat, endY: CGFloat) {
            //     let padding: CGFloat = 10
            //     let rect = CGRect(
            //         x: margin,
            //         y: startY - padding,
            //         width: pageWidth - (margin * 2),
            //         height: (endY - startY) + (padding * 2)
            //     )
            //     let path = UIBezierPath(roundedRect: rect, cornerRadius: sectionCornerRadius)

            //     cgContext.saveGState()
            //     cgContext.setBlendMode(.destinationOver)
            //     cgContext.addPath(path.cgPath)
            //     cgContext.setFillColor(sectionBackgroundColor.cgColor)
            //     cgContext.fillPath()
            //     cgContext.restoreGState()

            //     cgContext.saveGState()
            //     cgContext.addPath(path.cgPath)
            //     cgContext.setStrokeColor(sectionBorderColor.cgColor)
            //     cgContext.setLineWidth(1)
            //     cgContext.strokePath()
            //     cgContext.restoreGState()
            // }

            func checkNewPageForSection(_ sectionStartY: inout CGFloat) {
                if yPosition > pageHeight - 100 {
                    // drawSectionBackground(startY: sectionStartY, endY: yPosition)
                    context.beginPage()
                    yPosition = margin
                    sectionStartY = yPosition
                }
            }

            // Analysis Overview
            checkNewPage()
            let analysisSectionStartY = yPosition
            "Analysis Overview".draw(
                at: CGPoint(x: margin, y: yPosition), withAttributes: sectionTitleAttributes)
            yPosition += 25

            // Draw image if available
            if let image = image {
                let circleDiameter: CGFloat = 100

                let circleRect = CGRect(
                    x: pageWidth - margin - circleDiameter,
                    y: analysisSectionStartY,
                    width: circleDiameter,
                    height: circleDiameter
                )

                // Draw black circle border
                cgContext.setStrokeColor(UIColor.black.cgColor)
                cgContext.setLineWidth(2)
                cgContext.strokeEllipse(in: circleRect)

                // Clip to circle for image
                cgContext.saveGState()
                cgContext.addEllipse(in: circleRect)
                cgContext.clip()

                // Draw image centered inside circle with proper aspect ratio
                drawImageCentered(image, in: circleRect)
                cgContext.restoreGState()
            }

            var overviewRows: [(String, String)] = []
            if let skinType = analysisData.skinType, !skinType.isEmpty {
                overviewRows.append(("Skin Type", skinType.capitalized))
            }
            if let hydration = analysisData.hydrationLevel {
                overviewRows.append(("Hydration Level", "\(hydration)%"))
            }
            if let sensitivity = analysisData.sensitivity, !sensitivity.isEmpty {
                overviewRows.append(("Sensitivity", sensitivity.capitalized))
            }
            if let poreCondition = analysisData.poreCondition, !poreCondition.isEmpty {
                overviewRows.append(("Pore Condition", poreCondition.capitalized))
            }

            let metricValueX = margin + 200
            let metricRowSpacing: CGFloat = 30
            for (label, value) in overviewRows {
                "\(label):".draw(
                    at: CGPoint(x: margin, y: (yPosition + 5)),
                    withAttributes: metricLabelAttributes)
                value.draw(
                    at: CGPoint(x: metricValueX, y: (yPosition + 5)),
                    withAttributes: metricValueAttributes)
                yPosition += metricRowSpacing
            }

            // drawSectionBackground(startY: analysisSectionStartY, endY: yPosition)
            yPosition += 20

            // Concerns Section
            if let concerns = analysisData.concerns, !concerns.isEmpty {
                checkNewPage()
                var concernsSectionStartY = yPosition
                "Skin Concerns".draw(
                    at: CGPoint(x: margin, y: yPosition), withAttributes: sectionTitleAttributes)
                yPosition += 25

                let bulletAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 16, weight: .regular),
                    .foregroundColor: UIColor.black,
                    .baselineOffset: -10,
                ]

                for concern in concerns {
                    checkNewPageForSection(&concernsSectionStartY)
                    "• \(concern.capitalized)".draw(
                        at: CGPoint(x: margin + 10, y: yPosition), withAttributes: bulletAttributes)
                    yPosition += 18
                }

                // drawSectionBackground(startY: concernsSectionStartY, endY: yPosition)
                yPosition += 20
            }

            // Medical Considerations
            if let medicalConsiderations = analysisData.medicalConsiderations,
                !medicalConsiderations.isEmpty
            {
                checkNewPage()
                var medicalSectionStartY = yPosition
                "Medical Considerations".draw(
                    at: CGPoint(x: margin, y: yPosition), withAttributes: sectionTitleAttributes)
                yPosition += 25

                let medicalAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 16, weight: .regular),
                    .foregroundColor: UIColor.black,
                    .baselineOffset: -10,
                ]

                for consideration in medicalConsiderations {
                    checkNewPageForSection(&medicalSectionStartY)
                    let textWidth = pageWidth - (margin * 2) - 20
                    let text = "• \(consideration)"
                    let textRect = CGRect(
                        x: margin + 10, y: yPosition, width: textWidth, height: 1000)
                    let boundingRect = (text as NSString).boundingRect(
                        with: CGSize(width: textWidth, height: CGFloat.greatestFiniteMagnitude),
                        options: [.usesLineFragmentOrigin],
                        attributes: medicalAttributes,
                        context: nil
                    )

                    text.draw(in: textRect, withAttributes: medicalAttributes)
                    yPosition += boundingRect.height + 8
                }

                // drawSectionBackground(startY: medicalSectionStartY, endY: yPosition)
                yPosition += 20
            }

            // Recommendations Section
            if let recommendations = analysisData.recommendations, !recommendations.isEmpty {
                checkNewPage()
                var recommendationSectionStartY = yPosition
                "Recommendations".draw(
                    at: CGPoint(x: margin, y: yPosition), withAttributes: sectionTitleAttributes)
                yPosition += 25

                let recAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 16, weight: .regular),
                    .foregroundColor: UIColor.black,
                    .baselineOffset: -10,
                ]

                for (index, recommendation) in recommendations.enumerated() {
                    checkNewPageForSection(&recommendationSectionStartY)
                    let textWidth = pageWidth - (margin * 2) - 30
                    let text = "\(index + 1). \(recommendation)"
                    let textRect = CGRect(
                        x: margin + 10, y: yPosition, width: textWidth, height: 1000)
                    let boundingRect = (text as NSString).boundingRect(
                        with: CGSize(width: textWidth, height: CGFloat.greatestFiniteMagnitude),
                        options: [.usesLineFragmentOrigin],
                        attributes: recAttributes,
                        context: nil
                    )

                    text.draw(in: textRect, withAttributes: recAttributes)
                    yPosition += boundingRect.height + 8
                }

                // drawSectionBackground(startY: recommendationSectionStartY, endY: yPosition)
                yPosition += 20
            }

            // Product Recommendations
            if let productRecs = analysisData.productRecommendations, !productRecs.isEmpty {
                checkNewPage()
                var productSectionStartY = yPosition
                "Product Recommendations".draw(
                    at: CGPoint(x: margin, y: yPosition), withAttributes: sectionTitleAttributes)
                yPosition += 25

                let productAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 16, weight: .regular),
                    .foregroundColor: UIColor.black,
                    .baselineOffset: -10,
                ]

                for (index, product) in productRecs.enumerated() {
                    checkNewPageForSection(&productSectionStartY)
                    let textWidth = pageWidth - (margin * 2) - 30
                    let text = "\(index + 1). \(product)"
                    let textRect = CGRect(
                        x: margin + 10, y: yPosition, width: textWidth, height: 1000)
                    let boundingRect = (text as NSString).boundingRect(
                        with: CGSize(width: textWidth, height: CGFloat.greatestFiniteMagnitude),
                        options: [.usesLineFragmentOrigin],
                        attributes: productAttributes,
                        context: nil
                    )

                    text.draw(in: textRect, withAttributes: productAttributes)
                    yPosition += boundingRect.height + 8
                }

                // drawSectionBackground(startY: productSectionStartY, endY: yPosition)
                yPosition += 20
            }

            // Products Used
            if let products = productsUsed, !products.isEmpty {
                checkNewPage()
                "Products Used".draw(
                    at: CGPoint(x: margin, y: yPosition), withAttributes: sectionTitleAttributes)
                yPosition += 25

                let textAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 16, weight: .regular),
                    .foregroundColor: UIColor.black,
                    .baselineOffset: -10,
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
                // drawSectionBackground(startY: productsUsedSectionStartY, endY: yPosition)
                yPosition += 5
            }

            // Treatments Performed
            if let treatments = treatmentsPerformed, !treatments.isEmpty {
                checkNewPage()
                "Treatments Performed".draw(
                    at: CGPoint(x: margin, y: yPosition), withAttributes: sectionTitleAttributes)
                yPosition += 25

                let textAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 16, weight: .regular),
                    .foregroundColor: UIColor.black,
                    .baselineOffset: -10,
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
                // drawSectionBackground(startY: treatmentsSectionStartY, endY: yPosition)
                yPosition += 5
            }

            // Notes Section
            if let notes = notes, !notes.isEmpty {
                checkNewPage()
                "Notes".draw(
                    at: CGPoint(x: margin, y: yPosition), withAttributes: sectionTitleAttributes)
                yPosition += 25

                let notesAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 16, weight: .regular),
                    .foregroundColor: UIColor.black,
                    .baselineOffset: -10,
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
                yPosition += boundingRect.height + 15
                // drawSectionBackground(startY: notesSectionStartY, endY: yPosition)
                yPosition += 5
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
                .foregroundColor: UIColor.darkGray,
            ]

            let footerFormatter = DateFormatter()
            footerFormatter.dateStyle = .long

            // Show company name if available
            if let companyName = company?.name, !companyName.isEmpty {
                let companyText = "\(companyName) • Powered by Skin Insight Pro"
                companyText.draw(
                    at: CGPoint(x: margin, y: footerY + 10), withAttributes: footerAttributes)

                "Generated on \(footerFormatter.string(from: Date()))".draw(
                    at: CGPoint(x: margin, y: footerY + 25), withAttributes: footerAttributes)
            } else {
                let footerText =
                    "Powered by Skin Insight Pro • Generated on \(footerFormatter.string(from: Date()))"
                footerText.draw(
                    at: CGPoint(x: margin, y: footerY + 10), withAttributes: footerAttributes)

                "This report is confidential and intended for professional use only.".draw(
                    at: CGPoint(x: margin, y: footerY + 25), withAttributes: footerAttributes)
            }
        }

        return data
    }

    /// Generate a PDF for a recommended morning/evening routine
    func generateRoutinePDF(client: Client, routine: SkinCareRoutine, company: Company? = nil)
        -> Data?
    {
        let pdfMetaData = [
            kCGPDFContextCreator: "SkinInsight Pro",
            kCGPDFContextAuthor: "SkinInsight Pro",
            kCGPDFContextTitle: "Recommended Routine - \(client.name)",
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

            drawStandardHeader(
                cgContext: cgContext,
                pageRect: pageRect,
                margin: margin,
                subtitle: "Recommended Routine",
                company: company
            )

            yPosition = 100

            let clientNameAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 25, weight: .semibold),
                .foregroundColor: UIColor.black,
            ]
            "Client: \(client.name)".draw(
                at: CGPoint(x: margin, y: yPosition), withAttributes: clientNameAttributes)
            yPosition += 35

            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .long
            dateFormatter.timeStyle = .short

            let dateAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 14, weight: .medium),
                .foregroundColor: UIColor.black,
            ]
            "Generated: \(dateFormatter.string(from: Date()))".draw(
                at: CGPoint(x: margin, y: yPosition), withAttributes: dateAttributes)
            yPosition += 22

            let guidanceAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12, weight: .regular),
                .foregroundColor: UIColor.darkGray,
            ]
            "Personalized morning and evening steps".draw(
                at: CGPoint(x: margin, y: yPosition), withAttributes: guidanceAttributes)
            yPosition += 18

            cgContext.setStrokeColor(UIColor.black.cgColor)
            cgContext.setLineWidth(3)
            cgContext.move(to: CGPoint(x: margin, y: yPosition))
            cgContext.addLine(to: CGPoint(x: pageWidth - margin, y: yPosition))
            cgContext.strokePath()
            yPosition += 25

            let sectionTitleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 20, weight: .bold),
                .foregroundColor: UIColor.black,
            ]
            let stepTitleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 14, weight: .semibold),
                .foregroundColor: UIColor.black,
            ]
            let detailAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12, weight: .regular),
                .foregroundColor: UIColor.darkGray,
            ]
            let bodyAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12, weight: .regular),
                .foregroundColor: UIColor.black,
            ]

            func checkNewPage() {
                if yPosition > pageHeight - 120 {
                    context.beginPage()
                    yPosition = margin
                }
            }

            func drawWrappedText(
                _ text: String, attributes: [NSAttributedString.Key: Any], indent: CGFloat = 0,
                spacing: CGFloat = 6
            ) {
                let textWidth = pageWidth - (margin * 2) - indent
                let textRect = CGRect(
                    x: margin + indent, y: yPosition, width: textWidth, height: 1000)
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
                title.draw(
                    at: CGPoint(x: margin, y: yPosition), withAttributes: sectionTitleAttributes)
                yPosition += 26

                if steps.isEmpty {
                    drawWrappedText("No steps provided.", attributes: detailAttributes, indent: 10)
                    yPosition += 10
                    return
                }

                let imageSize: CGFloat = 52
                let imageSpacing: CGFloat = 12

                for (index, step) in steps.enumerated() {
                    checkNewPage()
                    let rowStartY = yPosition
                    var hasImage = false
                    if let image = getProductImage(urlString: step.imageUrl) {
                        let imageRect = CGRect(
                            x: margin, y: yPosition, width: imageSize, height: imageSize)
                        drawImageCentered(image, in: imageRect)
                        hasImage = true
                    }

                    let indent = hasImage ? imageSize + imageSpacing : 0
                    let stepNumber = step.stepNumber > 0 ? step.stepNumber : index + 1
                    let stepTitle = "\(stepNumber). \(step.productName)"
                    drawWrappedText(stepTitle, attributes: stepTitleAttributes, indent: indent)

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
                        drawWrappedText(
                            details.joined(separator: " • "), attributes: detailAttributes,
                            indent: indent + 12, spacing: 4)
                    }
                    if let instructions = step.instructions, !instructions.isEmpty {
                        drawWrappedText(instructions, attributes: bodyAttributes, indent: indent + 12)
                    }
                    if hasImage && yPosition < rowStartY + imageSize {
                        yPosition = rowStartY + imageSize
                    }
                    yPosition += 6
                }
                yPosition += 10
            }

            drawRoutineSection(title: "Morning Routine", steps: routine.morningSteps)
            drawRoutineSection(title: "Evening Routine", steps: routine.eveningSteps)

            if let notes = routine.notes, !notes.isEmpty {
                checkNewPage()
                "Routine Tips".draw(
                    at: CGPoint(x: margin, y: yPosition), withAttributes: sectionTitleAttributes)
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
                .foregroundColor: UIColor.darkGray,
            ]

            let footerFormatter = DateFormatter()
            footerFormatter.dateStyle = .long

            // Show company name if available
            if let companyName = company?.name, !companyName.isEmpty {
                let companyText = "\(companyName) • Powered by Skin Insight Pro"
                companyText.draw(
                    at: CGPoint(x: margin, y: footerY + 10), withAttributes: footerAttributes)

                "Generated on \(footerFormatter.string(from: Date()))".draw(
                    at: CGPoint(x: margin, y: footerY + 25), withAttributes: footerAttributes)
            } else {
                let footerText =
                    "Powered by Skin Insight Pro • Generated on \(footerFormatter.string(from: Date()))"
                footerText.draw(
                    at: CGPoint(x: margin, y: footerY + 10), withAttributes: footerAttributes)

                "Routine guidance only. Adjust based on professional assessment.".draw(
                    at: CGPoint(x: margin, y: footerY + 25), withAttributes: footerAttributes)
            }
        }

        return data
    }

    /// Generate basic PDF (used for trending and backward compatibility)
    private func generateBasicAnalysisPDF(
        client: Client, analysis: SkinAnalysis, image: UIImage?, company: Company? = nil
    )
        -> Data?
    {
        let pdfMetaData = [
            kCGPDFContextCreator: "SkinInsight Pro",
            kCGPDFContextAuthor: "SkinInsight Pro",
            kCGPDFContextTitle: "Skin Analysis Report - \(client.name)",
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

            drawStandardHeader(
                cgContext: cgContext,
                pageRect: pageRect,
                margin: margin,
                subtitle: "Skin Analysis Report",
                company: company
            )

            yPosition = 100

            // Client name
            let clientNameAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 25, weight: .semibold),
                .foregroundColor: UIColor.black,
            ]
            "Client: \(client.name)".draw(
                at: CGPoint(x: margin, y: yPosition), withAttributes: clientNameAttributes)
            yPosition += 35

            // Analysis date
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .long
            dateFormatter.timeStyle = .short

            let dateAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 14, weight: .medium),
                .foregroundColor: UIColor.black,
            ]
            "Date: \(dateFormatter.string(from: analysis.timestamp))".draw(
                at: CGPoint(x: margin, y: yPosition), withAttributes: dateAttributes)
            yPosition += 25

            // Divider line
            cgContext.setStrokeColor(UIColor.black.cgColor)
            cgContext.setLineWidth(3)
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
                let imageRect = CGRect(
                    x: imageX, y: yPosition, width: drawWidth, height: drawHeight)

                // Draw border around image
                cgContext.setStrokeColor(UIColor.lightGray.cgColor)
                cgContext.setLineWidth(1)
                cgContext.stroke(imageRect)

                image.draw(in: imageRect)
                yPosition += drawHeight + 30
            }

            // Analysis Results Section
            let sectionTitleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 20, weight: .bold),
                .foregroundColor: UIColor.black,
            ]
            "Analysis Results".draw(
                at: CGPoint(x: margin, y: yPosition), withAttributes: sectionTitleAttributes)
            yPosition += 25

            // Metrics - only show hydration if we have it
            let metricLabelAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 14, weight: .semibold),
                .foregroundColor: UIColor.black,
            ]
            let metricValueAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 14, weight: .regular),
                .foregroundColor: UIColor.darkGray,
            ]

            if analysis.hydration > 0 {
                "Hydration Level:".draw(
                    at: CGPoint(x: margin, y: yPosition), withAttributes: metricLabelAttributes)
                let valueText = String(format: "%.0f%%", analysis.hydration)
                valueText.draw(
                    at: CGPoint(x: margin + 150, y: yPosition),
                    withAttributes: metricValueAttributes)
                yPosition += 20
            }

            yPosition += 10

            // Recommendations Section
            if let recommendations = analysis.recommendations, !recommendations.isEmpty {
                yPosition += 10

                "Recommendations".draw(
                    at: CGPoint(x: margin, y: yPosition), withAttributes: sectionTitleAttributes)
                yPosition += 25

                let paragraphStyle = NSMutableParagraphStyle()
                paragraphStyle.lineSpacing = 6
                paragraphStyle.alignment = .left

                let recAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 14, weight: .regular),
                    .foregroundColor: UIColor.black,
                    .paragraphStyle: paragraphStyle,
                ]

                let textWidth = pageWidth - (margin * 2)
                let recText = NSAttributedString(string: recommendations, attributes: recAttributes)
                let textRect = CGRect(
                    x: margin, y: yPosition, width: textWidth, height: pageHeight - yPosition - 80)
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

                "Notes".draw(
                    at: CGPoint(x: margin, y: yPosition), withAttributes: sectionTitleAttributes)
                yPosition += 25

                let paragraphStyle = NSMutableParagraphStyle()
                paragraphStyle.lineSpacing = 6

                let notesAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 14, weight: .regular),
                    .foregroundColor: UIColor.black,
                    .paragraphStyle: paragraphStyle,
                ]

                let textWidth = pageWidth - (margin * 2)
                let notesText = NSAttributedString(string: notes, attributes: notesAttributes)
                let textRect = CGRect(
                    x: margin, y: yPosition, width: textWidth, height: pageHeight - yPosition - 80)
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
                .foregroundColor: UIColor.darkGray,
            ]

            let footerFormatter = DateFormatter()
            footerFormatter.dateStyle = .long

            // Show company name if available
            if let companyName = company?.name, !companyName.isEmpty {
                let companyText = "\(companyName) • Powered by Skin Insight Pro"
                companyText.draw(
                    at: CGPoint(x: margin, y: footerY + 10), withAttributes: footerAttributes)

                "Generated on \(footerFormatter.string(from: Date()))".draw(
                    at: CGPoint(x: margin, y: footerY + 25), withAttributes: footerAttributes)
            } else {
                let footerText =
                    "Powered by Skin Insight Pro • Generated on \(footerFormatter.string(from: Date()))"
                footerText.draw(
                    at: CGPoint(x: margin, y: footerY + 10), withAttributes: footerAttributes)

                "This report is confidential and intended for professional use only.".draw(
                    at: CGPoint(x: margin, y: footerY + 25), withAttributes: footerAttributes)
            }
        }

        return data
    }

    /// Generate PDF with trending graphs for all client scans
    func generateTrendingPDF(
        client: Client,
        analyses: [SkinAnalysis],
        selectedMetric: TrendingMetric = .hydration,
        company: Company? = nil
    ) -> Data? {
        guard !analyses.isEmpty else { return nil }

        let pdfMetaData = [
            kCGPDFContextCreator: "SkinInsight Pro",
            kCGPDFContextAuthor: "SkinInsight Pro",
            kCGPDFContextTitle: "Skin Analysis Trends - \(client.name)",
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

            drawStandardHeader(
                cgContext: cgContext,
                pageRect: pageRect,
                margin: margin,
                subtitle: "Skin Analysis Trends",
                company: company
            )

            yPosition = 100

            // Client name
            let clientNameAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 25, weight: .semibold),
                .foregroundColor: UIColor.black,
            ]
            "Client: \(client.name)".draw(
                at: CGPoint(x: margin, y: yPosition), withAttributes: clientNameAttributes)
            yPosition += 35

            // Date range
            let sortedAnalyses = analyses.sorted { $0.timestamp < $1.timestamp }
            if let firstDate = sortedAnalyses.first?.timestamp,
                let lastDate = sortedAnalyses.last?.timestamp
            {
                let dateFormatter = DateFormatter()
                dateFormatter.dateStyle = .medium

                let dateAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 14, weight: .medium),
                    .foregroundColor: UIColor.black,
                ]
                let dateRangeText =
                    "Period: \(dateFormatter.string(from: firstDate)) - \(dateFormatter.string(from: lastDate))"
                dateRangeText.draw(
                    at: CGPoint(x: margin, y: yPosition), withAttributes: dateAttributes)
                yPosition += 24
            }

            let countAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 13, weight: .medium),
                .foregroundColor: UIColor.darkGray,
            ]
            "Total Scans: \(analyses.count)".draw(
                at: CGPoint(x: margin, y: yPosition), withAttributes: countAttributes)
            yPosition += 35

            let metricLabel = selectedMetric == .all ? "All Metrics" : selectedMetric.rawValue
            let metricAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 13, weight: .medium),
                .foregroundColor: UIColor.darkGray,
            ]
            "Metric: \(metricLabel)".draw(
                at: CGPoint(x: margin, y: yPosition), withAttributes: metricAttributes)
            yPosition += 28

            // Divider
            cgContext.setStrokeColor(UIColor.black.cgColor)
            cgContext.setLineWidth(3)
            cgContext.move(to: CGPoint(x: margin, y: yPosition))
            cgContext.addLine(to: CGPoint(x: pageWidth - margin, y: yPosition))
            cgContext.strokePath()
            yPosition += 25

            func metricValue(for analysis: SkinAnalysis, metric: TrendingMetric) -> Double {
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

            func formattedMetricValue(_ value: Double, metric: TrendingMetric) -> String {
                if metric == .hydration {
                    return String(format: "%.1f%%", value)
                }
                return String(format: "%.1f", value)
            }

            func ensureSpace(_ height: CGFloat) {
                if yPosition + height > pageHeight - 60 {
                    context.beginPage()
                    yPosition = margin
                }
            }

            let metricsToShow: [TrendingMetric] =
                selectedMetric == .all
                ? TrendingMetric.allCases.filter { $0 != .all }
                : [selectedMetric]

            // Statistics Section(s)
            let sectionTitleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 20, weight: .bold),
                .foregroundColor: UIColor.black,
            ]

            let statsLabelAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12, weight: .semibold),
                .foregroundColor: UIColor.black,
            ]
            let statsValueAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12, weight: .regular),
                .foregroundColor: UIColor.darkGray,
            ]

            for metric in metricsToShow {
                ensureSpace(110)
                "\(metric.rawValue) Statistics".draw(
                    at: CGPoint(x: margin, y: yPosition), withAttributes: sectionTitleAttributes)
                yPosition += 25

                let values = analyses.map { metricValue(for: $0, metric: metric) }
                let avg = values.reduce(0, +) / Double(values.count)
                let min = values.min() ?? 0
                let max = values.max() ?? 0
                let latest = values.last ?? 0
                let first = values.first ?? 0
                let change = latest - first

                let stats = [
                    ("Average:", formattedMetricValue(avg, metric: metric)),
                    ("Minimum:", formattedMetricValue(min, metric: metric)),
                    ("Maximum:", formattedMetricValue(max, metric: metric)),
                    ("Latest:", formattedMetricValue(latest, metric: metric)),
                    ("First:", formattedMetricValue(first, metric: metric)),
                    ("Change:", (change >= 0 ? "+" : "") + formattedMetricValue(change, metric: metric)),
                ]

                for (index, stat) in stats.enumerated() {
                    let xOffset: CGFloat = margin + CGFloat((index % 3) * 220)
                    let yOffset = yPosition + CGFloat((index / 3) * 25)

                    stat.0.draw(
                        at: CGPoint(x: xOffset, y: yOffset), withAttributes: statsLabelAttributes)
                    stat.1.draw(
                        at: CGPoint(x: xOffset + 80, y: yOffset),
                        withAttributes: statsValueAttributes)
                }

                yPosition += 70
            }

            if selectedMetric == .all {
                ensureSpace(80)
                "Latest Metrics Snapshot".draw(
                    at: CGPoint(x: margin, y: yPosition), withAttributes: sectionTitleAttributes)
                yPosition += 25

                let latestAnalysis = sortedAnalyses.last ?? sortedAnalyses.first
                if let latestAnalysis {
                    for (index, metric) in metricsToShow.enumerated() {
                        let xOffset: CGFloat = margin + CGFloat((index % 3) * 220)
                        let yOffset = yPosition + CGFloat((index / 3) * 22)
                        let value = metricValue(for: latestAnalysis, metric: metric)

                        metric.rawValue.draw(
                            at: CGPoint(x: xOffset, y: yOffset),
                            withAttributes: statsLabelAttributes)
                        formattedMetricValue(value, metric: metric).draw(
                            at: CGPoint(x: xOffset + 120, y: yOffset),
                            withAttributes: statsValueAttributes)
                    }
                    yPosition += CGFloat(((metricsToShow.count - 1) / 3) + 1) * 22 + 10
                }
            } else {
                ensureSpace(160)
                "Scan History".draw(
                    at: CGPoint(x: margin, y: yPosition), withAttributes: sectionTitleAttributes)
                yPosition += 25

                let historyLabelAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 12, weight: .semibold),
                    .foregroundColor: UIColor.black,
                ]
                let historyValueAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 12, weight: .regular),
                    .foregroundColor: UIColor.darkGray,
                ]

                // Table headers
                "Date".draw(
                    at: CGPoint(x: margin, y: yPosition), withAttributes: historyLabelAttributes)
                selectedMetric.rawValue.draw(
                    at: CGPoint(x: margin + 200, y: yPosition),
                    withAttributes: historyLabelAttributes)
                yPosition += 20

                let shortDateFormatter = DateFormatter()
                shortDateFormatter.dateStyle = .short
                shortDateFormatter.timeStyle = .short

                for analysis in sortedAnalyses.prefix(15) {
                    let dateStr = shortDateFormatter.string(from: analysis.timestamp)
                    dateStr.draw(
                        at: CGPoint(x: margin, y: yPosition),
                        withAttributes: historyValueAttributes)

                    let metricStr = formattedMetricValue(
                        metricValue(for: analysis, metric: selectedMetric),
                        metric: selectedMetric
                    )
                    metricStr.draw(
                        at: CGPoint(x: margin + 200, y: yPosition),
                        withAttributes: historyValueAttributes)

                    yPosition += 18

                    if yPosition > pageHeight - 60 {
                        break
                    }
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
                .foregroundColor: UIColor.darkGray,
            ]

            let footerFormatter = DateFormatter()
            footerFormatter.dateStyle = .long

            // Show company name if available
            if let companyName = company?.name, !companyName.isEmpty {
                let companyText =
                    "\(companyName) • Powered by Skin Insight Pro • Generated on \(footerFormatter.string(from: Date()))"
                companyText.draw(
                    at: CGPoint(x: margin, y: footerY + 8), withAttributes: footerAttributes)
            } else {
                let footerText =
                    "Powered by Skin Insight Pro • Generated on \(footerFormatter.string(from: Date()))"
                footerText.draw(
                    at: CGPoint(x: margin, y: footerY + 8), withAttributes: footerAttributes)
            }
        }

        return data
    }

    func prefetchRoutineImages(_ routine: SkinCareRoutine) async {
        let urls = (routine.morningSteps + routine.eveningSteps)
            .compactMap { $0.imageUrl?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        await prefetchImages(urls, cache: productImageCache)
    }

    // MARK: - Helper Functions

    @discardableResult
    private func drawStandardHeader(
        cgContext: CGContext,
        pageRect: CGRect,
        margin: CGFloat,
        subtitle: String,
        company: Company?
    ) -> CGRect? {
        let headerRect = CGRect(x: 0, y: 0, width: pageRect.width, height: 80)

        cgContext.saveGState()
        cgContext.addRect(headerRect)
        cgContext.clip()

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let gradientColors: [CGColor] = [
            UIColor(white: 0.2, alpha: 1.0).cgColor,
            UIColor.black.cgColor,
        ]
        let locations: [CGFloat] = [0.0, 1.0]
        if let gradient = CGGradient(
            colorsSpace: colorSpace, colors: gradientColors as CFArray, locations: locations)
        {
            let startPoint = CGPoint(x: 0, y: 0)
            let endPoint = CGPoint(x: 0, y: headerRect.maxY)
            cgContext.drawLinearGradient(
                gradient, start: startPoint, end: endPoint, options: [])
        } else {
            cgContext.setFillColor(UIColor.black.cgColor)
            cgContext.fill(headerRect)
        }

        cgContext.restoreGState()

        let headerFont =
            UIFont(name: "AvenirNext-DemiBold", size: 28)
            ?? UIFont.systemFont(ofSize: 28, weight: .semibold)
        let headerAttributes: [NSAttributedString.Key: Any] = [
            .font: headerFont,
            .foregroundColor: UIColor.white,
        ]
        let subtitleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14, weight: .medium),
            .foregroundColor: UIColor.white.withAlphaComponent(0.9),
        ]

        let companyName = companyDisplayName(company)
        companyName.draw(at: CGPoint(x: margin, y: 20), withAttributes: headerAttributes)
        subtitle.draw(at: CGPoint(x: margin, y: 52), withAttributes: subtitleAttributes)

        var logoCircleRect: CGRect?
        let logoImage = getLogoImage(company: company)
        if let logoImage = logoImage {
            let logoSize: CGFloat = 100
            let padding: CGFloat = 1
            let circleDiameter = logoSize + (padding * 2)

            let circleRect = CGRect(
                x: pageRect.width - margin - circleDiameter,
                y: (120 - circleDiameter) / 2,
                width: circleDiameter,
                height: circleDiameter
            )
            logoCircleRect = circleRect

            cgContext.setFillColor(UIColor.black.withAlphaComponent(0.85).cgColor)
            cgContext.fillEllipse(in: circleRect)

            cgContext.saveGState()
            cgContext.addEllipse(in: circleRect)
            cgContext.clip()

            let logoRect = CGRect(
                x: circleRect.origin.x + padding,
                y: circleRect.origin.y + padding,
                width: logoSize,
                height: logoSize
            )

            drawImageCentered(logoImage, in: logoRect)
            cgContext.restoreGState()
        }

        return logoCircleRect
    }

    private func companyDisplayName(_ company: Company?) -> String {
        let trimmedName = company?.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmedName.isEmpty ? "Skin Insight Pro" : trimmedName
    }

    /// Get logo image - prefer company logo, fallback to default app logo
    private func getLogoImage(company: Company?) -> UIImage? {
        if let logoUrl = company?.logoUrl, !logoUrl.isEmpty {
            if let image = fetchImage(urlString: logoUrl, cache: logoCache) {
                return image
            }
        }

        // Fallback to default app logo
        return UIImage(named: "logo")
    }

    private func getProductImage(urlString: String?) -> UIImage? {
        guard let urlString, !urlString.isEmpty else {
            return nil
        }
        return fetchImage(urlString: urlString, cache: productImageCache)
    }

    private func fetchImage(urlString: String, cache: NSCache<NSString, UIImage>) -> UIImage? {
        let cacheKey = urlString as NSString
        if let cachedImage = cache.object(forKey: cacheKey) {
            return cachedImage
        }

        guard let url = URL(string: urlString) else {
            return nil
        }

        if Thread.isMainThread {
            return nil
        }

        let semaphore = DispatchSemaphore(value: 0)
        var downloadedImage: UIImage?
        let task = URLSession.shared.dataTask(with: url) { data, _, _ in
            if let data, let image = UIImage(data: data) {
                downloadedImage = image
            }
            semaphore.signal()
        }
        task.resume()
        _ = semaphore.wait(timeout: .now() + 5)

        if let downloadedImage {
            cache.setObject(downloadedImage, forKey: cacheKey)
        }
        return downloadedImage
    }

    private func prefetchImages(_ urls: [String], cache: NSCache<NSString, UIImage>) async {
        let uniqueUrls = Array(Set(urls))
        await withTaskGroup(of: Void.self) { group in
            for urlString in uniqueUrls {
                let cacheKey = urlString as NSString
                if cache.object(forKey: cacheKey) != nil {
                    continue
                }
                guard let url = URL(string: urlString) else { continue }
                group.addTask {
                    if let (data, _) = try? await URLSession.shared.data(from: url),
                       let image = UIImage(data: data) {
                        cache.setObject(image, forKey: cacheKey)
                    }
                }
            }
        }
    }

    /// Resize image to fit within a square while maintaining aspect ratio
    /// - Parameters:
    ///   - image: The source image to resize
    ///   - targetSize: The target square size
    /// - Returns: Resized image that fits within the target size
    private func resizeImageToFit(_ image: UIImage, targetSize: CGFloat) -> UIImage {
        let size = image.size

        // Calculate scale to fit the image within the target size
        let widthRatio = targetSize / size.width
        let heightRatio = targetSize / size.height
        let scaleFactor = min(widthRatio, heightRatio)

        // Calculate new size maintaining aspect ratio
        let scaledWidth = size.width * scaleFactor
        let scaledHeight = size.height * scaleFactor

        // Create a new image context
        let renderer = UIGraphicsImageRenderer(
            size: CGSize(width: scaledWidth, height: scaledHeight))
        let resizedImage = renderer.image { context in
            image.draw(in: CGRect(x: 0, y: 0, width: scaledWidth, height: scaledHeight))
        }

        return resizedImage
    }

    /// Draw image centered within a rect, maintaining aspect ratio
    /// - Parameters:
    ///   - image: The image to draw
    ///   - rect: The rect to center the image within
    private func drawImageCentered(_ image: UIImage, in rect: CGRect) {
        let imageSize = image.size

        // Calculate aspect ratio
        let imageAspect = imageSize.width / imageSize.height
        let rectAspect = rect.width / rect.height

        var drawRect = rect

        if imageAspect > rectAspect {
            // Image is wider - fit to width
            let scaledHeight = rect.width / imageAspect
            let yOffset = (rect.height - scaledHeight) / 2
            drawRect = CGRect(
                x: rect.origin.x,
                y: rect.origin.y + yOffset,
                width: rect.width,
                height: scaledHeight
            )
        } else {
            // Image is taller - fit to height
            let scaledWidth = rect.height * imageAspect
            let xOffset = (rect.width - scaledWidth) / 2
            drawRect = CGRect(
                x: rect.origin.x + xOffset,
                y: rect.origin.y,
                width: scaledWidth,
                height: rect.height
            )
        }

        image.draw(in: drawRect)
    }
}

//#Preview("Generate Detailed Analysis PDF") {
//    Text("PDF generation is not a SwiftUI View. Create a SwiftUI wrapper View to preview output.")
//}
