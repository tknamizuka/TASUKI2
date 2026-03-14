import SwiftUI

struct MainTabView: View {
    @State private var selectedTab: Int = 0
    @EnvironmentObject private var unreadProvider: UnreadCountProviderBase
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // タブ1: Home（メッセージへのリンク・未読バッジ用に NavigationStack でラップ）
            NavigationStack {
                HomeView()
                    .environmentObject(unreadProvider)
            }
            .tabItem {
                Image(systemName: "house.fill")
                Text("Home")
            }
            .tag(0)
            
            // タブ2: Find
            FindView()
                .tabItem {
                    Image(systemName: "magnifyingglass")
                    Text("Find")
                }
                .tag(1)
            
            // タブ3: タイムトライアル（TimeTrialEntryView が内部で NavigationStack を持つ）
            TimeTrialEntryView()
                .tabItem {
                Image(systemName: "stopwatch.fill")
                Text("タイムトライアル")
            }
            .tag(2)
            
            // タブ4: EKIDEN
            TeamView()
                .tabItem {
                    Image(systemName: "person.3.fill")
                    Text("EKIDEN")
                }
                .tag(3)
            
            // タブ5: Coach
            CoachView()
                .tabItem {
                    Image(systemName: "graduationcap.fill")
                    Text("Coach")
                }
                .tag(4)
            
            // タブ6: Me
            MyProfileView()
                .tabItem {
                    Image(systemName: "person.fill")
                    Text("Me")
                }
                .tag(5)
        }
        .tint(Color(hex: "0F1A2E"))
    }
}

#Preview {
    MainTabView()
        .environmentObject(AuthManager(forPreview: true))
        .environmentObject(UserManager())
        .environmentObject(PreviewUnreadProvider() as UnreadCountProviderBase)
        .environmentObject(JoinedPracticesStore())
}
