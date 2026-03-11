import SwiftUI

struct MainTabView: View {
    @State private var selectedTab: Int = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // タブ1: Home（メッセージへのリンク・未読バッジ用に NavigationStack でラップ）
            NavigationStack {
                HomeView()
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
            
            // タブ3: EKIDEN
            TeamView()
                .tabItem {
                    Image(systemName: "person.3.fill")
                    Text("EKIDEN")
                }
                .tag(2)
            
            // タブ4: Coach
            CoachView()
                .tabItem {
                    Image(systemName: "graduationcap.fill")
                    Text("Coach")
                }
                .tag(3)
            
            // タブ5: Me
            MyProfileView()
                .tabItem {
                    Image(systemName: "person.fill")
                    Text("Me")
                }
                .tag(4)
        }
        .tint(Color(hex: "0F1A2E"))
    }
}

#Preview {
    MainTabView()
        .environmentObject(AuthManager())
        .environmentObject(UserManager())
}
