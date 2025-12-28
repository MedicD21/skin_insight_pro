import Foundation

struct AppUser: Identifiable, Hashable, Codable {
    var id: String?
    var email: String?
    var provider: String?
    var createdAt: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case email
        case provider
        case createdAt = "created_at"
    }
}

struct AppClient: Identifiable, Hashable, Codable {
    var id: String?
    var userId: String?
    var name: String?
    var phone: String?
    var email: String?
    var notes: String?
    var medicalHistory: String?
    var allergies: String?
    var knownSensitivities: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case phone
        case email
        case notes
        case medicalHistory = "medical_history"
        case allergies
        case knownSensitivities = "known_sensitivities"
    }
}

struct SkinAnalysisResult: Identifiable, Hashable, Codable {
    var id: String?
    var clientId: String?
    var userId: String?
    var imageUrl: String?
    var analysisResults: AnalysisData?
    var notes: String?
    var productsUsed: String?
    var treatmentsPerformed: String?
    var createdAt: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case clientId = "client_id"
        case userId = "user_id"
        case imageUrl = "image_url"
        case analysisResults = "analysis_results"
        case notes
        case productsUsed = "products_used"
        case treatmentsPerformed = "treatments_performed"
        case createdAt = "created_at"
    }
}

struct AnalysisData: Hashable, Codable {
    var skinType: String?
    var hydrationLevel: Int?
    var sensitivity: String?
    var concerns: [String]?
    var poreCondition: String?
    var skinHealthScore: Int?
    var recommendations: [String]?
    var medicalConsiderations: [String]?
    var progressNotes: [String]?
    
    enum CodingKeys: String, CodingKey {
        case skinType = "skin_type"
        case hydrationLevel = "hydration_level"
        case sensitivity
        case concerns
        case poreCondition = "pore_condition"
        case skinHealthScore = "skin_health_score"
        case recommendations
        case medicalConsiderations = "medical_considerations"
        case progressNotes = "progress_notes"
    }
}

struct LoginRequest: Codable {
    let appId: String
    let email: String
    let password: String
    let provider: String
    
    enum CodingKeys: String, CodingKey {
        case appId = "app_id"
        case email
        case password
        case provider
    }
}

struct CreateUserRequest: Codable {
    let appId: String
    let tableName: String
    let data: UserData
    
    enum CodingKeys: String, CodingKey {
        case appId = "app_id"
        case tableName = "table_name"
        case data
    }
    
    struct UserData: Codable {
        let email: String
        let password: String
        let provider: String
    }
}

struct CreateClientRequest: Codable {
    let appId: String
    let tableName: String
    let data: ClientData
    
    enum CodingKeys: String, CodingKey {
        case appId = "app_id"
        case tableName = "table_name"
        case data
    }
    
    struct ClientData: Codable {
        var id: String?
        let userId: String
        let name: String
        let phone: String
        let email: String
        let notes: String
        let medicalHistory: String
        let allergies: String
        let knownSensitivities: String
        
        enum CodingKeys: String, CodingKey {
            case id
            case userId = "user_id"
            case name
            case phone
            case email
            case notes
            case medicalHistory = "medical_history"
            case allergies
            case knownSensitivities = "known_sensitivities"
        }
    }
}

struct CreateAnalysisRequest: Codable {
    let appId: String
    let tableName: String
    let data: AnalysisRequestData
    
    enum CodingKeys: String, CodingKey {
        case appId = "app_id"
        case tableName = "table_name"
        case data
    }
    
    struct AnalysisRequestData: Codable {
        var id: String?
        let clientId: String
        let userId: String
        let imageUrl: String
        let analysisResults: AnalysisData
        let notes: String
        let clientMedicalHistory: String?
        let clientAllergies: String?
        let clientKnownSensitivities: String?
        let productsUsed: String?
        let treatmentsPerformed: String?
        
        enum CodingKeys: String, CodingKey {
            case id
            case clientId = "client_id"
            case userId = "user_id"
            case imageUrl = "image_url"
            case analysisResults = "analysis_results"
            case notes
            case clientMedicalHistory = "client_medical_history"
            case clientAllergies = "client_allergies"
            case clientKnownSensitivities = "client_known_sensitivities"
            case productsUsed = "products_used"
            case treatmentsPerformed = "treatments_performed"
        }
    }
}

struct FileUploadResponse: Codable {
    let url: String
}

struct AIAnalysisResponse: Codable {
    let skinType: String?
    let hydrationLevel: Int?
    let sensitivity: String?
    let concerns: [String]?
    let poreCondition: String?
    let skinHealthScore: Int?
    let recommendations: [String]?
    let medicalConsiderations: [String]?
    let progressNotes: [String]?
    
    enum CodingKeys: String, CodingKey {
        case skinType = "skin_type"
        case hydrationLevel = "hydration_level"
        case sensitivity
        case concerns
        case poreCondition = "pore_condition"
        case skinHealthScore = "skin_health_score"
        case recommendations
        case medicalConsiderations = "medical_considerations"
        case progressNotes = "progress_notes"
    }
}