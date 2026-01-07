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

        #if DEBUG
        print("-> Request: Login with Supabase Auth")
        #endif

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }

            #if DEBUG
            print("<- Response: Login")
            if let jsonString = String(data: data, encoding: .utf8) {
                #if DEBUG
                print(jsonString)
                #endif
            }
            #endif

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

        #if DEBUG
        print("-> Request: Signup with Supabase Auth")
        print("-> POST: \(url.absoluteString)")

        #endif
        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }

            #if DEBUG
            print("<- Response: Signup")
            print("<- Status Code: \(httpResponse.statusCode)")
            if let jsonString = String(data: data, encoding: .utf8) {
                print(jsonString)
            }

            #endif
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

        #if DEBUG
        print("-> Request: Fetch User Profile")
        print("-> GET: \(url.absoluteString)")
        print("-> Headers: \(request.allHTTPHeaderFields ?? [:])")

        #endif
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        #if DEBUG
        print("<- Response: Fetch User Profile")
        print("<- Status Code: \(httpResponse.statusCode)")
        if let jsonString = String(data: data, encoding: .utf8) {
            print("<- Body: \(jsonString)")
        }

        #endif
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

        #if DEBUG
        print("-> Request: Create User Profile")
        print("-> POST: \(createUrl.absoluteString)")
        print("-> Body: \(userData)")

        #endif
        let (createData, createResponse) = try await session.data(for: createRequest)

        guard let createHttpResponse = createResponse as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        #if DEBUG
        print("<- Response: Create User Profile")
        print("<- Status Code: \(createHttpResponse.statusCode)")
        if let jsonString = String(data: createData, encoding: .utf8) {
            print("<- Body: \(jsonString)")
        }

        #endif
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

    func fetchUser(userId: String) async throws -> AppUser {
        var components = URLComponents(string: "\(AppConstants.supabaseUrl)/rest/v1/users")!
        components.queryItems = [
            URLQueryItem(name: "id", value: "eq.\(userId)"),
            URLQueryItem(name: "select", value: "*,company_name:companies(name),company_email:companies(email)")
        ]

        guard let url = components.url else {
            throw NetworkError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        for (key, value) in supabaseHeaders(authenticated: true) {
            request.setValue(value, forHTTPHeaderField: key)
        }

        #if DEBUG
        print("-> Request: Fetch User Profile")
        print("-> GET: \(url.absoluteString)")
        #endif

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        #if DEBUG
        print("<- Response: Fetch User Profile")
        print("<- Status Code: \(httpResponse.statusCode)")
        #endif

        guard (200...299).contains(httpResponse.statusCode) else {
            throw NetworkError.serverError(httpResponse.statusCode)
        }

        let users = try JSONDecoder().decode([AppUser].self, from: data)

        guard let user = users.first else {
            throw NetworkError.invalidCredentials
        }

        return user
    }

    // MARK: - Company Management

    func createCompany(name: String) async throws -> (companyId: String, companyCode: String) {
        guard let userId = await AuthenticationManager.shared.currentUser?.id else {
            throw NetworkError.invalidCredentials
        }

        // Generate unique company code
        let companyCode = generateCompanyCode()

        // Create company
        let companyPayload: [String: Any] = [
            "name": name,
            "company_code": companyCode
        ]

        let companyData = try JSONSerialization.data(withJSONObject: companyPayload)

        var companyRequest = URLRequest(url: URL(string: "\(AppConstants.supabaseUrl)/rest/v1/companies")!)
        companyRequest.httpMethod = "POST"
        companyRequest.httpBody = companyData
        for (key, value) in supabaseHeaders(authenticated: true) {
            companyRequest.setValue(value, forHTTPHeaderField: key)
        }
        companyRequest.setValue("return=representation", forHTTPHeaderField: "Prefer")

        let (companyResponseData, companyResponse) = try await session.data(for: companyRequest)

        guard let httpResponse = companyResponse as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw NetworkError.serverError((companyResponse as? HTTPURLResponse)?.statusCode ?? 500)
        }

        let companies = try JSONDecoder().decode([Company].self, from: companyResponseData)
        guard let newCompany = companies.first, let companyId = newCompany.id else {
            throw NetworkError.invalidResponse
        }

        // Update user with company_id and set as both company admin and platform admin
        let userPayload: [String: Any] = [
            "company_id": companyId,
            "is_company_admin": true,
            "is_admin": true
        ]

        let userData = try JSONSerialization.data(withJSONObject: userPayload)

        var userRequest = URLRequest(url: URL(string: "\(AppConstants.supabaseUrl)/rest/v1/users?id=eq.\(userId)")!)
        userRequest.httpMethod = "PATCH"
        userRequest.httpBody = userData
        for (key, value) in supabaseHeaders(authenticated: true) {
            userRequest.setValue(value, forHTTPHeaderField: key)
        }

        let (_, userResponse) = try await session.data(for: userRequest)

        guard let userHttpResponse = userResponse as? HTTPURLResponse,
              (200...299).contains(userHttpResponse.statusCode) else {
            throw NetworkError.serverError((userResponse as? HTTPURLResponse)?.statusCode ?? 500)
        }

        #if DEBUG
        print("✅ Company created successfully")
        print("   Company ID: \(companyId)")
        print("   Company Code: \(companyCode)")
        print("   User \(userId) set as company admin and platform admin")
        #endif

        return (companyId, companyCode)
    }

    func joinCompany(code: String) async throws {
        guard let userId = await AuthenticationManager.shared.currentUser?.id else {
            throw NetworkError.invalidCredentials
        }

        // Find company by code
        var components = URLComponents(string: "\(AppConstants.supabaseUrl)/rest/v1/companies")!
        components.queryItems = [
            URLQueryItem(name: "company_code", value: "eq.\(code)")
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

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw NetworkError.serverError((response as? HTTPURLResponse)?.statusCode ?? 500)
        }

        let companies = try JSONDecoder().decode([Company].self, from: data)
        guard let company = companies.first, let companyId = company.id else {
            throw NetworkError.custom("Company not found with code: \(code)")
        }

        // Update user with company_id
        let payload: [String: Any] = [
            "company_id": companyId
        ]

        let jsonData = try JSONSerialization.data(withJSONObject: payload)

        var updateRequest = URLRequest(url: URL(string: "\(AppConstants.supabaseUrl)/rest/v1/users?id=eq.\(userId)")!)
        updateRequest.httpMethod = "PATCH"
        updateRequest.httpBody = jsonData
        for (key, value) in supabaseHeaders(authenticated: true) {
            updateRequest.setValue(value, forHTTPHeaderField: key)
        }

        let (_, updateResponse) = try await session.data(for: updateRequest)

        guard let updateHttpResponse = updateResponse as? HTTPURLResponse,
              (200...299).contains(updateHttpResponse.statusCode) else {
            throw NetworkError.serverError((updateResponse as? HTTPURLResponse)?.statusCode ?? 500)
        }
    }

    private func generateCompanyCode() -> String {
        let letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<8).map { _ in letters.randomElement()! })
    }

    // MARK: - Receipt Validation

    func validateReceipt(receipt: String, companyId: String, productId: String, transactionId: String) async throws {
        // Call Supabase Edge Function to validate receipt
        let payload: [String: Any] = [
            "receipt": receipt,
            "company_id": companyId,
            "product_id": productId,
            "transaction_id": transactionId
        ]

        let jsonData = try JSONSerialization.data(withJSONObject: payload)

        var request = URLRequest(url: URL(string: "\(AppConstants.supabaseUrl)/functions/v1/validate-receipt")!)
        request.httpMethod = "POST"
        request.httpBody = jsonData
        for (key, value) in supabaseHeaders(authenticated: true) {
            request.setValue(value, forHTTPHeaderField: key)
        }

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        if !(200...299).contains(httpResponse.statusCode) {
            if let errorResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let message = errorResponse["error"] as? String {
                throw NetworkError.custom("Receipt validation failed: \(message)")
            }
            throw NetworkError.serverError(httpResponse.statusCode)
        }

        print("✅ Receipt validated successfully")
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

        #if DEBUG
        print("-> Request: Fetch Clients")
        print("-> GET: \(url.absoluteString)")

        #endif
        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }

            #if DEBUG
            print("<- Response: Fetch Clients")
            print("<- Status Code: \(httpResponse.statusCode)")

            #endif
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

    func fetchClientsByCompany(companyId: String) async throws -> [AppClient] {
        var components = URLComponents(string: "\(AppConstants.supabaseUrl)/rest/v1/clients")!
        components.queryItems = [
            URLQueryItem(name: "company_id", value: "eq.\(companyId)"),
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

        #if DEBUG
        print("-> Request: Fetch Clients by Company")
        print("-> GET: \(url.absoluteString)")

        #endif
        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }

            #if DEBUG
            print("<- Response: Fetch Clients by Company")
            print("<- Status Code: \(httpResponse.statusCode)")

            #endif
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
                "first_name": client.firstName,
                "last_name": client.lastName,
                "phone": client.phone,
                "email": client.email,
                "notes": client.notes,
                "medical_history": client.medicalHistory,
                "allergies": client.allergies,
                "known_sensitivities": client.knownSensitivities,
                "medications": client.medications,
                "products_to_avoid": (client.productsToAvoid?.isEmpty == false ? client.productsToAvoid : NSNull()),
                "profile_image_url": client.profileImageUrl,
                "company_id": client.companyId,
                "fillers_date": client.fillersDate,
                "biostimulators_date": client.biostimulatorsDate,
                "consent_signature": (client.consentSignature?.isEmpty == false ? client.consentSignature : nil),
                "consent_date": (client.consentDate?.isEmpty == false ? client.consentDate : nil)
            ]

            request.httpBody = try JSONSerialization.data(withJSONObject: clientData.compactMapValues { $0 })

            #if DEBUG
            print("-> Request: Update Client")
            print("-> PATCH: \(url.absoluteString)")

            #endif
            do {
                let (data, response) = try await session.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse else {
                    throw NetworkError.invalidResponse
                }

                #if DEBUG
                print("<- Response: Update Client")
                print("<- Status Code: \(httpResponse.statusCode)")

                #endif
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

            let clientData: [String: Any?] = [
                "user_id": userId,
                "name": client.name ?? "",
                "first_name": client.firstName,
                "last_name": client.lastName,
                "phone": client.phone ?? "",
                "email": client.email ?? "",
                "notes": client.notes,
                "medical_history": client.medicalHistory,
                "allergies": client.allergies,
                "known_sensitivities": client.knownSensitivities,
                "medications": client.medications,
                "products_to_avoid": (client.productsToAvoid?.isEmpty == false ? client.productsToAvoid : NSNull()),
                "profile_image_url": client.profileImageUrl,
                "company_id": client.companyId,
                "fillers_date": client.fillersDate,
                "biostimulators_date": client.biostimulatorsDate,
                "consent_signature": (client.consentSignature?.isEmpty == false ? client.consentSignature : nil),
                "consent_date": (client.consentDate?.isEmpty == false ? client.consentDate : nil)
            ]

            request.httpBody = try JSONSerialization.data(withJSONObject: clientData.compactMapValues { $0 })

            #if DEBUG
            print("-> Request: Create Client")
            print("-> POST: \(url.absoluteString)")

            #endif
            do {
                let (data, response) = try await session.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse else {
                    throw NetworkError.invalidResponse
                }

                #if DEBUG
                print("<- Response: Create Client")
                print("<- Status Code: \(httpResponse.statusCode)")

                #endif
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

    func deleteClient(clientId: String) async throws {
        let url = URL(string: "\(AppConstants.supabaseUrl)/rest/v1/clients?id=eq.\(clientId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        for (key, value) in supabaseHeaders(authenticated: true) {
            request.setValue(value, forHTTPHeaderField: key)
        }

        #if DEBUG
        print("-> Request: Delete Client")
        print("-> DELETE: \(url.absoluteString)")
        #endif

        let (_, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw NetworkError.serverError(httpResponse.statusCode)
        }
    }

    // MARK: - User Profile

    func updateUserProfile(_ user: AppUser) async throws -> AppUser {
        guard let userId = user.id else {
            throw NetworkError.invalidResponse
        }

        let url = URL(string: "\(AppConstants.supabaseUrl)/rest/v1/users?id=eq.\(userId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        for (key, value) in supabaseHeaders(authenticated: true) {
            request.setValue(value, forHTTPHeaderField: key)
        }
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")

        var userData: [String: Any] = [:]

        if let firstName = user.firstName, !firstName.isEmpty {
            userData["first_name"] = firstName
        }
        if let lastName = user.lastName, !lastName.isEmpty {
            userData["last_name"] = lastName
        }
        if let phoneNumber = user.phoneNumber, !phoneNumber.isEmpty {
            userData["phone_number"] = phoneNumber
        }
        if let role = user.role, !role.isEmpty {
            userData["role"] = role
        }
        if let profileImageUrl = user.profileImageUrl, !profileImageUrl.isEmpty {
            userData["profile_image_url"] = profileImageUrl
        }
        if let companyId = user.companyId, !companyId.isEmpty {
            userData["company_id"] = companyId
        }
        if let companyName = user.companyName, !companyName.isEmpty {
            userData["company_name"] = companyName
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: userData)

        #if DEBUG
        print("-> Request: Update User Profile")
        print("-> PATCH: \(url.absoluteString)")
        print("-> Body: \(userData)")

        #endif
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        #if DEBUG
        print("<- Response: Update User Profile")
        print("<- Status Code: \(httpResponse.statusCode)")

        #endif
        guard (200...299).contains(httpResponse.statusCode) else {
            if let errorString = String(data: data, encoding: .utf8) {
                #if DEBUG
                print("<- Error Response: \(errorString)")
                #endif
            }
            throw NetworkError.serverError(httpResponse.statusCode)
        }

        let users = try JSONDecoder().decode([AppUser].self, from: data)
        guard let updatedUser = users.first else {
            throw NetworkError.invalidResponse
        }

        return updatedUser
    }

    func updatePassword(newPassword: String) async throws {
        let url = URL(string: "\(AppConstants.supabaseUrl)/auth/v1/user")!
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        for (key, value) in supabaseHeaders(authenticated: true) {
            request.setValue(value, forHTTPHeaderField: key)
        }

        let passwordData: [String: Any] = ["password": newPassword]
        request.httpBody = try JSONSerialization.data(withJSONObject: passwordData)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            if let errorString = String(data: data, encoding: .utf8) {
                #if DEBUG
                print("Password update error: \(errorString)")
                #endif
            }
            throw NetworkError.serverError(httpResponse.statusCode)
        }
    }

    // MARK: - Companies

    func fetchCompany(id: String) async throws -> Company {
        let url = URL(string: "\(AppConstants.supabaseUrl)/rest/v1/companies?id=eq.\(id)")!
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

        let companies = try JSONDecoder().decode([Company].self, from: data)
        guard let company = companies.first else {
            throw NetworkError.invalidResponse
        }

        return company
    }

    func createOrUpdateCompany(_ company: Company) async throws -> Company {
        if let companyId = company.id {
            // Update existing company
            let url = URL(string: "\(AppConstants.supabaseUrl)/rest/v1/companies?id=eq.\(companyId)")!
            var request = URLRequest(url: url)
            request.httpMethod = "PATCH"
            for (key, value) in supabaseHeaders(authenticated: true) {
                request.setValue(value, forHTTPHeaderField: key)
            }
            request.setValue("return=representation", forHTTPHeaderField: "Prefer")

            let companyData: [String: Any?] = [
                "name": company.name,
                "address": company.address,
                "phone": company.phone,
                "email": company.email,
                "logo_url": company.logoUrl,
                "website": company.website
            ]

            request.httpBody = try JSONSerialization.data(withJSONObject: companyData.compactMapValues { $0 })

            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                throw NetworkError.serverError(httpResponse.statusCode)
            }

            let companies = try JSONDecoder().decode([Company].self, from: data)
            guard let updatedCompany = companies.first else {
                throw NetworkError.invalidResponse
            }

            return updatedCompany
        } else {
            // Create new company
            let url = URL(string: "\(AppConstants.supabaseUrl)/rest/v1/companies")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            for (key, value) in supabaseHeaders(authenticated: true) {
                request.setValue(value, forHTTPHeaderField: key)
            }
            request.setValue("return=representation", forHTTPHeaderField: "Prefer")

            let companyData: [String: Any] = [
                "name": company.name ?? "",
                "address": company.address ?? "",
                "phone": company.phone ?? "",
                "email": company.email ?? "",
                "logo_url": company.logoUrl ?? "",
                "website": company.website ?? ""
            ]

            request.httpBody = try JSONSerialization.data(withJSONObject: companyData)

            #if DEBUG
            print("-> Request: Create Company")
            print("-> POST: \(url.absoluteString)")
            print("-> Headers: \(request.allHTTPHeaderFields ?? [:])")
            print("-> Body: \(companyData)")
            print("-> Access Token: \(accessToken ?? "NIL")")

            #endif
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }

            #if DEBUG
            print("<- Response: Create Company")
            print("<- Status Code: \(httpResponse.statusCode)")

            #endif
            guard (200...299).contains(httpResponse.statusCode) else {
                // Print error response body
                if let errorString = String(data: data, encoding: .utf8) {
                    #if DEBUG
                    print("<- Error Response: \(errorString)")
                    #endif
                }
                throw NetworkError.serverError(httpResponse.statusCode)
            }

            let companies = try JSONDecoder().decode([Company].self, from: data)
            guard let newCompany = companies.first else {
                throw NetworkError.invalidResponse
            }

            return newCompany
        }
    }

    func updateCompanyId(oldId: String, newId: String) async throws {
        #if DEBUG
        print("🏢 Updating company ID from '\(oldId)' to '\(newId)'")
        print("⚠️ Step 1: Updating foreign keys first (users and clients)")
        #endif

        // IMPORTANT: Update foreign keys FIRST before changing the primary key
        // Step 1: Update all users with the old company_id to the new company_id
        let updateUsersUrl = URL(string: "\(AppConstants.supabaseUrl)/rest/v1/users?company_id=eq.\(oldId)")!
        var updateUsersRequest = URLRequest(url: updateUsersUrl)
        updateUsersRequest.httpMethod = "PATCH"
        for (key, value) in supabaseHeaders(authenticated: true) {
            updateUsersRequest.setValue(value, forHTTPHeaderField: key)
        }

        let userData: [String: Any] = ["company_id": newId]
        updateUsersRequest.httpBody = try JSONSerialization.data(withJSONObject: userData)

        let (_, usersResponse) = try await session.data(for: updateUsersRequest)

        guard let httpResponse2 = usersResponse as? HTTPURLResponse,
              (200...299).contains(httpResponse2.statusCode) else {
            #if DEBUG
            print("❌ Failed to update users: status \(String(describing: (usersResponse as? HTTPURLResponse)?.statusCode))")
            #endif
            throw NetworkError.serverError((usersResponse as? HTTPURLResponse)?.statusCode ?? 500)
        }

        #if DEBUG
        print("✅ All users updated with new company ID")
        #endif

        // Step 2: Update all clients with the old company_id to the new company_id
        let updateClientsUrl = URL(string: "\(AppConstants.supabaseUrl)/rest/v1/clients?company_id=eq.\(oldId)")!
        var updateClientsRequest = URLRequest(url: updateClientsUrl)
        updateClientsRequest.httpMethod = "PATCH"
        for (key, value) in supabaseHeaders(authenticated: true) {
            updateClientsRequest.setValue(value, forHTTPHeaderField: key)
        }

        let clientData: [String: Any] = ["company_id": newId]
        updateClientsRequest.httpBody = try JSONSerialization.data(withJSONObject: clientData)

        let (_, clientsResponse) = try await session.data(for: updateClientsRequest)

        guard let httpResponse3 = clientsResponse as? HTTPURLResponse,
              (200...299).contains(httpResponse3.statusCode) else {
            #if DEBUG
            print("❌ Failed to update clients: status \(String(describing: (clientsResponse as? HTTPURLResponse)?.statusCode))")
            #endif
            throw NetworkError.serverError((clientsResponse as? HTTPURLResponse)?.statusCode ?? 500)
        }

        #if DEBUG
        print("✅ All clients updated with new company ID")
        print("⚠️ Step 2: Now updating company primary key")
        #endif

        // Step 3: Now update the company's ID (primary key) - this must be done LAST
        let updateCompanyUrl = URL(string: "\(AppConstants.supabaseUrl)/rest/v1/companies?id=eq.\(oldId)")!
        var updateCompanyRequest = URLRequest(url: updateCompanyUrl)
        updateCompanyRequest.httpMethod = "PATCH"
        for (key, value) in supabaseHeaders(authenticated: true) {
            updateCompanyRequest.setValue(value, forHTTPHeaderField: key)
        }

        let companyData: [String: Any] = ["id": newId]
        updateCompanyRequest.httpBody = try JSONSerialization.data(withJSONObject: companyData)

        let (_, companyResponse) = try await session.data(for: updateCompanyRequest)

        guard let httpResponse = companyResponse as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            #if DEBUG
            print("❌ Failed to update company: status \(String(describing: (companyResponse as? HTTPURLResponse)?.statusCode))")
            #endif
            throw NetworkError.serverError((companyResponse as? HTTPURLResponse)?.statusCode ?? 500)
        }

        #if DEBUG
        print("✅ Company record updated successfully")
        print("🎉 Company ID change complete: '\(oldId)' → '\(newId)'")
        #endif
    }

    func updateCompanyCode(companyId: String, newCode: String) async throws {
        #if DEBUG
        print("🏢 Updating company_code for company '\(companyId)' to '\(newCode)'")
        #endif

        let url = URL(string: "\(AppConstants.supabaseUrl)/rest/v1/companies?id=eq.\(companyId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        for (key, value) in supabaseHeaders(authenticated: true) {
            request.setValue(value, forHTTPHeaderField: key)
        }

        let data: [String: Any] = ["company_code": newCode]
        request.httpBody = try JSONSerialization.data(withJSONObject: data)

        let (_, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            #if DEBUG
            print("❌ Failed to update company_code: status \(String(describing: (response as? HTTPURLResponse)?.statusCode))")
            #endif
            throw NetworkError.serverError((response as? HTTPURLResponse)?.statusCode ?? 500)
        }

        #if DEBUG
        print("✅ Company code updated successfully to '\(newCode)'")
        #endif
    }

    // MARK: - Team Members

    func fetchTeamMembers(companyId: String) async throws -> [AppUser] {
        var components = URLComponents(string: "\(AppConstants.supabaseUrl)/rest/v1/users")!
        components.queryItems = [
            URLQueryItem(name: "company_id", value: "eq.\(companyId)"),
            URLQueryItem(name: "select", value: "*"),
            URLQueryItem(name: "order", value: "created_at.asc")
        ]

        guard let url = components.url else {
            throw NetworkError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        for (key, value) in supabaseHeaders(authenticated: true) {
            request.setValue(value, forHTTPHeaderField: key)
        }

        // Add Range header to ensure no pagination limit
        request.setValue("0-999", forHTTPHeaderField: "Range")

        // Add Prefer header to get full count
        request.setValue("count=exact", forHTTPHeaderField: "Prefer")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw NetworkError.serverError(httpResponse.statusCode)
        }

        let teamMembers = try JSONDecoder().decode([AppUser].self, from: data)
        return teamMembers
    }

    func verifyCompanyExists(id: String) async throws -> Bool {
        var components = URLComponents(string: "\(AppConstants.supabaseUrl)/rest/v1/companies")!
        components.queryItems = [
            URLQueryItem(name: "id", value: "eq.\(id)"),
            URLQueryItem(name: "select", value: "id")
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

        // Decode as array of companies
        let companies = try JSONDecoder().decode([Company].self, from: data)
        return !companies.isEmpty
    }

    func fetchCompanyByCode(_ code: String) async throws -> Company? {
        let trimmedCode = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedCode.isEmpty else {
            return nil
        }

        if let exactMatch = try await fetchCompanyByCode(trimmedCode, matchType: "eq") {
            return exactMatch
        }

        return try await fetchCompanyByCode(trimmedCode, matchType: "ilike")
    }

    private func fetchCompanyByCode(_ code: String, matchType: String) async throws -> Company? {
        var components = URLComponents(string: "\(AppConstants.supabaseUrl)/rest/v1/companies")!
        components.queryItems = [
            URLQueryItem(name: "company_code", value: "\(matchType).\(code)"),
            URLQueryItem(name: "select", value: "id,company_code,name"),
            URLQueryItem(name: "limit", value: "1")
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

        let companies = try JSONDecoder().decode([Company].self, from: data)
        return companies.first
    }

    // MARK: - Skin Analyses

    func fetchAnalyses(clientId: String) async throws -> [SkinAnalysisResult] {
        var components = URLComponents(string: "\(AppConstants.supabaseUrl)/rest/v1/skin_analyses")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: "eq.\(clientId)"),
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

        #if DEBUG
        print("-> Request: Fetch Analyses")
        print("-> GET: \(url.absoluteString)")

        #endif
        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }

            #if DEBUG
            print("<- Response: Fetch Analyses")
            print("<- Status Code: \(httpResponse.statusCode)")

            #endif
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

    func fetchLatestAnalysisImageUrl(clientId: String) async throws -> String? {
        var components = URLComponents(string: "\(AppConstants.supabaseUrl)/rest/v1/skin_analyses")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: "eq.\(clientId)"),
            URLQueryItem(name: "select", value: "image_url,created_at"),
            URLQueryItem(name: "order", value: "created_at.desc"),
            URLQueryItem(name: "limit", value: "1")
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

        let analyses = try JSONDecoder().decode([SkinAnalysisResult].self, from: data)
        return analyses.first?.imageUrl
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

        #if DEBUG
        print("-> Request: Save Analysis")
        print("-> POST: \(url.absoluteString)")

        #endif
        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }

            #if DEBUG
            print("<- Response: Save Analysis")
            print("<- Status Code: \(httpResponse.statusCode)")

            #endif
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

    func deleteAnalysis(analysisId: String) async throws {
        let url = URL(string: "\(AppConstants.supabaseUrl)/rest/v1/skin_analyses?id=eq.\(analysisId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        for (key, value) in supabaseHeaders(authenticated: true) {
            request.setValue(value, forHTTPHeaderField: key)
        }

        let (_, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw NetworkError.serverError(httpResponse.statusCode)
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

        #if DEBUG
        print("-> Request: Upload Image")
        print("-> POST: \(url.absoluteString)")

        #endif
        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }

            #if DEBUG
            print("<- Response: Upload Image")
            print("<- Status Code: \(httpResponse.statusCode)")
            if let jsonString = String(data: data, encoding: .utf8) {
                print(jsonString)
            }

            #endif
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

    func uploadProductImage(image: UIImage, userId: String) async throws -> String {
        // Upload to Supabase Storage in product-images bucket
        let fileName = "\(userId)/\(UUID().uuidString).jpg"
        let url = URL(string: "\(AppConstants.supabaseUrl)/storage/v1/object/product-images/\(fileName)")!
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

        #if DEBUG
        print("-> Request: Upload Product Image")
        print("-> POST: \(url.absoluteString)")

        #endif
        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }

            #if DEBUG
            print("<- Response: Upload Product Image")
            print("<- Status Code: \(httpResponse.statusCode)")
            if let jsonString = String(data: data, encoding: .utf8) {
                print(jsonString)
            }

            #endif
            guard (200...299).contains(httpResponse.statusCode) else {
                throw NetworkError.serverError(httpResponse.statusCode)
            }

            // Return public URL
            return "\(AppConstants.supabaseUrl)/storage/v1/object/public/product-images/\(fileName)"
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
        aiRules: [AIRule] = [],
        products: [Product] = []
    ) async throws -> AnalysisData {
        // Use new AI service (Apple Vision or Claude based on AppConstants.aiProvider)
        return try await AIAnalysisService.shared.analyzeImage(
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

    func refreshAccessToken() async throws -> String {
        guard let refreshToken, !refreshToken.isEmpty else {
            throw NetworkError.invalidCredentials
        }

        let url = URL(string: "\(AppConstants.supabaseUrl)/auth/v1/token?grant_type=refresh_token")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        for (key, value) in supabaseHeaders() {
            request.setValue(value, forHTTPHeaderField: key)
        }

        let payload: [String: String] = ["refresh_token": refreshToken]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw NetworkError.serverError(httpResponse.statusCode)
        }

        let authResponse = try JSONDecoder().decode(SupabaseAuthResponse.self, from: data)
        saveTokens(access: authResponse.accessToken, refresh: authResponse.refreshToken, userId: authResponse.user.id)
        return authResponse.accessToken
    }

    // MARK: - User Management

    func createEmployeeAccount(
        email: String,
        password: String,
        firstName: String,
        lastName: String,
        role: String,
        isAdmin: Bool,
        companyId: String,
        companyName: String? = nil
    ) async throws -> AppUser {
        // Create account via Supabase Auth
        let url = URL(string: "\(AppConstants.supabaseUrl)/auth/v1/signup")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // Use anon key for auth signup
        request.setValue(AppConstants.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(AppConstants.supabaseAnonKey)", forHTTPHeaderField: "Authorization")

        let signupData: [String: Any] = [
            "email": email,
            "password": password
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: signupData)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            // Try to parse error message
            if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorMsg = errorJson["msg"] as? String {
                throw NSError(domain: "NetworkService", code: httpResponse.statusCode, userInfo: [
                    NSLocalizedDescriptionKey: errorMsg
                ])
            }
            throw NetworkError.serverError(httpResponse.statusCode)
        }

        // Parse the response to get the user ID + access token
        guard let authResponse = try? JSONDecoder().decode(SupabaseAuthResponse.self, from: data) else {
            throw NetworkError.invalidResponse
        }

        let userId = authResponse.user.id
        let userAccessToken = authResponse.accessToken

        // Create user profile in users table
        let profileUrl = URL(string: "\(AppConstants.supabaseUrl)/rest/v1/users")!
        var profileRequest = URLRequest(url: profileUrl)
        profileRequest.httpMethod = "POST"
        profileRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // Use the new user's access token to satisfy the self-insert policy
        profileRequest.setValue(AppConstants.supabaseAnonKey, forHTTPHeaderField: "apikey")
        profileRequest.setValue("Bearer \(userAccessToken)", forHTTPHeaderField: "Authorization")
        profileRequest.setValue("return=representation", forHTTPHeaderField: "Prefer")

        var profileData: [String: Any] = [
            "id": userId,
            "email": email,
            "provider": "email",
            "first_name": firstName,
            "last_name": lastName,
            "role": role,
            "is_admin": isAdmin,
            "company_id": companyId
        ]

        if let companyName, !companyName.isEmpty {
            profileData["company_name"] = companyName
        }

        profileRequest.httpBody = try JSONSerialization.data(withJSONObject: profileData)

        let (profileResponseData, profileResponse) = try await session.data(for: profileRequest)

        guard let profileHttpResponse = profileResponse as? HTTPURLResponse,
              (200...299).contains(profileHttpResponse.statusCode) else {
            throw NetworkError.serverError((profileResponse as? HTTPURLResponse)?.statusCode ?? -1)
        }

        let users = try JSONDecoder().decode([AppUser].self, from: profileResponseData)
        if let createdUser = users.first {
            return createdUser
        }

        // Fallback: return basic AppUser object
        return AppUser(
            id: userId,
            email: email,
            provider: "email",
            isAdmin: isAdmin,
            createdAt: nil,
            companyId: companyId,
            firstName: firstName,
            lastName: lastName,
            phoneNumber: nil,
            profileImageUrl: nil,
            role: role
        )
    }

    func resolveCompanyAssociation(from value: String) async throws -> (id: String, name: String?) {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if let uuid = UUID(uuidString: trimmedValue) {
            return (uuid.uuidString, nil)
        }

        if let company = try await fetchCompanyByCode(trimmedValue),
           let companyId = company.id {
            return (companyId, company.name)
        }

        throw NSError(
            domain: "NetworkService",
            code: 404,
            userInfo: [NSLocalizedDescriptionKey: "Company code not found. Please check the code and try again."]
        )
    }

    func fetchCompanyUsers(companyId: String) async throws -> [AppUser] {
        var components = URLComponents(string: "\(AppConstants.supabaseUrl)/rest/v1/users")!
        components.queryItems = [
            URLQueryItem(name: "company_id", value: "eq.\(companyId)"),
            URLQueryItem(name: "select", value: "*"),
            URLQueryItem(name: "order", value: "email.asc")
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
        return users
    }

    func updateUserAdminStatus(userId: String, isAdmin: Bool) async throws {
        let url = URL(string: "\(AppConstants.supabaseUrl)/rest/v1/users?id=eq.\(userId)")!

        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        for (key, value) in supabaseHeaders(authenticated: true) {
            request.setValue(value, forHTTPHeaderField: key)
        }
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")

        let updateData: [String: Any] = [
            "is_admin": isAdmin
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: updateData)

        #if DEBUG
        print("🌐 Updating user admin status:")
        print("   URL: \(url.absoluteString)")
        print("   UserID: \(userId)")
        print("   isAdmin: \(isAdmin)")
        #endif

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        #if DEBUG
        print("📡 Response status code: \(httpResponse.statusCode)")
        if let responseString = String(data: data, encoding: .utf8) {
            print("📡 Response body: \(responseString)")
        }
        #endif

        guard (200...299).contains(httpResponse.statusCode) else {
            if let errorString = String(data: data, encoding: .utf8) {
                #if DEBUG
                print("❌ Server error response: \(errorString)")
                #endif
            }
            throw NetworkError.serverError(httpResponse.statusCode)
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

    func fetchProductsForUser(userId: String, companyId: String?) async throws -> [Product] {
        let resolvedCompanyId = await resolveCompanyId(from: companyId)

        if let companyId = resolvedCompanyId {
            do {
                let companyUserProducts = try await fetchProductsByCompanyUsers(companyId: companyId)
                if !companyUserProducts.isEmpty {
                    return companyUserProducts
                }
            } catch {
                // Fall through to user-specific products.
            }
        }

        return try await fetchProducts(userId: userId)
    }

    private func resolveCompanyId(from companyId: String?) async -> String? {
        guard let companyId = companyId?.trimmingCharacters(in: .whitespacesAndNewlines),
              !companyId.isEmpty else {
            return nil
        }

        if UUID(uuidString: companyId) != nil {
            return companyId
        }

        if let resolved = try? await resolveCompanyAssociation(from: companyId) {
            return resolved.id
        }

        return nil
    }

    private func fetchProductsByCompanyUsers(companyId: String) async throws -> [Product] {
        let users = try await fetchCompanyUsers(companyId: companyId)
        let userIds = users.compactMap { $0.id }
        guard !userIds.isEmpty else {
            return []
        }

        let inList = userIds.joined(separator: ",")
        var components = URLComponents(string: "\(AppConstants.supabaseUrl)/rest/v1/products")!
        components.queryItems = [
            URLQueryItem(name: "user_id", value: "in.(\(inList))"),
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

        return try JSONDecoder().decode([Product].self, from: data)
    }

    // MARK: - Usage Tracking

    func fetchClaudeUsageCounts(companyId: String, userId: String) async throws -> (companyCount: Int, userCount: Int) {
        let startOfMonth = currentMonthStartISO8601()

        let companyCount = try await fetchUsageCount(queryItems: [
            URLQueryItem(name: "company_id", value: "eq.\(companyId)"),
            URLQueryItem(name: "provider", value: "eq.claude"),
            URLQueryItem(name: "created_at", value: "gte.\(startOfMonth)")
        ])

        let userCount = try await fetchUsageCount(queryItems: [
            URLQueryItem(name: "user_id", value: "eq.\(userId)"),
            URLQueryItem(name: "provider", value: "eq.claude"),
            URLQueryItem(name: "created_at", value: "gte.\(startOfMonth)")
        ])

        return (companyCount, userCount)
    }

    private func fetchUsageCount(queryItems: [URLQueryItem]) async throws -> Int {
        var components = URLComponents(string: "\(AppConstants.supabaseUrl)/rest/v1/ai_usage_events")!
        components.queryItems = queryItems + [URLQueryItem(name: "select", value: "id")]

        guard let url = components.url else {
            throw NetworkError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        for (key, value) in supabaseHeaders(authenticated: true) {
            request.setValue(value, forHTTPHeaderField: key)
        }

        request.setValue("0-0", forHTTPHeaderField: "Range")
        request.setValue("count=exact", forHTTPHeaderField: "Prefer")

        let (_, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw NetworkError.serverError(httpResponse.statusCode)
        }

        let contentRange = httpResponse.value(forHTTPHeaderField: "Content-Range")
        return parseContentRangeCount(contentRange)
    }

    private func parseContentRangeCount(_ contentRange: String?) -> Int {
        guard let contentRange, let total = contentRange.split(separator: "/").last else {
            return 0
        }

        return Int(total) ?? 0
    }

    private func currentMonthStartISO8601() -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current

        let components = calendar.dateComponents([.year, .month], from: Date())
        let startOfMonth = calendar.date(from: components) ?? Date()

        let formatter = ISO8601DateFormatter()
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: startOfMonth)
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
                "all_ingredients": product.allIngredients,
                "skin_types": product.skinTypes,
                "concerns": product.concerns,
                "image_url": product.imageUrl,
                "price": product.price,
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

            var productData: [String: Any] = [
                "user_id": userId,
                "name": product.name ?? "",
                "brand": product.brand ?? "",
                "category": product.category ?? "",
                "description": product.description ?? "",
                "ingredients": product.ingredients ?? "",
                "all_ingredients": product.allIngredients ?? "",
                "skin_types": product.skinTypes ?? [],
                "concerns": product.concerns ?? [],
                "is_active": product.isActive ?? true
            ]

            if let imageUrl = product.imageUrl {
                productData["image_url"] = imageUrl
            }
            if let price = product.price {
                productData["price"] = price
            }

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
        // Fetch company-wide rules if user belongs to a company
        let user = await MainActor.run { AuthenticationManager.shared.currentUser }

        guard let user = user else {
            throw NetworkError.invalidResponse
        }

        var components = URLComponents(string: "\(AppConstants.supabaseUrl)/rest/v1/ai_rules")!

        if let companyId = user.companyId {
            // Fetch all rules for the company
            components.queryItems = [
                URLQueryItem(name: "company_id", value: "eq.\(companyId)"),
                URLQueryItem(name: "order", value: "priority.desc")
            ]
        } else {
            // No company - fetch only personal rules
            components.queryItems = [
                URLQueryItem(name: "user_id", value: "eq.\(userId)"),
                URLQueryItem(name: "order", value: "priority.desc")
            ]
        }

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

    func createAIRule(
        userId: String,
        name: String,
        condition: String,
        action: String,
        priority: Int,
        isActive: Bool
    ) async throws -> AIRule {
        let url = URL(string: "\(AppConstants.supabaseUrl)/rest/v1/ai_rules")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        for (key, value) in supabaseHeaders(authenticated: true) {
            request.setValue(value, forHTTPHeaderField: key)
        }
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")

        var ruleData: [String: Any] = [
            "user_id": userId,
            "name": name,
            "condition": condition,
            "action": action,
            "priority": priority,
            "is_active": isActive
        ]

        // Add company_id if user belongs to a company
        let companyId = await MainActor.run { AuthenticationManager.shared.currentUser?.companyId }
        if let companyId = companyId {
            ruleData["company_id"] = companyId
        }

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

    func updateAIRule(
        ruleId: String,
        userId: String,
        name: String,
        condition: String,
        action: String,
        priority: Int,
        isActive: Bool
    ) async throws -> AIRule {
        let url = URL(string: "\(AppConstants.supabaseUrl)/rest/v1/ai_rules?id=eq.\(ruleId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        for (key, value) in supabaseHeaders(authenticated: true) {
            request.setValue(value, forHTTPHeaderField: key)
        }
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")

        let ruleData: [String: Any] = [
            "name": name,
            "condition": condition,
            "action": action,
            "priority": priority,
            "is_active": isActive
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
        guard let updatedRule = rules.first else {
            throw NetworkError.invalidResponse
        }

        return updatedRule
    }

    func deleteAIRule(ruleId: String) async throws {
        let url = URL(string: "\(AppConstants.supabaseUrl)/rest/v1/ai_rules?id=eq.\(ruleId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        for (key, value) in supabaseHeaders(authenticated: true) {
            request.setValue(value, forHTTPHeaderField: key)
        }

        let (_, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw NetworkError.serverError(httpResponse.statusCode)
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

        #if DEBUG
        print("-> Request: Delete User")
        print("-> DELETE: \(url.absoluteString)")

        #endif
        do {
            let (_, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }

            #if DEBUG
            print("<- Response: Delete User")
            print("<- Status Code: \(httpResponse.statusCode)")

            #endif
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
    case custom(String)

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
        case .custom(let message):
            return message
        }
    }
}
