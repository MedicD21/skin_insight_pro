import SwiftUI

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
                        ClientDetailView(client: client, selectedClient: $selectedClient)
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
                            ClientDetailView(client: client, selectedClient: $selectedClient)
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
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, horizontalSizeClass == .regular ? 20 : 100)
                }
                .refreshable {
                    await viewModel.loadClients()
                }
            }
        }
        .navigationTitle("Clients")
        .searchable(text: $searchText, prompt: "Search clients")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Image("logo")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 32)
            }

            ToolbarItemGroup(placement: .topBarTrailing) {
                if horizontalSizeClass == .regular {
                    Button(action: { showAddClient = true }) {
                        Label("Add Client", systemImage: "plus")
                    }
                    .keyboardShortcut("n", modifiers: .command)
                    
                    NavigationLink(destination: ProfileView()) {
                        Image(systemName: "person.circle")
                    }
                } else {
                    Button(action: { showAddClient = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
        }
    }
    
    private var filteredClients: [AppClient] {
        if searchText.isEmpty {
            return viewModel.clients
        }
        return viewModel.clients.filter { client in
            (client.name?.localizedCaseInsensitiveContains(searchText) ?? false) ||
            (client.email?.localizedCaseInsensitiveContains(searchText) ?? false) ||
            (client.phone?.localizedCaseInsensitiveContains(searchText) ?? false)
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
}

struct ClientRowView: View {
    @ObservedObject var theme = ThemeManager.shared
    let client: AppClient
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(theme.accent.opacity(0.15))
                    .frame(width: 56, height: 56)
                
                Text(initials)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(theme.accent)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(client.name ?? "Unknown")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(theme.primaryText)
                    .lineLimit(1)
                
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
}

@MainActor
class ClientDashboardViewModel: ObservableObject {
    @Published private(set) var clients: [AppClient] = []
    @Published private(set) var isLoading = false
    @Published var showError = false
    @Published var errorMessage = ""
    
    func loadClients() async {
        guard let userId = AuthenticationManager.shared.currentUser?.id else { return }
        
        if AuthenticationManager.shared.isGuestMode {
            loadLocalClients(userId: userId)
            return
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            try Task.checkCancellation()
            let fetchedClients = try await NetworkService.shared.fetchClients(userId: userId)
            clients = fetchedClients.sorted { ($0.name ?? "") < ($1.name ?? "") }
        } catch is CancellationError {
            return
        } catch {
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
        
        if let encoded = try? JSONEncoder().encode(clients) {
            UserDefaults.standard.set(encoded, forKey: "local_clients_\(userId)")
        }
    }
}