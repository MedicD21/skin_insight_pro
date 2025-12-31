import SwiftUI

struct SplashScreen: View {
    @ObservedObject var theme = ThemeManager.shared
    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Image("logoWithText")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 250)
                    .scaleEffect(scale)
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