import Foundation

struct AppConstants {
    static let appId = "1c2c6725-f7ca-4fd5-860a-bef747d136a2"
    static let supabaseUrl = "https://meqrnevrimzvvhmopxrq.supabase.co"
    static let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1lcXJuZXZyaW16dnZobW9weHJxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjY5MjMwMzksImV4cCI6MjA4MjQ5OTAzOX0.1a_o4AVJv2RXxefs2MPxmcgo7cCigwMO59Tv8Um-sag"

    // AI Vision Provider
    enum AIProvider {
        case appleVision  // Free, runs on-device
        case claude       // Paid, superior analysis
    }

    // AI provider is now controlled via settings (Admin → AI Vision Provider)
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
}
