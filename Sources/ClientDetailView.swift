import SwiftUI

struct ClientDetailView: View {
    @ObservedObject var theme = ThemeManager.shared
    let client: AppClient
    @Binding var selectedClient: AppClient?
    @StateObject private var viewModel = ClientDetailViewModel()
    @State private var showAnalysisInput = false
    @State private var showEditClient = false
    @State private var showCompareAnalyses = false
    @State private var showConsentForm = false
    @State private var showConsentAlert = false
    @State private var currentClient: AppClient
    @Environment(\.horizontalSizeClass) var horizontalSizeClass

    init(client: AppClient, selectedClient: Binding<AppClient?>) {
        self.client = client
        self._selectedClient = selectedClient
        self._currentClient = State(initialValue: client)
    }
    
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

                        newAnalysisButton

                        if hasMedicalInfo {
                            medicalInfoCard
                        }
                        
                        if viewModel.analyses.count >= 2 {
                            compareAnalysesButton
                        }

                        if !viewModel.analyses.isEmpty {
                            progressMetricsCard
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

                Button(action: {
                    if currentClient.hasValidConsent {
                        showAnalysisInput = true
                    } else {
                        showConsentAlert = true
                    }
                }) {
                    Label("New Analysis", systemImage: "camera")
                }
                .keyboardShortcut("a", modifiers: .command)
            }
        }
        .navigationBarBackButtonHidden(false)
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
        .sheet(isPresented: $showConsentForm) {
            ClientHIPAAConsentView(client: client, onConsent: { signature in
                viewModel.updateClientConsent(client: client, signature: signature) { updatedClient in
                    selectedClient = updatedClient
                }
            })
        }
        .alert("Consent Required", isPresented: $showConsentAlert) {
            Button("Sign Now") {
                showConsentForm = true
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            if client.hasExpiredConsent {
                Text("This client's HIPAA consent has expired. A new consent signature is required before performing skin analysis.")
            } else {
                Text("This client has not signed a HIPAA consent form. A consent signature is required before performing skin analysis.")
            }
        }
        .task {
            await viewModel.loadAnalyses(clientId: client.id ?? "", userId: AuthenticationManager.shared.currentUser?.id ?? "")
        }
    }
    
    private var hasMedicalInfo: Bool {
        (client.medicalHistory != nil && !client.medicalHistory!.isEmpty) ||
        (client.allergies != nil && !client.allergies!.isEmpty) ||
        (client.knownSensitivities != nil && !client.knownSensitivities!.isEmpty) ||
        (client.medications != nil && !client.medications!.isEmpty) ||
        (client.productsToAvoid != nil && !client.productsToAvoid!.isEmpty) ||
        client.fillersDate != nil ||
        client.biostimulatorsDate != nil
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

                    // HIPAA Consent Status Badge
                    consentStatusBadge

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

            // Show consent date if available
            if let consentDate = client.consentDate {
                Divider()

                HStack(spacing: 8) {
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 14))
                        .foregroundColor(theme.accent)
                    Text("Consent signed on \(formatConsentDate(consentDate))")
                        .font(.system(size: 13))
                        .foregroundColor(theme.secondaryText)
                }
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
                        title: "Medications and/or Supplements",
                        content: medications,
                        color: theme.accent
                    )
                }

                if let productsToAvoid = client.productsToAvoid, !productsToAvoid.isEmpty {
                    if (client.medicalHistory != nil && !client.medicalHistory!.isEmpty) ||
                       (client.allergies != nil && !client.allergies!.isEmpty) ||
                       (client.knownSensitivities != nil && !client.knownSensitivities!.isEmpty) ||
                       (client.medications != nil && !client.medications!.isEmpty) {
                        Divider()
                    }
                    medicalInfoRow(
                        icon: "exclamationmark.shield",
                        title: "Products to Avoid",
                        content: productsToAvoid,
                        color: theme.error
                    )
                }

                if client.fillersDate != nil || client.biostimulatorsDate != nil {
                    if (client.medicalHistory != nil && !client.medicalHistory!.isEmpty) ||
                       (client.allergies != nil && !client.allergies!.isEmpty) ||
                       (client.knownSensitivities != nil && !client.knownSensitivities!.isEmpty) ||
                       (client.medications != nil && !client.medications!.isEmpty) ||
                       (client.productsToAvoid != nil && !client.productsToAvoid!.isEmpty) {
                        Divider()
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: "cross.vial.fill")
                                .font(.system(size: 16))
                                .foregroundColor(theme.accent)
                            Text("Injectables History")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(theme.secondaryText)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            if let fillersDate = client.fillersDate {
                                HStack {
                                    Text("Fillers:")
                                        .font(.system(size: 15))
                                        .foregroundColor(theme.secondaryText)
                                    Text(formatInjectablesDate(fillersDate))
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(theme.primaryText)
                                }
                            }

                            if let biostimulatorsDate = client.biostimulatorsDate {
                                HStack {
                                    Text("Biostimulators:")
                                        .font(.system(size: 15))
                                        .foregroundColor(theme.secondaryText)
                                    Text(formatInjectablesDate(biostimulatorsDate))
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(theme.primaryText)
                                }
                            }
                        }
                        .padding(.leading, 24)
                    }
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
    
    private var newAnalysisButton: some View {
        Button(action: {
            // Check if consent is valid before allowing analysis
            if client.hasValidConsent {
                showAnalysisInput = true
            } else {
                showConsentAlert = true
            }
        }) {
            HStack {
                Spacer()
                Image(systemName: "camera.fill")
                Text("New Skin Analysis")
                Spacer()
            }
            .font(.system(size: 17, weight: .semibold))
            .foregroundColor(.white)
            .frame(height: 52)
            .background(theme.accent)
            .clipShape(RoundedRectangle(cornerRadius: theme.radiusMedium))
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

    private var progressMetricsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundColor(theme.accent)
                Text("Progress Metrics")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(theme.primaryText)
            }

            if viewModel.analyses.count >= 2 {
                let sortedAnalyses = viewModel.analyses.sorted { ($0.createdAt ?? "") < ($1.createdAt ?? "") }
                let first = sortedAnalyses.first
                let last = sortedAnalyses.last

                VStack(spacing: 12) {
                    if let firstScore = first?.analysisResults?.skinHealthScore,
                       let lastScore = last?.analysisResults?.skinHealthScore {
                        progressMetricRow(
                            label: "Skin Health Score",
                            icon: "heart.fill",
                            firstValue: firstScore,
                            lastValue: lastScore,
                            unit: "/10"
                        )
                    }

                    if let firstHydration = first?.analysisResults?.hydrationLevel,
                       let lastHydration = last?.analysisResults?.hydrationLevel {
                        progressMetricRow(
                            label: "Hydration Level",
                            icon: "humidity",
                            firstValue: firstHydration,
                            lastValue: lastHydration,
                            unit: "%"
                        )
                    }

                    Divider()

                    HStack {
                        Image(systemName: "calendar")
                            .font(.system(size: 16))
                            .foregroundColor(theme.accent)
                            .frame(width: 24)

                        Text("Total Analyses")
                            .font(.system(size: 15))
                            .foregroundColor(theme.secondaryText)

                        Spacer()

                        Text("\(viewModel.analyses.count)")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(theme.primaryText)
                    }

                    if let firstDate = first?.createdAt,
                       last?.createdAt != nil {
                        HStack {
                            Image(systemName: "clock")
                                .font(.system(size: 16))
                                .foregroundColor(theme.accent)
                                .frame(width: 24)

                            Text("Tracking Since")
                                .font(.system(size: 15))
                                .foregroundColor(theme.secondaryText)

                            Spacer()

                            Text(formatProgressDate(firstDate))
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(theme.primaryText)
                        }
                    }
                }
            } else {
                Text("Track progress over time with multiple analyses")
                    .font(.system(size: 14))
                    .foregroundColor(theme.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
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

    private func progressMetricRow(label: String, icon: String, firstValue: Int, lastValue: Int, unit: String) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(theme.accent)
                .frame(width: 24)

            Text(label)
                .font(.system(size: 15))
                .foregroundColor(theme.secondaryText)

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("\(lastValue)\(unit)")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(theme.primaryText)

                let change = lastValue - firstValue
                HStack(spacing: 4) {
                    if change > 0 {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 12))
                            .foregroundColor(theme.success)
                        Text("+\(change) from first")
                            .font(.system(size: 13))
                            .foregroundColor(theme.success)
                    } else if change < 0 {
                        Image(systemName: "arrow.down")
                            .font(.system(size: 12))
                            .foregroundColor(theme.error)
                        Text("\(change) from first")
                            .font(.system(size: 13))
                            .foregroundColor(theme.error)
                    } else {
                        Text("No change")
                            .font(.system(size: 13))
                            .foregroundColor(theme.secondaryText)
                    }
                }
            }
        }
    }

    private func formatProgressDate(_ dateString: String) -> String {
        // Try ISO8601DateFormatter with fractional seconds
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        if let date = isoFormatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateFormat = "MM/dd/yyyy"
            return displayFormatter.string(from: date)
        }

        // Fallback: Try without fractional seconds
        isoFormatter.formatOptions = [.withInternetDateTime]
        if let date = isoFormatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateFormat = "MM/dd/yyyy"
            return displayFormatter.string(from: date)
        }

        return dateString
    }

    private func formatInjectablesDate(_ dateString: String) -> String {
        let isoFormatter = ISO8601DateFormatter()

        // Try parsing the date
        if let date = isoFormatter.date(from: dateString) {
            let now = Date()
            let calendar = Calendar.current
            let components = calendar.dateComponents([.day, .month, .year], from: date, to: now)

            if let years = components.year, years > 0 {
                return years == 1 ? "1 year ago" : "\(years) years ago"
            } else if let months = components.month, months > 0 {
                return months == 1 ? "1 month ago" : "\(months) months ago"
            } else if let days = components.day, days > 0 {
                return days == 1 ? "1 day ago" : "\(days) days ago"
            } else {
                return "Today"
            }
        }

        return dateString
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

    private func formatConsentDate(_ dateString: String) -> String {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        if let date = isoFormatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateFormat = "MMM d, yyyy"
            return displayFormatter.string(from: date)
        }

        // Fallback: Try without fractional seconds
        isoFormatter.formatOptions = [.withInternetDateTime]
        if let date = isoFormatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateFormat = "MMM d, yyyy"
            return displayFormatter.string(from: date)
        }

        return dateString
    }

    @ViewBuilder
    private var consentStatusBadge: some View {
        let status = client.consentStatus

        HStack(spacing: 6) {
            Image(systemName: status.icon)
                .font(.system(size: 12))
            Text(status.displayText)
                .font(.system(size: 12, weight: .medium))
        }
        .foregroundColor(Color(red: status.color.red, green: status.color.green, blue: status.color.blue))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(red: status.color.red, green: status.color.green, blue: status.color.blue).opacity(0.1))
        .clipShape(Capsule())
        .onTapGesture {
            // Allow tapping to renew consent
            if status == .expired || status == .missing {
                showConsentForm = true
            }
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
        // Try ISO8601DateFormatter with fractional seconds
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        if let date = isoFormatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateFormat = "MM/dd/yyyy hh:mm a"
            return displayFormatter.string(from: date)
        }

        // Fallback: Try without fractional seconds
        isoFormatter.formatOptions = [.withInternetDateTime]
        if let date = isoFormatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateFormat = "MM/dd/yyyy hh:mm a"
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

    func updateClientConsent(client: AppClient, signature: String, completion: @escaping (AppClient) -> Void) {
        guard let userId = AuthenticationManager.shared.currentUser?.id else { return }

        var updatedClient = client
        updatedClient.consentSignature = signature
        updatedClient.consentDate = ISO8601DateFormatter().string(from: Date())

        Task {
            do {
                let savedClient = try await NetworkService.shared.createOrUpdateClient(client: updatedClient, userId: userId)
                await MainActor.run {
                    completion(savedClient)
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
}
