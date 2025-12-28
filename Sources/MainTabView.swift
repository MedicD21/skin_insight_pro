import SwiftUI

struct MainTabView: View {
    @ObservedObject var theme = ThemeManager.shared
    @State private var selectedTab = 0
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                ClientDashboardView()
            } else {
                TabView(selection: $selectedTab) {
                    ClientDashboardView()
                        .tabItem {
                            Label("Clients", systemImage: "person.2")
                        }
                        .tag(0)
                    
                    ProfileView()
                        .tabItem {
                            Label("Profile", systemImage: "person.circle")
                        }
                        .tag(1)
                }
                .tint(theme.accent)
            }
        }
    }
}