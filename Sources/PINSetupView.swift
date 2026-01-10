import SwiftUI

struct PINSetupView: View {
    @ObservedObject var theme = ThemeManager.shared
    let userId: String
    let onComplete: () -> Void

    @State private var pin = ""
    @State private var confirmPin = ""
    @State private var isConfirming = false
    @State private var showError = false
    @State private var errorMessage = ""
    @FocusState private var isPINFocused: Bool

    var body: some View {
        ZStack {
            theme.primaryBackground
                .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                VStack(spacing: 16) {
                    Image(systemName: "lock.shield")
                        .font(.system(size: 60))
                        .foregroundColor(theme.accent)

                    Text(isConfirming ? "Confirm Your PIN" : "Create a 4-Digit PIN")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(theme.primaryText)

                    Text(isConfirming ? "Enter your PIN again to confirm" : "This PIN will be used for quick login on this device")
                        .font(.system(size: 15))
                        .foregroundColor(theme.secondaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                // PIN Display
                HStack(spacing: 20) {
                    ForEach(0..<4, id: \.self) { index in
                        Circle()
                            .fill(currentPIN.count > index ? theme.accent : theme.tertiaryBackground)
                            .frame(width: 20, height: 20)
                            .overlay(
                                Circle()
                                    .stroke(theme.border, lineWidth: 2)
                            )
                    }
                }
                .padding(.vertical, 24)

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

                Spacer()

                Button(action: skip) {
                    Text("Skip for Now")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(theme.secondaryText)
                }
                .padding(.bottom, 32)
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {
                // Reset on error
                pin = ""
                confirmPin = ""
                isConfirming = false
            }
        } message: {
            Text(errorMessage)
        }
    }

    private var currentPIN: String {
        isConfirming ? confirmPin : pin
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
        if isConfirming {
            guard confirmPin.count < 4 else { return }
            confirmPin += "\(digit)"

            if confirmPin.count == 4 {
                // Check if PINs match
                if pin == confirmPin {
                    savePIN()
                } else {
                    errorMessage = "PINs do not match. Please try again."
                    showError = true
                }
            }
        } else {
            guard pin.count < 4 else { return }
            pin += "\(digit)"

            if pin.count == 4 {
                // Move to confirmation
                isConfirming = true
            }
        }
    }

    private func deleteDigit() {
        if isConfirming {
            if !confirmPin.isEmpty {
                confirmPin.removeLast()
            }
        } else {
            if !pin.isEmpty {
                pin.removeLast()
            }
        }
    }

    private func savePIN() {
        let success = DeviceLoginManager.shared.savePIN(pin, for: userId)

        if success {
            onComplete()
        } else {
            errorMessage = "Failed to save PIN. Please try again."
            showError = true
        }
    }

    private func skip() {
        onComplete()
    }
}
