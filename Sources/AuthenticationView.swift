import SwiftUI

struct AuthenticationView: View {
    @ObservedObject var theme = ThemeManager.shared
    @StateObject private var authManager = AuthenticationManager.shared
    @State private var email = ""
    @State private var password = ""
    @State private var isLogin = true
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    @FocusState private var focusedField: Field?
    
    enum Field {
        case email, password
    }
    
    var body: some View {
        ZStack {
            theme.primaryBackground
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 0) {
                    headerSection
                        .padding(.top, 60)
                        .padding(.bottom, 40)
                    
                    formSection
                    
                    guestSection
                        .padding(.top, 32)
                }
                .frame(maxWidth: 450)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 20)
            }
            .scrollDismissesKeyboard(.interactively)
            
            if isLoading {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(theme.accent)
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            Image("logoWithText")
                .resizable()
                .scaledToFit()
                .frame(width: 200)

            Text("Professional Skin Analysis")
                .font(.system(size: 16))
                .foregroundColor(theme.secondaryText)
        }
    }
    
    private var formSection: some View {
        VStack(spacing: 24) {
            VStack(spacing: 16) {
                ThemedTextField(
                    title: "Email",
                    placeholder: "Enter your email",
                    text: $email,
                    field: .email,
                    focusedField: $focusedField,
                    theme: theme,
                    icon: "envelope",
                    keyboardType: .emailAddress,
                    textContentType: .emailAddress,
                    autocapitalization: .none
                )
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Password")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(theme.secondaryText)
                    
                    HStack(spacing: 12) {
                        Image(systemName: "lock")
                            .font(.system(size: 18))
                            .foregroundColor(theme.tertiaryText)
                            .frame(width: 24)
                        
                        SecureField("Enter your password", text: $password)
                            .font(.system(size: 17))
                            .foregroundColor(theme.primaryText)
                            .textContentType(isLogin ? .password : .newPassword)
                            .focused($focusedField, equals: .password)
                    }
                    .padding(16)
                    .background(theme.tertiaryBackground)
                    .clipShape(RoundedRectangle(cornerRadius: theme.radiusMedium))
                    .overlay(
                        RoundedRectangle(cornerRadius: theme.radiusMedium)
                            .stroke(focusedField == .password ? theme.accent : theme.border, lineWidth: focusedField == .password ? 2 : 1)
                    )
                    
                    if !isLogin {
                        Text("Password must contain: At least 6 characters, 1 capital letter, and 1 special character.")
                            .font(.system(size: 12))
                            .foregroundColor(theme.secondaryText)
                            .padding(.top, 4)
                    }
                }
            }
            
            Button(action: handleAuthentication) {
                HStack {
                    Spacer()
                    Text(isLogin ? "Sign In" : "Create Account")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                    Spacer()
                }
                .frame(height: 52)
                .background(theme.accent)
                .clipShape(RoundedRectangle(cornerRadius: theme.radiusMedium))
            }
            .disabled(!isFormValid)
            .opacity(isFormValid ? 1.0 : 0.5)
            
            Button(action: {
                withAnimation(theme.springSnappy) {
                    isLogin.toggle()
                    password = ""
                }
            }) {
                HStack(spacing: 4) {
                    Text(isLogin ? "Don't have an account?" : "Already have an account?")
                        .font(.system(size: 15))
                        .foregroundColor(theme.secondaryText)
                    
                    Text(isLogin ? "Sign Up" : "Sign In")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(theme.accent)
                }
            }
            .padding(.top, 8)
        }
        .padding(.vertical, 32)
        .padding(.horizontal, 24)
        .background(
            RoundedRectangle(cornerRadius: theme.radiusXL)
                .fill(theme.cardBackground)
                .shadow(color: theme.shadowColor, radius: theme.shadowRadiusMedium, x: 0, y: 8)
        )
    }
    
    private var guestSection: some View {
        VStack(spacing: 16) {
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

            SignInWithAppleButton {
                Task {
                    do {
                        try await authManager.signInWithApple()
                    } catch {
                        errorMessage = error.localizedDescription
                        showError = true
                    }
                }
            }

            Button(action: {
                authManager.loginAsGuest()
            }) {
                HStack {
                    Spacer()
                    Image(systemName: "person.fill")
                    Text("Continue as Guest")
                    Spacer()
                }
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(theme.primaryText)
                .frame(height: 52)
                .background(theme.tertiaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: theme.radiusMedium))
                .overlay(
                    RoundedRectangle(cornerRadius: theme.radiusMedium)
                        .stroke(theme.border, lineWidth: 1)
                )
            }
            
            Text("Guest mode allows you to explore the app. Your data will be stored locally.")
                .font(.system(size: 13))
                .foregroundColor(theme.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
    }
    
    private var isFormValid: Bool {
        !email.isEmpty && !password.isEmpty && email.contains("@") && (!isLogin ? isPasswordValid : true)
    }
    
    private var isPasswordValid: Bool {
        let hasMinLength = password.count >= 6
        let hasCapital = password.range(of: "[A-Z]", options: .regularExpression) != nil
        let hasSpecial = password.range(of: "[!@#$%^&*(),.?\":{}|<>]", options: .regularExpression) != nil
        return hasMinLength && hasCapital && hasSpecial
    }
    
    private func handleAuthentication() {
        focusedField = nil
        isLoading = true
        
        Task {
            do {
                if isLogin {
                    try await authManager.login(email: email, password: password)
                } else {
                    try await authManager.createAccount(email: email, password: password)
                }
            } catch is CancellationError {
                return
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
            isLoading = false
        }
    }
}
