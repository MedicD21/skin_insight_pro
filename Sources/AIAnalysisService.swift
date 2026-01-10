import UIKit
import Vision
import VisionKit
import CoreImage

class AIAnalysisService {
    static let shared = AIAnalysisService()
    private init() {}
    private let ciContext = CIContext()

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

        // Perform comprehensive skin image analysis with multiple passes
        var comprehensiveMetrics: SkinImageAnalyzer.ComprehensiveMetrics?
        if image.cgImage != nil {
            let skinAnalyzer = SkinImageAnalyzer()
            let variants = generateImageVariants(from: image)
            var metricsPasses: [SkinImageAnalyzer.ComprehensiveMetrics] = []
            metricsPasses.reserveCapacity(variants.count)

            for variant in variants {
                let metrics = await skinAnalyzer.analyze(image: variant)
                metricsPasses.append(metrics)
            }

            comprehensiveMetrics = selectMostSevereMetrics(from: metricsPasses)

            if let metrics = comprehensiveMetrics {
                imageMetrics = ImageMetrics(
                    brightness: metrics.perceptualColor.averageBrightness,
                    rednessLevel: max(0, metrics.perceptualColor.averageRedness / 20.0),
                    saturation: metrics.perceptualColor.averageSaturation,
                    textureVariance: (metrics.texture.fineTextureLevel + metrics.texture.mediumTextureLevel + metrics.texture.coarseTextureLevel) / 3.0
                )
            }

            // Aggregate concerns across passes to catch subtle issues
            if metricsPasses.contains(where: { $0.pigmentation.hyperpigmentationLevel > 0.35 }) {
                if !concerns.contains("Dark Spots") {
                    concerns.append("Dark Spots")
                }
            }

            if metricsPasses.contains(where: {
                $0.vascular.overallRednessLevel == SkinImageAnalyzer.VascularMetrics.RednessLevel.elevated ||
                $0.vascular.overallRednessLevel == SkinImageAnalyzer.VascularMetrics.RednessLevel.high ||
                $0.perceptualColor.averageRedness > 8
            }) {
                if !concerns.contains("Redness") {
                    concerns.append("Redness")
                }
            }

            if metricsPasses.contains(where: { $0.texture.smoothness < 0.45 }) {
                if !concerns.contains("Uneven Texture") {
                    concerns.append("Uneven Texture")
                }
            }

            if metricsPasses.contains(where: { $0.structure.lineDensity > 0.45 }) {
                if !concerns.contains("Fine Lines") {
                    concerns.append("Fine Lines")
                }
            }

            if metricsPasses.contains(where: { $0.texture.flakingLikelihood > 0.4 }) {
                if !concerns.contains("Dryness") {
                    concerns.append("Dryness")
                }
            }

            if metricsPasses.contains(where: { $0.texture.porelikeStructures > 0.45 }) {
                if !concerns.contains("Enlarged Pores") {
                    concerns.append("Enlarged Pores")
                }
            }

            if metricsPasses.contains(where: { $0.vascular.hasActiveBreakouts }) {
                if !concerns.contains("Acne") {
                    concerns.append("Acne")
                }
            }

            if metricsPasses.contains(where: { $0.structure.laxityScore > 0.45 }) {
                if !concerns.contains("Aging") {
                    concerns.append("Aging")
                }
            }
        }

        let concernsForScore = concerns
        concerns = expandConcerns(concerns)

        // Apply AI Rules to recommendations (not product recommendations)
        let appliedRules = applyAIRules(concerns: concerns, rules: aiRules)
        recommendations.append(contentsOf: appliedRules)

        // Match Products only for product recommendations
        let matchedProducts = matchProducts(
            concerns: concerns,
            skinType: manualSkinType,
            products: products,
            allergies: allergies,
            sensitivities: knownSensitivities,
            productsToAvoid: productsToAvoid
        )
        productRecommendations = matchedProducts

        let hasOilinessConcern = concerns.contains { concern in
            let normalized = concern.lowercased()
            return normalized == "excess oil" || normalized == "oiliness"
        }

        // Generate intelligent recommendations based on detected concerns
        if concerns.contains("Redness") {
            recommendations.append("Use a gentle, fragrance-free cleanser to avoid irritation")
            recommendations.append("Apply products with soothing ingredients like centella asiatica, aloe, or niacinamide")
            recommendations.append("Avoid hot water and harsh exfoliants")
        }
        if concerns.contains("Dark Spots") {
            recommendations.append("Use vitamin C serum in the morning for brightening")
            recommendations.append("Apply SPF 50+ daily to prevent further darkening")
            recommendations.append("Consider retinol or alpha hydroxy acids for evening use")
        }
        if concerns.contains("Uneven Texture") {
            recommendations.append("Incorporate gentle chemical exfoliation (AHA/BHA) 2-3x weekly")
            recommendations.append("Use a hydrating serum with hyaluronic acid")
        }
        if hasOilinessConcern {
            recommendations.append("Use a salicylic acid cleanser to control oil")
            recommendations.append("Apply lightweight, oil-free moisturizer")
            recommendations.append("Use clay masks 1-2x weekly")
        }
        if concerns.contains("Dryness") {
            recommendations.append("Use a creamy, hydrating cleanser")
            recommendations.append("Apply a rich moisturizer with ceramides and hyaluronic acid")
            recommendations.append("Consider adding a facial oil for extra hydration")
        }
        if concerns.contains("Enlarged Pores") {
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

        // Calculate trending metrics
        let trendingMetrics = calculateTrendingMetrics(
            comprehensiveMetrics: comprehensiveMetrics,
            concerns: concerns,
            skinType: skinType,
            sensitivity: sensitivity,
            poreCondition: poreCondition
        )

        // Calculate health score tuned to align closer to Claude scoring
        let healthScore = calculateAppleHealthScore(concerns: concernsForScore, metrics: trendingMetrics)

        let recommendedRoutine = buildRecommendedRoutine(
            productRecommendations: productRecommendations,
            products: products
        )

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
            progressNotes: buildProgressNotes(previousAnalyses: previousAnalyses),
            oilinessScore: trendingMetrics.oiliness,
            textureScore: trendingMetrics.texture,
            poresScore: trendingMetrics.pores,
            wrinklesScore: trendingMetrics.wrinkles,
            rednessScore: trendingMetrics.redness,
            darkSpotsScore: trendingMetrics.darkSpots,
            acneScore: trendingMetrics.acne,
            sensitivityScore: trendingMetrics.sensitivityScore,
            recommendedRoutine: recommendedRoutine
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
        // Convert image to base64
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw NSError(domain: "AIAnalysisService", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "Failed to convert image to JPEG"
            ])
        }
        let base64Image = imageData.base64EncodedString()

        // Perform comprehensive skin analysis for additional context
        var clinicalSummary: String?
        if image.cgImage != nil {
            let skinAnalyzer = SkinImageAnalyzer()
            let comprehensiveMetrics = await skinAnalyzer.analyze(image: image)
            clinicalSummary = comprehensiveMetrics.clinicalSummary()
            if let summary = clinicalSummary {
                print("📊 CLINICAL SUMMARY:\n\(summary)")
            }
        }

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
            products: products,
            clinicalSummary: clinicalSummary
        )

        // Call Supabase Edge Function (enforces usage caps)
        let url = URL(string: "\(AppConstants.supabaseUrl)/functions/v1/claude-analyze")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(AppConstants.supabaseAnonKey, forHTTPHeaderField: "apikey")

        guard let accessToken = UserDefaults.standard.string(forKey: AppConstants.accessTokenKey),
              !accessToken.isEmpty else {
            throw NSError(domain: "AIAnalysisService", code: 3, userInfo: [
                NSLocalizedDescriptionKey: "Missing authentication token. Please log in again."
            ])
        }
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let requestBody: [String: Any] = [
            "model": "claude-sonnet-4-5-20250929",
            "prompt": prompt,
            "image_base64": base64Image
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 401 {
            let refreshedToken = try await NetworkService.shared.refreshAccessToken()
            var retryRequest = request
            retryRequest.setValue("Bearer \(refreshedToken)", forHTTPHeaderField: "Authorization")
            let (retryData, retryResponse) = try await URLSession.shared.data(for: retryRequest)
            return try await processClaudeResponse(
                data: retryData,
                response: retryResponse,
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

        return try await processClaudeResponse(
            data: data,
            response: response,
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

    private func processClaudeResponse(
        data: Data,
        response: URLResponse,
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
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "AIAnalysisService", code: 3, userInfo: [
                NSLocalizedDescriptionKey: "Invalid response from Claude service"
            ])
        }

        #if DEBUG
        if !(200...299).contains(httpResponse.statusCode),
           let responseBody = String(data: data, encoding: .utf8) {
            print("❌ Claude edge response: \(httpResponse.statusCode) \(responseBody)")
        }
        #endif

        guard (200...299).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 401 {
                let errorDetails = extractClaudeErrorMessage(from: data)
                if let errorDetails,
                   errorDetails.localizedCaseInsensitiveContains("Invalid user token") {
                    var fallbackResult = try await analyzeWithAppleVision(
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
                    fallbackResult.analysisNotice = "Claude session expired. Results generated with Apple Vision. Log in again to restore Claude."
                    return fallbackResult
                }

                let message = errorDetails ?? "Claude authentication failed."
                throw NSError(domain: "AIAnalysisService", code: httpResponse.statusCode, userInfo: [
                    NSLocalizedDescriptionKey: message
                ])
            }

            if httpResponse.statusCode == 402 {
                var fallbackResult = try await analyzeWithAppleVision(
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
                fallbackResult.analysisNotice = "Claude usage limit reached. Results generated with Apple Vision."
                return fallbackResult
            }

            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "AIAnalysisService", code: httpResponse.statusCode, userInfo: [
                NSLocalizedDescriptionKey: errorMessage
            ])
        }

        // Parse Claude response
        return try parseClaudeResponse(data: data, products: products)
    }

    private func extractClaudeErrorMessage(from data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        if let errorString = json["error"] as? String {
            return errorString
        }

        if let errorObject = json["error"] as? [String: Any] {
            if let message = errorObject["message"] as? String {
                return message
            }
            if let type = errorObject["type"] as? String {
                return type
            }
        }

        if let message = json["message"] as? String {
            return message
        }

        return nil
    }

    // MARK: - Helper Methods

    // Legacy ImageMetrics structure maintained for backward compatibility with existing inference functions
    // These are populated from the new ComprehensiveMetrics in analyzeWithAppleVision
    struct ImageMetrics {
        let brightness: CGFloat
        let rednessLevel: CGFloat
        let saturation: CGFloat
        let textureVariance: CGFloat
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

    private func appendConcern(_ concern: String, to concerns: inout [String]) {
        let trimmed = concern.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let exists = concerns.contains { $0.caseInsensitiveCompare(trimmed) == .orderedSame }
        if !exists {
            concerns.append(trimmed)
        }
    }

    private func expandConcerns(_ concerns: [String]) -> [String] {
        var expanded: [String] = []
        let normalized = concerns
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }

        func containsAny(_ terms: [String]) -> Bool {
            normalized.contains { value in
                terms.contains { value.contains($0) }
            }
        }

        let hasFineLinesPlus = containsAny(["fine lines + wrinkles", "fine lines and wrinkles"])
        let hasFineLines = containsAny(["fine line", "fine lines"])
        let hasWrinkles = containsAny(["wrinkle"])

        let hasDiscoloration = containsAny(["discoloration", "discolouration", "uneven tone", "uneven color", "uneven colour"])
        let hasDarkSpots = containsAny(["dark spot", "dark spots", "hyperpigmentation", "pigmentation"])

        let hasBlemishes = containsAny(["blemish", "blemishes", "blackhead", "blackheads", "clogged pores", "pimple", "pimples"])
        let hasAcne = containsAny(["acne", "breakout", "breakouts"])

        let hasDehydrated = containsAny(["dehydrated", "dehydration"])
        let hasDryness = containsAny(["dryness", "dry skin", "flaky", "flaking"])

        let hasDull = containsAny(["dull", "lackluster", "lacklustre", "lifeless"])
        let hasUnevenTexture = containsAny(["uneven texture", "rough texture"])

        let hasEnlargedPores = containsAny(["enlarged pores", "large pores"])
        let hasPores = containsAny(["pores"])

        let hasOiliness = containsAny(["excess oil", "oiliness", "oily", "sebum"])

        let hasRedness = containsAny(["redness", "flushing", "blotching"])
        let hasPuffiness = containsAny(["puffiness", "puffy", "under eye", "under-eye"])
        let hasPollution = containsAny(["pollution", "environmental"])
        let hasScar = containsAny(["scar", "scarring"])
        let hasAging = containsAny(["aging", "ageing", "mature"])

        if hasFineLinesPlus {
            appendConcern("Wrinkles", to: &expanded)
        } else {
            if hasFineLines {
                appendConcern("Fine Lines", to: &expanded)
            }
            if hasWrinkles {
                appendConcern("Wrinkles", to: &expanded)
            }
        }

        if hasDiscoloration {
            appendConcern("Discoloration", to: &expanded)
        }

        if hasDarkSpots {
            appendConcern("Dark Spots", to: &expanded)
        }

        if hasBlemishes {
            appendConcern("Blemishes", to: &expanded)
        }

        if hasAcne {
            appendConcern("Acne", to: &expanded)
        }

        if hasDehydrated {
            appendConcern("Dehydrated Skin", to: &expanded)
        }

        if hasDryness {
            appendConcern("Dryness", to: &expanded)
        }

        if hasDull {
            appendConcern("Dull Skin", to: &expanded)
        }

        if hasUnevenTexture {
            appendConcern("Uneven Texture", to: &expanded)
        }

        if hasEnlargedPores {
            appendConcern("Enlarged Pores", to: &expanded)
        } else if hasPores {
            appendConcern("Pores", to: &expanded)
        }

        if hasOiliness {
            appendConcern("Oiliness", to: &expanded)
        }

        if hasRedness {
            appendConcern("Redness", to: &expanded)
        }

        if hasPuffiness {
            appendConcern("Puffiness Under Eyes", to: &expanded)
        }

        if hasPollution {
            appendConcern("Pollution", to: &expanded)
        }

        if hasScar {
            appendConcern("Scar Prevention", to: &expanded)
        }

        if hasAging {
            appendConcern("Aging", to: &expanded)
        }

        return expanded
    }

    private func parseAvoidList(_ value: String?) -> [String] {
        guard let value, !value.isEmpty else { return [] }
        let separators = CharacterSet(charactersIn: ",;\n")
        return value
            .components(separatedBy: separators)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }
    }

    private func matchProducts(
        concerns: [String],
        skinType: String?,
        products: [Product],
        allergies: String?,
        sensitivities: String?,
        productsToAvoid: String?
    ) -> [String] {
        var matchedProducts: [String] = []

        // Build list of ingredients to avoid
        var ingredientsToAvoid: [String] = []
        ingredientsToAvoid.append(contentsOf: parseAvoidList(allergies))
        ingredientsToAvoid.append(contentsOf: parseAvoidList(sensitivities))
        ingredientsToAvoid.append(contentsOf: parseAvoidList(productsToAvoid))
        if !ingredientsToAvoid.isEmpty {
            ingredientsToAvoid = Array(Set(ingredientsToAvoid))
        }

        // Filter active products
        let activeProducts = products.filter { $0.isActive == true }

        // Group products by concern they address
        var productsByConcern: [String: [Product]] = [:]
        for concern in concerns {
            productsByConcern[concern] = []
        }

        for product in activeProducts {
            // Check if product ingredients contain allergens/avoid list
            let ingredientText = [
                product.ingredients,
                product.allIngredients
            ]
            .compactMap { $0?.lowercased() }
            .joined(separator: " ")

            let nameText = [
                product.brand,
                product.name
            ]
            .compactMap { $0?.lowercased() }
            .joined(separator: " ")

            if !ingredientsToAvoid.isEmpty {
                let hasAllergen = ingredientsToAvoid.contains { allergen in
                    !allergen.isEmpty && (ingredientText.contains(allergen) || nameText.contains(allergen))
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

    private func calculateAppleHealthScore(
        concerns: [String],
        metrics: (oiliness: Double, texture: Double, pores: Double, wrinkles: Double, redness: Double, darkSpots: Double, acne: Double, sensitivityScore: Double)
    ) -> Int {
        let baseScore = Double(calculateHealthScore(concerns: concerns))
        let oilinessIssue = min(10.0, abs(metrics.oiliness - 5.0) * 2.0)
        let textureIssue = min(10.0, 10.0 - metrics.texture)

        let issues = [
            oilinessIssue,
            textureIssue,
            metrics.pores,
            metrics.wrinkles,
            metrics.redness,
            metrics.darkSpots,
            metrics.acne,
            metrics.sensitivityScore
        ]
        let sortedIssues = issues.sorted(by: >)
        let topIssues = sortedIssues.prefix(3)
        let topAverage = topIssues.reduce(0.0, +) / Double(topIssues.count)
        let severityPenalty = max(0.0, topAverage - 5.0) * 4.0
        let improvementBonus = max(0.0, 5.0 - topAverage) * 2.0
        let score = baseScore - severityPenalty + improvementBonus

        return max(0, min(100, Int(score.rounded())))
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
        if concerns.contains("Enlarged Pores") {
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

    private func calculateTrendingMetrics(
        comprehensiveMetrics: SkinImageAnalyzer.ComprehensiveMetrics?,
        concerns: [String],
        skinType: String?,
        sensitivity: String?,
        poreCondition: String?
    ) -> (oiliness: Double, texture: Double, pores: Double, wrinkles: Double, redness: Double, darkSpots: Double, acne: Double, sensitivityScore: Double) {

        // Default scores (0-10 scale)
        var oiliness: Double = 5.0
        var texture: Double = 7.0
        var pores: Double = 4.0
        var wrinkles: Double = 2.0
        var redness: Double = 2.0
        var darkSpots: Double = 2.0
        var acne: Double = 2.0
        var sensitivityScore: Double = 3.0

        // Calculate from comprehensive metrics if available
        if let metrics = comprehensiveMetrics {
            // Oiliness: Based on skin type and brightness
            switch skinType {
            case "Oily": oiliness = 7.5 + (metrics.perceptualColor.averageBrightness * 2.5)
            case "Dry": oiliness = 2.0 + (metrics.perceptualColor.averageBrightness * 1.5)
            case "Combination": oiliness = 5.0 + (metrics.perceptualColor.averageBrightness * 2.0)
            default: oiliness = 5.0
            }
            oiliness = min(10.0, max(0.0, oiliness))

            // Texture: Inverse of smoothness (0 = rough, 10 = smooth)
            texture = metrics.texture.smoothness * 10.0

            // Pores: Based on pore-like structures
            pores = metrics.texture.porelikeStructures * 10.0
            if poreCondition == "Enlarged" {
                pores = max(pores, 6.0)
            } else if poreCondition == "Fine" {
                pores = min(pores, 3.0)
            }

            // Wrinkles: Based on line density and laxity
            wrinkles = (metrics.structure.lineDensity * 6.0) + (metrics.structure.laxityScore * 4.0)
            wrinkles = min(10.0, wrinkles)

            // Redness: Based on vascular metrics
            switch metrics.vascular.overallRednessLevel {
            case SkinImageAnalyzer.VascularMetrics.RednessLevel.minimal:
                redness = 1.0
            case SkinImageAnalyzer.VascularMetrics.RednessLevel.low:
                redness = 3.0
            case SkinImageAnalyzer.VascularMetrics.RednessLevel.moderate:
                redness = 5.0
            case SkinImageAnalyzer.VascularMetrics.RednessLevel.elevated:
                redness = 7.0
            case SkinImageAnalyzer.VascularMetrics.RednessLevel.high:
                redness = 9.0
            }
            redness += (metrics.vascular.inflammationScore * 1.0)
            redness = min(10.0, redness)

            // Dark Spots: Based on hyperpigmentation
            darkSpots = metrics.pigmentation.hyperpigmentationLevel * 10.0

            // Acne: Based on active breakouts and inflammation
            if metrics.vascular.hasActiveBreakouts {
                acne = 5.0 + (metrics.vascular.inflammationScore * 5.0)
            } else {
                acne = metrics.vascular.inflammationScore * 3.0
            }
            acne = min(10.0, acne)

            // Sensitivity: Based on sensitivity string and redness
            switch sensitivity {
            case "High": sensitivityScore = 8.0
            case "Moderate": sensitivityScore = 5.0
            case "Low": sensitivityScore = 2.0
            default: sensitivityScore = 3.0
            }
            // Adjust based on actual redness
            sensitivityScore = (sensitivityScore + redness) / 2.0
            sensitivityScore = min(10.0, sensitivityScore)
        } else {
            // Fallback to concern-based estimation when comprehensive metrics not available
            if concerns.contains("Oiliness") || skinType == "Oily" {
                oiliness = 7.0
            } else if concerns.contains("Dryness") || skinType == "Dry" {
                oiliness = 2.5
            }

            if concerns.contains("Uneven Texture") {
                texture = 4.0
            }

            if concerns.contains("Enlarged Pores") || poreCondition == "Enlarged" {
                pores = 6.0
            }

            if concerns.contains("Wrinkles") {
                wrinkles = 7.0
            } else if concerns.contains("Fine Lines") {
                wrinkles = 6.0
            } else if concerns.contains("Aging") {
                wrinkles = 5.0
            }

            if concerns.contains("Redness") {
                redness = 6.0
            }

            if concerns.contains("Dark Spots") {
                darkSpots = 6.0
            }

            if concerns.contains("Acne") {
                acne = 6.0
            }

            switch sensitivity {
            case "High": sensitivityScore = 8.0
            case "Moderate": sensitivityScore = 5.0
            case "Low": sensitivityScore = 2.0
            default: sensitivityScore = 3.0
            }
        }

        return (oiliness, texture, pores, wrinkles, redness, darkSpots, acne, sensitivityScore)
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
        products: [Product],
        clinicalSummary: String?
    ) -> String {
        // Separate rules into settings and conditions
        let activeRules = aiRules.filter { $0.isActive == true }
        let settingsRules = activeRules.filter { $0.ruleType == "setting" }
        let conditionRules = activeRules.filter { $0.ruleType == "condition" || $0.ruleType == nil }

        // Extract general AI settings
        var tone = "professional and empathetic"
        var depth = "detailed"
        var format = "clear and structured"
        var focusAreas: [String] = []
        var alwaysInclude: [String] = []
        var avoidMentioning: [String] = []

        for setting in settingsRules {
            guard let key = setting.settingKey?.lowercased(), let value = setting.settingValue else { continue }

            switch key {
            case "tone":
                tone = value
            case "depth", "detail_level":
                depth = value
            case "format", "output_format":
                format = value
            case "focus":
                focusAreas.append(value)
            case "always_include":
                alwaysInclude.append(value)
            case "avoid":
                avoidMentioning.append(value)
            default:
                break
            }
        }

        // Build base prompt with AI personality
        var prompt = """
        You are an expert skin analysis AI for estheticians and medspa professionals. Analyze this skin image and provide a detailed assessment.

        """

        // Add AI behavior instructions based on settings
        if !settingsRules.isEmpty {
            prompt += "\nAI BEHAVIOR SETTINGS:\n"
            prompt += "- Tone: Use a \(tone) tone throughout your analysis\n"
            prompt += "- Detail Level: Provide \(depth) analysis and explanations\n"
            prompt += "- Format: Present information in a \(format) manner\n"

            if !focusAreas.isEmpty {
                prompt += "- Focus Areas: Pay special attention to: \(focusAreas.joined(separator: ", "))\n"
            }

            if !alwaysInclude.isEmpty {
                prompt += "- Always Include: Make sure to mention: \(alwaysInclude.joined(separator: ", "))\n"
            }

            if !avoidMentioning.isEmpty {
                prompt += "- Avoid: Do not mention or focus on: \(avoidMentioning.joined(separator: ", "))\n"
            }
        }

        prompt += "\nConsider the following context carefully while performing your analysis:\n\n"

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

        // Add comprehensive clinical image analysis
        if let clinicalSummary = clinicalSummary, !clinicalSummary.isEmpty {
            prompt += "\n\n📊 DETAILED CLINICAL IMAGE ANALYSIS:\n"
            prompt += "The following metrics were extracted from the image using advanced perceptual color analysis (LAB color space),\n"
            prompt += "spatial region mapping, multi-scale texture analysis, structural feature detection, vascular assessment,\n"
            prompt += "and pigmentation analysis. Use these objective measurements to inform your professional assessment:\n\n"
            prompt += clinicalSummary
            prompt += "\n\nInterpret these metrics in combination with your visual analysis of the image to provide the most accurate assessment.\n"
        }

        // Add manual assessments if provided
        if let manualSkinType = manualSkinType {
            prompt += "Esthetician's skin type assessment: \(manualSkinType)\n"
        }
        if let manualHydrationLevel = manualHydrationLevel, !manualHydrationLevel.isEmpty {
            prompt += "Esthetician's hydration assessment (percent): \(manualHydrationLevel)\n"
        }

        // Add Condition-Based AI Rules
        if !conditionRules.isEmpty {
            prompt += "\n\nCUSTOM CONDITIONAL RULES - These are professional rules you MUST follow:\n"
            let sortedRules = conditionRules.sorted { ($0.priority ?? 0) > ($1.priority ?? 0) }
            for (index, rule) in sortedRules.enumerated() {
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
                        if let usageGuidelines = product.usageGuidelines, !usageGuidelines.isEmpty {
                            productDetails += " | Usage: \(usageGuidelines)"
                        }

                        prompt += productDetails + "\n"
                    }
                }
            }
        }

        let concernLabels = AppConstants.concernOptions.joined(separator: ", ")

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
          "medical_considerations": ["consideration1"],
          "recommended_routine": {
            "morning_steps": [
              {
                "id": "uuid",
                "product_name": "Brand - Product Name",
                "product_id": "optional_product_id",
                "step_number": 1,
                "instructions": "Apply to clean, damp skin",
                "amount": "Pea-sized",
                "wait_time": 60,
                "frequency": "Daily"
              }
            ],
            "evening_steps": [...],
            "notes": "General routine tips"
          }
        }

        CONCERN LABELS:
        - Use standardized concern labels only: \(concernLabels).

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

        3. "recommended_routine" - Create a structured morning and evening skincare routine:
           - Order products by category: Cleanser → Toner → Treatment/Serum → Eye Cream → Moisturizer → Sunscreen (AM only)
           - ONLY include products from the catalog that match the client's skin concerns
           - For each step provide:
             * product_name: "Brand - Product Name" (must match catalog exactly)
             * step_number: Sequential order (1, 2, 3...)
             * instructions: Brief how-to (e.g., "Gently massage into damp skin in circular motions")
             * amount: How much to use (e.g., "Pea-sized", "2-3 drops", "Dime-sized", "Generous layer")
             * wait_time: Seconds to wait before next step (optional, e.g., 60 for actives, 30 for serums)
             * frequency: "Daily", "2-3 times per week", "Every other day", etc.
           - Morning routine: Focus on protection (antioxidants, sunscreen)
           - Evening routine: Focus on treatment and repair (actives, retinol, heavier moisturizers)
           - Add routine notes with general tips (e.g., "Always apply products to damp skin for better absorption")
           - Keep routines simple (3-5 steps each) - don't overwhelm the client
           - Use the product's "Usage Guidelines" field when available to inform instructions

        Example routine for dry, aging skin:
        Morning: Gentle Cleanser → Vitamin C Serum → Eye Cream → Moisturizer → SPF 50
        Evening: Oil Cleanser → Gentle Cleanser → Hyaluronic Acid Serum → Retinol → Night Cream
        """

        return prompt
    }

    private func parseClaudeResponse(data: Data, products: [Product]) throws -> AnalysisData {
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
        let baseConcerns = analysisResponse.concerns ?? []
        let expandedConcerns = expandConcerns(baseConcerns)
        let healthScore = normalizeHealthScore(analysisResponse.skinHealthScore, concerns: baseConcerns)

        let normalizedRoutine = normalizeRecommendedRoutine(analysisResponse.recommendedRoutine, products: products)

        return AnalysisData(
            skinType: skinType,
            hydrationLevel: hydratedLevel,
            sensitivity: sensitivity,
            concerns: expandedConcerns.isEmpty ? nil : expandedConcerns,
            poreCondition: poreCondition,
            skinHealthScore: healthScore,
            recommendations: analysisResponse.recommendations,
            productRecommendations: analysisResponse.productRecommendations,
            medicalConsiderations: analysisResponse.medicalConsiderations,
            progressNotes: analysisResponse.progressNotes,
            recommendedRoutine: normalizedRoutine
        )
    }

    private func normalizeRecommendedRoutine(_ routine: SkinCareRoutine?, products: [Product]) -> SkinCareRoutine? {
        guard let routine else { return nil }

        let morningSteps = normalizeRoutineSteps(routine.morningSteps, products: products)
        let eveningSteps = normalizeRoutineSteps(routine.eveningSteps, products: products)
        let notes = routine.notes?.trimmingCharacters(in: .whitespacesAndNewlines)

        return SkinCareRoutine(
            morningSteps: morningSteps,
            eveningSteps: eveningSteps,
            notes: notes?.isEmpty == true ? nil : notes
        )
    }

    private func normalizeRoutineSteps(_ steps: [RoutineStep], products: [Product]) -> [RoutineStep] {
        let sortedSteps = steps.sorted { lhs, rhs in
            if lhs.stepNumber == rhs.stepNumber {
                return lhs.productName.localizedCaseInsensitiveCompare(rhs.productName) == .orderedAscending
            }
            if lhs.stepNumber == 0 { return false }
            if rhs.stepNumber == 0 { return true }
            return lhs.stepNumber < rhs.stepNumber
        }

        return sortedSteps.enumerated().map { index, step in
            var updatedStep = step
            updatedStep.stepNumber = index + 1

            if let matchedProduct = matchProduct(for: step.productName, products: products) {
                let canonicalName = formattedProductName(for: matchedProduct)
                if !canonicalName.isEmpty {
                    updatedStep.productName = canonicalName
                }
                updatedStep.productId = matchedProduct.id
                updatedStep.imageUrl = matchedProduct.imageUrl
                if (updatedStep.instructions ?? "").isEmpty,
                   let guidelines = matchedProduct.usageGuidelines,
                   !guidelines.isEmpty {
                    updatedStep.instructions = guidelines
                }
            }

            return updatedStep
        }
    }

    private func matchProduct(for stepName: String, products: [Product]) -> Product? {
        let normalizedStepName = normalizeProductName(stepName)
        guard !normalizedStepName.isEmpty else { return nil }

        return products.first { product in
            let displayName = formattedProductName(for: product)
            let normalizedDisplay = normalizeProductName(displayName)
            let normalizedProductName = normalizeProductName(product.name ?? "")
            return normalizedDisplay == normalizedStepName || normalizedProductName == normalizedStepName
        }
    }

    private func formattedProductName(for product: Product) -> String {
        let brand = product.brand?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let name = product.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if brand.isEmpty { return name }
        if name.isEmpty { return brand }
        return "\(brand) - \(name)"
    }

    private func normalizeProductName(_ value: String) -> String {
        value
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .joined()
    }

    private func generateImageVariants(from image: UIImage) -> [UIImage] {
        var variants: [UIImage] = [image]

        if let boosted = applyColorBoost(image: image, contrast: 1.2, saturation: 1.15, brightness: 0.02) {
            variants.append(boosted)
        }
        if let highContrast = applyColorBoost(image: image, contrast: 1.3, saturation: 1.05, brightness: 0.0) {
            variants.append(highContrast)
        }

        return variants
    }

    private func applyColorBoost(image: UIImage, contrast: CGFloat, saturation: CGFloat, brightness: CGFloat) -> UIImage? {
        guard let ciImage = CIImage(image: image) else { return nil }
        guard let filter = CIFilter(name: "CIColorControls") else { return nil }
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        filter.setValue(contrast, forKey: kCIInputContrastKey)
        filter.setValue(saturation, forKey: kCIInputSaturationKey)
        filter.setValue(brightness, forKey: kCIInputBrightnessKey)

        guard let outputImage = filter.outputImage,
              let cgImage = ciContext.createCGImage(outputImage, from: outputImage.extent) else {
            return nil
        }

        return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
    }

    private func selectMostSevereMetrics(
        from metricsList: [SkinImageAnalyzer.ComprehensiveMetrics]
    ) -> SkinImageAnalyzer.ComprehensiveMetrics? {
        guard !metricsList.isEmpty else { return nil }
        return metricsList.max { lhs, rhs in
            severityScore(for: lhs) < severityScore(for: rhs)
        }
    }

    private func severityScore(for metrics: SkinImageAnalyzer.ComprehensiveMetrics) -> Double {
        let redness = min(1.0, metrics.perceptualColor.averageRedness / 20.0)
        let roughness = 1.0 - metrics.texture.smoothness
        let score = (metrics.vascular.inflammationScore * 1.5)
            + metrics.texture.flakingLikelihood
            + metrics.texture.porelikeStructures
            + metrics.structure.lineDensity
            + metrics.structure.laxityScore
            + metrics.pigmentation.hyperpigmentationLevel
            + roughness
            + redness
        return score
    }

    private func buildRecommendedRoutine(
        productRecommendations: [String],
        products: [Product]
    ) -> SkinCareRoutine? {
        let normalizedRecommendations = productRecommendations
            .map(normalizeProductName)
            .filter { !$0.isEmpty }

        guard !normalizedRecommendations.isEmpty else { return nil }

        var seen = Set<String>()
        var uniqueRecommendations: [String] = []
        for recommendation in productRecommendations {
            let normalized = normalizeProductName(recommendation)
            guard !normalized.isEmpty else { continue }
            if seen.insert(normalized).inserted {
                uniqueRecommendations.append(recommendation)
            }
        }

        var morningSteps: [RoutineStep] = []
        var eveningSteps: [RoutineStep] = []

        for recommendation in uniqueRecommendations {
            if let product = matchProduct(for: recommendation, products: products) {
                let targets = routineTargets(for: product)
                if targets.includeMorning {
                    morningSteps.append(makeRoutineStep(for: product))
                }
                if targets.includeEvening {
                    eveningSteps.append(makeRoutineStep(for: product))
                }
            } else {
                morningSteps.append(RoutineStep(productName: recommendation, stepNumber: 0))
                if !isMorningOnlyProduct(recommendation) {
                    eveningSteps.append(RoutineStep(productName: recommendation, stepNumber: 0))
                }
            }
        }

        morningSteps = normalizeAndSortRoutineSteps(morningSteps, products: products)
        eveningSteps = normalizeAndSortRoutineSteps(eveningSteps, products: products)

        return SkinCareRoutine(morningSteps: morningSteps, eveningSteps: eveningSteps, notes: nil)
    }

    private func makeRoutineStep(for product: Product) -> RoutineStep {
        let usageText = product.usageGuidelines?.trimmingCharacters(in: .whitespacesAndNewlines)
        let instructions = usageText?.isEmpty == true ? nil : usageText
        let amount = instructions.flatMap { extractAmount(from: $0) }
        return RoutineStep(
            productName: formattedProductName(for: product),
            productId: product.id,
            stepNumber: 0,
            instructions: instructions,
            amount: amount,
            imageUrl: product.imageUrl
        )
    }

    private func extractAmount(from text: String) -> String? {
        let patterns = [
            "\\b\\d+\\s*-\\s*\\d+\\s*(drops|pumps)\\b",
            "\\b\\d+\\s*(drops|pumps)\\b",
            "\\b(pea[- ]sized|pea[- ]size|dime[- ]sized|nickel[- ]sized|coin[- ]sized|rice[- ]grain|two fingers|thin layer|generous layer)\\b"
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                let range = NSRange(text.startIndex..<text.endIndex, in: text)
                if let match = regex.firstMatch(in: text, options: [], range: range),
                   let matchRange = Range(match.range, in: text) {
                    return String(text[matchRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        }

        return nil
    }

    private func normalizeAndSortRoutineSteps(_ steps: [RoutineStep], products: [Product]) -> [RoutineStep] {
        let sortedSteps = steps.sorted { lhs, rhs in
            let lhsOrder = routineCategoryOrder(for: lhs, products: products)
            let rhsOrder = routineCategoryOrder(for: rhs, products: products)
            if lhsOrder == rhsOrder {
                return lhs.productName.localizedCaseInsensitiveCompare(rhs.productName) == .orderedAscending
            }
            return lhsOrder < rhsOrder
        }

        return sortedSteps.enumerated().map { index, step in
            var updated = step
            updated.stepNumber = index + 1
            return updated
        }
    }

    private func routineCategoryOrder(for step: RoutineStep, products: [Product]) -> Int {
        if let product = matchProduct(for: step.productName, products: products) {
            return routineCategoryOrder(for: product)
        }
        return routineCategoryOrder(forText: step.productName)
    }

    private func routineCategoryOrder(for product: Product) -> Int {
        let combined = "\(product.category ?? "") \(product.name ?? "")"
        return routineCategoryOrder(forText: combined)
    }

    private func routineCategoryOrder(forText value: String) -> Int {
        let text = value.lowercased()
        if text.contains("cleanser") || text.contains("cleanse") {
            return 1
        }
        if text.contains("toner") || text.contains("essence") || text.contains("mist") {
            return 2
        }
        if text.contains("serum") || text.contains("treatment") || text.contains("retinol") || text.contains("exfol") || text.contains("acid") || text.contains("mask") {
            return 3
        }
        if text.contains("eye") {
            return 4
        }
        if text.contains("moistur") || text.contains("cream") || text.contains("lotion") {
            return 5
        }
        if text.contains("oil") {
            return 6
        }
        if text.contains("spf") || text.contains("sunscreen") {
            return 7
        }
        return 99
    }

    private func routineTargets(for product: Product) -> (includeMorning: Bool, includeEvening: Bool) {
        let combined = "\(product.category ?? "") \(product.name ?? "")".lowercased()
        if combined.contains("spf") || combined.contains("sunscreen") {
            return (true, false)
        }
        if combined.contains("retinol") || combined.contains("night") || combined.contains("pm") {
            return (false, true)
        }
        return (true, true)
    }

    private func isMorningOnlyProduct(_ name: String) -> Bool {
        let text = name.lowercased()
        return text.contains("spf") || text.contains("sunscreen")
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
