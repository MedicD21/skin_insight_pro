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
        productsToAvoid: String?,
        manualSkinType: String?,
        manualHydrationLevel: String?,
        manualSensitivity: String?,
        manualPoreCondition: String?,
        manualConcerns: String?,
        productsUsed: String?,
        treatmentsPerformed: String?,
        injectablesHistory: String?,
        previousAnalyses: [SkinAnalysisResult],
        aiRules: [AIRule],
        products: [Product] = []
    ) async throws -> AnalysisData {
        switch AppConstants.aiProvider {
        case .appleVision:
            return try await analyzeWithAppleVision(
                image: image,
                medicalHistory: medicalHistory,
                allergies: allergies,
                knownSensitivities: knownSensitivities,
                medications: medications,
                productsToAvoid: productsToAvoid,
                manualSkinType: manualSkinType,
                manualHydrationLevel: manualHydrationLevel,
                manualSensitivity: manualSensitivity,
                manualPoreCondition: manualPoreCondition,
                manualConcerns: manualConcerns,
                productsUsed: productsUsed,
                treatmentsPerformed: treatmentsPerformed,
                injectablesHistory: injectablesHistory,
                previousAnalyses: previousAnalyses,
                aiRules: aiRules,
                products: products
            )
        case .claude:
            return try await analyzeWithClaude(
                image: image,
                medicalHistory: medicalHistory,
                allergies: allergies,
                knownSensitivities: knownSensitivities,
                medications: medications,
                productsToAvoid: productsToAvoid,
                manualSkinType: manualSkinType,
                manualHydrationLevel: manualHydrationLevel,
                manualSensitivity: manualSensitivity,
                manualPoreCondition: manualPoreCondition,
                manualConcerns: manualConcerns,
                productsUsed: productsUsed,
                treatmentsPerformed: treatmentsPerformed,
                injectablesHistory: injectablesHistory,
                previousAnalyses: previousAnalyses,
                aiRules: aiRules,
                products: products
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
        productsToAvoid: String?,
        manualSkinType: String?,
        manualHydrationLevel: String?,
        manualSensitivity: String?,
        manualPoreCondition: String?,
        manualConcerns: String?,
        productsUsed: String?,
        treatmentsPerformed: String?,
        injectablesHistory: String?,
        previousAnalyses: [SkinAnalysisResult],
        aiRules: [AIRule],
        products: [Product]
    ) async throws -> AnalysisData {
        // Apple Vision with enhanced image analysis
        var concerns: [String] = []
        var recommendations: [String] = []
        var productRecommendations: [String] = []
        var imageMetrics: ImageMetrics?

        // Use manual inputs if provided
        if let manualConcerns = manualConcerns, !manualConcerns.isEmpty {
            concerns = manualConcerns.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        }

        // Perform enhanced image analysis
        if let cgImage = image.cgImage {
            imageMetrics = await analyzeImageMetrics(cgImage: cgImage)

            // Analyze brightness for dark spots and hyperpigmentation
            if let imageMetrics, imageMetrics.brightness < 0.35 {
                if !concerns.contains("Dark spots") {
                    concerns.append("Dark spots")
                }
            }

            // Analyze redness
            if let imageMetrics, imageMetrics.rednessLevel > 0.45 {
                if !concerns.contains("Redness") {
                    concerns.append("Redness")
                }
            }

            // Analyze texture/smoothness
            if let imageMetrics, imageMetrics.textureVariance > 0.6 {
                if !concerns.contains("Uneven texture") {
                    concerns.append("Uneven texture")
                }
            }

            // Analyze oiliness (high brightness + color saturation)
            if let imageMetrics, imageMetrics.brightness > 0.7 && imageMetrics.saturation > 0.5 {
                if !concerns.contains("Excess oil") {
                    concerns.append("Excess oil")
                }
            }

            // Analyze dryness (low saturation, uneven texture)
            if let imageMetrics, imageMetrics.saturation < 0.3 && imageMetrics.textureVariance > 0.5 {
                if !concerns.contains("Dryness") {
                    concerns.append("Dryness")
                }
            }

            // Indicate pores when texture variance is elevated
            if let imageMetrics, imageMetrics.textureVariance > 0.55 {
                if !concerns.contains("Enlarged pores") {
                    concerns.append("Enlarged pores")
                }
            }
        }

        // Apply AI Rules to recommendations (not product recommendations)
        let appliedRules = applyAIRules(concerns: concerns, rules: aiRules)
        recommendations.append(contentsOf: appliedRules)

        // Match Products only for product recommendations
        let matchedProducts = matchProducts(
            concerns: concerns,
            skinType: manualSkinType,
            products: products,
            allergies: allergies,
            sensitivities: knownSensitivities
        )
        productRecommendations = matchedProducts

        // Generate intelligent recommendations based on detected concerns
        if concerns.contains("Redness") {
            recommendations.append("Use a gentle, fragrance-free cleanser to avoid irritation")
            recommendations.append("Apply products with soothing ingredients like centella asiatica, aloe, or niacinamide")
            recommendations.append("Avoid hot water and harsh exfoliants")
        }
        if concerns.contains("Dark spots") {
            recommendations.append("Use vitamin C serum in the morning for brightening")
            recommendations.append("Apply SPF 50+ daily to prevent further darkening")
            recommendations.append("Consider retinol or alpha hydroxy acids for evening use")
        }
        if concerns.contains("Uneven texture") {
            recommendations.append("Incorporate gentle chemical exfoliation (AHA/BHA) 2-3x weekly")
            recommendations.append("Use a hydrating serum with hyaluronic acid")
        }
        if concerns.contains("Excess oil") {
            recommendations.append("Use a salicylic acid cleanser to control oil")
            recommendations.append("Apply lightweight, oil-free moisturizer")
            recommendations.append("Use clay masks 1-2x weekly")
        }
        if concerns.contains("Dryness") {
            recommendations.append("Use a creamy, hydrating cleanser")
            recommendations.append("Apply a rich moisturizer with ceramides and hyaluronic acid")
            recommendations.append("Consider adding a facial oil for extra hydration")
        }
        if concerns.contains("Enlarged pores") {
            recommendations.append("Use niacinamide or salicylic acid to help minimize pore appearance")
            recommendations.append("Avoid heavy, occlusive products that can clog pores")
        }
        if concerns.isEmpty {
            recommendations.append("Skin appears healthy - maintain current routine")
            recommendations.append("Continue daily SPF protection")
            recommendations.append("Keep skin hydrated with regular moisturizer use")
        }

        // Determine skin type and key metrics
        let skinType = manualSkinType ?? inferSkinType(metrics: imageMetrics)
        let hydrationLevel = parseManualHydrationLevel(manualHydrationLevel)
            ?? estimateHydrationLevel(metrics: imageMetrics)
        let sensitivity = manualSensitivity ?? inferSensitivity(metrics: imageMetrics, concerns: concerns)
        let poreCondition = manualPoreCondition ?? inferPoreCondition(metrics: imageMetrics, concerns: concerns)

        // Calculate basic health score
        let healthScore = calculateHealthScore(concerns: concerns)

        return AnalysisData(
            skinType: skinType,
            hydrationLevel: hydrationLevel,
            sensitivity: sensitivity,
            concerns: concerns.isEmpty ? nil : concerns,
            poreCondition: poreCondition,
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
        productsToAvoid: String?,
        manualSkinType: String?,
        manualHydrationLevel: String?,
        manualSensitivity: String?,
        manualPoreCondition: String?,
        manualConcerns: String?,
        productsUsed: String?,
        treatmentsPerformed: String?,
        injectablesHistory: String?,
        previousAnalyses: [SkinAnalysisResult],
        aiRules: [AIRule],
        products: [Product]
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
            productsToAvoid: productsToAvoid,
            manualSkinType: manualSkinType,
            manualHydrationLevel: manualHydrationLevel,
            manualSensitivity: manualSensitivity,
            manualPoreCondition: manualPoreCondition,
            manualConcerns: manualConcerns,
            productsUsed: productsUsed,
            treatmentsPerformed: treatmentsPerformed,
            injectablesHistory: injectablesHistory,
            previousAnalyses: previousAnalyses,
            aiRules: aiRules,
            products: products
        )

        // Call Claude API
        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(AppConstants.claudeApiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let requestBody: [String: Any] = [
            "model": "claude-sonnet-4-5-20250929",
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

    struct ImageMetrics {
        let brightness: CGFloat
        let rednessLevel: CGFloat
        let saturation: CGFloat
        let textureVariance: CGFloat
    }

    private func analyzeImageMetrics(cgImage: CGImage) async -> ImageMetrics {
        return await withCheckedContinuation { continuation in
            let ciImage = CIImage(cgImage: cgImage)
            let extentVector = CIVector(x: ciImage.extent.origin.x, y: ciImage.extent.origin.y, z: ciImage.extent.size.width, w: ciImage.extent.size.height)

            // Analyze average color
            guard let averageFilter = CIFilter(name: "CIAreaAverage", parameters: [kCIInputImageKey: ciImage, kCIInputExtentKey: extentVector]),
                  let outputImage = averageFilter.outputImage else {
                continuation.resume(returning: ImageMetrics(brightness: 0.5, rednessLevel: 0.3, saturation: 0.4, textureVariance: 0.4))
                return
            }

            var bitmap = [UInt8](repeating: 0, count: 4)
            let context = CIContext(options: [.workingColorSpace: kCFNull as Any])
            context.render(outputImage, toBitmap: &bitmap, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: nil)

            let r = CGFloat(bitmap[0]) / 255.0
            let g = CGFloat(bitmap[1]) / 255.0
            let b = CGFloat(bitmap[2]) / 255.0

            // Calculate metrics
            let brightness = (r + g + b) / 3.0
            let rednessLevel = r / max(g + b, 0.01) // How much more red than other colors

            // Calculate saturation
            let maxChannel = max(r, g, b)
            let minChannel = min(r, g, b)
            let saturation = maxChannel > 0 ? (maxChannel - minChannel) / maxChannel : 0

            // Estimate texture variance using edge detection
            let edgeFilter = CIFilter(name: "CIEdges")
            edgeFilter?.setValue(ciImage, forKey: kCIInputImageKey)
            edgeFilter?.setValue(1.5, forKey: kCIInputIntensityKey)

            var textureVariance: CGFloat = 0.4 // Default
            if let edgeOutput = edgeFilter?.outputImage {
                let avgEdgeFilter = CIFilter(name: "CIAreaAverage", parameters: [kCIInputImageKey: edgeOutput, kCIInputExtentKey: extentVector])
                if let edgeAvg = avgEdgeFilter?.outputImage {
                    var edgeBitmap = [UInt8](repeating: 0, count: 4)
                    context.render(edgeAvg, toBitmap: &edgeBitmap, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: nil)
                    textureVariance = CGFloat(edgeBitmap[0]) / 255.0
                }
            }

            let metrics = ImageMetrics(
                brightness: brightness,
                rednessLevel: rednessLevel,
                saturation: saturation,
                textureVariance: textureVariance
            )

            continuation.resume(returning: metrics)
        }
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

    private func matchProducts(
        concerns: [String],
        skinType: String?,
        products: [Product],
        allergies: String?,
        sensitivities: String?
    ) -> [String] {
        var matchedProducts: [String] = []

        // Build list of ingredients to avoid
        var ingredientsToAvoid: [String] = []
        if let allergies = allergies, !allergies.isEmpty {
            ingredientsToAvoid.append(contentsOf: allergies.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces).lowercased() })
        }
        if let sensitivities = sensitivities, !sensitivities.isEmpty {
            ingredientsToAvoid.append(contentsOf: sensitivities.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces).lowercased() })
        }

        // Filter active products
        let activeProducts = products.filter { $0.isActive == true }

        // Group products by concern they address
        var productsByConcern: [String: [Product]] = [:]
        for concern in concerns {
            productsByConcern[concern] = []
        }

        for product in activeProducts {
            // Check if product ingredients contain allergens
            if let ingredients = product.ingredients {
                let hasAllergen = ingredientsToAvoid.contains { allergen in
                    ingredients.lowercased().contains(allergen)
                }
                if hasAllergen {
                    continue // Skip this product
                }
            }

            // Check skin type compatibility
            if let skinType = skinType, let productSkinTypes = product.skinTypes, !productSkinTypes.isEmpty {
                let isCompatible = productSkinTypes.contains { productSkinType in
                    productSkinType.lowercased().contains(skinType.lowercased()) ||
                    skinType.lowercased().contains(productSkinType.lowercased())
                }
                if !isCompatible {
                    continue // Skip if skin type doesn't match
                }
            }

            // Match product to concerns
            if let productConcerns = product.concerns {
                for concern in concerns {
                    let matches = productConcerns.contains { productConcern in
                        concern.lowercased().contains(productConcern.lowercased()) ||
                        productConcern.lowercased().contains(concern.lowercased())
                    }
                    if matches {
                        productsByConcern[concern]?.append(product)
                    }
                }
            }
        }

        // Select best 2-3 products per concern
        for (_, productsForConcern) in productsByConcern {
            let topProducts = Array(productsForConcern.prefix(3)) // Take top 3

            for product in topProducts {
                let productName: String
                if let brand = product.brand, let name = product.name {
                    productName = "\(brand) - \(name)"
                } else if let name = product.name {
                    productName = name
                } else {
                    continue
                }

                // Avoid duplicates
                if !matchedProducts.contains(productName) {
                    matchedProducts.append(productName)
                }
            }
        }

        return matchedProducts
    }

    private func calculateHealthScore(concerns: [String]) -> Int {
        let baseScore = 85
        let deduction = concerns.count * 10
        return max(0, min(100, baseScore - deduction))
    }

    private func parseManualHydrationLevel(_ manualHydrationLevel: String?) -> Int? {
        guard let manualHydrationLevel else { return nil }
        let digits = manualHydrationLevel.compactMap { $0.isNumber ? $0 : nil }
        let value = Int(String(digits))
        guard let parsed = value else { return nil }
        return max(0, min(100, parsed))
    }

    private func estimateHydrationLevel(metrics: ImageMetrics?) -> Int {
        guard let metrics else { return 65 }

        var hydration = 65.0
        hydration -= max(0.0, (0.35 - metrics.saturation)) * 140.0
        hydration -= max(0.0, (metrics.textureVariance - 0.5)) * 80.0
        hydration += max(0.0, (metrics.saturation - 0.5)) * 40.0
        hydration -= max(0.0, (metrics.rednessLevel - 0.6)) * 15.0

        return max(0, min(100, Int(hydration.rounded())))
    }

    private func inferSkinType(metrics: ImageMetrics?) -> String {
        guard let metrics else { return "Normal" }

        let isDry = metrics.saturation < 0.35 && metrics.textureVariance > 0.5
        let isOily = metrics.brightness > 0.65 && metrics.saturation > 0.45

        if isDry && isOily {
            return "Combination"
        }
        if isOily {
            return "Oily"
        }
        if isDry {
            return "Dry"
        }
        return "Normal"
    }

    private func inferSensitivity(metrics: ImageMetrics?, concerns: [String]) -> String {
        if concerns.contains("Redness") {
            return "High"
        }
        guard let metrics else { return "Normal" }

        if metrics.rednessLevel > 0.6 {
            return "High"
        }
        if metrics.rednessLevel > 0.45 {
            return "Moderate"
        }
        return "Normal"
    }

    private func inferPoreCondition(metrics: ImageMetrics?, concerns: [String]) -> String {
        if concerns.contains("Enlarged pores") {
            return "Enlarged"
        }
        guard let metrics else { return "Normal" }

        if metrics.textureVariance > 0.6 {
            return "Enlarged"
        }
        if metrics.textureVariance < 0.3 {
            return "Fine"
        }
        return "Normal"
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
        productsToAvoid: String?,
        manualSkinType: String?,
        manualHydrationLevel: String?,
        manualSensitivity: String?,
        manualPoreCondition: String?,
        manualConcerns: String?,
        productsUsed: String?,
        treatmentsPerformed: String?,
        injectablesHistory: String?,
        previousAnalyses: [SkinAnalysisResult],
        aiRules: [AIRule],
        products: [Product]
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
        if let productsToAvoid = productsToAvoid, !productsToAvoid.isEmpty {
            prompt += "⚠️ PRODUCTS TO AVOID: \(productsToAvoid) - DO NOT recommend any products containing these ingredients or products\n"
        }
        if let injectablesHistory = injectablesHistory, !injectablesHistory.isEmpty {
            prompt += "Injectables History: \(injectablesHistory)\n"
        }

        // Add manual assessments if provided
        if let manualSkinType = manualSkinType {
            prompt += "Esthetician's skin type assessment: \(manualSkinType)\n"
        }
        if let manualHydrationLevel = manualHydrationLevel, !manualHydrationLevel.isEmpty {
            prompt += "Esthetician's hydration assessment (percent): \(manualHydrationLevel)\n"
        }

        // Add AI Rules
        if !aiRules.isEmpty {
            prompt += "\n\nCUSTOM AI RULES - These are professional rules you MUST follow:\n"
            for (index, rule) in aiRules.enumerated() {
                if let condition = rule.condition, let action = rule.action {
                    prompt += "Rule \(index + 1): IF skin shows \"\(condition)\" THEN add to recommendations: \"\(action)\" (Priority: \(rule.priority ?? 0))\n"
                }
            }
        }

        // Add Available Products
        if !products.isEmpty {
            let activeProducts = products.filter { $0.isActive == true }
            if !activeProducts.isEmpty {
                prompt += "\n\nAVAILABLE PRODUCTS CATALOG - Use your professional judgment to select the BEST products:\n"
                for (index, product) in activeProducts.enumerated() {
                    if let name = product.name {
                        let brand = product.brand ?? ""
                        let productName = brand.isEmpty ? name : "\(brand) - \(name)"

                        var productDetails = "Product \(index + 1): \"\(productName)\""

                        if let skinTypes = product.skinTypes, !skinTypes.isEmpty {
                            productDetails += " | Skin Types: \(skinTypes.joined(separator: ", "))"
                        }
                        if let concerns = product.concerns, !concerns.isEmpty {
                            productDetails += " | Addresses: \(concerns.joined(separator: ", "))"
                        }
                        if let ingredients = product.ingredients, !ingredients.isEmpty {
                            productDetails += " | Key Ingredients: \(ingredients)"
                        }
                        if let allIngredients = product.allIngredients, !allIngredients.isEmpty {
                            productDetails += " | ALL Ingredients: \(allIngredients)"
                        }
                        if let description = product.description, !description.isEmpty {
                            productDetails += " | Details: \(description)"
                        }

                        prompt += productDetails + "\n"
                    }
                }
            }
        }

        prompt += """

        Provide your analysis in this EXACT JSON format:
        {
          "skin_type": "Normal/Dry/Oily/Combination/Sensitive",
          "hydration_level": 0-100,
          "sensitivity": "Low/Normal/High",
          "concerns": ["concern1", "concern2"],
          "pore_condition": "Fine/Normal/Enlarged",
          "skin_health_score": 0-100,
          "recommendations": ["recommendation1", "recommendation2"],
          "product_recommendations": ["product1", "product2"],
          "medical_considerations": ["consideration1"]
        }

        HYDRATION GUIDANCE:
        - "hydration_level" is an estimated percent (0-100) of moisture appearance.
        - Avoid single-digit values unless the skin is extremely dehydrated.
        - Typical ranges: 20-35 severely dehydrated, 36-50 low, 51-65 moderate, 66-80 good, 81-95 excellent.
        - Use the esthetician’s hydration assessment if provided, adjusted only if the photo strongly contradicts it.

        METRIC GUIDANCE:
        - "skin_type" should reflect oil vs dryness cues in the photo (shine, texture, flaking) and avoid defaulting to Normal.
        - "sensitivity" should be Low/Normal/High and based on visible redness/irritation or reactive indicators.
        - "pore_condition" should be Fine/Normal/Enlarged based on visible pore size/texture.
        - "skin_health_score" should be 0-100 and reflect the overall condition given concerns, hydration, and sensitivity.

        CRITICAL INSTRUCTIONS FOR TWO SEPARATE FIELDS:

        1. "recommendations" - Include BOTH:
           a) Your own professional skincare recommendations based on the analysis
           b) ALL matching custom AI rules (check detected concerns against rule conditions and include every match)

        2. "product_recommendations" - ONLY matching products from the catalog:
           - Consider detected skin type and concerns
           - Select products that address the specific concerns
           - From multiple products addressing the same concern, choose the BEST 2-3 based on ingredients and efficacy
           - ⚠️ CRITICAL SAFETY CHECK: For EACH product, check BOTH "Key Ingredients" AND "ALL Ingredients" lists against:
             * Client's Allergies
             * Client's Known Sensitivities
             * Products to Avoid list
           - SKIP ANY PRODUCT that contains ANY ingredient matching the above lists (check both partial and full matches)
           - Format products as: "Brand - Product Name"
           - DO NOT include AI rules here, they belong in "recommendations"

        Example: If you detect "Redness" and "Dry" skin type:
        - recommendations: Your professional advice + ALL matching AI rules
        - product_recommendations: The 2-3 BEST products for redness on dry skin (excluding allergens)
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

        let hydratedLevel = normalizeHydrationLevel(analysisResponse.hydrationLevel)
        let skinType = normalizeSkinType(analysisResponse.skinType)
        let sensitivity = normalizeSensitivity(analysisResponse.sensitivity)
        let poreCondition = normalizePoreCondition(analysisResponse.poreCondition)
        let healthScore = normalizeHealthScore(analysisResponse.skinHealthScore, concerns: analysisResponse.concerns)

        return AnalysisData(
            skinType: skinType,
            hydrationLevel: hydratedLevel,
            sensitivity: sensitivity,
            concerns: analysisResponse.concerns,
            poreCondition: poreCondition,
            skinHealthScore: healthScore,
            recommendations: analysisResponse.recommendations,
            productRecommendations: analysisResponse.productRecommendations,
            medicalConsiderations: analysisResponse.medicalConsiderations,
            progressNotes: analysisResponse.progressNotes
        )
    }

    private func normalizeHydrationLevel(_ hydrationLevel: Int?) -> Int? {
        guard let hydrationLevel else { return nil }
        if hydrationLevel <= 10 {
            return max(0, min(100, hydrationLevel * 10))
        }
        return max(0, min(100, hydrationLevel))
    }

    private func normalizeSkinType(_ skinType: String?) -> String? {
        guard let skinType, !skinType.isEmpty else { return nil }
        let value = skinType.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if value.contains("comb") {
            return "Combination"
        }
        if value.contains("oily") {
            return "Oily"
        }
        if value.contains("dry") {
            return "Dry"
        }
        if value.contains("sens") {
            return "Sensitive"
        }
        return "Normal"
    }

    private func normalizeSensitivity(_ sensitivity: String?) -> String? {
        guard let sensitivity, !sensitivity.isEmpty else { return nil }
        let value = sensitivity.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if value.contains("high") {
            return "High"
        }
        if value.contains("low") {
            return "Low"
        }
        return "Normal"
    }

    private func normalizePoreCondition(_ poreCondition: String?) -> String? {
        guard let poreCondition, !poreCondition.isEmpty else { return nil }
        let value = poreCondition.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if value.contains("enlarg") {
            return "Enlarged"
        }
        if value.contains("fine") {
            return "Fine"
        }
        return "Normal"
    }

    private func normalizeHealthScore(_ skinHealthScore: Int?, concerns: [String]?) -> Int? {
        if let skinHealthScore {
            return max(0, min(100, skinHealthScore))
        }

        let concernCount = concerns?.count ?? 0
        return calculateHealthScore(concerns: Array(repeating: "", count: concernCount))
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
