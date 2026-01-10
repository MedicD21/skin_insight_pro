import SwiftUI

struct PINEntryView: View {
    @ObservedObject var theme = ThemeManager.shared
    let userProfile: UserProfile
    let onSuccess: () -> Void
    let onCancel: () -> Void

    @State private var pin = ""
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var attempts = 0
    private let maxAttempts = 3

    var body: some View {
        ZStack {
            theme.primaryBackground
                .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // User Profile
                VStack(spacing: 16) {
                    if let imageUrl = userProfile.profileImageUrl, let url = URL(string: imageUrl) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                            case .empty, .failure:
                                Text(userProfile.initials)
                                    .font(.system(size: 32, weight: .semibold))
                                    .foregroundColor(.white)
                            @unknown default:
                                EmptyView()
                            }
                        }
                        .frame(width: 80, height: 80)
                        .background(theme.accent)
                        .clipShape(Circle())
                    } else {
                        Text(userProfile.initials)
                            .font(.system(size: 32, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 80, height: 80)
                            .background(theme.accent)
                            .clipShape(Circle())
                    }

                    Text(userProfile.name ?? userProfile.email)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(theme.primaryText)

                    Text("Enter PIN")
                        .font(.system(size: 15))
                        .foregroundColor(theme.secondaryText)
                }

                // PIN Display
                HStack(spacing: 20) {
                    ForEach(0..<4, id: \.self) { index in
                        Circle()
                            .fill(pin.count > index ? theme.accent : theme.tertiaryBackground)
                            .frame(width: 20, height: 20)
                            .overlay(
                                Circle()
                                    .stroke(showError ? theme.error : theme.border, lineWidth: 2)
                            )
                    }
                }
                .padding(.vertical, 24)
                .animation(.easeInOut(duration: 0.2), value: showError)

                // Number Pad
                VStack(spacing: 16) {
                    ForEach(0..<3) { row in
                        HStack(spacing: 16) {
                            ForEach(1...3, id: \.self) { col in
                                let number = row * 3 + col
                                numberButton(number)
                            }
                        }
                    }

                    HStack(spacing: 16) {
                        // Empty space
                        Color.clear
                            .frame(width: 80, height: 80)

                        numberButton(0)

                        // Delete button
                        Button(action: deleteDigit) {
                            Image(systemName: "delete.left")
                                .font(.system(size: 24))
                                .foregroundColor(theme.primaryText)
                                .frame(width: 80, height: 80)
                                .background(theme.secondaryBackground)
                                .clipShape(Circle())
                        }
                    }
                }

                if showError {
                    Text(errorMessage)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(theme.error)
                        .padding(.horizontal, 32)
                        .multilineTextAlignment(.center)
                }

                Spacer()

                Button(action: onCancel) {
                    Text("Use Different Account")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(theme.secondaryText)
                }
                .padding(.bottom, 32)
            }
        }
    }

    private func numberButton(_ number: Int) -> some View {
        Button(action: { addDigit(number) }) {
            Text("\(number)")
                .font(.system(size: 28, weight: .medium))
                .foregroundColor(theme.primaryText)
                .frame(width: 80, height: 80)
                .background(theme.secondaryBackground)
                .clipShape(Circle())
        }
    }

    private func addDigit(_ digit: Int) {
        guard pin.count < 4 else { return }
        pin += "\(digit)"

        if pin.count == 4 {
            // Verify PIN
            verifyPIN()
        }
    }

    private func deleteDigit() {
        if !pin.isEmpty {
            pin.removeLast()
            showError = false
        }
    }

    private func verifyPIN() {
        let isValid = DeviceLoginManager.shared.verifyPIN(pin, for: userProfile.id)

        if isValid {
            onSuccess()
        } else {
            attempts += 1

            if attempts >= maxAttempts {
                errorMessage = "Too many attempts. Please sign in with your password."
                showError = true

                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    onCancel()
                }
            } else {
                errorMessage = "Incorrect PIN. \(maxAttempts - attempts) attempt(s) remaining."
                showError = true
                pin = ""

                // Shake animation
                withAnimation(.easeInOut(duration: 0.1).repeatCount(3, autoreverses: true)) {
                    showError = true
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    showError = false
                }
            }
        }
    }
}
