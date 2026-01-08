import SwiftUI
import PhotosUI
import UIKit

struct SkinAnalysisInputView: View {
    @ObservedObject var theme = ThemeManager.shared
    let client: AppClient
    @ObservedObject var viewModel: ClientDetailViewModel
    @Environment(\.dismiss) var dismiss
    @State private var selectedImage: UIImage?
    @State private var showImagePicker = false
    @State private var showCamera = false
    @State private var showCameraWithOverlay = false
    @State private var isAnalyzing = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var analysisResult: AnalysisData?
    @State private var showResults = false
    @State private var showManualInput = false
    @State private var manualSkinType = ""
    @State private var manualHydrationLevel = ""
    @State private var manualSensitivity = ""
    @State private var manualPoreCondition = ""
    @State private var manualConcerns = ""
    @State private var productsUsed = ""
    @State private var treatmentsPerformed = ""
    @State private var hasFillers = false
    @State private var hasBiostimulators = false
    @State private var fillersTimeAmount = ""
    @State private var fillersTimeUnit = "months"
    @State private var biostimulatorsTimeAmount = ""
    @State private var biostimulatorsTimeUnit = "months"
    @State private var showSubscriptionRequired = false
    @StateObject private var storeManager = StoreKitManager.shared
    @FocusState private var focusedField: Field?

    enum Field {
        case skinType, hydration, sensitivity, pore, concerns, products, treatments, fillersTime, biostimulatorsTime
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                theme.primaryBackground
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        imageSection
                        
                        if selectedImage == nil {
                            instructionsSection
                        }
                        
                        if hasMedicalInfo {
                            medicalInfoNotice
                        }
                        
                        if selectedImage != nil {
                            fillersAndBiostimulatorsSection
                            treatmentSection
                            manualInputSection
                            analyzeButton
                        }
                    }
                    .padding(20)
                }
                .scrollDismissesKeyboard(.interactively)
                
                if isAnalyzing {
                    Color.black.opacity(0.5)
                        .ignoresSafeArea()
                    
                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.white)
                        
                        Text("Analyzing skin...")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(.white)
                        
                        if hasMedicalInfo {
                            Text("Considering medical history")
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.8))
                        }
                        
                        if !productsUsed.isEmpty || !treatmentsPerformed.isEmpty {
                            Text("Including treatment history")
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                }
            }
            .navigationTitle("Skin Analysis")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(image: $selectedImage, sourceType: .photoLibrary)
            }
            .sheet(isPresented: $showCamera) {
                if ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] != nil {
                    Text("Camera is not available on Simulator. Please test on a real device.")
                        .padding()
                } else {
                    ImagePicker(image: $selectedImage, sourceType: .camera)
                }
            }
            .fullScreenCover(isPresented: $showCameraWithOverlay) {
                if let previousImage = getPreviousAnalysisImage() {
                    CameraWithOverlayView(capturedImage: $selectedImage, overlayImage: previousImage)
                } else {
                    if ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] != nil {
                        Text("Camera is not available on Simulator. Please test on a real device.")
                            .padding()
                    } else {
                        ImagePicker(image: $selectedImage, sourceType: .camera)
                    }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .alert("Subscription Required", isPresented: $showSubscriptionRequired) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("An active subscription is required to use Claude Vision AI. You can switch to Apple Vision (free) in Admin → AI Vision Provider, or contact your company admin to purchase a subscription.")
            }
            .navigationDestination(isPresented: $showResults) {
                if let result = analysisResult, let image = selectedImage {
                    SkinAnalysisResultsView(
                        client: client,
                        image: image,
                        analysisResult: result,
                        viewModel: viewModel,
                        productsUsed: productsUsed,
                        treatmentsPerformed: treatmentsPerformed
                    )
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .dismissAnalysisInput)) { _ in
                dismiss()
            }
        }
    }
    
    private var hasMedicalInfo: Bool {
        (client.medicalHistory != nil && !client.medicalHistory!.isEmpty) ||
        (client.allergies != nil && !client.allergies!.isEmpty) ||
        (client.knownSensitivities != nil && !client.knownSensitivities!.isEmpty) ||
        (client.productsToAvoid != nil && !client.productsToAvoid!.isEmpty)
    }
    
    private func getPreviousAnalysisImage() -> UIImage? {
        guard let latestAnalysis = viewModel.analyses.first,
              let imageUrlString = latestAnalysis.imageUrl,
              let imageUrl = URL(string: imageUrlString) else {
            return nil
        }
        
        if let cachedImage = ImageCache.shared.getImage(forKey: imageUrlString) {
            return cachedImage
        }
        
        if let data = try? Data(contentsOf: imageUrl),
           let image = UIImage(data: data) {
            ImageCache.shared.setImage(image, forKey: imageUrlString)
            return image
        }
        
        return nil
    }
    
    private var imageSection: some View {
        VStack(spacing: 16) {
            if let image = selectedImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .frame(maxHeight: 400)
                    .clipShape(RoundedRectangle(cornerRadius: theme.radiusLarge))
                    .overlay(
                        RoundedRectangle(cornerRadius: theme.radiusLarge)
                            .stroke(theme.border, lineWidth: 1)
                    )
                
                Button(action: { selectedImage = nil }) {
                    HStack {
                        Image(systemName: "xmark.circle.fill")
                        Text("Remove Image")
                    }
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(theme.error)
                }
            } else {
                VStack(spacing: 20) {
                    Image(systemName: "camera")
                        .font(.system(size: 60))
                        .foregroundColor(theme.tertiaryText)
                    
                    Text("No Image Selected")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(theme.primaryText)
                    
                    if !viewModel.analyses.isEmpty {
                        VStack(spacing: 12) {
                            Text("Follow-up Photo")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(theme.secondaryText)
                            
                            Button(action: { 
                                if getPreviousAnalysisImage() != nil {
                                    showCameraWithOverlay = true
                                } else {
                                    showCamera = true
                                }
                            }) {
                                VStack(spacing: 8) {
                                    Image(systemName: "camera.filters")
                                        .font(.system(size: 28))
                                    Text("Camera with Overlay")
                                        .font(.system(size: 14, weight: .medium))
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 24)
                                .background(theme.accent)
                                .clipShape(RoundedRectangle(cornerRadius: theme.radiusMedium))
                            }
                            
                            Text("Previous photo will appear as overlay for alignment")
                                .font(.system(size: 12))
                                .foregroundColor(theme.secondaryText)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.horizontal)
                        
                        HStack {
                            Rectangle()
                                .fill(theme.border)
                                .frame(height: 1)
                            
                            Text("OR")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(theme.secondaryText)
                                .padding(.horizontal, 12)
                            
                            Rectangle()
                                .fill(theme.border)
                                .frame(height: 1)
                        }
                        .padding(.horizontal)
                    }
                    
                    HStack(spacing: 16) {
                        if viewModel.analyses.isEmpty {
                            Button(action: { showCamera = true }) {
                                VStack(spacing: 8) {
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 28))
                                    Text("Camera")
                                        .font(.system(size: 14, weight: .medium))
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 24)
                                .background(theme.accent)
                                .clipShape(RoundedRectangle(cornerRadius: theme.radiusMedium))
                            }
                        } else {
                            Button(action: { showCamera = true }) {
                                VStack(spacing: 8) {
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 28))
                                    Text("Camera")
                                        .font(.system(size: 14, weight: .medium))
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 24)
                                .background(theme.accentSubtle)
                                .clipShape(RoundedRectangle(cornerRadius: theme.radiusMedium))
                            }
                        }
                        
                        Button(action: { showImagePicker = true }) {
                            VStack(spacing: 8) {
                                Image(systemName: "photo.fill")
                                    .font(.system(size: 28))
                                Text("Gallery")
                                    .font(.system(size: 14, weight: .medium))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 24)
                            .background(viewModel.analyses.isEmpty ? theme.accentSubtle : theme.accent)
                            .clipShape(RoundedRectangle(cornerRadius: theme.radiusMedium))
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 60)
                .background(
                    RoundedRectangle(cornerRadius: theme.radiusXL)
                        .fill(theme.cardBackground)
                        .shadow(color: theme.shadowColor, radius: theme.shadowRadiusMedium, x: 0, y: 8)
                )
            }
        }
    }
    
    private var instructionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Tips for Best Results")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(theme.primaryText)
            
            VStack(alignment: .leading, spacing: 12) {
                tipRow(icon: "sun.max", text: "Use natural lighting")
                tipRow(icon: "camera.viewfinder", text: "Capture face straight-on")
                tipRow(icon: "sparkles", text: "Ensure clean, makeup-free skin")
                tipRow(icon: "square.and.arrow.up", text: "High-quality image recommended")
                if !viewModel.analyses.isEmpty {
                    tipRow(icon: "camera.filters", text: "Use overlay camera for consistent positioning")
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: theme.radiusXL)
                .fill(theme.cardBackground)
                .shadow(color: theme.shadowColor, radius: theme.shadowRadiusSmall, x: 0, y: 4)
        )
    }
    
    private var medicalInfoNotice: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(theme.accent)
                Text("Medical Information Included")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(theme.primaryText)
            }
            
            Text("This analysis will consider the client's medical history, allergies, and known sensitivities for more accurate recommendations.")
                .font(.system(size: 14))
                .foregroundColor(theme.secondaryText)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: theme.radiusLarge)
                .fill(theme.accent.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: theme.radiusLarge)
                .stroke(theme.accent.opacity(0.3), lineWidth: 1)
        )
    }
    
    private var manualInputSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            DisclosureGroup {
                VStack(spacing: 16) {
                    Text("Override or supplement AI analysis with your professional assessment")
                        .font(.system(size: 13))
                        .foregroundColor(theme.secondaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 8)

                    inputField(
                        title: "Skin Type",
                        icon: "drop",
                        placeholder: "e.g., Oily, Dry, Combination, Normal",
                        text: $manualSkinType,
                        field: .skinType
                    )

                    inputField(
                        title: "Hydration Level",
                        icon: "humidity",
                        placeholder: "e.g., 65% or Well-hydrated",
                        text: $manualHydrationLevel,
                        field: .hydration
                    )

                    inputField(
                        title: "Sensitivity",
                        icon: "exclamationmark.triangle",
                        placeholder: "e.g., Low, Medium, High",
                        text: $manualSensitivity,
                        field: .sensitivity
                    )

                    inputField(
                        title: "Pore Condition",
                        icon: "circle.grid.3x3",
                        placeholder: "e.g., Enlarged, Normal, Refined",
                        text: $manualPoreCondition,
                        field: .pore
                    )

                    textEditorField(
                        title: "Specific Concerns",
                        icon: "exclamationmark.circle",
                        placeholder: "List any specific skin concerns you observe",
                        text: $manualConcerns,
                        field: .concerns
                    )
                }
                .padding(.bottom, 8)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "slider.horizontal.3")
                        .foregroundColor(theme.accent)
                    Text("Manual Parameters (Optional)")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(theme.primaryText)
                }
            }
            .tint(theme.accent)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: theme.radiusXL)
                .fill(theme.cardBackground)
                .shadow(color: theme.shadowColor, radius: theme.shadowRadiusSmall, x: 0, y: 4)
        )
    }
    
    private var fillersAndBiostimulatorsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Injectables History")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(theme.primaryText)

            Text("Select if client has had any of these treatments recently")
                .font(.system(size: 13))
                .foregroundColor(theme.secondaryText)

            // Toggle buttons for Fillers and Biostimulators
            HStack(spacing: 12) {
                Button(action: { hasFillers.toggle() }) {
                    HStack {
                        Image(systemName: hasFillers ? "checkmark.circle.fill" : "circle")
                        Text("Fillers")
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(hasFillers ? .white : theme.primaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(hasFillers ? theme.accent : theme.tertiaryBackground)
                    .clipShape(RoundedRectangle(cornerRadius: theme.radiusMedium))
                    .overlay(
                        RoundedRectangle(cornerRadius: theme.radiusMedium)
                            .stroke(hasFillers ? theme.accent : theme.border, lineWidth: hasFillers ? 2 : 1)
                    )
                }

                Button(action: { hasBiostimulators.toggle() }) {
                    HStack {
                        Image(systemName: hasBiostimulators ? "checkmark.circle.fill" : "circle")
                        Text("Biostimulators")
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(hasBiostimulators ? .white : theme.primaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(hasBiostimulators ? theme.accent : theme.tertiaryBackground)
                    .clipShape(RoundedRectangle(cornerRadius: theme.radiusMedium))
                    .overlay(
                        RoundedRectangle(cornerRadius: theme.radiusMedium)
                            .stroke(hasBiostimulators ? theme.accent : theme.border, lineWidth: hasBiostimulators ? 2 : 1)
                    )
                }
            }

            // Fillers time input
            if hasFillers {
                timeInputField(
                    title: "How long ago were fillers administered?",
                    amount: $fillersTimeAmount,
                    unit: $fillersTimeUnit,
                    field: .fillersTime
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            // Biostimulators time input
            if hasBiostimulators {
                timeInputField(
                    title: "How long ago were biostimulators administered?",
                    amount: $biostimulatorsTimeAmount,
                    unit: $biostimulatorsTimeUnit,
                    field: .biostimulatorsTime
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: theme.radiusXL)
                .fill(theme.cardBackground)
                .shadow(color: theme.shadowColor, radius: theme.shadowRadiusSmall, x: 0, y: 4)
        )
        .animation(.spring(), value: hasFillers)
        .animation(.spring(), value: hasBiostimulators)
    }

    private func timeInputField(
        title: String,
        amount: Binding<String>,
        unit: Binding<String>,
        field: Field
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(theme.secondaryText)

            HStack(spacing: 12) {
                // Number input
                TextField("0", text: amount)
                    .font(.system(size: 17))
                    .foregroundColor(theme.primaryText)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .frame(width: 80)
                    .padding(12)
                    .background(theme.tertiaryBackground)
                    .clipShape(RoundedRectangle(cornerRadius: theme.radiusMedium))
                    .overlay(
                        RoundedRectangle(cornerRadius: theme.radiusMedium)
                            .stroke(focusedField == field ? theme.accent : theme.border, lineWidth: focusedField == field ? 2 : 1)
                    )
                    .focused($focusedField, equals: field)

                // Unit picker
                Menu {
                    Button("day(s)") { unit.wrappedValue = "day(s)" }
                    Button("week(s)") { unit.wrappedValue = "week(s)" }
                    Button("month(s)") { unit.wrappedValue = "month(s)" }
                    Button("year(s)") { unit.wrappedValue = "year(s)" }
                } label: {
                    HStack {
                        Text(unit.wrappedValue)
                            .font(.system(size: 17))
                            .foregroundColor(theme.primaryText)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 14))
                            .foregroundColor(theme.tertiaryText)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(12)
                    .background(theme.tertiaryBackground)
                    .clipShape(RoundedRectangle(cornerRadius: theme.radiusMedium))
                    .overlay(
                        RoundedRectangle(cornerRadius: theme.radiusMedium)
                            .stroke(theme.border, lineWidth: 1)
                    )
                }
            }
        }
    }

    private var treatmentSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            DisclosureGroup {
                VStack(spacing: 16) {
                    Text("Track products and treatments to monitor effectiveness over time")
                        .font(.system(size: 13))
                        .foregroundColor(theme.secondaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 8)

                    textEditorField(
                        title: "Products Used",
                        icon: "drop.triangle",
                        placeholder: "List products applied (e.g., serums, moisturizers, cleansers)",
                        text: $productsUsed,
                        field: .products
                    )

                    textEditorField(
                        title: "Treatments Performed",
                        icon: "wand.and.stars",
                        placeholder: "Describe treatments performed (e.g., chemical peel, microdermabrasion, facial massage)",
                        text: $treatmentsPerformed,
                        field: .treatments
                    )
                }
                .padding(.bottom, 8)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "cross.case")
                        .foregroundColor(theme.accent)
                    Text("Products & Treatments")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(theme.primaryText)
                }
            }
            .tint(theme.accent)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: theme.radiusXL)
                .fill(theme.cardBackground)
                .shadow(color: theme.shadowColor, radius: theme.shadowRadiusSmall, x: 0, y: 4)
        )
    }
    
    private func inputField(
        title: String,
        icon: String,
        placeholder: String,
        text: Binding<String>,
        field: Field
    ) -> some View {
        ThemedTextField(
            title: title,
            placeholder: placeholder,
            text: text,
            field: field,
            focusedField: $focusedField,
            theme: theme,
            icon: icon
        )
    }
    
    private func textEditorField(
        title: String,
        icon: String,
        placeholder: String,
        text: Binding<String>,
        field: Field
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(theme.secondaryText)
            
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(theme.tertiaryText)
                    .frame(width: 24)
                    .padding(.top, 12)
                
                ZStack(alignment: .topLeading) {
                    if text.wrappedValue.isEmpty {
                        Text(placeholder)
                            .font(.system(size: 17))
                            .foregroundColor(theme.tertiaryText)
                            .padding(.top, 8)
                            .padding(.leading, 4)
                    }
                    
                    TextEditor(text: text)
                        .font(.system(size: 17))
                        .foregroundColor(theme.primaryText)
                        .frame(minHeight: 80)
                        .focused($focusedField, equals: field)
                        .scrollContentBackground(.hidden)
                }
            }
            .padding(16)
            .background(theme.tertiaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: theme.radiusMedium))
            .overlay(
                RoundedRectangle(cornerRadius: theme.radiusMedium)
                    .stroke(focusedField == field ? theme.accent : theme.border, lineWidth: focusedField == field ? 2 : 1)
            )
        }
    }
    
    private func tipRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(theme.accent)
                .frame(width: 24)
            
            Text(text)
                .font(.system(size: 15))
                .foregroundColor(theme.primaryText)
        }
    }
    
    private var analyzeButton: some View {
        Button(action: performAnalysis) {
            HStack {
                Spacer()
                Image(systemName: "sparkles")
                Text("Analyze Skin")
                Spacer()
            }
            .font(.system(size: 17, weight: .semibold))
            .foregroundColor(.white)
            .frame(height: 52)
            .background(theme.accent)
            .clipShape(RoundedRectangle(cornerRadius: theme.radiusMedium))
        }
    }
    
    private func performAnalysis() {
        guard let image = selectedImage else { return }

        // Check if user is trying to use Claude Vision without active subscription
        if AppConstants.aiProvider == .claude && !storeManager.hasActiveSubscription() {
            showSubscriptionRequired = true
            return
        }

        // Note: Apple Vision free tier limit (5/month) is checked earlier in ClientDetailView
        // before the user even reaches this screen, providing better UX

        focusedField = nil
        isAnalyzing = true

        Task {
            await continueAnalysis(image: image)
        }
    }

    private func continueAnalysis(image: UIImage) async {
        // Build injectables history string
        var injectablesHistory: String? = nil
        var historyParts: [String] = []

        if hasFillers && !fillersTimeAmount.isEmpty {
            historyParts.append("Fillers administered \(fillersTimeAmount) \(fillersTimeUnit) ago")
        }

        if hasBiostimulators && !biostimulatorsTimeAmount.isEmpty {
            historyParts.append("Biostimulators administered \(biostimulatorsTimeAmount) \(biostimulatorsTimeUnit) ago")
        }

        if !historyParts.isEmpty {
            injectablesHistory = historyParts.joined(separator: "; ")
        }

        do {
            // Fetch AI rules and products for the current user
                let aiRules: [AIRule]
                let products: [Product]
                if let user = AuthenticationManager.shared.currentUser,
                   let userId = user.id {
                    aiRules = try await NetworkService.shared.fetchAIRules(userId: userId)
                    products = try await NetworkService.shared.fetchProductsForUser(
                        userId: userId,
                        companyId: user.companyId
                    )
                } else {
                    aiRules = []
                    products = []
                }

                let result = try await NetworkService.shared.analyzeImage(
                    image: image,
                    medicalHistory: client.medicalHistory,
                    allergies: client.allergies,
                    knownSensitivities: client.knownSensitivities,
                    medications: client.medications,
                    productsToAvoid: client.productsToAvoid,
                    manualSkinType: manualSkinType.isEmpty ? nil : manualSkinType,
                    manualHydrationLevel: manualHydrationLevel.isEmpty ? nil : manualHydrationLevel,
                    manualSensitivity: manualSensitivity.isEmpty ? nil : manualSensitivity,
                    manualPoreCondition: manualPoreCondition.isEmpty ? nil : manualPoreCondition,
                    manualConcerns: manualConcerns.isEmpty ? nil : manualConcerns,
                    productsUsed: productsUsed.isEmpty ? nil : productsUsed,
                    treatmentsPerformed: treatmentsPerformed.isEmpty ? nil : treatmentsPerformed,
                    injectablesHistory: injectablesHistory,
                    previousAnalyses: viewModel.analyses,
                    aiRules: aiRules,
                    products: products
                )
                await MainActor.run {
                    analysisResult = result
                    isAnalyzing = false
                    showResults = true
                }
            } catch is CancellationError {
                await MainActor.run {
                    isAnalyzing = false
                }
                return
            } catch {
                await MainActor.run {
                    isAnalyzing = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
    }
}

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    let sourceType: UIImagePickerController.SourceType
    @Environment(\.dismiss) var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.image = image
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

struct CameraWithOverlayView: UIViewControllerRepresentable {
    @Binding var capturedImage: UIImage?
    let overlayImage: UIImage
    @Environment(\.dismiss) var dismiss
    
    func makeUIViewController(context: Context) -> CameraOverlayViewController {
        let controller = CameraOverlayViewController()
        controller.overlayImage = overlayImage
        controller.onCapture = { image in
            capturedImage = image
            dismiss()
        }
        controller.onCancel = {
            dismiss()
        }
        return controller
    }
    
    func updateUIViewController(_ uiViewController: CameraOverlayViewController, context: Context) {}
}

class CameraOverlayViewController: UIViewController, AVCapturePhotoCaptureDelegate {
    var overlayImage: UIImage?
    var onCapture: ((UIImage) -> Void)?
    var onCancel: (() -> Void)?
    
    private var captureSession: AVCaptureSession?
    private var photoOutput: AVCapturePhotoOutput?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var overlayImageView: UIImageView?
    private var opacitySlider: UISlider?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCamera()
        setupOverlay()
        setupControls()
    }
    
    private func setupCamera() {
        captureSession = AVCaptureSession()
        captureSession?.sessionPreset = .photo
        
        guard let captureSession = captureSession,
              let videoCaptureDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) ?? AVCaptureDevice.default(for: .video),
              let videoInput = try? AVCaptureDeviceInput(device: videoCaptureDevice) else {
            return
        }
        
        if captureSession.canAddInput(videoInput) {
            captureSession.addInput(videoInput)
        }
        
        photoOutput = AVCapturePhotoOutput()
        if let photoOutput = photoOutput, captureSession.canAddOutput(photoOutput) {
            captureSession.addOutput(photoOutput)
        }
        
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer?.videoGravity = .resizeAspectFill
        previewLayer?.frame = view.bounds
        
        if let previewLayer = previewLayer {
            view.layer.addSublayer(previewLayer)
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            captureSession.startRunning()
        }
    }
    
    private func setupOverlay() {
        guard let overlayImage = overlayImage else { return }
        
        overlayImageView = UIImageView(image: overlayImage)
        overlayImageView?.contentMode = .scaleAspectFit
        overlayImageView?.frame = view.bounds
        overlayImageView?.alpha = 0.4
        
        if let overlayImageView = overlayImageView {
            view.addSubview(overlayImageView)
        }
    }
    
    private func setupControls() {
        let controlsContainer = UIView()
        controlsContainer.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        controlsContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(controlsContainer)
        
        NSLayoutConstraint.activate([
            controlsContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            controlsContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            controlsContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            controlsContainer.heightAnchor.constraint(equalToConstant: 200)
        ])
        
        let opacityLabel = UILabel()
        opacityLabel.text = "Overlay Opacity"
        opacityLabel.textColor = .white
        opacityLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        opacityLabel.translatesAutoresizingMaskIntoConstraints = false
        controlsContainer.addSubview(opacityLabel)
        
        opacitySlider = UISlider()
        opacitySlider?.minimumValue = 0
        opacitySlider?.maximumValue = 1
        opacitySlider?.value = 0.4
        opacitySlider?.translatesAutoresizingMaskIntoConstraints = false
        opacitySlider?.addTarget(self, action: #selector(opacityChanged), for: .valueChanged)
        
        if let opacitySlider = opacitySlider {
            controlsContainer.addSubview(opacitySlider)
        }
        
        let buttonStack = UIStackView()
        buttonStack.axis = .horizontal
        buttonStack.distribution = .fillEqually
        buttonStack.spacing = 20
        buttonStack.translatesAutoresizingMaskIntoConstraints = false
        controlsContainer.addSubview(buttonStack)
        
        let cancelButton = UIButton(type: .system)
        cancelButton.setTitle("Cancel", for: .normal)
        cancelButton.titleLabel?.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        cancelButton.setTitleColor(.white, for: .normal)
        cancelButton.backgroundColor = UIColor.white.withAlphaComponent(0.2)
        cancelButton.layer.cornerRadius = 12
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        
        let captureButton = UIButton(type: .system)
        captureButton.setTitle("Capture", for: .normal)
        captureButton.titleLabel?.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        captureButton.setTitleColor(.white, for: .normal)
        captureButton.backgroundColor = UIColor(red: 0.6, green: 0.65, blue: 0.62, alpha: 1.0)
        captureButton.layer.cornerRadius = 12
        captureButton.addTarget(self, action: #selector(captureTapped), for: .touchUpInside)
        
        buttonStack.addArrangedSubview(cancelButton)
        buttonStack.addArrangedSubview(captureButton)
        
        NSLayoutConstraint.activate([
            opacityLabel.topAnchor.constraint(equalTo: controlsContainer.topAnchor, constant: 20),
            opacityLabel.centerXAnchor.constraint(equalTo: controlsContainer.centerXAnchor),
            
            opacitySlider!.topAnchor.constraint(equalTo: opacityLabel.bottomAnchor, constant: 12),
            opacitySlider!.leadingAnchor.constraint(equalTo: controlsContainer.leadingAnchor, constant: 40),
            opacitySlider!.trailingAnchor.constraint(equalTo: controlsContainer.trailingAnchor, constant: -40),
            
            buttonStack.leadingAnchor.constraint(equalTo: controlsContainer.leadingAnchor, constant: 20),
            buttonStack.trailingAnchor.constraint(equalTo: controlsContainer.trailingAnchor, constant: -20),
            buttonStack.bottomAnchor.constraint(equalTo: controlsContainer.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            buttonStack.heightAnchor.constraint(equalToConstant: 52)
        ])
    }
    
    @objc private func opacityChanged() {
        overlayImageView?.alpha = CGFloat(opacitySlider?.value ?? 0.4)
    }
    
    @objc private func cancelTapped() {
        onCancel?()
    }
    
    @objc private func captureTapped() {
        let settings = AVCapturePhotoSettings()
        photoOutput?.capturePhoto(with: settings, delegate: self)
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else {
            return
        }
        
        onCapture?(image)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        captureSession?.stopRunning()
    }
}

class ImageCache {
    static let shared = ImageCache()
    private var cache = NSCache<NSString, UIImage>()
    
    private init() {
        cache.countLimit = 20
    }
    
    func setImage(_ image: UIImage, forKey key: String) {
        cache.setObject(image, forKey: key as NSString)
    }
    
    func getImage(forKey key: String) -> UIImage? {
        return cache.object(forKey: key as NSString)
    }
    
    func removeImage(forKey key: String) {
        cache.removeObject(forKey: key as NSString)
    }
    
    func clearCache() {
        cache.removeAllObjects()
    }
}
