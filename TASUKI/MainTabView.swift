import SwiftUI

struct MainTabView: View {
    @State private var selectedTab: Int = 0
    @State private var previousTabIndex: Int = 0
    @State private var tabEnterDate: Date = Date()
    @EnvironmentObject private var unreadProvider: UnreadCountProviderBase
    
    private let tabItems: [(icon: String, label: String)] = [
        ("house.fill", "Home"),
        ("magnifyingglass", "Find"),
        ("stopwatch.fill", "Time"),
        ("person.3.fill", "EKIDEN"),
        ("graduationcap.fill", "Coach"),
        ("person.fill", "Me")
    ]
    
    var body: some View {
        Group {
            switch selectedTab {
            case 0:
                NavigationStack {
                    HomeView()
                        .environmentObject(unreadProvider)
                }
            case 1:
                FindView()
            case 2:
                TimeTrialEntryView()
            case 3:
                TeamView()
            case 4:
                CoachView()
            case 5:
                MyProfileView()
            default:
                NavigationStack { HomeView().environmentObject(unreadProvider) }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            customTabBar
        }
        .ignoresSafeArea(.keyboard)
        .onAppear {
            previousTabIndex = selectedTab
            tabEnterDate = Date()
            RealityMiningManager.shared.trackScreenView(name: tabItems[selectedTab].label)
        }
        .onChange(of: selectedTab) { newValue in
            let previousTabName = tabItems.indices.contains(previousTabIndex) ? tabItems[previousTabIndex].label : "unknown"
            let duration = Date().timeIntervalSince(tabEnterDate)
            RealityMiningManager.shared.trackEvent(
                name: "screen_view_end",
                properties: [
                    "screen_name": previousTabName,
                    "duration_sec": duration
                ]
            )

            tabEnterDate = Date()
            let nextTabName = tabItems.indices.contains(newValue) ? tabItems[newValue].label : "unknown"
            RealityMiningManager.shared.trackScreenView(name: nextTabName)
            previousTabIndex = newValue
        }
    }
    
    private var customTabBar: some View {
        HStack(spacing: 0) {
            ForEach(0..<tabItems.count, id: \.self) { index in
                Button(action: { selectedTab = index }) {
                    VStack(spacing: 2) {
                        Image(systemName: tabItems[index].icon)
                            .font(.system(size: 20))
                        Text(tabItems[index].label)
                            .font(.system(size: 9))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundColor(selectedTab == index ? Color(hex: "0F1A2E") : .gray)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 6)
        .background(Color.white)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(height: 0.5)
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(AuthManager(forPreview: true))
        .environmentObject(UserManager())
        .environmentObject(PreviewUnreadProvider() as UnreadCountProviderBase)
        .environmentObject(JoinedPracticesStore())
}
