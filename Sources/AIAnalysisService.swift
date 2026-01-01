import UIKit
import Vision
import VisionKit

class AIAnalysisService {
    static let shared = AIAnalysisService()
    private init() {}

    func analyzeImage(
        image: UIImage,
        medicalHistory: String?,
        allergies: String?,
        knownSensitivities: String?,
        medications: String?,
        manualSkinType: String?,
        manualHydrationLevel: String?,
        manualSensitivity: String?,
        manualPoreCondition: String?,
        manualConcerns: String?,
        productsUsed: String?,
        treatmentsPerformed: String?,
        injectablesHistory: String?,
        previousAnalyses: [SkinAnalysisResult],
        aiRules: [AIRule]
    ) async throws -> AnalysisData {
        switch AppConstants.aiProvider {
        case .appleVision:
            return try await analyzeWithAppleVision(
                image: image,
                medicalHistory: medicalHistory,
                allergies: allergies,
                knownSensitivities: knownSensitivities,
                medications: medications,
                manualSkinType: manualSkinType,
                manualHydrationLevel: manualHydrationLevel,
                manualSensitivity: manualSensitivity,
                manualPoreCondition: manualPoreCondition,
                manualConcerns: manualConcerns,
                productsUsed: productsUsed,
                treatmentsPerformed: treatmentsPerformed,
                injectablesHistory: injectablesHistory,
                previousAnalyses: previousAnalyses,
                aiRules: aiRules
            )
        case .claude:
            return try await analyzeWithClaude(
                image: image,
                medicalHistory: medicalHistory,
                allergies: allergies,
                knownSensitivities: knownSensitivities,
                medications: medications,
                manualSkinType: manualSkinType,
                manualHydrationLevel: manualHydrationLevel,
                manualSensitivity: manualSensitivity,
                manualPoreCondition: manualPoreCondition,
                manualConcerns: manualConcerns,
                productsUsed: productsUsed,
                treatmentsPerformed: treatmentsPerformed,
                injectablesHistory: injectablesHistory,
                previousAnalyses: previousAnalyses,
                aiRules: aiRules
            )
        }
    }

    // MARK: - Apple Vision Analysis (Free)
    private func analyzeWithAppleVision(
        image: UIImage,
        medicalHistory: String?,
        allergies: String?,
        knownSensitivities: String?,
        medications: String?,
        manualSkinType: String?,
        manualHydrationLevel: String?,
        manualSensitivity: String?,
        manualPoreCondition: String?,
        manualConcerns: String?,
        productsUsed: String?,
        treatmentsPerformed: String?,
        injectablesHistory: String?,
        previousAnalyses: [SkinAnalysisResult],
        aiRules: [AIRule]
    ) async throws -> AnalysisData {
        // Apple Vision doesn't have pre-trained skin analysis
        // We'll use manual inputs + basic image analysis + apply AI rules

        var concerns: [String] = []
        var recommendations: [String] = []
        var productRecommendations: [String] = []

        // Use manual inputs if provided
        if let manualConcerns = manualConcerns, !manualConcerns.isEmpty {
            concerns = manualConcerns.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        }

        // Perform basic image analysis
        if let cgImage = image.cgImage {
            let brightness = await analyzeBrightness(cgImage: cgImage)
            let dominantColors = await analyzeDominantColors(cgImage: cgImage)

            // Basic heuristics
            if brightness < 0.3 {
                if !concerns.contains("Dark spots") {
                    concerns.append("Dark spots")
                }
            }

            // Check for redness based on color analysis
            if dominantColors.contains(where: { $0.isReddish }) {
                if !concerns.contains("Redness") {
                    concerns.append("Redness")
                }
            }
        }

        // Apply AI Rules
        let appliedRules = applyAIRules(concerns: concerns, rules: aiRules)
        productRecommendations = appliedRules

        // Generate basic recommendations
        if concerns.contains("Redness") {
            recommendations.append("Use a gentle, fragrance-free cleanser")
            recommendations.append("Apply soothing ingredients like aloe or chamomile")
        }
        if concerns.contains("Dark spots") {
            recommendations.append("Consider vitamin C serum for brightening")
            recommendations.append("Use SPF 30+ daily to prevent further darkening")
        }
        if concerns.isEmpty {
            recommendations.append("Maintain current skincare routine")
            recommendations.append("Continue using SPF daily")
        }

        // Determine skin type from manual input or default
        let skinType = manualSkinType ?? "Normal"

        // Calculate basic health score
        let healthScore = calculateHealthScore(concerns: concerns)

        return AnalysisData(
            skinType: skinType,
            hydrationLevel: manualHydrationLevel.flatMap { Int($0) },
            sensitivity: manualSensitivity ?? "Normal",
            concerns: concerns.isEmpty ? nil : concerns,
            poreCondition: manualPoreCondition ?? "Normal",
            skinHealthScore: healthScore,
            recommendations: recommendations,
            productRecommendations: productRecommendations.isEmpty ? nil : productRecommendations,
            medicalConsiderations: buildMedicalConsiderations(
                medicalHistory: medicalHistory,
                allergies: allergies,
                medications: medications
            ),
            progressNotes: buildProgressNotes(previousAnalyses: previousAnalyses)
        )
    }

    // MARK: - Claude Vision Analysis (Paid)
    private func analyzeWithClaude(
        image: UIImage,
        medicalHistory: String?,
        allergies: String?,
        knownSensitivities: String?,
        medications: String?,
        manualSkinType: String?,
        manualHydrationLevel: String?,
        manualSensitivity: String?,
        manualPoreCondition: String?,
        manualConcerns: String?,
        productsUsed: String?,
        treatmentsPerformed: String?,
        injectablesHistory: String?,
        previousAnalyses: [SkinAnalysisResult],
        aiRules: [AIRule]
    ) async throws -> AnalysisData {
        guard !AppConstants.claudeApiKey.isEmpty else {
            throw NSError(domain: "AIAnalysisService", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Claude API key not configured. Add your key to AppConstants.claudeApiKey"
            ])
        }

        // Convert image to base64
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw NSError(domain: "AIAnalysisService", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "Failed to convert image to JPEG"
            ])
        }
        let base64Image = imageData.base64EncodedString()

        // Build the prompt
        let prompt = buildClaudePrompt(
            medicalHistory: medicalHistory,
            allergies: allergies,
            knownSensitivities: knownSensitivities,
            medications: medications,
            manualSkinType: manualSkinType,
            manualHydrationLevel: manualHydrationLevel,
            manualSensitivity: manualSensitivity,
            manualPoreCondition: manualPoreCondition,
            manualConcerns: manualConcerns,
            productsUsed: productsUsed,
            treatmentsPerformed: treatmentsPerformed,
            injectablesHistory: injectablesHistory,
            previousAnalyses: previousAnalyses,
            aiRules: aiRules
        )

        // Call Claude API
        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(AppConstants.claudeApiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let requestBody: [String: Any] = [
            "model": "claude-3-5-sonnet-20241022",
            "max_tokens": 2048,
            "messages": [
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "image",
                            "source": [
                                "type": "base64",
                                "media_type": "image/jpeg",
                                "data": base64Image
                            ]
                        ],
                        [
                            "type": "text",
                            "text": prompt
                        ]
                    ]
                ]
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "AIAnalysisService", code: 3, userInfo: [
                NSLocalizedDescriptionKey: "Invalid response from Claude API"
            ])
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "AIAnalysisService", code: httpResponse.statusCode, userInfo: [
                NSLocalizedDescriptionKey: "Claude API error: \(errorMessage)"
            ])
        }

        // Parse Claude response
        return try parseClaudeResponse(data: data)
    }

    // MARK: - Helper Methods

    private func analyzeBrightness(cgImage: CGImage) async -> CGFloat {
        return await withCheckedContinuation { continuation in
            let ciImage = CIImage(cgImage: cgImage)
            let extentVector = CIVector(x: ciImage.extent.origin.x, y: ciImage.extent.origin.y, z: ciImage.extent.size.width, w: ciImage.extent.size.height)

            guard let filter = CIFilter(name: "CIAreaAverage", parameters: [kCIInputImageKey: ciImage, kCIInputExtentKey: extentVector]) else {
                continuation.resume(returning: 0.5)
                return
            }
            guard let outputImage = filter.outputImage else {
                continuation.resume(returning: 0.5)
                return
            }

            var bitmap = [UInt8](repeating: 0, count: 4)
            let context = CIContext(options: [.workingColorSpace: kCFNull as Any])
            context.render(outputImage, toBitmap: &bitmap, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: nil)

            let brightness = (CGFloat(bitmap[0]) + CGFloat(bitmap[1]) + CGFloat(bitmap[2])) / (3.0 * 255.0)
            continuation.resume(returning: brightness)
        }
    }

    private func analyzeDominantColors(cgImage: CGImage) async -> [UIColor] {
        // Simplified color analysis
        return []
    }

    private func applyAIRules(concerns: [String], rules: [AIRule]) -> [String] {
        var productRecommendations: [String] = []

        // Sort rules by priority (highest first)
        let activeRules = rules.filter { $0.isActive == true }.sorted { ($0.priority ?? 0) > ($1.priority ?? 0) }

        for rule in activeRules {
            guard let condition = rule.condition?.lowercased(),
                  let action = rule.action else { continue }

            // Check if any concern matches the rule condition
            let concernsMatch = concerns.contains { concern in
                concern.lowercased().contains(condition) || condition.contains(concern.lowercased())
            }

            if concernsMatch {
                productRecommendations.append(action)
            }
        }

        return productRecommendations
    }

    private func calculateHealthScore(concerns: [String]) -> Int {
        let baseScore = 85
        let deduction = concerns.count * 10
        return max(0, min(100, baseScore - deduction))
    }

    private func buildMedicalConsiderations(medicalHistory: String?, allergies: String?, medications: String?) -> [String]? {
        var considerations: [String] = []

        if let allergies = allergies, !allergies.isEmpty {
            considerations.append("Avoid products containing: \(allergies)")
        }
        if let medications = medications, !medications.isEmpty {
            considerations.append("Current medications may affect skin sensitivity")
        }

        return considerations.isEmpty ? nil : considerations
    }

    private func buildProgressNotes(previousAnalyses: [SkinAnalysisResult]) -> [String]? {
        guard !previousAnalyses.isEmpty else { return nil }

        var notes: [String] = []
        if previousAnalyses.count > 1 {
            notes.append("This is analysis #\(previousAnalyses.count + 1)")
        }
        return notes
    }

    private func buildClaudePrompt(
        medicalHistory: String?,
        allergies: String?,
        knownSensitivities: String?,
        medications: String?,
        manualSkinType: String?,
        manualHydrationLevel: String?,
        manualSensitivity: String?,
        manualPoreCondition: String?,
        manualConcerns: String?,
        productsUsed: String?,
        treatmentsPerformed: String?,
        injectablesHistory: String?,
        previousAnalyses: [SkinAnalysisResult],
        aiRules: [AIRule]
    ) -> String {
        var prompt = """
        You are an expert skin analysis AI for estheticians and spa professionals. Analyze this skin image and provide a detailed assessment.

        """

        // Add client context
        if let medicalHistory = medicalHistory, !medicalHistory.isEmpty {
            prompt += "Medical History: \(medicalHistory)\n"
        }
        if let allergies = allergies, !allergies.isEmpty {
            prompt += "Allergies: \(allergies)\n"
        }
        if let knownSensitivities = knownSensitivities, !knownSensitivities.isEmpty {
            prompt += "Known Sensitivities: \(knownSensitivities)\n"
        }
        if let medications = medications, !medications.isEmpty {
            prompt += "Medications: \(medications)\n"
        }
        if let injectablesHistory = injectablesHistory, !injectablesHistory.isEmpty {
            prompt += "Injectables History: \(injectablesHistory)\n"
        }

        // Add manual assessments if provided
        if let manualSkinType = manualSkinType {
            prompt += "Esthetician's skin type assessment: \(manualSkinType)\n"
        }

        // Add AI Rules
        if !aiRules.isEmpty {
            prompt += "\nIMPORTANT - Apply these professional rules when making product recommendations:\n"
            for (index, rule) in aiRules.enumerated() {
                if let condition = rule.condition, let action = rule.action {
                    prompt += "\(index + 1). WHEN: \(condition) → THEN recommend: \(action) (Priority: \(rule.priority ?? 0))\n"
                }
            }
        }

        prompt += """

        Provide your analysis in this EXACT JSON format:
        {
          "skinType": "Normal/Dry/Oily/Combination/Sensitive",
          "hydrationLevel": 1-10,
          "sensitivity": "Low/Normal/High",
          "concerns": ["concern1", "concern2"],
          "poreCondition": "Fine/Normal/Enlarged",
          "skinHealthScore": 0-100,
          "recommendations": ["recommendation1", "recommendation2"],
          "productRecommendations": ["product1", "product2"],
          "medicalConsiderations": ["consideration1"]
        }

        CRITICAL: The "productRecommendations" field must contain product recommendations that follow the AI rules provided above. Match the detected concerns with the rule conditions and apply the corresponding actions.
        """

        return prompt
    }

    private func parseClaudeResponse(data: Data) throws -> AnalysisData {
        struct ClaudeResponse: Codable {
            let content: [ClaudeContent]
        }

        struct ClaudeContent: Codable {
            let type: String
            let text: String
        }

        let response = try JSONDecoder().decode(ClaudeResponse.self, from: data)
        guard let text = response.content.first?.text else {
            throw NSError(domain: "AIAnalysisService", code: 4, userInfo: [
                NSLocalizedDescriptionKey: "No text content in Claude response"
            ])
        }

        // Extract JSON from response (Claude may wrap it in markdown)
        var jsonText = text
        if let jsonStart = text.range(of: "{"),
           let jsonEnd = text.range(of: "}", options: .backwards) {
            jsonText = String(text[jsonStart.lowerBound...jsonEnd.upperBound])
        }

        guard let jsonData = jsonText.data(using: .utf8) else {
            throw NSError(domain: "AIAnalysisService", code: 5, userInfo: [
                NSLocalizedDescriptionKey: "Failed to convert response to data"
            ])
        }

        let analysisResponse = try JSONDecoder().decode(AIAnalysisResponse.self, from: jsonData)

        return AnalysisData(
            skinType: analysisResponse.skinType,
            hydrationLevel: analysisResponse.hydrationLevel,
            sensitivity: analysisResponse.sensitivity,
            concerns: analysisResponse.concerns,
            poreCondition: analysisResponse.poreCondition,
            skinHealthScore: analysisResponse.skinHealthScore,
            recommendations: analysisResponse.recommendations,
            productRecommendations: analysisResponse.productRecommendations,
            medicalConsiderations: analysisResponse.medicalConsiderations,
            progressNotes: analysisResponse.progressNotes
        )
    }
}

// Helper extension for color analysis
extension UIColor {
    var isReddish: Bool {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        getRed(&red, green: &green, blue: &blue, alpha: nil)
        return red > 0.6 && red > green && red > blue
    }
}
