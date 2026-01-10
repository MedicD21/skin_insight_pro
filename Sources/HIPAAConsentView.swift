import SwiftUI

struct HIPAAConsentView: View {
    @ObservedObject var theme = ThemeManager.shared
    @StateObject private var complianceManager = HIPAAComplianceManager.shared

    @State private var hasReadNotice = false
    @State private var agreedToTerms = false
    @State private var agreedToPrivacy = false
    @State private var showingFullNotice = false

    var onConsent: () -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                theme.primaryBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        headerSection

                        noticeSection

                        consentCheckboxes

                        continueButton
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 20)
                }
            }
            .navigationTitle("Terms & Privacy")
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled()
            .sheet(isPresented: $showingFullNotice) {
                FullHIPAANoticeView()
            }
        }
    }

    private var headerSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 60))
                .foregroundColor(theme.accent)

            Text("Terms & Privacy")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(theme.primaryText)

            Text("Please review and accept our terms to continue")
                .font(.system(size: 15))
                .foregroundColor(theme.secondaryText)
                .multilineTextAlignment(.center)
        }
        .padding(.bottom, 8)
    }

    private var noticeSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("What We Collect & How We Protect It")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(theme.primaryText)

            VStack(alignment: .leading, spacing: 12) {
                PrivacyPointView(
                    icon: "person.circle.fill",
                    title: "Your Account Data",
                    description: "We collect your name, email, role, company information, and profile photo to provide you with access to the app."
                )

                PrivacyPointView(
                    icon: "doc.text.fill",
                    title: "Client Records You Create",
                    description: "You create and store client records including skin analysis data, photos, and personal information. This data belongs to you and your company."
                )

                PrivacyPointView(
                    icon: "lock.fill",
                    title: "Enterprise-Grade Security",
                    description: "All data is encrypted in transit and at rest. Optional Face ID/Touch ID authentication adds an extra layer of protection."
                )

                PrivacyPointView(
                    icon: "clock.fill",
                    title: "HIPAA Compliance Features",
                    description: "Automatic 15-minute session timeout, comprehensive audit logging, and role-based access controls help you meet compliance requirements."
                )

                PrivacyPointView(
                    icon: "dollarsign.circle.fill",
                    title: "Subscription Management",
                    description: "Subscriptions are managed through Apple's App Store. We never see or store your payment information."
                )
            }

            Button(action: { showingFullNotice = true }) {
                HStack {
                    Text("Read Full Privacy Policy")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(theme.accent)
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 13))
                        .foregroundColor(theme.accent)
                }
                .padding(12)
                .frame(maxWidth: .infinity)
                .background(theme.accent.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: theme.radiusMedium))
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: theme.radiusXL)
                .fill(theme.cardBackground)
                .shadow(color: theme.shadowColor, radius: theme.shadowRadiusSmall, x: 0, y: 4)
        )
    }

    private var consentCheckboxes: some View {
        VStack(alignment: .leading, spacing: 16) {
            Button(action: { agreedToTerms.toggle() }) {
                HStack(spacing: 12) {
                    Image(systemName: agreedToTerms ? "checkmark.square.fill" : "square")
                        .font(.system(size: 24))
                        .foregroundColor(agreedToTerms ? theme.accent : theme.secondaryText)

                    Text("I agree to the Terms of Service")
                        .font(.system(size: 15))
                        .foregroundColor(theme.primaryText)
                        .multilineTextAlignment(.leading)

                    Spacer()
                }
            }

            Button(action: { agreedToPrivacy.toggle() }) {
                HStack(spacing: 12) {
                    Image(systemName: agreedToPrivacy ? "checkmark.square.fill" : "square")
                        .font(.system(size: 24))
                        .foregroundColor(agreedToPrivacy ? theme.accent : theme.secondaryText)

                    Text("I acknowledge the Privacy Policy and consent to data collection as described")
                        .font(.system(size: 15))
                        .foregroundColor(theme.primaryText)
                        .multilineTextAlignment(.leading)

                    Spacer()
                }
            }

            Button(action: { hasReadNotice.toggle() }) {
                HStack(spacing: 12) {
                    Image(systemName: hasReadNotice ? "checkmark.square.fill" : "square")
                        .font(.system(size: 24))
                        .foregroundColor(hasReadNotice ? theme.accent : theme.secondaryText)

                    Text("I understand this app includes HIPAA compliance features and I am responsible for ensuring my use complies with regulations")
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
                .shadow(color: theme.shadowColor, radius: theme.shadowRadiusSmall, x: 0, y: 4)
        )
    }

    private var continueButton: some View {
        Button(action: handleConsent) {
            HStack {
                Image(systemName: "checkmark.shield.fill")
                Text("Accept and Continue")
            }
            .font(.system(size: 17, weight: .semibold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(16)
            .background(canContinue ? theme.accent : Color.gray)
            .clipShape(RoundedRectangle(cornerRadius: theme.radiusMedium))
        }
        .disabled(!canContinue)
    }

    private var canContinue: Bool {
        agreedToTerms && agreedToPrivacy && hasReadNotice
    }

    private func handleConsent() {
        complianceManager.recordConsent()

        // Log consent event
        if let userId = AuthenticationManager.shared.currentUser?.id,
           let email = AuthenticationManager.shared.currentUser?.email {
            complianceManager.logEvent(
                eventType: .userLogin,
                userId: userId,
                userEmail: email,
                resourceType: "CONSENT"
            )
        }

        onConsent()
    }
}

struct PrivacyPointView: View {
    @ObservedObject var theme = ThemeManager.shared
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(theme.accent)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(theme.primaryText)

                Text(description)
                    .font(.system(size: 14))
                    .foregroundColor(theme.secondaryText)
            }
        }
    }
}

struct FullHIPAANoticeView: View {
    @ObservedObject var theme = ThemeManager.shared
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                theme.primaryBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("NOTICE OF PRIVACY PRACTICES")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(theme.primaryText)

                        Group {
                            sectionHeader("Effective Date")
                            sectionText("This notice is effective as of \(Date().formatted(date: .long, time: .omitted)).")

                            sectionHeader("This Notice Describes How Information About You May Be Used and Disclosed")
                            sectionText("Skin Insight Pro is committed to protecting your health information. This notice describes our privacy practices and your rights regarding your information.")

                            sectionHeader("How We Use Your Information")
                            sectionText("We collect and use your health information to:\n\n• Provide skin analysis and treatment recommendations\n• Coordinate care between team members\n• Improve our services and technology\n• Comply with legal and regulatory requirements")

                            sectionHeader("Information We Collect")
                            sectionText("• Personal information (name, contact details)\n• Skin analysis images and results\n• Treatment history and notes\n• Account and authentication data")

                            sectionHeader("How We Protect Your Information")
                            sectionText("• Encryption of all data in transit and at rest\n• Secure authentication and session management\n• Automatic session timeout after 15 minutes\n• Comprehensive audit logging of all access\n• Regular security assessments")

                            sectionHeader("Your Rights")
                            sectionText("You have the right to:\n\n• Access and review your information\n• Request corrections to your information\n• Receive a copy of your information (data export)\n• Request deletion of your information\n• Revoke consent at any time\n• Receive notification of data breaches")

                            sectionHeader("Data Retention")
                            sectionText("We retain your information as long as necessary to provide services and comply with legal obligations. You may request deletion at any time through your profile settings.")

                            sectionHeader("Contact Us")
                            sectionText("If you have questions about this notice or your privacy rights, please contact us through the app's support page.")
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Privacy Notice")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 16, weight: .bold))
            .foregroundColor(theme.primaryText)
            .padding(.top, 8)
    }

    private func sectionText(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 14))
            .foregroundColor(theme.secondaryText)
    }
}
