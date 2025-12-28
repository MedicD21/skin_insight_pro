import SwiftUI

struct SplashScreen: View {
    @ObservedObject var theme = ThemeManager.shared
    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0
    
    var body: some View {
        ZStack {
            theme.accent
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                Image(systemName: "sparkles")
                    .font(.system(size: 80, weight: .light))
                    .foregroundColor(.white)
                    .scaleEffect(scale)
                    .opacity(opacity)
                
                Text("Skin Insight Pro")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .opacity(opacity)
                
                Text("AI-Powered Skin Analysis")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
                    .opacity(opacity)
            }
        }
        .onAppear {
            withAnimation(theme.springSmooth) {
                scale = 1.0
                opacity = 1.0
            }
        }
    }
}