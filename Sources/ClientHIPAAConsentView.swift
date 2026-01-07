import SwiftUI
import UIKit

struct ClientHIPAAConsentView: View {
    @ObservedObject var theme = ThemeManager.shared
    @StateObject private var authManager = AuthenticationManager.shared
    @Environment(\.dismiss) var dismiss

    let client: AppClient
    var onConsent: (String) -> Void // Pass back signature data URL

    @State private var hasReadNotice = false
    @State private var agreedToTreatment = false
    @State private var agreedToPhotos = false
    @State private var showSignaturePad = false
    @State private var signatureImage: UIImage?
    @State private var showError = false
    @State private var errorMessage = ""

    // Skip signature when running in the simulator to speed up testing
    private var signatureRequired: Bool {
        #if targetEnvironment(simulator)
        return false
        #else
        return true
        #endif
    }

    var body: some View {
        NavigationStack {
            ZStack {
                theme.primaryBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        headerSection

                        noticeOfPrivacyPractices

                        consentCheckboxes

                        signatureSection

                        continueButton
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 20)
                }
            }
            .navigationTitle("Client Consent")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .fullScreenCover(isPresented: $showSignaturePad) {
                SignatureCaptureView(signatureImage: $signatureImage)
                    .interactiveDismissDisabled()
            }
        }
    }

    private var headerSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.fill")
                .font(.system(size: 50))
                .foregroundColor(theme.accent)

            if client.hasExpiredConsent {
                Text("Renew Consent for Treatment")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(theme.primaryText)
            } else {
                Text("Consent for Treatment")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(theme.primaryText)
            }

            Text("Client: \(client.firstName ?? "") \(client.lastName ?? "")")
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(theme.secondaryText)

            if client.hasExpiredConsent {
                VStack(spacing: 8) {
                    Text("Your previous consent has expired. Please review and sign to renew authorization for skin analysis and photography")
                        .font(.system(size: 15))
                        .foregroundColor(theme.secondaryText)
                        .multilineTextAlignment(.center)

                    if let expirationDate = client.consentExpirationDate {
                        Text("Previous consent expired on \(expirationDate.formatted(date: .abbreviated, time: .omitted))")
                            .font(.system(size: 13))
                            .foregroundColor(Color(red: 1.0, green: 0.6, blue: 0.0))
                            .multilineTextAlignment(.center)
                    }
                }
            } else {
                Text("Please review and sign to authorize skin analysis and photography")
                    .font(.system(size: 15))
                    .foregroundColor(theme.secondaryText)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var noticeOfPrivacyPractices: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("NOTICE OF PRIVACY PRACTICES")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(theme.primaryText)

            VStack(alignment: .leading, spacing: 12) {
                noticeSection(
                    title: "Effective Date",
                    content: "This notice is effective as of \(Date().formatted(date: .long, time: .omitted))."
                )

                noticeSection(
                    title: "Your Health Information Rights",
                    content: """
                    You have the right to:
                    • Inspect and copy your health information
                    • Request corrections to your health information
                    • Receive a copy of this privacy notice
                    • Request restrictions on certain uses of your information
                    • Request confidential communications
                    • File a complaint if you believe your privacy rights have been violated
                    """
                )

                noticeSection(
                    title: "How We Use Your Information",
                    content: """
                    ###\(authManager.currentUser?.companyId ?? "Our practice") will use your health information to:
                    • Provide skin analysis and treatment recommendations
                    • Document your care in our records
                    • Track treatment progress over time
                    • Communicate with you about your care

                    Provider: \(authManager.currentUser?.firstName ?? "") \(authManager.currentUser?.lastName ?? "")
                    """
                )

                noticeSection(
                    title: "Photography Consent",
                    content: """
                    We request permission to take photographs of your skin for:
                    • Clinical documentation and analysis
                    • Tracking treatment progress
                    • Before and after comparisons

                    Your photographs will be:
                    • Stored securely and encrypted
                    • Only accessible to authorized staff
                    • Never shared without your explicit consent
                    • Deleted upon request at any time
                    """
                )

                noticeSection(
                    title: "Data Security",
                    content: """
                    We protect your information by:
                    • Encrypting all data in transit and at rest
                    • Limiting access to authorized personnel only
                    • Using secure authentication
                    • Maintaining comprehensive audit logs
                    • Following HIPAA security standards
                    """
                )

                noticeSection(
                    title: "Your Right to Revoke",
                    content: "You may revoke this consent at any time by providing written notice. Revocation will not affect any actions taken before we receive your notice."
                )

                noticeSection(
                    title: "Questions or Complaints",
                    content: """
                    If you have questions about this notice or wish to file a complaint:
                    ###Contact: \(authManager.currentUser?.email ?? "your provider")

                    You may also file a complaint with the U.S. Department of Health and Human Services if you believe your privacy rights have been violated.
                    """
                )
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: theme.radiusXL)
                .fill(theme.cardBackground)
                .shadow(color: theme.shadowColor, radius: theme.shadowRadiusMedium, x: 0, y: 8)
        )
    }

    private func noticeSection(title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(theme.primaryText)

            Text(content)
                .font(.system(size: 14))
                .foregroundColor(theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var companyDisplayName: String {
        let trimmedName = authManager.currentUser?.companyName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmedName.isEmpty {
            return trimmedName
        }
        if let companyId = authManager.currentUser?.companyId, !companyId.isEmpty {
            return companyId
        }
        let providerName = [
            authManager.currentUser?.firstName?.trimmingCharacters(in: .whitespacesAndNewlines),
            authManager.currentUser?.lastName?.trimmingCharacters(in: .whitespacesAndNewlines)
        ]
        .compactMap { $0 }
        .filter { !$0.isEmpty }
        .joined(separator: " ")

        return providerName.isEmpty ? "this provider" : providerName
    }

    private var consentCheckboxes: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("ACKNOWLEDGMENTS")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(theme.primaryText)

            Button(action: { hasReadNotice.toggle() }) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: hasReadNotice ? "checkmark.square.fill" : "square")
                        .font(.system(size: 24))
                        .foregroundColor(hasReadNotice ? theme.accent : theme.secondaryText)

                    Text("I have received and read the Notice of Privacy Practices and understand my rights")
                        .font(.system(size: 15))
                        .foregroundColor(theme.primaryText)
                        .multilineTextAlignment(.leading)

                    Spacer()
                }
            }

            Divider()

            Button(action: { agreedToTreatment.toggle() }) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: agreedToTreatment ? "checkmark.square.fill" : "square")
                        .font(.system(size: 24))
                        .foregroundColor(agreedToTreatment ? theme.accent : theme.secondaryText)

                    Text("I consent to skin analysis and treatment by \(companyDisplayName)")
                        .font(.system(size: 15))
                        .foregroundColor(theme.primaryText)
                        .multilineTextAlignment(.leading)

                    Spacer()
                }
            }

            Divider()

            Button(action: { agreedToPhotos.toggle() }) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: agreedToPhotos ? "checkmark.square.fill" : "square")
                        .font(.system(size: 24))
                        .foregroundColor(agreedToPhotos ? theme.accent : theme.secondaryText)

                    Text("I consent to photography of my skin for clinical documentation and treatment tracking")
                        .font(.system(size: 15))
                        .foregroundColor(theme.primaryText)
                        .multilineTextAlignment(.leading)

                    Spacer()
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: theme.radiusXL)
                .fill(theme.cardBackground)
                .shadow(color: theme.shadowColor, radius: theme.shadowRadiusMedium, x: 0, y: 8)
        )
    }

    private var signatureSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("SIGNATURE")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(theme.primaryText)

            if let signature = signatureImage {
                // Show captured signature
                VStack(spacing: 12) {
                    Image(uiImage: signature)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 100)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: theme.radiusMedium))

                    HStack {
                        Text("Signed by: \(client.firstName ?? "") \(client.lastName ?? "")")
                            .font(.system(size: 13))
                            .foregroundColor(theme.secondaryText)

                        Spacer()

                        Text(Date().formatted(date: .abbreviated, time: .shortened))
                            .font(.system(size: 13))
                            .foregroundColor(theme.secondaryText)
                    }

                    Button(action: {
                        self.signatureImage = nil
                        showSignaturePad = true
                    }) {
                        Text("Re-sign")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(theme.accent)
                    }
                }
            } else {
                // Show button to open signature pad
                Button(action: {
                    showSignaturePad = true
                }) {
                    VStack(spacing: 12) {
                        Image(systemName: "pencil.tip.crop.circle")
                            .font(.system(size: 50))
                            .foregroundColor(theme.accent)

                        Text("Tap to Sign")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(theme.primaryText)

                        Text("Please provide your signature")
                            .font(.system(size: 14))
                            .foregroundColor(theme.secondaryText)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 150)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: theme.radiusMedium))
                    .overlay(
                        RoundedRectangle(cornerRadius: theme.radiusMedium)
                            .stroke(theme.accent.opacity(0.3), lineWidth: 2)
                            .overlay(
                                RoundedRectangle(cornerRadius: theme.radiusMedium)
                                    .stroke(theme.accent.opacity(0.1), lineWidth: 4)
                            )
                    )
                }

                if !signatureRequired {
                    Text("Simulator mode: signature is optional. A placeholder will be used.")
                        .font(.system(size: 12))
                        .foregroundColor(theme.secondaryText)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 8)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: theme.radiusXL)
                .fill(theme.cardBackground)
                .shadow(color: theme.shadowColor, radius: theme.shadowRadiusMedium, x: 0, y: 8)
        )
    }

    private var continueButton: some View {
        Button(action: handleConsent) {
            HStack {
                Image(systemName: "checkmark.seal.fill")
                Text("Submit Consent")
            }
            .font(.system(size: 17, weight: .semibold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(16)
            .background(canSubmit ? theme.accent : Color.gray)
            .clipShape(RoundedRectangle(cornerRadius: theme.radiusMedium))
        }
        .disabled(!canSubmit)
    }

    private var canSubmit: Bool {
        hasReadNotice && agreedToTreatment && agreedToPhotos && (signatureImage != nil || !signatureRequired)
    }

    private func handleConsent() {
        var signatureBase64 = ""

        if let signature = signatureImage, let signatureData = signature.pngData() {
            // Convert to base64 for storage
            signatureBase64 = signatureData.base64EncodedString()
        } else if signatureRequired {
            errorMessage = "Invalid signature"
            showError = true
            return
        } else {
            // Simulator shortcut to allow testing without drawing
            signatureBase64 = "SIMULATOR_TEST_SIGNATURE"
        }

        // Log consent
        if let userId = authManager.currentUser?.id,
           let email = authManager.currentUser?.email {
            HIPAAComplianceManager.shared.logEvent(
                eventType: .clientCreated,
                userId: userId,
                userEmail: email,
                resourceType: "CLIENT_CONSENT",
                resourceId: client.id
            )
        }

        onConsent(signatureBase64)
        dismiss()
    }
}

// MARK: - Signature Capture View
struct SignatureCaptureView: View {
    @ObservedObject var theme = ThemeManager.shared
    @Environment(\.dismiss) var dismiss
    @Binding var signatureImage: UIImage?

    @State private var strokes: [SignatureStroke] = []
    @State private var currentStroke: [CGPoint] = []

    private let captureSize = CGSize(width: UIScreen.main.bounds.width - 32, height: 320)

    var body: some View {
        NavigationStack {
            ZStack {
                Color.white
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    Text("Sign below")
                        .font(.system(size: 16))
                        .foregroundColor(.gray)
                        .padding(.top, 20)

                    SignaturePadView(
                        strokes: $strokes,
                        currentStroke: $currentStroke,
                        lineWidth: 3,
                        lineColor: .black
                    )
                    .frame(width: captureSize.width, height: captureSize.height)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                    .padding(.horizontal, 16)

                    HStack(spacing: 16) {
                        Button(action: clearSignature) {
                            HStack {
                                Image(systemName: "arrow.counterclockwise")
                                Text("Clear")
                            }
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(theme.accent)
                            .frame(maxWidth: .infinity)
                            .padding(14)
                            .background(theme.accent.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }

                        Button(action: saveSignature) {
                            HStack {
                                Image(systemName: "checkmark")
                                Text("Done")
                            }
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(14)
                            .background(theme.accent)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Sign Here")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func clearSignature() {
        strokes = []
        currentStroke = []
    }

    private func saveSignature() {
        let image = renderSignatureImage()
        if let image, image.size.width > 1 && image.size.height > 1 {
            signatureImage = image
            dismiss()
        }
    }

    private func renderSignatureImage() -> UIImage? {
        if !currentStroke.isEmpty {
            strokes.append(SignatureStroke(points: currentStroke))
            currentStroke = []
        }
        let allStrokes = strokes
        guard !allStrokes.isEmpty else { return nil }

        let renderer = UIGraphicsImageRenderer(size: captureSize)
        let img = renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: captureSize))

            let path = UIBezierPath()
            path.lineWidth = 3
            path.lineCapStyle = .round
            UIColor.black.setStroke()

            for stroke in allStrokes {
                guard let first = stroke.points.first else { continue }
                path.move(to: first)
                for point in stroke.points.dropFirst() {
                    path.addLine(to: point)
                }
            }
            path.stroke()
        }
        return img
    }
}


// MARK: - SwiftUI Signature Pad
struct SignatureStroke: Identifiable {
    let id = UUID()
    var points: [CGPoint]
}

struct SignaturePadView: View {
    @Binding var strokes: [SignatureStroke]
    @Binding var currentStroke: [CGPoint]
    var lineWidth: CGFloat
    var lineColor: Color

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            ZStack {
                Color.white
                Path { path in
                    for stroke in strokes {
                        guard let first = stroke.points.first else { continue }
                        path.move(to: first)
                        for point in stroke.points.dropFirst() {
                            path.addLine(to: point)
                        }
                    }
                    if let first = currentStroke.first {
                        path.move(to: first)
                        for point in currentStroke.dropFirst() {
                            path.addLine(to: point)
                        }
                    }
                }
                .stroke(lineColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let point = value.location
                        guard point.x >= 0, point.y >= 0, point.x <= size.width, point.y <= size.height else { return }
                        currentStroke.append(point)
                    }
                    .onEnded { _ in
                        if !currentStroke.isEmpty {
                            strokes.append(SignatureStroke(points: currentStroke))
                            currentStroke = []
                        }
                    }
            )
        }
    }
}
