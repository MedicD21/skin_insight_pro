import Foundation
import UIKit

class NetworkService {
    static let shared = NetworkService()
    private let session: URLSession
    private var accessToken: String?
    private var refreshToken: String?

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)

        // Load tokens from UserDefaults
        self.accessToken = UserDefaults.standard.string(forKey: AppConstants.accessTokenKey)
        self.refreshToken = UserDefaults.standard.string(forKey: AppConstants.refreshTokenKey)
    }

    // MARK: - Helper Methods

    private func supabaseHeaders(authenticated: Bool = false) -> [String: String] {
        var headers = [
            "apikey": AppConstants.supabaseAnonKey,
            "Content-Type": "application/json"
        ]

        if authenticated, let token = accessToken {
            headers["Authorization"] = "Bearer \(token)"
        } else {
            headers["Authorization"] = "Bearer \(AppConstants.supabaseAnonKey)"
        }

        return headers
    }

    private func saveTokens(access: String, refresh: String, userId: String) {
        self.accessToken = access
        self.refreshToken = refresh
        UserDefaults.standard.set(access, forKey: AppConstants.accessTokenKey)
        UserDefaults.standard.set(refresh, forKey: AppConstants.refreshTokenKey)
        UserDefaults.standard.set(userId, forKey: AppConstants.userIdKey)
    }

    private func clearTokens() {
        self.accessToken = nil
        self.refreshToken = nil
        UserDefaults.standard.removeObject(forKey: AppConstants.accessTokenKey)
        UserDefaults.standard.removeObject(forKey: AppConstants.refreshTokenKey)
        UserDefaults.standard.removeObject(forKey: AppConstants.userIdKey)
    }

    // MARK: - Authentication with Supabase Auth

    func login(email: String, password: String) async throws -> AppUser {
        let url = URL(string: "\(AppConstants.supabaseUrl)/auth/v1/token?grant_type=password")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        for (key, value) in supabaseHeaders() {
            request.setValue(value, forHTTPHeaderField: key)
        }

        let loginData: [String: String] = [
            "email": email,
            "password": password
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: loginData)

        print("-> Request: Login with Supabase Auth")
        print("-> POST: \(url.absoluteString)")

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }

            print("<- Response: Login")
            print("<- Status Code: \(httpResponse.statusCode)")
            if let jsonString = String(data: data, encoding: .utf8) {
                print(jsonString)
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                if httpResponse.statusCode == 400 {
                    throw NetworkError.invalidCredentials
                }
                throw NetworkError.serverError(httpResponse.statusCode)
            }

            let authResponse = try JSONDecoder().decode(SupabaseAuthResponse.self, from: data)

            // Save tokens
            saveTokens(access: authResponse.accessToken, refresh: authResponse.refreshToken, userId: authResponse.user.id)

            // Fetch or create user profile
            let user = try await fetchOrCreateUserProfile(userId: authResponse.user.id, email: email, provider: "email")

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
        let url = URL(string: "\(AppConstants.supabaseUrl)/auth/v1/signup")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        for (key, value) in supabaseHeaders() {
            request.setValue(value, forHTTPHeaderField: key)
        }

        let signupData: [String: String] = [
            "email": email,
            "password": password
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: signupData)

        print("-> Request: Signup with Supabase Auth")
        print("-> POST: \(url.absoluteString)")

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }

            print("<- Response: Signup")
            print("<- Status Code: \(httpResponse.statusCode)")
            if let jsonString = String(data: data, encoding: .utf8) {
                print(jsonString)
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                throw NetworkError.serverError(httpResponse.statusCode)
            }

            let authResponse = try JSONDecoder().decode(SupabaseAuthResponse.self, from: data)

            // Save tokens
            saveTokens(access: authResponse.accessToken, refresh: authResponse.refreshToken, userId: authResponse.user.id)

            // Create user profile
            let user = try await fetchOrCreateUserProfile(userId: authResponse.user.id, email: email, provider: "email")

            return user
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
        } catch {
            throw error
        }
    }

    func createOrLoginAppleUser(appleUserId: String, email: String, fullName: PersonNameComponents?) async throws -> AppUser {
        // For Apple Sign In, we need to use a different approach
        // First check if user exists, if not create them

        // For now, create a unique email based on Apple User ID if email is not provided
        let userEmail = email.isEmpty ? "\(appleUserId)@appleid.private" : email

        // Try to sign up (will fail if user exists)
        // If signup fails, try to login

        // Generate a random password for Apple users (they won't use it)
        let randomPassword = UUID().uuidString

        do {
            // Try signup first
            let user = try await createUser(email: userEmail, password: randomPassword)

            // Update profile with Apple user ID and name
            try await updateUserProfile(userId: user.id ?? "", appleUserId: appleUserId, firstName: fullName?.givenName, lastName: fullName?.familyName)

            return user
        } catch {
            // User likely exists, try to login
            // For existing Apple users, we need a different flow
            // This is a limitation - we'll need to handle this better

            // For now, fetch user by apple_user_id from our profiles table
            let user = try await fetchUserByAppleId(appleUserId: appleUserId)
            return user
        }
    }

    private func fetchOrCreateUserProfile(userId: String, email: String, provider: String) async throws -> AppUser {
        // Check if profile exists
        var components = URLComponents(string: "\(AppConstants.supabaseUrl)/rest/v1/users")!
        components.queryItems = [
            URLQueryItem(name: "id", value: "eq.\(userId)")
        ]

        guard let url = components.url else {
            throw NetworkError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        for (key, value) in supabaseHeaders(authenticated: true) {
            request.setValue(value, forHTTPHeaderField: key)
        }
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw NetworkError.serverError(httpResponse.statusCode)
        }

        let users = try JSONDecoder().decode([AppUser].self, from: data)

        if let existingUser = users.first {
            return existingUser
        }

        // Create profile
        let createUrl = URL(string: "\(AppConstants.supabaseUrl)/rest/v1/users")!
        var createRequest = URLRequest(url: createUrl)
        createRequest.httpMethod = "POST"
        for (key, value) in supabaseHeaders(authenticated: true) {
            createRequest.setValue(value, forHTTPHeaderField: key)
        }
        createRequest.setValue("return=representation", forHTTPHeaderField: "Prefer")

        let userData: [String: Any] = [
            "id": userId,
            "email": email,
            "provider": provider,
            "is_admin": false
        ]

        createRequest.httpBody = try JSONSerialization.data(withJSONObject: userData)

        let (createData, createResponse) = try await session.data(for: createRequest)

        guard let createHttpResponse = createResponse as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        guard (200...299).contains(createHttpResponse.statusCode) else {
            throw NetworkError.serverError(createHttpResponse.statusCode)
        }

        let newUsers = try JSONDecoder().decode([AppUser].self, from: createData)
        guard let newUser = newUsers.first else {
            throw NetworkError.invalidResponse
        }

        return newUser
    }

    private func updateUserProfile(userId: String, appleUserId: String, firstName: String?, lastName: String?) async throws {
        let url = URL(string: "\(AppConstants.supabaseUrl)/rest/v1/users?id=eq.\(userId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        for (key, value) in supabaseHeaders(authenticated: true) {
            request.setValue(value, forHTTPHeaderField: key)
        }

        var userData: [String: Any] = [
            "apple_user_id": appleUserId,
            "provider": "apple"
        ]

        if let firstName = firstName {
            userData["first_name"] = firstName
        }
        if let lastName = lastName {
            userData["last_name"] = lastName
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: userData)

        let (_, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw NetworkError.serverError(httpResponse.statusCode)
        }
    }

    private func fetchUserByAppleId(appleUserId: String) async throws -> AppUser {
        var components = URLComponents(string: "\(AppConstants.supabaseUrl)/rest/v1/users")!
        components.queryItems = [
            URLQueryItem(name: "apple_user_id", value: "eq.\(appleUserId)")
        ]

        guard let url = components.url else {
            throw NetworkError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        for (key, value) in supabaseHeaders(authenticated: true) {
            request.setValue(value, forHTTPHeaderField: key)
        }

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw NetworkError.serverError(httpResponse.statusCode)
        }

        let users = try JSONDecoder().decode([AppUser].self, from: data)

        guard let user = users.first else {
            throw NetworkError.invalidCredentials
        }

        return user
    }

    // MARK: - Clients

    func fetchClients(userId: String) async throws -> [AppClient] {
        var components = URLComponents(string: "\(AppConstants.supabaseUrl)/rest/v1/clients")!
        components.queryItems = [
            URLQueryItem(name: "user_id", value: "eq.\(userId)"),
            URLQueryItem(name: "order", value: "created_at.desc")
        ]

        guard let url = components.url else {
            throw NetworkError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        for (key, value) in supabaseHeaders(authenticated: true) {
            request.setValue(value, forHTTPHeaderField: key)
        }

        print("-> Request: Fetch Clients")
        print("-> GET: \(url.absoluteString)")

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }

            print("<- Response: Fetch Clients")
            print("<- Status Code: \(httpResponse.statusCode)")

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
        if let clientId = client.id {
            // Update existing client
            let url = URL(string: "\(AppConstants.supabaseUrl)/rest/v1/clients?id=eq.\(clientId)")!
            var request = URLRequest(url: url)
            request.httpMethod = "PATCH"
            for (key, value) in supabaseHeaders(authenticated: true) {
                request.setValue(value, forHTTPHeaderField: key)
            }
            request.setValue("return=representation", forHTTPHeaderField: "Prefer")

            let clientData: [String: Any?] = [
                "name": client.name,
                "phone": client.phone,
                "email": client.email,
                "notes": client.notes,
                "medical_history": client.medicalHistory,
                "allergies": client.allergies,
                "known_sensitivities": client.knownSensitivities,
                "medications": client.medications
            ]

            request.httpBody = try JSONSerialization.data(withJSONObject: clientData.compactMapValues { $0 })

            print("-> Request: Update Client")
            print("-> PATCH: \(url.absoluteString)")

            do {
                let (data, response) = try await session.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse else {
                    throw NetworkError.invalidResponse
                }

                print("<- Response: Update Client")
                print("<- Status Code: \(httpResponse.statusCode)")

                guard (200...299).contains(httpResponse.statusCode) else {
                    throw NetworkError.serverError(httpResponse.statusCode)
                }

                let clients = try JSONDecoder().decode([AppClient].self, from: data)
                guard let updatedClient = clients.first else {
                    throw NetworkError.invalidResponse
                }

                return updatedClient
            } catch let error as URLError {
                if error.code == .notConnectedToInternet || error.code == .networkConnectionLost {
                    throw NetworkError.networkUnavailable
                } else if error.code == .timedOut {
                    throw NetworkError.timeout
                }
                throw error
            } catch {
                throw error
            }
        } else {
            // Create new client
            let url = URL(string: "\(AppConstants.supabaseUrl)/rest/v1/clients")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            for (key, value) in supabaseHeaders(authenticated: true) {
                request.setValue(value, forHTTPHeaderField: key)
            }
            request.setValue("return=representation", forHTTPHeaderField: "Prefer")

            let clientData: [String: Any] = [
                "user_id": userId,
                "name": client.name ?? "",
                "phone": client.phone ?? "",
                "email": client.email ?? "",
                "notes": client.notes ?? "",
                "medical_history": client.medicalHistory ?? "",
                "allergies": client.allergies ?? "",
                "known_sensitivities": client.knownSensitivities ?? "",
                "medications": client.medications ?? ""
            ]

            request.httpBody = try JSONSerialization.data(withJSONObject: clientData)

            print("-> Request: Create Client")
            print("-> POST: \(url.absoluteString)")

            do {
                let (data, response) = try await session.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse else {
                    throw NetworkError.invalidResponse
                }

                print("<- Response: Create Client")
                print("<- Status Code: \(httpResponse.statusCode)")

                guard (200...299).contains(httpResponse.statusCode) else {
                    throw NetworkError.serverError(httpResponse.statusCode)
                }

                let clients = try JSONDecoder().decode([AppClient].self, from: data)
                guard let newClient = clients.first else {
                    throw NetworkError.invalidResponse
                }

                return newClient
            } catch let error as URLError {
                if error.code == .notConnectedToInternet || error.code == .networkConnectionLost {
                    throw NetworkError.networkUnavailable
                } else if error.code == .timedOut {
                    throw NetworkError.timeout
                }
                throw error
            } catch {
                throw error
            }
        }
    }

    // MARK: - Skin Analyses

    func fetchAnalyses(clientId: String, userId: String) async throws -> [SkinAnalysisResult] {
        var components = URLComponents(string: "\(AppConstants.supabaseUrl)/rest/v1/skin_analyses")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: "eq.\(clientId)"),
            URLQueryItem(name: "user_id", value: "eq.\(userId)"),
            URLQueryItem(name: "order", value: "created_at.desc")
        ]

        guard let url = components.url else {
            throw NetworkError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        for (key, value) in supabaseHeaders(authenticated: true) {
            request.setValue(value, forHTTPHeaderField: key)
        }

        print("-> Request: Fetch Analyses")
        print("-> GET: \(url.absoluteString)")

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }

            print("<- Response: Fetch Analyses")
            print("<- Status Code: \(httpResponse.statusCode)")

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

    func saveAnalysis(
        clientId: String,
        userId: String,
        imageUrl: String,
        analysisResults: AnalysisData,
        notes: String,
        clientMedicalHistory: String?,
        clientAllergies: String?,
        clientKnownSensitivities: String?,
        clientMedications: String?,
        productsUsed: String?,
        treatmentsPerformed: String?
    ) async throws -> SkinAnalysisResult {
        let url = URL(string: "\(AppConstants.supabaseUrl)/rest/v1/skin_analyses")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        for (key, value) in supabaseHeaders(authenticated: true) {
            request.setValue(value, forHTTPHeaderField: key)
        }
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let analysisResultsData = try encoder.encode(analysisResults)
        let analysisResultsJSON = try JSONSerialization.jsonObject(with: analysisResultsData)

        var analysisData: [String: Any] = [
            "client_id": clientId,
            "user_id": userId,
            "image_url": imageUrl,
            "analysis_results": analysisResultsJSON,
            "notes": notes
        ]

        if let clientMedicalHistory = clientMedicalHistory {
            analysisData["client_medical_history"] = clientMedicalHistory
        }
        if let clientAllergies = clientAllergies {
            analysisData["client_allergies"] = clientAllergies
        }
        if let clientKnownSensitivities = clientKnownSensitivities {
            analysisData["client_known_sensitivities"] = clientKnownSensitivities
        }
        if let clientMedications = clientMedications {
            analysisData["client_medications"] = clientMedications
        }
        if let productsUsed = productsUsed {
            analysisData["products_used"] = productsUsed
        }
        if let treatmentsPerformed = treatmentsPerformed {
            analysisData["treatments_performed"] = treatmentsPerformed
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: analysisData)

        print("-> Request: Save Analysis")
        print("-> POST: \(url.absoluteString)")

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }

            print("<- Response: Save Analysis")
            print("<- Status Code: \(httpResponse.statusCode)")

            guard (200...299).contains(httpResponse.statusCode) else {
                throw NetworkError.serverError(httpResponse.statusCode)
            }

            let analyses = try JSONDecoder().decode([SkinAnalysisResult].self, from: data)
            guard let savedAnalysis = analyses.first else {
                throw NetworkError.invalidResponse
            }

            return savedAnalysis
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
        } catch {
            throw error
        }
    }

    // MARK: - Image Upload & AI Analysis

    func uploadImage(image: UIImage, userId: String) async throws -> String {
        // Use Supabase Storage API
        let fileName = "\(userId)/\(UUID().uuidString).jpg"
        let url = URL(string: "\(AppConstants.supabaseUrl)/storage/v1/object/skin-images/\(fileName)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(AppConstants.supabaseAnonKey, forHTTPHeaderField: "apikey")
        if let token = accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        } else {
            request.setValue("Bearer \(AppConstants.supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        }
        request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")

        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw NetworkError.invalidResponse
        }

        request.httpBody = imageData

        print("-> Request: Upload Image")
        print("-> POST: \(url.absoluteString)")

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }

            print("<- Response: Upload Image")
            print("<- Status Code: \(httpResponse.statusCode)")
            if let jsonString = String(data: data, encoding: .utf8) {
                print(jsonString)
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                throw NetworkError.serverError(httpResponse.statusCode)
            }

            // Return public URL
            return "\(AppConstants.supabaseUrl)/storage/v1/object/public/skin-images/\(fileName)"
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
        medications: String?,
        manualSkinType: String?,
        manualHydrationLevel: String?,
        manualSensitivity: String?,
        manualPoreCondition: String?,
        manualConcerns: String?,
        productsUsed: String?,
        treatmentsPerformed: String?,
        previousAnalyses: [SkinAnalysisResult]
    ) async throws -> AnalysisData {
        // AI analysis still uses the separate AI API endpoint
        let url = URL(string: "\(AppConstants.aiApiUrl)/aiapi/answerimage")!
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

        if let medications = medications, !medications.isEmpty {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"medications\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(medications)\r\n".data(using: .utf8)!)
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

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }

            print("<- Response: AI Image Analysis")
            print("<- Status Code: \(httpResponse.statusCode)")

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

    // MARK: - Products

    func fetchProducts(userId: String) async throws -> [Product] {
        var components = URLComponents(string: "\(AppConstants.supabaseUrl)/rest/v1/products")!
        components.queryItems = [
            URLQueryItem(name: "user_id", value: "eq.\(userId)"),
            URLQueryItem(name: "order", value: "created_at.desc")
        ]

        guard let url = components.url else {
            throw NetworkError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        for (key, value) in supabaseHeaders(authenticated: true) {
            request.setValue(value, forHTTPHeaderField: key)
        }

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw NetworkError.serverError(httpResponse.statusCode)
        }

        let products = try JSONDecoder().decode([Product].self, from: data)
        return products
    }

    func createOrUpdateProduct(product: Product, userId: String) async throws -> Product {
        if let productId = product.id {
            // Update existing product
            let url = URL(string: "\(AppConstants.supabaseUrl)/rest/v1/products?id=eq.\(productId)")!
            var request = URLRequest(url: url)
            request.httpMethod = "PATCH"
            for (key, value) in supabaseHeaders(authenticated: true) {
                request.setValue(value, forHTTPHeaderField: key)
            }
            request.setValue("return=representation", forHTTPHeaderField: "Prefer")

            let productData: [String: Any?] = [
                "name": product.name,
                "brand": product.brand,
                "category": product.category,
                "description": product.description,
                "ingredients": product.ingredients,
                "skin_types": product.skinTypes,
                "concerns": product.concerns,
                "is_active": product.isActive
            ]

            request.httpBody = try JSONSerialization.data(withJSONObject: productData.compactMapValues { $0 })

            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                throw NetworkError.serverError(httpResponse.statusCode)
            }

            let products = try JSONDecoder().decode([Product].self, from: data)
            guard let updatedProduct = products.first else {
                throw NetworkError.invalidResponse
            }

            return updatedProduct
        } else {
            // Create new product
            let url = URL(string: "\(AppConstants.supabaseUrl)/rest/v1/products")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            for (key, value) in supabaseHeaders(authenticated: true) {
                request.setValue(value, forHTTPHeaderField: key)
            }
            request.setValue("return=representation", forHTTPHeaderField: "Prefer")

            let productData: [String: Any] = [
                "user_id": userId,
                "name": product.name ?? "",
                "brand": product.brand ?? "",
                "category": product.category ?? "",
                "description": product.description ?? "",
                "ingredients": product.ingredients ?? "",
                "skin_types": product.skinTypes ?? [],
                "concerns": product.concerns ?? [],
                "is_active": product.isActive ?? true
            ]

            request.httpBody = try JSONSerialization.data(withJSONObject: productData)

            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                throw NetworkError.serverError(httpResponse.statusCode)
            }

            let products = try JSONDecoder().decode([Product].self, from: data)
            guard let newProduct = products.first else {
                throw NetworkError.invalidResponse
            }

            return newProduct
        }
    }

    // MARK: - AI Rules

    func fetchAIRules(userId: String) async throws -> [AIRule] {
        var components = URLComponents(string: "\(AppConstants.supabaseUrl)/rest/v1/ai_rules")!
        components.queryItems = [
            URLQueryItem(name: "user_id", value: "eq.\(userId)"),
            URLQueryItem(name: "order", value: "priority.desc")
        ]

        guard let url = components.url else {
            throw NetworkError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        for (key, value) in supabaseHeaders(authenticated: true) {
            request.setValue(value, forHTTPHeaderField: key)
        }

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw NetworkError.serverError(httpResponse.statusCode)
        }

        let rules = try JSONDecoder().decode([AIRule].self, from: data)
        return rules
    }

    func createOrUpdateAIRule(rule: AIRule, userId: String) async throws -> AIRule {
        if let ruleId = rule.id {
            // Update existing rule
            let url = URL(string: "\(AppConstants.supabaseUrl)/rest/v1/ai_rules?id=eq.\(ruleId)")!
            var request = URLRequest(url: url)
            request.httpMethod = "PATCH"
            for (key, value) in supabaseHeaders(authenticated: true) {
                request.setValue(value, forHTTPHeaderField: key)
            }
            request.setValue("return=representation", forHTTPHeaderField: "Prefer")

            let ruleData: [String: Any?] = [
                "name": rule.name,
                "condition": rule.condition,
                "product_id": rule.productId,
                "priority": rule.priority,
                "is_active": rule.isActive
            ]

            request.httpBody = try JSONSerialization.data(withJSONObject: ruleData.compactMapValues { $0 })

            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                throw NetworkError.serverError(httpResponse.statusCode)
            }

            let rules = try JSONDecoder().decode([AIRule].self, from: data)
            guard let updatedRule = rules.first else {
                throw NetworkError.invalidResponse
            }

            return updatedRule
        } else {
            // Create new rule
            let url = URL(string: "\(AppConstants.supabaseUrl)/rest/v1/ai_rules")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            for (key, value) in supabaseHeaders(authenticated: true) {
                request.setValue(value, forHTTPHeaderField: key)
            }
            request.setValue("return=representation", forHTTPHeaderField: "Prefer")

            let ruleData: [String: Any] = [
                "user_id": userId,
                "name": rule.name ?? "",
                "condition": rule.condition ?? "",
                "product_id": rule.productId ?? "",
                "priority": rule.priority ?? 0,
                "is_active": rule.isActive ?? true
            ]

            request.httpBody = try JSONSerialization.data(withJSONObject: ruleData)

            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                throw NetworkError.serverError(httpResponse.statusCode)
            }

            let rules = try JSONDecoder().decode([AIRule].self, from: data)
            guard let newRule = rules.first else {
                throw NetworkError.invalidResponse
            }

            return newRule
        }
    }

    // MARK: - User Management

    func deleteUser(userId: String) async throws {
        let url = URL(string: "\(AppConstants.supabaseUrl)/rest/v1/users?id=eq.\(userId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        for (key, value) in supabaseHeaders(authenticated: true) {
            request.setValue(value, forHTTPHeaderField: key)
        }

        print("-> Request: Delete User")
        print("-> DELETE: \(url.absoluteString)")

        do {
            let (_, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }

            print("<- Response: Delete User")
            print("<- Status Code: \(httpResponse.statusCode)")

            guard (200...299).contains(httpResponse.statusCode) else {
                throw NetworkError.serverError(httpResponse.statusCode)
            }

            // Also logout from Supabase Auth
            clearTokens()
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
        } catch {
            throw error
        }
    }

    func logout() {
        clearTokens()
    }
}

// MARK: - Supabase Auth Response Models

struct SupabaseAuthResponse: Codable {
    let accessToken: String
    let refreshToken: String
    let user: SupabaseUser

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case user
    }
}

struct SupabaseUser: Codable {
    let id: String
    let email: String
}

enum NetworkError: LocalizedError {
    case invalidURL
    case invalidResponse
    case serverError(Int)
    case invalidCredentials
    case networkUnavailable
    case timeout

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server. Please try again."
        case .serverError(let code):
            switch code {
            case 400:
                return "Bad request. Please check your input and try again."
            case 401:
                return "Authentication failed. Please log in again."
            case 404:
                return "Resource not found. Please contact support."
            case 500:
                return "Server error. Our team has been notified. Please try again later."
            case 503:
                return "Service temporarily unavailable. Please try again in a few moments."
            default:
                return "Server error (\(code)). Please try again later."
            }
        case .invalidCredentials:
            return "Invalid email or password. Please try again."
        case .networkUnavailable:
            return "No internet connection. Please check your network and try again."
        case .timeout:
            return "Request timed out. Please check your connection and try again."
        }
    }
}
