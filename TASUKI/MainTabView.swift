import SwiftUI

struct MainTabView: View {
    // タブの選択状態を管理する変数
    @State private var selectedTab: Int = 0
    
    // カラー設定
    init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor.white
        
        let itemAppearance = UITabBarItemAppearance()
        itemAppearance.normal.iconColor = UIColor.gray
        itemAppearance.selected.iconColor = UIColor(red: 15/255, green: 26/255, blue: 46/255, alpha: 1.0) // Deep Navy
        itemAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor.gray]
        itemAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor(red: 15/255, green: 26/255, blue: 46/255, alpha: 1.0)] // Deep Navy
        
        appearance.stackedLayoutAppearance = itemAppearance
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // タブ1: Home
            HomeView()
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
}
