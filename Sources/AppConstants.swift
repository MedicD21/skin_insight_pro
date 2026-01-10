import Foundation

struct AppConstants {
    static let appId = "1c2c6725-f7ca-4fd5-860a-bef747d136a2"
    static let supabaseUrl = "https://meqrnevrimzvvhmopxrq.supabase.co"
    static let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1lcXJuZXZyaW16dnZobW9weHJxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjY5MjMwMzksImV4cCI6MjA4MjQ5OTAzOX0.1a_o4AVJv2RXxefs2MPxmcgo7cCigwMO59Tv8Um-sag"
    static let concernOptions = [
        "Wrinkles",
        "Discoloration",
        "Blemishes",
        "Dehydrated Skin",
        "Redness",
        "Puffiness Under Eyes",
        "Dull Skin",
        "Pollution",
        "Scar Prevention",
        "Acne",
        "Aging",
        "Dark Spots",
        "Dryness",
        "Oiliness",
        "Fine Lines",
        "Pores",
        "Uneven Texture",
        "Enlarged Pores"
    ]

    // AI Vision Provider
    enum AIProvider {
        case appleVision  // Free, runs on-device
        case claude       // Paid, superior analysis
    }

    // AI provider is now controlled via settings (Admin → AI Vision Provider)
    // Defaults to Apple Vision (free), Claude requires active subscription
    // The AI Provider Settings view automatically resets to Apple Vision if subscription expires
    static var aiProvider: AIProvider {
        let savedProvider = UserDefaults.standard.string(forKey: "ai_provider") ?? "appleVision"
        return savedProvider == "claude" ? .claude : .appleVision
    }

    // Claude API key (loaded from Secrets.swift - not committed to git)
    static var claudeApiKey: String {
        return Secrets.claudeApiKey
    }

    // UserDefaults keys
    static let accessTokenKey = "supabase_access_token"
    static let refreshTokenKey = "supabase_refresh_token"
    static let userIdKey = "supabase_user_id"

    static func normalizeConcerns(_ concerns: [String]?) -> [String] {
        guard let concerns else { return [] }
        var normalizedConcerns: [String] = []

        for concern in concerns {
            guard let normalized = normalizeConcernLabel(concern) else { continue }
            let exists = normalizedConcerns.contains { $0.caseInsensitiveCompare(normalized) == .orderedSame }
            if !exists {
                normalizedConcerns.append(normalized)
            }
        }

        return normalizedConcerns
    }

    static func normalizeConcernLabel(_ concern: String) -> String? {
        let trimmed = concern.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let lowercased = trimmed.lowercased()

        if lowercased.contains("fine lines + wrinkles") || lowercased.contains("fine lines and wrinkles") {
            return "Wrinkles"
        }
        if lowercased.contains("wrinkle") {
            return "Wrinkles"
        }
        if lowercased.contains("fine line") {
            return "Fine Lines"
        }

        if lowercased.contains("discoloration")
            || lowercased.contains("discolouration")
            || lowercased.contains("uneven tone")
            || lowercased.contains("uneven color")
            || lowercased.contains("uneven colour") {
            return "Discoloration"
        }

        if lowercased.contains("dark spot")
            || lowercased.contains("hyperpigmentation")
            || lowercased.contains("pigmentation") {
            return "Dark Spots"
        }

        if lowercased.contains("blemish")
            || lowercased.contains("blackhead")
            || lowercased.contains("clogged pore") {
            return "Blemishes"
        }

        if lowercased.contains("acne")
            || lowercased.contains("breakout")
            || lowercased.contains("pimple") {
            return "Acne"
        }

        if lowercased.contains("dehydrated")
            || lowercased.contains("dehydration") {
            return "Dehydrated Skin"
        }

        if lowercased.contains("dryness")
            || lowercased.contains("dry skin")
            || lowercased.contains("flaky")
            || lowercased.contains("flaking") {
            return "Dryness"
        }

        if lowercased.contains("redness")
            || lowercased.contains("flushing")
            || lowercased.contains("blotch") {
            return "Redness"
        }

        if lowercased.contains("puff")
            || lowercased.contains("under eye")
            || lowercased.contains("under-eye") {
            return "Puffiness Under Eyes"
        }

        if lowercased.contains("dull")
            || lowercased.contains("lackluster")
            || lowercased.contains("lacklustre")
            || lowercased.contains("lifeless") {
            return "Dull Skin"
        }

        if lowercased.contains("pollution")
            || lowercased.contains("environmental") {
            return "Pollution"
        }

        if lowercased.contains("scar") {
            return "Scar Prevention"
        }

        if lowercased.contains("aging")
            || lowercased.contains("ageing")
            || lowercased.contains("mature") {
            return "Aging"
        }

        if lowercased.contains("enlarged pores")
            || lowercased.contains("large pores") {
            return "Enlarged Pores"
        }

        if lowercased.contains("pores") {
            return "Pores"
        }

        if lowercased.contains("oil")
            || lowercased.contains("oily")
            || lowercased.contains("sebum") {
            return "Oiliness"
        }

        if lowercased.contains("uneven texture")
            || lowercased.contains("rough texture")
            || lowercased.contains("texture") {
            return "Uneven Texture"
        }

        let canonicalMatch = concernOptions.first { $0.caseInsensitiveCompare(trimmed) == .orderedSame }
        return canonicalMatch
    }
}
