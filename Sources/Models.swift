import Foundation

struct AppUser: Identifiable, Hashable, Codable {
    var id: String?
    var email: String?
    var provider: String?
    var isAdmin: Bool?
    var isCompanyAdmin: Bool?
    var createdAt: String?
    var companyId: String?
    var firstName: String?
    var lastName: String?
    var phoneNumber: String?
    var profileImageUrl: String?
    var role: String?
    var companyName: String?

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case provider
        case isAdmin = "is_admin"
        case isCompanyAdmin = "is_company_admin"
        case createdAt = "created_at"
        case companyId = "company_id"
        case firstName = "first_name"
        case lastName = "last_name"
        case phoneNumber = "phone_number"
        case profileImageUrl = "profile_image_url"
        case role
        case companyName = "company_name"
    }
}

struct AppClient: Identifiable, Hashable, Codable {
    var id: String?
    var userId: String?
    var companyId: String?
    var name: String?
    var firstName: String?
    var lastName: String?
    var phone: String?
    var email: String?
    var notes: String?
    var medicalHistory: String?
    var allergies: String?
    var knownSensitivities: String?
    var medications: String?
    var productsToAvoid: String?
    var profileImageUrl: String?
    var fillersDate: String?
    var biostimulatorsDate: String?
    var consentSignature: String?
    var consentDate: String?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case companyId = "company_id"
        case name
        case firstName = "first_name"
        case lastName = "last_name"
        case phone
        case email
        case notes
        case medicalHistory = "medical_history"
        case allergies
        case knownSensitivities = "known_sensitivities"
        case medications
        case productsToAvoid = "products_to_avoid"
        case profileImageUrl = "profile_image_url"
        case fillersDate = "fillers_date"
        case biostimulatorsDate = "biostimulators_date"
        case consentSignature = "consent_signature"
        case consentDate = "consent_date"
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
    var productRecommendations: [String]?
    var medicalConsiderations: [String]?
    var progressNotes: [String]?
    var analysisNotice: String? = nil

    enum CodingKeys: String, CodingKey {
        case skinType = "skin_type"
        case hydrationLevel = "hydration_level"
        case sensitivity
        case concerns
        case poreCondition = "pore_condition"
        case skinHealthScore = "skin_health_score"
        case recommendations
        case productRecommendations = "product_recommendations"
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
        let companyId: String?
        let name: String
        let phone: String
        let email: String
        let notes: String
        let medicalHistory: String
        let allergies: String
        let knownSensitivities: String
        let medications: String
        let profileImageUrl: String?

        enum CodingKeys: String, CodingKey {
            case id
            case userId = "user_id"
            case companyId = "company_id"
            case name
            case phone
            case email
            case notes
            case medicalHistory = "medical_history"
            case allergies
            case knownSensitivities = "known_sensitivities"
            case medications
            case profileImageUrl = "profile_image_url"
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
        let clientMedications: String?
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
            case clientMedications = "client_medications"
            case productsUsed = "products_used"
            case treatmentsPerformed = "treatments_performed"
        }
    }
}

struct AppleLoginRequest: Codable {
    let appId: String
    let appleUserId: String
    let email: String
    let firstName: String?
    let lastName: String?

    enum CodingKeys: String, CodingKey {
        case appId = "app_id"
        case appleUserId = "apple_user_id"
        case email
        case firstName = "first_name"
        case lastName = "last_name"
    }
}

struct Company: Identifiable, Hashable, Codable {
    var id: String?
    var companyCode: String?
    var name: String?
    var address: String?
    var phone: String?
    var email: String?
    var logoUrl: String?
    var website: String?
    var createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case companyCode = "company_code"
        case name
        case address
        case phone
        case email
        case logoUrl = "logo_url"
        case website
        case createdAt = "created_at"
    }
}

struct CreateCompanyRequest: Codable {
    let appId: String
    let tableName: String
    let data: CompanyData

    enum CodingKeys: String, CodingKey {
        case appId = "app_id"
        case tableName = "table_name"
        case data
    }

    struct CompanyData: Codable {
        var id: String?
        var companyCode: String?
        let name: String
        let address: String
        let phone: String
        let email: String
        let logoUrl: String?
        let website: String?

        enum CodingKeys: String, CodingKey {
            case id
            case companyCode = "company_code"
            case name
            case address
            case phone
            case email
            case logoUrl = "logo_url"
            case website
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
    let productRecommendations: [String]?
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
        case productRecommendations = "product_recommendations"
        case medicalConsiderations = "medical_considerations"
        case progressNotes = "progress_notes"
    }
}

struct Product: Identifiable, Hashable, Codable {
    var id: String?
    var userId: String?
    var name: String?
    var brand: String?
    var category: String?
    var description: String?
    var ingredients: String?  // Key ingredients
    var allIngredients: String?  // Complete ingredients list
    var skinTypes: [String]?
    var concerns: [String]?
    var imageUrl: String?
    var price: Double?
    var isActive: Bool?
    var createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case brand
        case category
        case description
        case ingredients
        case allIngredients = "all_ingredients"
        case skinTypes = "skin_types"
        case concerns
        case imageUrl = "image_url"
        case price
        case isActive = "is_active"
        case createdAt = "created_at"
    }
}

struct AIRule: Identifiable, Hashable, Codable {
    var id: String?
    var userId: String?
    var companyId: String?
    var name: String?
    var condition: String?
    var action: String?
    var productId: String?
    var priority: Int?
    var isActive: Bool?
    var createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case companyId = "company_id"
        case name
        case condition
        case action
        case productId = "product_id"
        case priority
        case isActive = "is_active"
        case createdAt = "created_at"
    }
}

struct CreateProductRequest: Codable {
    let appId: String
    let tableName: String
    let data: ProductData

    enum CodingKeys: String, CodingKey {
        case appId = "app_id"
        case tableName = "table_name"
        case data
    }

    struct ProductData: Codable {
        var id: String?
        let userId: String
        let name: String
        let brand: String
        let category: String
        let description: String
        let ingredients: String
        let allIngredients: String?
        let skinTypes: [String]
        let concerns: [String]
        let imageUrl: String?
        let price: Double?
        let isActive: Bool

        enum CodingKeys: String, CodingKey {
            case id
            case userId = "user_id"
            case name
            case brand
            case category
            case description
            case ingredients
            case allIngredients = "all_ingredients"
            case skinTypes = "skin_types"
            case concerns
            case imageUrl = "image_url"
            case price
            case isActive = "is_active"
        }
    }
}

struct CreateAIRuleRequest: Codable {
    let appId: String
    let tableName: String
    let data: AIRuleData

    enum CodingKeys: String, CodingKey {
        case appId = "app_id"
        case tableName = "table_name"
        case data
    }

    struct AIRuleData: Codable {
        var id: String?
        let userId: String
        let name: String
        let condition: String
        let productId: String
        let priority: Int
        let isActive: Bool

        enum CodingKeys: String, CodingKey {
            case id
            case userId = "user_id"
            case name
            case condition
            case productId = "product_id"
            case priority
            case isActive = "is_active"
        }
    }
}
