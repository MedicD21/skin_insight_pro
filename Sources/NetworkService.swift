import Foundation
import UIKit

class NetworkService {
    static let shared = NetworkService()
    private let session: URLSession
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)
    }
    
    func login(email: String, password: String) async throws -> AppUser {
        let url = URL(string: "\(AppConstants.baseUrl)/data/login")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let loginRequest = LoginRequest(
            appId: AppConstants.appId,
            email: email,
            password: password,
            provider: "email"
        )
        
        request.httpBody = try JSONEncoder().encode(loginRequest)
        
        print("-> Request: Login")
        print("-> POST: \(url.absoluteString)")
        print("-> Parameters:")
        if let jsonData = request.httpBody,
           let jsonString = String(data: jsonData, encoding: .utf8) {
            print(jsonString)
        }
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }
            
            print("<- Response: Login")
            print("<- POST: \(url.absoluteString)")
            print("<- Status Code: \(httpResponse.statusCode)")
            print("<- Response Body:")
            if let jsonString = String(data: data, encoding: .utf8) {
                print(jsonString)
            }
            
            if httpResponse.statusCode == 400 {
                throw NetworkError.invalidCredentials
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                throw NetworkError.serverError(httpResponse.statusCode)
            }
            
            let user = try JSONDecoder().decode(AppUser.self, from: data)
            return user
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
        } catch {
            throw error
        }
    }
    
    func createUser(email: String, password: String) async throws -> AppUser {
        let url = URL(string: "\(AppConstants.baseUrl)/data")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let createRequest = CreateUserRequest(
            appId: AppConstants.appId,
            tableName: "users",
            data: CreateUserRequest.UserData(
                email: email,
                password: password,
                provider: "email"
            )
        )
        
        request.httpBody = try JSONEncoder().encode(createRequest)
        
        print("-> Request: Create User")
        print("-> POST: \(url.absoluteString)")
        print("-> Parameters:")
        if let jsonData = request.httpBody,
           let jsonString = String(data: jsonData, encoding: .utf8) {
            print(jsonString)
        }
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }
            
            print("<- Response: Create User")
            print("<- POST: \(url.absoluteString)")
            print("<- Status Code: \(httpResponse.statusCode)")
            print("<- Response Body:")
            if let jsonString = String(data: data, encoding: .utf8) {
                print(jsonString)
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                throw NetworkError.serverError(httpResponse.statusCode)
            }
            
            let user = try JSONDecoder().decode(AppUser.self, from: data)
            return user
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
        } catch {
            throw error
        }
    }
    
    func fetchClients(userId: String) async throws -> [AppClient] {
        var components = URLComponents(string: "\(AppConstants.baseUrl)/data")!
        components.queryItems = [
            URLQueryItem(name: "app_id", value: AppConstants.appId),
            URLQueryItem(name: "table_name", value: "clients"),
            URLQueryItem(name: "user_id", value: userId)
        ]
        
        guard let url = components.url else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        print("-> Request: Fetch Clients")
        print("-> GET: \(url.absoluteString)")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }
            
            print("<- Response: Fetch Clients")
            print("<- GET: \(url.absoluteString)")
            print("<- Status Code: \(httpResponse.statusCode)")
            print("<- Response Body:")
            if let jsonString = String(data: data, encoding: .utf8) {
                print(jsonString)
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                throw NetworkError.serverError(httpResponse.statusCode)
            }
            
            let clients = try JSONDecoder().decode([AppClient].self, from: data)
            return clients
        } catch is CancellationError {
            return []
        } catch let error as URLError where error.code == .cancelled {
            return []
        } catch {
            throw error
        }
    }
    
    func createOrUpdateClient(client: AppClient, userId: String) async throws -> AppClient {
        let url = URL(string: "\(AppConstants.baseUrl)/data")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let clientRequest = CreateClientRequest(
            appId: AppConstants.appId,
            tableName: "clients",
            data: CreateClientRequest.ClientData(
                id: client.id,
                userId: userId,
                name: client.name ?? "",
                phone: client.phone ?? "",
                email: client.email ?? "",
                notes: client.notes ?? "",
                medicalHistory: client.medicalHistory ?? "",
                allergies: client.allergies ?? "",
                knownSensitivities: client.knownSensitivities ?? ""
            )
        )
        
        request.httpBody = try JSONEncoder().encode(clientRequest)
        
        print("-> Request: Create/Update Client")
        print("-> POST: \(url.absoluteString)")
        print("-> Parameters:")
        if let jsonData = request.httpBody,
           let jsonString = String(data: jsonData, encoding: .utf8) {
            print(jsonString)
        }
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }
            
            print("<- Response: Create/Update Client")
            print("<- POST: \(url.absoluteString)")
            print("<- Status Code: \(httpResponse.statusCode)")
            print("<- Response Body:")
            if let jsonString = String(data: data, encoding: .utf8) {
                print(jsonString)
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                throw NetworkError.serverError(httpResponse.statusCode)
            }
            
            let savedClient = try JSONDecoder().decode(AppClient.self, from: data)
            return savedClient
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
        } catch {
            throw error
        }
    }
    
    func fetchAnalyses(clientId: String, userId: String) async throws -> [SkinAnalysisResult] {
        var components = URLComponents(string: "\(AppConstants.baseUrl)/data")!
        components.queryItems = [
            URLQueryItem(name: "app_id", value: AppConstants.appId),
            URLQueryItem(name: "table_name", value: "skin_analyses"),
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "user_id", value: userId)
        ]
        
        guard let url = components.url else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        print("-> Request: Fetch Analyses")
        print("-> GET: \(url.absoluteString)")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }
            
            print("<- Response: Fetch Analyses")
            print("<- GET: \(url.absoluteString)")
            print("<- Status Code: \(httpResponse.statusCode)")
            print("<- Response Body:")
            if let jsonString = String(data: data, encoding: .utf8) {
                print(jsonString)
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                throw NetworkError.serverError(httpResponse.statusCode)
            }
            
            let analyses = try JSONDecoder().decode([SkinAnalysisResult].self, from: data)
            return analyses
        } catch is CancellationError {
            return []
        } catch let error as URLError where error.code == .cancelled {
            return []
        } catch {
            throw error
        }
    }
    
    func uploadImage(image: UIImage, userId: String) async throws -> String {
        let url = URL(string: "\(AppConstants.baseUrl)/data/upload")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"app_id\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(AppConstants.appId)\r\n".data(using: .utf8)!)
        
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"user_id\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(userId)\r\n".data(using: .utf8)!)
        
        if let imageData = image.jpegData(compressionQuality: 0.8) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"file\"; filename=\"skin_image.jpg\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
            body.append(imageData)
            body.append("\r\n".data(using: .utf8)!)
        }
        
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body
        
        print("-> Request: Upload Image")
        print("-> POST: \(url.absoluteString)")
        print("-> Parameters: multipart/form-data with image")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }
            
            print("<- Response: Upload Image")
            print("<- POST: \(url.absoluteString)")
            print("<- Status Code: \(httpResponse.statusCode)")
            print("<- Response Body:")
            if let jsonString = String(data: data, encoding: .utf8) {
                print(jsonString)
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                throw NetworkError.serverError(httpResponse.statusCode)
            }
            
            let uploadResponse = try JSONDecoder().decode(FileUploadResponse.self, from: data)
            return uploadResponse.url
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
        } catch {
            throw error
        }
    }
    
    func analyzeImage(
        image: UIImage,
        medicalHistory: String?,
        allergies: String?,
        knownSensitivities: String?,
        manualSkinType: String?,
        manualHydrationLevel: String?,
        manualSensitivity: String?,
        manualPoreCondition: String?,
        manualConcerns: String?,
        productsUsed: String?,
        treatmentsPerformed: String?,
        previousAnalyses: [SkinAnalysisResult]
    ) async throws -> AnalysisData {
        let url = URL(string: "\(AppConstants.baseUrl)/aiapi/answerimage")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"app_id\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(AppConstants.appId)\r\n".data(using: .utf8)!)
        
        if let medicalHistory = medicalHistory, !medicalHistory.isEmpty {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"medical_history\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(medicalHistory)\r\n".data(using: .utf8)!)
        }
        
        if let allergies = allergies, !allergies.isEmpty {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"allergies\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(allergies)\r\n".data(using: .utf8)!)
        }
        
        if let knownSensitivities = knownSensitivities, !knownSensitivities.isEmpty {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"known_sensitivities\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(knownSensitivities)\r\n".data(using: .utf8)!)
        }
        
        if let manualSkinType = manualSkinType, !manualSkinType.isEmpty {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"manual_skin_type\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(manualSkinType)\r\n".data(using: .utf8)!)
        }
        
        if let manualHydrationLevel = manualHydrationLevel, !manualHydrationLevel.isEmpty {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"manual_hydration_level\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(manualHydrationLevel)\r\n".data(using: .utf8)!)
        }
        
        if let manualSensitivity = manualSensitivity, !manualSensitivity.isEmpty {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"manual_sensitivity\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(manualSensitivity)\r\n".data(using: .utf8)!)
        }
        
        if let manualPoreCondition = manualPoreCondition, !manualPoreCondition.isEmpty {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"manual_pore_condition\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(manualPoreCondition)\r\n".data(using: .utf8)!)
        }
        
        if let manualConcerns = manualConcerns, !manualConcerns.isEmpty {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"manual_concerns\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(manualConcerns)\r\n".data(using: .utf8)!)
        }
        
        if let productsUsed = productsUsed, !productsUsed.isEmpty {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"products_used\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(productsUsed)\r\n".data(using: .utf8)!)
        }
        
        if let treatmentsPerformed = treatmentsPerformed, !treatmentsPerformed.isEmpty {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"treatments_performed\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(treatmentsPerformed)\r\n".data(using: .utf8)!)
        }
        
        if !previousAnalyses.isEmpty {
            let recentAnalyses = Array(previousAnalyses.prefix(3))
            if let jsonData = try? JSONEncoder().encode(recentAnalyses),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                body.append("--\(boundary)\r\n".data(using: .utf8)!)
                body.append("Content-Disposition: form-data; name=\"previous_analyses\"\r\n\r\n".data(using: .utf8)!)
                body.append("\(jsonString)\r\n".data(using: .utf8)!)
            }
        }
        
        if let imageData = image.jpegData(compressionQuality: 0.8) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"image\"; filename=\"skin_analysis.jpg\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
            body.append(imageData)
            body.append("\r\n".data(using: .utf8)!)
        }
        
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body
        
        print("-> Request: AI Image Analysis")
        print("-> POST: \(url.absoluteString)")
        print("-> Parameters: multipart/form-data with image and analysis context")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }
            
            print("<- Response: AI Image Analysis")
            print("<- POST: \(url.absoluteString)")
            print("<- Status Code: \(httpResponse.statusCode)")
            print("<- Response Body:")
            if let jsonString = String(data: data, encoding: .utf8) {
                print(jsonString)
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                throw NetworkError.serverError(httpResponse.statusCode)
            }
            
            let aiResponse = try JSONDecoder().decode(AIAnalysisResponse.self, from: data)
            
            let analysisData = AnalysisData(
                skinType: aiResponse.skinType,
                hydrationLevel: aiResponse.hydrationLevel,
                sensitivity: aiResponse.sensitivity,
                concerns: aiResponse.concerns,
                poreCondition: aiResponse.poreCondition,
                skinHealthScore: aiResponse.skinHealthScore,
                recommendations: aiResponse.recommendations,
                medicalConsiderations: aiResponse.medicalConsiderations,
                progressNotes: aiResponse.progressNotes
            )
            
            return analysisData
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
        } catch {
            throw error
        }
    }
    
    func saveAnalysis(
        clientId: String,
        userId: String,
        imageUrl: String,
        analysisResults: AnalysisData,
        notes: String,
        clientMedicalHistory: String?,
        clientAllergies: String?,
        clientKnownSensitivities: String?,
        productsUsed: String?,
        treatmentsPerformed: String?
    ) async throws -> SkinAnalysisResult {
        let url = URL(string: "\(AppConstants.baseUrl)/data")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let analysisRequest = CreateAnalysisRequest(
            appId: AppConstants.appId,
            tableName: "skin_analyses",
            data: CreateAnalysisRequest.AnalysisRequestData(
                id: nil,
                clientId: clientId,
                userId: userId,
                imageUrl: imageUrl,
                analysisResults: analysisResults,
                notes: notes,
                clientMedicalHistory: clientMedicalHistory,
                clientAllergies: clientAllergies,
                clientKnownSensitivities: clientKnownSensitivities,
                productsUsed: productsUsed,
                treatmentsPerformed: treatmentsPerformed
            )
        )
        
        request.httpBody = try JSONEncoder().encode(analysisRequest)
        
        print("-> Request: Save Analysis")
        print("-> POST: \(url.absoluteString)")
        print("-> Parameters:")
        if let jsonData = request.httpBody,
           let jsonString = String(data: jsonData, encoding: .utf8) {
            print(jsonString)
        }
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }
            
            print("<- Response: Save Analysis")
            print("<- POST: \(url.absoluteString)")
            print("<- Status Code: \(httpResponse.statusCode)")
            print("<- Response Body:")
            if let jsonString = String(data: data, encoding: .utf8) {
                print(jsonString)
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                throw NetworkError.serverError(httpResponse.statusCode)
            }
            
            let savedAnalysis = try JSONDecoder().decode(SkinAnalysisResult.self, from: data)
            return savedAnalysis
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
        } catch {
            throw error
        }
    }
    
    func deleteUser(userId: String) async throws {
        var components = URLComponents(string: "\(AppConstants.baseUrl)/data")!
        components.queryItems = [
            URLQueryItem(name: "app_id", value: AppConstants.appId),
            URLQueryItem(name: "table_name", value: "users"),
            URLQueryItem(name: "id", value: userId)
        ]
        
        guard let url = components.url else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        
        print("-> Request: Delete User")
        print("-> DELETE: \(url.absoluteString)")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }
            
            print("<- Response: Delete User")
            print("<- DELETE: \(url.absoluteString)")
            print("<- Status Code: \(httpResponse.statusCode)")
            print("<- Response Body:")
            if let jsonString = String(data: data, encoding: .utf8) {
                print(jsonString)
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                throw NetworkError.serverError(httpResponse.statusCode)
            }
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
        } catch {
            throw error
        }
    }
}

enum NetworkError: LocalizedError {
    case invalidURL
    case invalidResponse
    case serverError(Int)
    case invalidCredentials
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .serverError(let code):
            return "Server error: \(code)"
        case .invalidCredentials:
            return "Invalid credentials"
        }
    }
}