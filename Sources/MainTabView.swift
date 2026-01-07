import SwiftUI

struct MainTabView: View {
    @ObservedObject var theme = ThemeManager.shared
    @State private var selectedTab = 0
    @Environment(\.horizontalSizeClass) var horizontalSizeClass

    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                // iPad layout with sidebar
                NavigationSplitView {
                    List {
                        Button {
                            selectedTab = 0
                        } label: {
                            HStack {
                                Label("Clients", systemImage: "person.2")
                                    .foregroundColor(selectedTab == 0 ? theme.accent : theme.primaryText)
                                Spacer()
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(selectedTab == 0 ? theme.accent.opacity(0.1) : Color.clear)

                        Button {
                            selectedTab = 1
                        } label: {
                            HStack {
                                Label("Profile", systemImage: "person.circle")
                                    .foregroundColor(selectedTab == 1 ? theme.accent : theme.primaryText)
                                Spacer()
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(selectedTab == 1 ? theme.accent.opacity(0.1) : Color.clear)
                    }
                    .listStyle(.sidebar)
                    .navigationTitle("Menu")
                } detail: {
                    Group {
                        switch selectedTab {
                        case 1:
                            NavigationStack {
                                ProfileView()
                            }
                        default:
                            ClientDashboardView()
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                // iPhone layout with tabs
                TabView(selection: $selectedTab) {
                    ClientDashboardView()
                        .tabItem {
                            Label("Clients", systemImage: "person.2")
                        }
                        .tag(0)

                    NavigationStack {
                        ProfileView()
                    }
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
