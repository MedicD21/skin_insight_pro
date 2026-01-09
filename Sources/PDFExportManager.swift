import UIKit
import PDFKit

/// Manages PDF generation for skin analysis reports
class PDFExportManager {
    static let shared = PDFExportManager()

    private init() {}

    /// Generate PDF for a single skin analysis
    func generateAnalysisPDF(client: Client, analysis: SkinAnalysis, image: UIImage?) -> Data? {
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
