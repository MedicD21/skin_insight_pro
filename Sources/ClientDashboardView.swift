import SwiftUI
import UIKit

struct ClientDashboardView: View {
    @ObservedObject var theme = ThemeManager.shared
    @StateObject private var viewModel = ClientDashboardViewModel()
    @State private var selectedClient: AppClient?
    @State private var showAddClient = false
    @State private var searchText = ""
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                NavigationSplitView {
                    clientListView
                } detail: {
                    if let client = selectedClient {
                        ClientDetailView(
                            client: client,
                            selectedClient: $selectedClient,
                            onClientUpdated: { updatedClient in
                                viewModel.updateClient(updatedClient)
                            }
                        )
                            .id(client.id)
                    } else {
                        ContentUnavailableView(
                            "Select a Client",
                            systemImage: "person.2",
                            description: Text("Choose a client to view their skin analysis history")
                        )
                    }
                }
                .navigationSplitViewStyle(.balanced)
            } else {
                NavigationStack {
                    clientListView
                        .navigationDestination(for: AppClient.self) { client in
                            ClientDetailView(
                                client: client,
                                selectedClient: $selectedClient,
                                onClientUpdated: { updatedClient in
                                    viewModel.updateClient(updatedClient)
                                }
                            )
                        }
                }
            }
        }
        .sheet(isPresented: $showAddClient) {
            AddClientView(viewModel: viewModel)
        }
        .task {
            await viewModel.loadClients()
        }
    }
    
    private var clientListView: some View {
        ZStack {
            theme.primaryBackground
                .ignoresSafeArea()
            
            if viewModel.isLoading && viewModel.clients.isEmpty {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(theme.accent)
            } else if viewModel.clients.isEmpty {
                emptyStateView
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        searchBar

                        LazyVStack(spacing: 12) {
                            ForEach(filteredClients) { client in
                                if horizontalSizeClass == .regular {
                                    ClientRowView(client: client)
                                        .contentShape(Rectangle())
                                        .background(
                                            RoundedRectangle(cornerRadius: theme.radiusLarge)
                                                .fill(selectedClient?.id == client.id ? theme.accentSubtle.opacity(0.3) : Color.clear)
                                        )
                                        .onTapGesture {
                                            withAnimation(theme.springSnappy) {
                                                selectedClient = client
                                            }
                                        }
                                } else {
                                    NavigationLink(value: client) {
                                        ClientRowView(client: client)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, horizontalSizeClass == .regular ? 20 : 100)
                }
                .refreshable {
                    await viewModel.loadClients()
                }
                .onTapGesture {
                    dismissKeyboard()
                }
            }
        }
        .navigationTitle("Clients")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Image("logo")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 32)
            }

            ToolbarItemGroup(placement: .topBarTrailing) {
                Button(action: { showAddClient = true }) {
                    if horizontalSizeClass == .regular {
                        Label("Add Client", systemImage: "plus")
                    } else {
                        Image(systemName: "plus")
                    }
                }
                .keyboardShortcut("n", modifiers: .command)
            }
        }
    }
    
    private var filteredClients: [AppClient] {
        let term = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if term.isEmpty {
            return viewModel.clients
        }
        return viewModel.clients.filter { client in
            (client.name?.localizedCaseInsensitiveContains(term) ?? false) ||
            (client.email?.localizedCaseInsensitiveContains(term) ?? false) ||
            (client.phone?.localizedCaseInsensitiveContains(term) ?? false)
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.2")
                .font(.system(size: 60))
                .foregroundColor(theme.tertiaryText)
            
            Text("No Clients Yet")
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(theme.primaryText)
            
            Text("Add your first client to start tracking their skin health journey")
                .font(.system(size: 16))
                .foregroundColor(theme.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button(action: { showAddClient = true }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Client")
                }
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 32)
                .padding(.vertical, 16)
                .background(theme.accent)
                .clipShape(RoundedRectangle(cornerRadius: theme.radiusMedium))
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 100)
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(theme.tertiaryText)

            TextField("Search clients", text: $searchText)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                .submitLabel(.done)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                    dismissKeyboard()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(theme.secondaryText)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(theme.tertiaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: theme.radiusMedium))
        .overlay(
            RoundedRectangle(cornerRadius: theme.radiusMedium)
                .stroke(theme.border, lineWidth: 1)
        )
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

struct ClientRowView: View {
    @ObservedObject var theme = ThemeManager.shared
    let client: AppClient
    @State private var latestAnalysisImageUrl: String?
    
    var body: some View {
        HStack(spacing: 16) {
            profileImageView
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(client.name ?? "Unknown")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(theme.primaryText)
                        .lineLimit(1)

                    if !isOwnClient {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 12))
                            .foregroundColor(theme.accent.opacity(0.6))
                    }
                }

                if let email = client.email, !email.isEmpty {
                    Text(email)
                        .font(.system(size: 14))
                        .foregroundColor(theme.secondaryText)
                        .lineLimit(1)
                }

                if let phone = client.phone, !phone.isEmpty {
                    Text(phone)
                        .font(.system(size: 14))
                        .foregroundColor(theme.secondaryText)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            // Consent status indicator
            consentStatusBadge

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(theme.tertiaryText)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: theme.radiusLarge)
                .fill(theme.cardBackground)
                .shadow(color: theme.shadowColor, radius: theme.shadowRadiusSmall, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: theme.radiusLarge)
                .stroke(theme.cardBorder, lineWidth: 1)
        )
        .task {
            await loadLatestAnalysisImage()
        }
    }

    private var profileImageView: some View {
        Group {
            if let imageUrl = latestAnalysisImageUrl, let url = URL(string: imageUrl) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .frame(width: 56, height: 56)
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        fallbackInitialsView
                    @unknown default:
                        fallbackInitialsView
                    }
                }
                .frame(width: 56, height: 56)
                .background(theme.tertiaryBackground)
                .clipShape(Circle())
            } else if let profileImageUrl = client.profileImageUrl,
                      let url = URL(string: profileImageUrl),
                      !profileImageUrl.isEmpty {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .frame(width: 56, height: 56)
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        fallbackInitialsView
                    @unknown default:
                        fallbackInitialsView
                    }
                }
                .frame(width: 56, height: 56)
                .background(theme.tertiaryBackground)
                .clipShape(Circle())
            } else {
                fallbackInitialsView
            }
        }
    }

    private var fallbackInitialsView: some View {
        ZStack {
            Circle()
                .fill(theme.accent.opacity(0.15))
                .frame(width: 56, height: 56)

            Text(initials)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(theme.accent)
        }
    }
    
    private var initials: String {
        let name = client.name ?? "?"
        let components = name.split(separator: " ")
        if components.count >= 2 {
            return "\(components[0].prefix(1))\(components[1].prefix(1))".uppercased()
        } else {
            return String(name.prefix(2)).uppercased()
        }
    }

    private var isOwnClient: Bool {
        guard let currentUserId = AuthenticationManager.shared.currentUser?.id,
              let clientUserId = client.userId else {
            return true
        }
        return clientUserId == currentUserId
    }

    @ViewBuilder
    private var consentStatusBadge: some View {
        let status = client.consentStatus

        switch status {
        case .valid:
            Image(systemName: status.icon)
                .font(.system(size: 18))
                .foregroundColor(Color(red: status.color.red, green: status.color.green, blue: status.color.blue))
        case .expired, .missing:
            Image(systemName: status.icon)
                .font(.system(size: 18))
                .foregroundColor(Color(red: status.color.red, green: status.color.green, blue: status.color.blue))
        }
    }

    @MainActor
    private func loadLatestAnalysisImage() async {
        if latestAnalysisImageUrl != nil || AuthenticationManager.shared.isGuestMode {
            return
        }
        guard let clientId = client.id else { return }
        do {
            let imageUrl = try await NetworkService.shared.fetchLatestAnalysisImageUrl(clientId: clientId)
            latestAnalysisImageUrl = imageUrl
        } catch {
            latestAnalysisImageUrl = nil
        }
    }
}

@MainActor
class ClientDashboardViewModel: ObservableObject {
    @Published private(set) var clients: [AppClient] = []
    @Published private(set) var isLoading = false
    @Published var showError = false
    @Published var errorMessage = ""
    
    func loadClients() async {
        guard let userId = AuthenticationManager.shared.currentUser?.id else {
            #if DEBUG
            print("❌ loadClients: No current user")
            #endif
            return
        }

        if AuthenticationManager.shared.isGuestMode {
            loadLocalClients(userId: userId)
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            try Task.checkCancellation()

            // Refresh user profile to ensure we have latest company_id
            await AuthenticationManager.shared.refreshUserProfile(userId: userId)

            guard let currentUser = AuthenticationManager.shared.currentUser else {
                #if DEBUG
                print("❌ loadClients: No current user after refresh")
                #endif
                return
            }

            #if DEBUG
            print("👤 Current user: \(currentUser.email ?? "unknown")")
            print("🏢 Company ID: \(currentUser.companyId ?? "nil")")
            print("🔍 Company ID isEmpty: \(currentUser.companyId?.isEmpty ?? true)")
            #endif

            // If user belongs to a company, fetch company-wide clients
            // Otherwise, fetch only user's clients
            let fetchedClients: [AppClient]
            if let companyId = currentUser.companyId, !companyId.isEmpty {
                #if DEBUG
                print("📋 Fetching clients for company: \(companyId)")
                #endif
                fetchedClients = try await NetworkService.shared.fetchClientsByCompany(companyId: companyId)
                #if DEBUG
                print("✅ Fetched \(fetchedClients.count) clients for company")
                #endif
            } else {
                #if DEBUG
                print("📋 Fetching clients for user: \(userId)")
                #endif
                fetchedClients = try await NetworkService.shared.fetchClients(userId: userId)
                #if DEBUG
                print("✅ Fetched \(fetchedClients.count) clients for user")
                #endif
            }

            clients = fetchedClients.sorted { ($0.name ?? "") < ($1.name ?? "") }
            #if DEBUG
            print("✅ Set \(clients.count) clients in view model")
            #endif
        } catch is CancellationError {
            #if DEBUG
            print("⚠️ loadClients cancelled")
            #endif
            return
        } catch {
            #if DEBUG
            print("❌ loadClients error: \(error)")
            #endif
            errorMessage = error.localizedDescription
            showError = true
        }
    }
    
    func addClient(_ client: AppClient) async {
        guard let userId = AuthenticationManager.shared.currentUser?.id else { return }
        
        if AuthenticationManager.shared.isGuestMode {
            saveClientLocally(client, userId: userId)
            return
        }
        
        do {
            let savedClient = try await NetworkService.shared.createOrUpdateClient(client: client, userId: userId)
            clients.append(savedClient)
            clients.sort { ($0.name ?? "") < ($1.name ?? "") }
        } catch is CancellationError {
            return
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    func updateClient(_ client: AppClient) {
        guard let userId = AuthenticationManager.shared.currentUser?.id else { return }

        if let index = clients.firstIndex(where: { $0.id == client.id }) {
            clients[index] = client
        } else {
            clients.append(client)
        }
        clients.sort { ($0.name ?? "") < ($1.name ?? "") }

        if AuthenticationManager.shared.isGuestMode {
            persistLocalClients(userId: userId)
        }
    }
    
    private func loadLocalClients(userId: String) {
        if let data = UserDefaults.standard.data(forKey: "local_clients_\(userId)"),
           let decoded = try? JSONDecoder().decode([AppClient].self, from: data) {
            clients = decoded.sorted { ($0.name ?? "") < ($1.name ?? "") }
        }
    }
    
    private func saveClientLocally(_ client: AppClient, userId: String) {
        var newClient = client
        newClient.id = UUID().uuidString
        newClient.userId = userId
        clients.append(newClient)
        clients.sort { ($0.name ?? "") < ($1.name ?? "") }
        
        persistLocalClients(userId: userId)
    }

    private func persistLocalClients(userId: String) {
        if let encoded = try? JSONEncoder().encode(clients) {
            UserDefaults.standard.set(encoded, forKey: "local_clients_\(userId)")
        }
    }
}
