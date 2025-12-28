import SwiftUI

struct ClientDetailView: View {
    @ObservedObject var theme = ThemeManager.shared
    let client: AppClient
    @Binding var selectedClient: AppClient?
    @StateObject private var viewModel = ClientDetailViewModel()
    @State private var showAnalysisInput = false
    @State private var showEditClient = false
    @State private var showCompareAnalyses = false
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    var body: some View {
        ZStack {
            theme.primaryBackground
                .ignoresSafeArea()
            
            if viewModel.isLoading && viewModel.analyses.isEmpty {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(theme.accent)
            } else {
                ScrollView {
                    VStack(spacing: 24) {
                        clientInfoCard
                        
                        if hasMedicalInfo {
                            medicalInfoCard
                        }
                        
                        if viewModel.analyses.count >= 2 {
                            compareAnalysesButton
                        }
                        
                        if viewModel.analyses.isEmpty {
                            emptyAnalysisView
                        } else {
                            analysisHistorySection
                        }
                    }
                    .padding(.horizontal, horizontalSizeClass == .regular ? 32 : 16)
                    .padding(.top, 20)
                    .padding(.bottom, horizontalSizeClass == .regular ? 40 : 100)
                }
                .refreshable {
                    await viewModel.loadAnalyses(clientId: client.id ?? "", userId: AuthenticationManager.shared.currentUser?.id ?? "")
                }
            }
        }
        .navigationTitle(client.name ?? "Client")
        .navigationBarTitleDisplayMode(horizontalSizeClass == .regular ? .large : .inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button(action: { showEditClient = true }) {
                    Label("Edit", systemImage: "pencil")
                }
                
                Button(action: { showAnalysisInput = true }) {
                    Label("New Analysis", systemImage: "camera")
                }
                .keyboardShortcut("a", modifiers: .command)
            }
        }
        .sheet(isPresented: $showAnalysisInput) {
            SkinAnalysisInputView(client: client, viewModel: viewModel)
        }
        .sheet(isPresented: $showEditClient) {
            EditClientView(client: client, onUpdate: { updatedClient in
                if let index = viewModel.clients.firstIndex(where: { $0.id == updatedClient.id }) {
                    viewModel.clients[index] = updatedClient
                }
                selectedClient = updatedClient
            })
        }
        .sheet(isPresented: $showCompareAnalyses) {
            CompareAnalysesView(client: client, analyses: viewModel.analyses)
        }
        .task {
            await viewModel.loadAnalyses(clientId: client.id ?? "", userId: AuthenticationManager.shared.currentUser?.id ?? "")
        }
    }
    
    private var hasMedicalInfo: Bool {
        (client.medicalHistory != nil && !client.medicalHistory!.isEmpty) ||
        (client.allergies != nil && !client.allergies!.isEmpty) ||
        (client.knownSensitivities != nil && !client.knownSensitivities!.isEmpty)
    }
    
    private var clientInfoCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(theme.accent.opacity(0.15))
                        .frame(width: 72, height: 72)
                    
                    Text(initials)
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundColor(theme.accent)
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(client.name ?? "Unknown")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(theme.primaryText)
                    
                    if let email = client.email, !email.isEmpty {
                        HStack(spacing: 8) {
                            Image(systemName: "envelope")
                                .font(.system(size: 14))
                            Text(email)
                                .font(.system(size: 15))
                        }
                        .foregroundColor(theme.secondaryText)
                    }
                    
                    if let phone = client.phone, !phone.isEmpty {
                        HStack(spacing: 8) {
                            Image(systemName: "phone")
                                .font(.system(size: 14))
                            Text(phone)
                                .font(.system(size: 15))
                        }
                        .foregroundColor(theme.secondaryText)
                    }
                }
                
                Spacer()
            }
            
            if let notes = client.notes, !notes.isEmpty {
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Notes")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(theme.secondaryText)
                    
                    Text(notes)
                        .font(.system(size: 15))
                        .foregroundColor(theme.primaryText)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: theme.radiusXL)
                .fill(theme.cardBackground)
                .shadow(color: theme.shadowColor, radius: theme.shadowRadiusMedium, x: 0, y: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: theme.radiusXL)
                .stroke(theme.cardBorder, lineWidth: 1)
        )
    }
    
    private var medicalInfoCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "cross.case.fill")
                    .foregroundColor(theme.accent)
                Text("Medical Information")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(theme.primaryText)
            }
            
            VStack(alignment: .leading, spacing: 16) {
                if let medicalHistory = client.medicalHistory, !medicalHistory.isEmpty {
                    medicalInfoRow(
                        icon: "heart.text.square",
                        title: "Medical History",
                        content: medicalHistory
                    )
                }
                
                if let allergies = client.allergies, !allergies.isEmpty {
                    if client.medicalHistory != nil && !client.medicalHistory!.isEmpty {
                        Divider()
                    }
                    medicalInfoRow(
                        icon: "exclamationmark.triangle",
                        title: "Allergies",
                        content: allergies,
                        color: theme.warning
                    )
                }
                
                if let sensitivities = client.knownSensitivities, !sensitivities.isEmpty {
                    if (client.medicalHistory != nil && !client.medicalHistory!.isEmpty) ||
                       (client.allergies != nil && !client.allergies!.isEmpty) {
                        Divider()
                    }
                    medicalInfoRow(
                        icon: "hand.raised",
                        title: "Known Sensitivities",
                        content: sensitivities
                    )
                }

                if let medications = client.medications, !medications.isEmpty {
                    if (client.medicalHistory != nil && !client.medicalHistory!.isEmpty) ||
                       (client.allergies != nil && !client.allergies!.isEmpty) ||
                       (client.knownSensitivities != nil && !client.knownSensitivities!.isEmpty) {
                        Divider()
                    }
                    medicalInfoRow(
                        icon: "pills",
                        title: "Current Medications",
                        content: medications,
                        color: theme.accent
                    )
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: theme.radiusXL)
                .fill(theme.cardBackground)
                .shadow(color: theme.shadowColor, radius: theme.shadowRadiusSmall, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: theme.radiusXL)
                .stroke(theme.cardBorder, lineWidth: 1)
        )
    }
    
    private func medicalInfoRow(icon: String, title: String, content: String, color: Color? = nil) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(color ?? theme.accent)
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(theme.secondaryText)
            }
            
            Text(content)
                .font(.system(size: 15))
                .foregroundColor(theme.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    private var compareAnalysesButton: some View {
        Button(action: { showCompareAnalyses = true }) {
            HStack {
                Spacer()
                Image(systemName: "arrow.left.arrow.right")
                Text("Compare Analyses")
                Spacer()
            }
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.white)
            .frame(height: 48)
            .background(theme.accent)
            .clipShape(RoundedRectangle(cornerRadius: theme.radiusMedium))
        }
    }
    
    private var analysisHistorySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Analysis History")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(theme.primaryText)
            
            ForEach(viewModel.analyses) { analysis in
                NavigationLink(destination: AnalysisDetailView(analysis: analysis)) {
                    AnalysisRowView(analysis: analysis)
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    private var emptyAnalysisView: some View {
        VStack(spacing: 20) {
            Image(systemName: "camera")
                .font(.system(size: 50))
                .foregroundColor(theme.tertiaryText)
            
            Text("No Analyses Yet")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(theme.primaryText)
            
            Text("Start by capturing a skin image for AI analysis")
                .font(.system(size: 15))
                .foregroundColor(theme.secondaryText)
                .multilineTextAlignment(.center)
            
            Button(action: { showAnalysisInput = true }) {
                HStack {
                    Image(systemName: "camera.fill")
                    Text("New Analysis")
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background(theme.accent)
                .clipShape(RoundedRectangle(cornerRadius: theme.radiusMedium))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
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

struct AnalysisRowView: View {
    @ObservedObject var theme = ThemeManager.shared
    let analysis: SkinAnalysisResult
    
    var body: some View {
        HStack(spacing: 16) {
            if let imageUrl = analysis.imageUrl, let url = URL(string: imageUrl) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        Rectangle()
                            .fill(theme.tertiaryBackground)
                            .overlay(ProgressView())
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure:
                        Rectangle()
                            .fill(theme.tertiaryBackground)
                            .overlay(
                                Image(systemName: "photo")
                                    .foregroundColor(theme.tertiaryText)
                            )
                    @unknown default:
                        EmptyView()
                    }
                }
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: theme.radiusMedium))
            }
            
            VStack(alignment: .leading, spacing: 6) {
                if let skinType = analysis.analysisResults?.skinType {
                    Text("Skin Type: \(skinType.capitalized)")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(theme.primaryText)
                        .lineLimit(1)
                }
                
                if let score = analysis.analysisResults?.skinHealthScore {
                    HStack(spacing: 8) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 14))
                        Text("Health Score: \(score)/10")
                            .font(.system(size: 14))
                    }
                    .foregroundColor(theme.accent)
                }
                
                if let date = analysis.createdAt {
                    Text(formatDate(date))
                        .font(.system(size: 13))
                        .foregroundColor(theme.secondaryText)
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
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            displayFormatter.timeStyle = .short
            return displayFormatter.string(from: date)
        }
        return dateString
    }
}

@MainActor
class ClientDetailViewModel: ObservableObject {
    @Published private(set) var analyses: [SkinAnalysisResult] = []
    @Published private(set) var isLoading = false
    @Published var showError = false
    @Published var errorMessage = ""
    @Published var clients: [AppClient] = []
    
    func loadAnalyses(clientId: String, userId: String) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            try Task.checkCancellation()
            let fetchedAnalyses = try await NetworkService.shared.fetchAnalyses(clientId: clientId, userId: userId)
            analyses = fetchedAnalyses.sorted { ($0.createdAt ?? "") > ($1.createdAt ?? "") }
        } catch is CancellationError {
            return
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
    
    func addAnalysis(_ analysis: SkinAnalysisResult) {
        analyses.insert(analysis, at: 0)
    }
}