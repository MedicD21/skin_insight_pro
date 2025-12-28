import SwiftUI

struct ThemedTextField<Field: Hashable>: View {
    let title: String
    let placeholder: String
    @Binding var text: String

    let field: Field
    @FocusState.Binding var focusedField: Field?

    @ObservedObject var theme: ThemeManager
    var icon: String? = nil
    var keyboardType: UIKeyboardType = .default
    var textContentType: UITextContentType? = nil
    var autocapitalization: UITextAutocapitalizationType = .sentences

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(theme.secondaryText)

            HStack(spacing: icon == nil ? 0 : 12) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 18))
                        .foregroundColor(theme.tertiaryText)
                        .frame(width: 24)
                }

                TextField(placeholder, text: $text)
                    .font(.system(size: 17))
                    .foregroundColor(theme.primaryText)
                    .keyboardType(keyboardType)
                    .textContentType(textContentType)
                    .autocapitalization(autocapitalization)
                    .focused($focusedField, equals: field)
            }
            .padding(16)
            .background(theme.tertiaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: theme.radiusMedium))
            .overlay(
                RoundedRectangle(cornerRadius: theme.radiusMedium)
                    .stroke(
                        focusedField == field
                            ? theme.inputBorderFocused
                            : theme.inputBorder,
                        lineWidth: focusedField == field ? 2 : 1
                    )
                    .animation(theme.easeMedium, value: focusedField)
            )
            .shadow(
                color: focusedField == field
                    ? theme.inputBorderFocused.opacity(0.25)
                    : .clear,
                radius: 6,
                x: 0,
                y: 0
            )
        }
    }
}
