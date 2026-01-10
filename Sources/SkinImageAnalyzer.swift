import UIKit
import CoreImage
import Accelerate

/// Advanced dermatological image analysis system
/// Extracts clinically relevant skin metrics for professional assessment
class SkinImageAnalyzer {

    // MARK: - Data Structures

    struct ComprehensiveMetrics {
        // PASS 1: Perceptual Color
        let perceptualColor: PerceptualColorMetrics

        // PASS 2: Spatial Regions
        let spatialRegions: [SkinRegion]

        // PASS 3: Texture Analysis
        let texture: TextureMetrics

        // PASS 4: Structural Features
        let structure: StructuralMetrics

        // PASS 5: Vascular/Inflammatory
        let vascular: VascularMetrics

        // PASS 6: Pigmentation
        let pigmentation: PigmentationMetrics

        /// Generate a clinical summary for AI consumption
        func clinicalSummary() -> String {
            var summary = "COMPREHENSIVE SKIN IMAGE ANALYSIS:\n\n"

            // Color Analysis
            summary += "COLOR PROFILE:\n"
            summary += "- Overall Brightness: \(String(format: "%.1f%%", perceptualColor.averageBrightness * 100))\n"
            summary += "- Redness Index (a*): \(String(format: "%.2f", perceptualColor.averageRedness))"
            if perceptualColor.averageRedness > 10 {
                summary += " [ELEVATED - suggests inflammation/erythema]"
            }
            summary += "\n"
            summary += "- Yellow-Blue Index (b*): \(String(format: "%.2f", perceptualColor.averageYellowness))"
            if perceptualColor.averageYellowness < -5 {
                summary += " [BLUE-SHIFTED - possible dullness]"
            }
            summary += "\n"
            summary += "- Color Uniformity: \(String(format: "%.1f%%", perceptualColor.colorUniformity * 100))"
            if perceptualColor.colorUniformity < 0.7 {
                summary += " [PATCHY - uneven tone detected]"
            }
            summary += "\n"
            summary += "- Saturation Level: \(String(format: "%.1f%%", perceptualColor.averageSaturation * 100))\n\n"

            // Spatial Analysis
            summary += "SPATIAL DISTRIBUTION (\(spatialRegions.count) regions analyzed):\n"
            let redRegions = spatialRegions.filter { $0.dominantCharacteristic == .redness }
            let dryRegions = spatialRegions.filter { $0.dominantCharacteristic == .dryness }
            let texturedRegions = spatialRegions.filter { $0.dominantCharacteristic == .roughTexture }

            if !redRegions.isEmpty {
                summary += "- Redness concentrated in: \(redRegions.map { $0.location.description }.joined(separator: ", "))\n"
            }
            if !dryRegions.isEmpty {
                summary += "- Dry/dull areas in: \(dryRegions.map { $0.location.description }.joined(separator: ", "))\n"
            }
            if !texturedRegions.isEmpty {
                summary += "- Rough texture in: \(texturedRegions.map { $0.location.description }.joined(separator: ", "))\n"
            }
            summary += "\n"

            // Texture Analysis
            summary += "TEXTURE PROFILE:\n"
            summary += "- Fine Texture (pores/micro-detail): \(String(format: "%.1f%%", texture.fineTextureLevel * 100))"
            if texture.fineTextureLevel > 0.6 {
                summary += " [HIGH - visible pores/roughness]"
            }
            summary += "\n"
            summary += "- Medium Texture (surface variation): \(String(format: "%.1f%%", texture.mediumTextureLevel * 100))\n"
            summary += "- Coarse Texture (lines/wrinkles): \(String(format: "%.1f%%", texture.coarseTextureLevel * 100))"
            if texture.coarseTextureLevel > 0.5 {
                summary += " [VISIBLE aging signs]"
            }
            summary += "\n"
            summary += "- Overall Smoothness: \(String(format: "%.1f%%", texture.smoothness * 100))"
            if texture.smoothness < 0.4 {
                summary += " [ROUGH - possible dehydration/barrier issues]"
            }
            summary += "\n"
            summary += "- Flaking/Scaling Likelihood: \(String(format: "%.1f%%", texture.flakingLikelihood * 100))"
            if texture.flakingLikelihood > 0.5 {
                summary += " [POSSIBLE barrier disruption]"
            }
            summary += "\n\n"

            // Structural Features
            summary += "STRUCTURAL FEATURES:\n"
            summary += "- Line Density: \(String(format: "%.1f%%", structure.lineDensity * 100))"
            if structure.lineDensity > 0.5 {
                summary += " [MODERATE-HIGH wrinkle presence]"
            }
            summary += "\n"
            summary += "- Expression Lines: \(structure.hasExpressionLines ? "Detected" : "Minimal")\n"
            summary += "- Skin Laxity Indicators: \(String(format: "%.1f%%", structure.laxityScore * 100))\n"
            summary += "- Left-Right Symmetry: \(String(format: "%.1f%%", structure.symmetryScore * 100))"
            if structure.symmetryScore < 0.7 {
                summary += " [ASYMMETRIC - possible localized issues]"
            }
            summary += "\n\n"

            // Vascular/Inflammatory
            summary += "VASCULAR & INFLAMMATION:\n"
            summary += "- Overall Redness Level: \(vascular.overallRednessLevel.description)\n"
            summary += "- Redness Pattern: \(vascular.rednessPattern.description)\n"
            summary += "- Inflammation Indicators: \(String(format: "%.1f%%", vascular.inflammationScore * 100))"
            if vascular.inflammationScore > 0.6 {
                summary += " [ELEVATED - active inflammation likely]"
            }
            summary += "\n"
            if vascular.hasActiveBreakouts {
                summary += "- Active Breakouts: Detected [sharp, localized redness]\n"
            }
            summary += "\n"

            // Pigmentation
            summary += "PIGMENTATION:\n"
            summary += "- Hyperpigmentation Density: \(String(format: "%.1f%%", pigmentation.hyperpigmentationLevel * 100))"
            if pigmentation.hyperpigmentationLevel > 0.4 {
                summary += " [SIGNIFICANT dark spots/melasma risk]"
            }
            summary += "\n"
            summary += "- Hypopigmentation Presence: \(String(format: "%.1f%%", pigmentation.hypopigmentationLevel * 100))\n"
            summary += "- Freckle/Spot Count: ~\(pigmentation.spotCount)\n"
            summary += "- Pigment Uniformity: \(String(format: "%.1f%%", pigmentation.uniformity * 100))"
            if pigmentation.uniformity < 0.6 {
                summary += " [UNEVEN tone - sun damage/PIH likely]"
            }
            summary += "\n"

            return summary
        }
    }

    // PASS 1: Perceptual Color Metrics
    struct PerceptualColorMetrics {
        let averageBrightness: CGFloat      // L* in LAB (0-1)
        let averageRedness: CGFloat         // a* in LAB (-100 to +100, positive = red)
        let averageYellowness: CGFloat      // b* in LAB (-100 to +100, positive = yellow)
        let colorUniformity: CGFloat        // How consistent is the tone? (0-1)
        let averageSaturation: CGFloat      // Overall color saturation (0-1)
        let brightnessVariance: CGFloat     // Standard deviation of brightness
        let rednessVariance: CGFloat        // Standard deviation of redness
    }

    // PASS 2: Spatial Region
    struct SkinRegion {
        let location: RegionLocation
        let brightness: CGFloat
        let redness: CGFloat
        let saturation: CGFloat
        let textureEnergy: CGFloat
        let dominantCharacteristic: CharacteristicType

        enum RegionLocation: CustomStringConvertible {
            case topLeft, topCenter, topRight
            case middleLeft, middleCenter, middleRight
            case bottomLeft, bottomCenter, bottomRight

            var description: String {
                switch self {
                case .topLeft: return "Upper Left"
                case .topCenter: return "Upper Center (forehead)"
                case .topRight: return "Upper Right"
                case .middleLeft: return "Mid Left (cheek)"
                case .middleCenter: return "Mid Center (nose)"
                case .middleRight: return "Mid Right (cheek)"
                case .bottomLeft: return "Lower Left"
                case .bottomCenter: return "Lower Center (chin)"
                case .bottomRight: return "Lower Right"
                }
            }
        }

        enum CharacteristicType {
            case normal, redness, dryness, oiliness, roughTexture, hyperpigmentation
        }
    }

    // PASS 3: Texture Metrics
    struct TextureMetrics {
        let fineTextureLevel: CGFloat       // Pores, micro-roughness (0-1)
        let mediumTextureLevel: CGFloat     // Surface variation (0-1)
        let coarseTextureLevel: CGFloat     // Lines, wrinkles (0-1)
        let smoothness: CGFloat             // Overall smoothness (0-1, higher = smoother)
        let porelikeStructures: CGFloat     // Density of pore-like patterns (0-1)
        let flakingLikelihood: CGFloat      // High-frequency noise + low reflectivity (0-1)
    }

    // PASS 4: Structural Metrics
    struct StructuralMetrics {
        let lineDensity: CGFloat            // Presence of lines/wrinkles (0-1)
        let hasExpressionLines: Bool        // Oriented patterns detected
        let laxityScore: CGFloat            // Shadow persistence, sagging (0-1)
        let symmetryScore: CGFloat          // Left-right symmetry (0-1, higher = more symmetric)
    }

    // PASS 5: Vascular Metrics
    struct VascularMetrics {
        let overallRednessLevel: RednessLevel
        let rednessPattern: RednessPattern
        let inflammationScore: CGFloat      // 0-1, based on red clustering
        let hasActiveBreakouts: Bool        // Sharp, localized redness

        enum RednessLevel: CustomStringConvertible {
            case minimal, low, moderate, elevated, high

            var description: String {
                switch self {
                case .minimal: return "Minimal"
                case .low: return "Low"
                case .moderate: return "Moderate"
                case .elevated: return "Elevated"
                case .high: return "High"
                }
            }
        }

        enum RednessPattern: CustomStringConvertible {
            case diffuse, clustered, localized, mixed

            var description: String {
                switch self {
                case .diffuse: return "Diffuse (rosacea-like)"
                case .clustered: return "Clustered (possible sensitivity)"
                case .localized: return "Localized (acne/breakouts)"
                case .mixed: return "Mixed pattern"
                }
            }
        }
    }

    // PASS 6: Pigmentation Metrics
    struct PigmentationMetrics {
        let hyperpigmentationLevel: CGFloat // Dark spots, melasma (0-1)
        let hypopigmentationLevel: CGFloat  // Light patches (0-1)
        let spotCount: Int                  // Estimated freckle/spot count
        let uniformity: CGFloat             // Pigment uniformity (0-1)
        let hasDiffusePigment: Bool         // vs spot-like
    }

    // MARK: - Main Analysis Function

    func analyze(image: UIImage) async -> ComprehensiveMetrics {
        guard let cgImage = image.cgImage else {
            return createDefaultMetrics()
        }

        let ciImage = CIImage(cgImage: cgImage)
        let context = CIContext(options: [.workingColorSpace: kCFNull as Any])

        // Run all analysis passes
        let perceptualColor = await analyzePerceptualColor(ciImage: ciImage, cgImage: cgImage, context: context)
        let spatialRegions = await analyzeSpatialRegions(ciImage: ciImage, cgImage: cgImage, context: context)
        let texture = await analyzeTexture(ciImage: ciImage, cgImage: cgImage, context: context)
        let structure = await analyzeStructure(ciImage: ciImage, cgImage: cgImage, context: context)
        let vascular = await analyzeVascular(ciImage: ciImage, cgImage: cgImage, context: context, perceptualColor: perceptualColor)
        let pigmentation = await analyzePigmentation(ciImage: ciImage, cgImage: cgImage, context: context, perceptualColor: perceptualColor)

        return ComprehensiveMetrics(
            perceptualColor: perceptualColor,
            spatialRegions: spatialRegions,
            texture: texture,
            structure: structure,
            vascular: vascular,
            pigmentation: pigmentation
        )
    }

    // MARK: - PASS 1: Perceptual Color Analysis

    private func analyzePerceptualColor(ciImage: CIImage, cgImage: CGImage, context: CIContext) async -> PerceptualColorMetrics {
        return await withCheckedContinuation { continuation in
            // Sample the image to get LAB values
            let samplePoints = sampleImageGrid(cgImage: cgImage, gridSize: 20)

            var brightnessValues: [CGFloat] = []
            var rednessValues: [CGFloat] = []
            var yellownessValues: [CGFloat] = []
            var saturationValues: [CGFloat] = []

            for point in samplePoints {
                let (l, a, b, sat) = rgbToLAB(r: point.r, g: point.g, b: point.b)
                brightnessValues.append(l)
                rednessValues.append(a)
                yellownessValues.append(b)
                saturationValues.append(sat)
            }

            let avgBrightness = brightnessValues.reduce(0, +) / CGFloat(brightnessValues.count)
            let avgRedness = rednessValues.reduce(0, +) / CGFloat(rednessValues.count)
            let avgYellowness = yellownessValues.reduce(0, +) / CGFloat(yellownessValues.count)
            let avgSaturation = saturationValues.reduce(0, +) / CGFloat(saturationValues.count)

            let brightnessVariance = calculateVariance(values: brightnessValues, mean: avgBrightness)
            let rednessVariance = calculateVariance(values: rednessValues, mean: avgRedness)

            let colorUniformity = max(0, 1.0 - (brightnessVariance + rednessVariance) / 2.0)

            let metrics = PerceptualColorMetrics(
                averageBrightness: avgBrightness,
                averageRedness: avgRedness,
                averageYellowness: avgYellowness,
                colorUniformity: colorUniformity,
                averageSaturation: avgSaturation,
                brightnessVariance: brightnessVariance,
                rednessVariance: rednessVariance
            )

            continuation.resume(returning: metrics)
        }
    }

    // MARK: - PASS 2: Spatial Region Mapping

    private func analyzeSpatialRegions(ciImage: CIImage, cgImage: CGImage, context: CIContext) async -> [SkinRegion] {
        return await withCheckedContinuation { continuation in
            var regions: [SkinRegion] = []

            let width = cgImage.width
            let height = cgImage.height
            let gridSize = 3 // 3x3 grid
            let regionWidth = width / gridSize
            let regionHeight = height / gridSize

            let locations: [SkinRegion.RegionLocation] = [
                .topLeft, .topCenter, .topRight,
                .middleLeft, .middleCenter, .middleRight,
                .bottomLeft, .bottomCenter, .bottomRight
            ]

            for (index, location) in locations.enumerated() {
                let row = index / gridSize
                let col = index % gridSize

                let x = col * regionWidth
                let y = row * regionHeight
                let regionRect = CGRect(x: x, y: y, width: regionWidth, height: regionHeight)

                // Extract region metrics
                let regionMetrics = extractRegionMetrics(
                    cgImage: cgImage,
                    rect: regionRect,
                    context: context
                )

                // Determine dominant characteristic
                var characteristic: SkinRegion.CharacteristicType = .normal
                if regionMetrics.redness > 15 {
                    characteristic = .redness
                } else if regionMetrics.brightness < 0.3 {
                    characteristic = .dryness
                } else if regionMetrics.textureEnergy > 0.6 {
                    characteristic = .roughTexture
                }

                let region = SkinRegion(
                    location: location,
                    brightness: regionMetrics.brightness,
                    redness: regionMetrics.redness,
                    saturation: regionMetrics.saturation,
                    textureEnergy: regionMetrics.textureEnergy,
                    dominantCharacteristic: characteristic
                )

                regions.append(region)
            }

            continuation.resume(returning: regions)
        }
    }

    // MARK: - PASS 3: Texture & Surface Analysis

    private func analyzeTexture(ciImage: CIImage, cgImage: CGImage, context: CIContext) async -> TextureMetrics {
        return await withCheckedContinuation { continuation in
            // Multi-scale edge detection
            let fineEdges = detectEdges(ciImage: ciImage, context: context, intensity: 0.5)
            let mediumEdges = detectEdges(ciImage: ciImage, context: context, intensity: 1.5)
            let coarseEdges = detectEdges(ciImage: ciImage, context: context, intensity: 3.0)

            let fineDensity = calculateEdgeDensity(edgeImage: fineEdges, context: context)
            let mediumDensity = calculateEdgeDensity(edgeImage: mediumEdges, context: context)
            let coarseDensity = calculateEdgeDensity(edgeImage: coarseEdges, context: context)

            let smoothness = 1.0 - ((fineDensity + mediumDensity + coarseDensity) / 3.0)

            // Detect high-frequency noise (possible flaking)
            let variance = calculateImageVariance(cgImage: cgImage)
            let averageBrightness = getAverageBrightness(cgImage: cgImage)
            let flakingLikelihood = variance > 0.3 && averageBrightness < 0.5 ? variance : variance * 0.5

            let metrics = TextureMetrics(
                fineTextureLevel: fineDensity,
                mediumTextureLevel: mediumDensity,
                coarseTextureLevel: coarseDensity,
                smoothness: smoothness,
                porelikeStructures: fineDensity * 0.8, // Fine edges often correlate with pores
                flakingLikelihood: min(1.0, flakingLikelihood)
            )

            continuation.resume(returning: metrics)
        }
    }

    // MARK: - PASS 4: Structural Features

    private func analyzeStructure(ciImage: CIImage, cgImage: CGImage, context: CIContext) async -> StructuralMetrics {
        return await withCheckedContinuation { continuation in
            // Detect lines using edge detection
            let edges = detectEdges(ciImage: ciImage, context: context, intensity: 2.0)
            let lineDensity = calculateEdgeDensity(edgeImage: edges, context: context)

            // Expression lines: check for oriented patterns (horizontal forehead, vertical glabella)
            let hasExpressionLines = lineDensity > 0.4

            // Laxity: shadow persistence (darker regions in lower face)
            let laxityScore = calculateLaxityScore(cgImage: cgImage)

            // Symmetry: compare left and right halves
            let symmetryScore = calculateSymmetry(cgImage: cgImage)

            let metrics = StructuralMetrics(
                lineDensity: lineDensity,
                hasExpressionLines: hasExpressionLines,
                laxityScore: laxityScore,
                symmetryScore: symmetryScore
            )

            continuation.resume(returning: metrics)
        }
    }

    // MARK: - PASS 5: Vascular & Inflammatory

    private func analyzeVascular(ciImage: CIImage, cgImage: CGImage, context: CIContext, perceptualColor: PerceptualColorMetrics) async -> VascularMetrics {
        return await withCheckedContinuation { continuation in
            let redness = perceptualColor.averageRedness

            // Determine redness level
            let rednessLevel: VascularMetrics.RednessLevel
            switch redness {
            case ..<5: rednessLevel = .minimal
            case 5..<10: rednessLevel = .low
            case 10..<15: rednessLevel = .moderate
            case 15..<20: rednessLevel = .elevated
            default: rednessLevel = .high
            }

            // Analyze redness pattern
            let rednessVariance = perceptualColor.rednessVariance
            let rednessPattern: VascularMetrics.RednessPattern
            if rednessVariance < 0.2 {
                rednessPattern = .diffuse
            } else if rednessVariance < 0.4 {
                rednessPattern = .clustered
            } else {
                rednessPattern = .localized
            }

            // Inflammation score based on redness and uniformity
            let inflammationScore = min(1.0, (redness / 20.0) + (rednessVariance * 0.5))

            // Active breakouts: sharp, localized redness
            let hasActiveBreakouts = rednessPattern == .localized && redness > 12

            let metrics = VascularMetrics(
                overallRednessLevel: rednessLevel,
                rednessPattern: rednessPattern,
                inflammationScore: inflammationScore,
                hasActiveBreakouts: hasActiveBreakouts
            )

            continuation.resume(returning: metrics)
        }
    }

    // MARK: - PASS 6: Pigmentation Analysis

    private func analyzePigmentation(ciImage: CIImage, cgImage: CGImage, context: CIContext, perceptualColor: PerceptualColorMetrics) async -> PigmentationMetrics {
        return await withCheckedContinuation { continuation in
            // Sample image for pigment variations
            let samplePoints = sampleImageGrid(cgImage: cgImage, gridSize: 30)

            let avgBrightness = perceptualColor.averageBrightness
            var darkSpotCount = 0
            var lightSpotCount = 0

            for point in samplePoints {
                let (l, _, _, _) = rgbToLAB(r: point.r, g: point.g, b: point.b)
                if l < avgBrightness - 0.15 {
                    darkSpotCount += 1
                } else if l > avgBrightness + 0.15 {
                    lightSpotCount += 1
                }
            }

            let totalPoints = CGFloat(samplePoints.count)
            let hyperpigmentationLevel = min(1.0, CGFloat(darkSpotCount) / totalPoints * 2.0)
            let hypopigmentationLevel = min(1.0, CGFloat(lightSpotCount) / totalPoints * 2.0)

            let spotCount = darkSpotCount + lightSpotCount
            let uniformity = 1.0 - perceptualColor.brightnessVariance
            let hasDiffusePigment = perceptualColor.brightnessVariance < 0.3

            let metrics = PigmentationMetrics(
                hyperpigmentationLevel: hyperpigmentationLevel,
                hypopigmentationLevel: hypopigmentationLevel,
                spotCount: spotCount,
                uniformity: uniformity,
                hasDiffusePigment: hasDiffusePigment
            )

            continuation.resume(returning: metrics)
        }
    }

    // MARK: - Helper Functions

    private func sampleImageGrid(cgImage: CGImage, gridSize: Int) -> [(r: CGFloat, g: CGFloat, b: CGFloat)] {
        guard let dataProvider = cgImage.dataProvider,
              let data = dataProvider.data,
              let bytes = CFDataGetBytePtr(data) else {
            return []
        }

        let width = cgImage.width
        let height = cgImage.height
        let bytesPerRow = cgImage.bytesPerRow
        let bytesPerPixel = cgImage.bitsPerPixel / 8

        var samples: [(r: CGFloat, g: CGFloat, b: CGFloat)] = []

        let stepX = width / gridSize
        let stepY = height / gridSize

        for row in 0..<gridSize {
            for col in 0..<gridSize {
                let x = col * stepX
                let y = row * stepY

                if x < width && y < height {
                    let offset = (y * bytesPerRow) + (x * bytesPerPixel)
                    let r = CGFloat(bytes[offset]) / 255.0
                    let g = CGFloat(bytes[offset + 1]) / 255.0
                    let b = CGFloat(bytes[offset + 2]) / 255.0

                    samples.append((r: r, g: g, b: b))
                }
            }
        }

        return samples
    }

    private func rgbToLAB(r: CGFloat, g: CGFloat, b: CGFloat) -> (l: CGFloat, a: CGFloat, b: CGFloat, saturation: CGFloat) {
        // RGB to XYZ
        var rLinear = r > 0.04045 ? pow((r + 0.055) / 1.055, 2.4) : r / 12.92
        var gLinear = g > 0.04045 ? pow((g + 0.055) / 1.055, 2.4) : g / 12.92
        var bLinear = b > 0.04045 ? pow((b + 0.055) / 1.055, 2.4) : b / 12.92

        rLinear *= 100
        gLinear *= 100
        bLinear *= 100

        var x = rLinear * 0.4124 + gLinear * 0.3576 + bLinear * 0.1805
        var y = rLinear * 0.2126 + gLinear * 0.7152 + bLinear * 0.0722
        var z = rLinear * 0.0193 + gLinear * 0.1192 + bLinear * 0.9505

        // XYZ to LAB (D65 illuminant)
        x /= 95.047
        y /= 100.0
        z /= 108.883

        x = x > 0.008856 ? pow(x, 1.0/3.0) : (7.787 * x) + (16.0 / 116.0)
        y = y > 0.008856 ? pow(y, 1.0/3.0) : (7.787 * y) + (16.0 / 116.0)
        z = z > 0.008856 ? pow(z, 1.0/3.0) : (7.787 * z) + (16.0 / 116.0)

        let l = (116.0 * y) - 16.0
        let a = 500.0 * (x - y)
        let bLab = 200.0 * (y - z)

        // Saturation
        let maxChannel = max(r, g, b)
        let minChannel = min(r, g, b)
        let saturation = maxChannel > 0 ? (maxChannel - minChannel) / maxChannel : 0

        return (l: l / 100.0, a: a, b: bLab, saturation: saturation)
    }

    private func calculateVariance(values: [CGFloat], mean: CGFloat) -> CGFloat {
        let squaredDiffs = values.map { pow($0 - mean, 2) }
        let variance = squaredDiffs.reduce(0, +) / CGFloat(values.count)
        return sqrt(variance) // Return standard deviation
    }

    private func extractRegionMetrics(cgImage: CGImage, rect: CGRect, context: CIContext) -> (brightness: CGFloat, redness: CGFloat, saturation: CGFloat, textureEnergy: CGFloat) {
        // Crop image to region
        guard let croppedImage = cgImage.cropping(to: rect) else {
            return (0.5, 0, 0.5, 0.5)
        }

        // Sample the region
        let samples = sampleImageGrid(cgImage: croppedImage, gridSize: 5)

        var brightnessSum: CGFloat = 0
        var rednessSum: CGFloat = 0
        var saturationSum: CGFloat = 0

        for sample in samples {
            let (l, a, _, sat) = rgbToLAB(r: sample.r, g: sample.g, b: sample.b)
            brightnessSum += l
            rednessSum += a
            saturationSum += sat
        }

        let count = CGFloat(samples.count)
        let brightness = brightnessSum / count
        let redness = rednessSum / count
        let saturation = saturationSum / count

        // Texture energy: variance of brightness in region
        let brightnessValues = samples.map { rgbToLAB(r: $0.r, g: $0.g, b: $0.b).l }
        let textureEnergy = calculateVariance(values: brightnessValues, mean: brightness)

        return (brightness, redness, saturation, textureEnergy)
    }

    private func detectEdges(ciImage: CIImage, context: CIContext, intensity: CGFloat) -> CIImage? {
        let edgeFilter = CIFilter(name: "CIEdges")
        edgeFilter?.setValue(ciImage, forKey: kCIInputImageKey)
        edgeFilter?.setValue(intensity, forKey: kCIInputIntensityKey)
        return edgeFilter?.outputImage
    }

    private func calculateEdgeDensity(edgeImage: CIImage?, context: CIContext) -> CGFloat {
        guard let edgeImage = edgeImage else { return 0 }

        let extentVector = CIVector(x: edgeImage.extent.origin.x, y: edgeImage.extent.origin.y, z: edgeImage.extent.size.width, w: edgeImage.extent.size.height)

        guard let avgFilter = CIFilter(name: "CIAreaAverage", parameters: [kCIInputImageKey: edgeImage, kCIInputExtentKey: extentVector]),
              let outputImage = avgFilter.outputImage else {
            return 0
        }

        var bitmap = [UInt8](repeating: 0, count: 4)
        context.render(outputImage, toBitmap: &bitmap, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: nil)

        return CGFloat(bitmap[0]) / 255.0
    }

    private func calculateImageVariance(cgImage: CGImage) -> CGFloat {
        let samples = sampleImageGrid(cgImage: cgImage, gridSize: 20)
        let brightnessValues = samples.map { rgbToLAB(r: $0.r, g: $0.g, b: $0.b).l }
        let mean = brightnessValues.reduce(0, +) / CGFloat(brightnessValues.count)
        return calculateVariance(values: brightnessValues, mean: mean)
    }

    private func getAverageBrightness(cgImage: CGImage) -> CGFloat {
        let samples = sampleImageGrid(cgImage: cgImage, gridSize: 10)
        let brightnessValues = samples.map { rgbToLAB(r: $0.r, g: $0.g, b: $0.b).l }
        return brightnessValues.reduce(0, +) / CGFloat(brightnessValues.count)
    }

    private func calculateLaxityScore(cgImage: CGImage) -> CGFloat {
        // Check lower half for shadow persistence (darker regions)
        let width = cgImage.width
        let height = cgImage.height
        let lowerHalfRect = CGRect(x: 0, y: height / 2, width: width, height: height / 2)

        guard let lowerHalf = cgImage.cropping(to: lowerHalfRect) else {
            return 0
        }

        let samples = sampleImageGrid(cgImage: lowerHalf, gridSize: 10)
        let avgBrightness = samples.map { rgbToLAB(r: $0.r, g: $0.g, b: $0.b).l }.reduce(0, +) / CGFloat(samples.count)

        // Lower brightness in lower face suggests sagging/shadows
        return max(0, 1.0 - avgBrightness * 2.0)
    }

    private func calculateSymmetry(cgImage: CGImage) -> CGFloat {
        let width = cgImage.width
        let height = cgImage.height
        let midPoint = width / 2

        let leftRect = CGRect(x: 0, y: 0, width: midPoint, height: height)
        let rightRect = CGRect(x: midPoint, y: 0, width: midPoint, height: height)

        guard let leftHalf = cgImage.cropping(to: leftRect),
              let rightHalf = cgImage.cropping(to: rightRect) else {
            return 1.0
        }

        let leftSamples = sampleImageGrid(cgImage: leftHalf, gridSize: 10)
        let rightSamples = sampleImageGrid(cgImage: rightHalf, gridSize: 10)

        let leftAvg = leftSamples.map { rgbToLAB(r: $0.r, g: $0.g, b: $0.b).l }.reduce(0, +) / CGFloat(leftSamples.count)
        let rightAvg = rightSamples.map { rgbToLAB(r: $0.r, g: $0.g, b: $0.b).l }.reduce(0, +) / CGFloat(rightSamples.count)

        let difference = abs(leftAvg - rightAvg)
        return max(0, 1.0 - difference * 3.0)
    }

    private func createDefaultMetrics() -> ComprehensiveMetrics {
        return ComprehensiveMetrics(
            perceptualColor: PerceptualColorMetrics(
                averageBrightness: 0.5,
                averageRedness: 0,
                averageYellowness: 0,
                colorUniformity: 0.8,
                averageSaturation: 0.5,
                brightnessVariance: 0.1,
                rednessVariance: 0.1
            ),
            spatialRegions: [],
            texture: TextureMetrics(
                fineTextureLevel: 0.4,
                mediumTextureLevel: 0.4,
                coarseTextureLevel: 0.3,
                smoothness: 0.5,
                porelikeStructures: 0.4,
                flakingLikelihood: 0.2
            ),
            structure: StructuralMetrics(
                lineDensity: 0.3,
                hasExpressionLines: false,
                laxityScore: 0.2,
                symmetryScore: 0.9
            ),
            vascular: VascularMetrics(
                overallRednessLevel: .low,
                rednessPattern: .diffuse,
                inflammationScore: 0.2,
                hasActiveBreakouts: false
            ),
            pigmentation: PigmentationMetrics(
                hyperpigmentationLevel: 0.2,
                hypopigmentationLevel: 0.1,
                spotCount: 0,
                uniformity: 0.8,
                hasDiffusePigment: true
            )
        )
    }
}
