import SwiftUI

final class ThemeManager: ObservableObject {
    static let shared = ThemeManager()
    
    private init() {}
    
    var primaryBackground: Color {
        Color(light: Color(hex: "F8F9FA"), dark: Color(hex: "000000"))
    }
    
    var secondaryBackground: Color {
        Color(light: Color(hex: "FFFFFF"), dark: Color(hex: "1C1C1E"))
    }
    
    var tertiaryBackground: Color {
        Color(light: Color(hex: "F0F0F0"), dark: Color(hex: "2C2C2E"))
    }
    
    var cardBackground: Color {
        Color(light: Color(hex: "FFFFFF"), dark: Color(hex: "1C1C1E"))
    }
    
    var primaryText: Color {
        Color(light: Color(hex: "1A1A1A"), dark: Color(hex: "F5F5F7"))
    }
    
    var secondaryText: Color {
        Color(light: Color(hex: "6B7280"), dark: Color(hex: "A1A1A6"))
    }
    
    var tertiaryText: Color {
        Color(light: Color(hex: "9CA3AF"), dark: Color(hex: "636366"))
    }
    
    var accent: Color {
        Color(light: Color(hex: "9AA79D"), dark: Color(hex: "9AA79D"))
    }
    
    var accentSubtle: Color {
        Color(light: Color(hex: "C3CEC6"), dark: Color(hex: "C3CEC6"))
    }
    
    var border: Color {
        Color(light: Color(hex: "E5E7EB"), dark: Color(hex: "38383A"))
    }
    
    var cardBorder: Color {
        Color(light: Color(hex: "E5E7EB"), dark: Color(hex: "38383A"))
    }
    
    var shadowColor: Color {
        Color(light: Color.black.opacity(0.08), dark: Color.black.opacity(0.3))
    }
    
    var error: Color {
        Color(light: Color(hex: "EF4444"), dark: Color(hex: "FF6B6B"))
    }
    
    var success: Color {
        Color(light: Color(hex: "10B981"), dark: Color(hex: "51CF66"))
    }
    
    var warning: Color {
        Color(light: Color(hex: "F59E0B"), dark: Color(hex: "FFD43B"))
    }
  
  // MARK: - Input Borders

    var inputBorder: Color {
        Color(
            light: Color.black.opacity(0.12),
            dark: Color.white.opacity(0.12)
        )
    }

    var inputBorderFocused: Color {
        accent
    }

    var inputBorderSubtle: Color {
        Color(
            light: Color.black.opacity(0.06),
            dark: Color.white.opacity(0.06)
        )
    }

    
    var buttonPrimary: Color { accent }
    var buttonSecondary: Color { tertiaryBackground }
    var buttonDestructive: Color { error }
    var tint: Color { accent }
    var link: Color { accent }
    
    var navBarBackground: Color { cardBackground }
    var navBarTitle: Color { primaryText }
    var navBarTint: Color { accent }
    var tabBarBackground: Color { cardBackground }
    var tabBarSelected: Color { accent }
    var tabBarUnselected: Color { tertiaryText }
    
    let radiusSmall: CGFloat = 8
    let radiusMedium: CGFloat = 12
    let radiusLarge: CGFloat = 16
    let radiusXL: CGFloat = 20
    let radiusFull: CGFloat = 100
    
    let spacingXS: CGFloat = 4
    let spacingS: CGFloat = 8
    let spacingM: CGFloat = 12
    let spacingL: CGFloat = 16
    let spacingXL: CGFloat = 20
    let spacingXXL: CGFloat = 24
    let spacingSection: CGFloat = 32
    
    let shadowRadiusSmall: CGFloat = 8
    let shadowRadiusMedium: CGFloat = 16
    let shadowRadiusLarge: CGFloat = 24
    
    var springSnappy: Animation {
        .spring(response: 0.3, dampingFraction: 0.7)
    }
    
    var springSmooth: Animation {
        .spring(response: 0.5, dampingFraction: 0.8)
    }
    
    var springBouncy: Animation {
        .spring(response: 0.4, dampingFraction: 0.6)
    }
    
    var easeQuick: Animation {
        .easeOut(duration: 0.2)
    }
    
    var easeMedium: Animation {
        .easeInOut(duration: 0.3)
    }
}

extension Color {
    init(light: Color, dark: Color) {
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
    }
    
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b, a: UInt64
        switch hex.count {
        case 6: (r, g, b, a) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF, 255)
        case 8: (r, g, b, a) = ((int >> 24) & 0xFF, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default: (r, g, b, a) = (0, 0, 0, 255)
        }
        self.init(.sRGB, red: Double(r)/255, green: Double(g)/255, blue: Double(b)/255, opacity: Double(a)/255)
    }
}
