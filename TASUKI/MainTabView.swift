import SwiftUI
import Foundation

struct MainTabView: View {
    @State private var selectedTab: Int = 0
    @EnvironmentObject private var unreadProvider: UnreadCountProviderBase
    
    var body: some View {
        // #region agent log
        #if DEBUG
        let _ = {
            let logPath = "/Users/takuyanamizuka/Desktop/TASUKI/.cursor/debug-d29366.log"
            let ts = Int(Date().timeIntervalSince1970 * 1000)
            let payload = "{\"sessionId\":\"d29366\",\"location\":\"MainTabView.swift:body\",\"message\":\"MainTabView body evaluated\",\"timestamp\":\(ts),\"hypothesisId\":\"H1\"}\n"
            if let data = payload.data(using: .utf8) {
                let url = URL(fileURLWithPath: logPath)
                if FileManager.default.fileExists(atPath: logPath), let fh = try? FileHandle(forUpdating: url) {
                    fh.seekToEndOfFile()
                    fh.write(data)
                    try? fh.close()
                } else if !FileManager.default.fileExists(atPath: logPath) {
                    try? FileManager.default.createDirectory(atPath: (logPath as NSString).deletingLastPathComponent, withIntermediateDirectories: true)
                    FileManager.default.createFile(atPath: logPath, contents: data)
                }
            }
        }()
        #endif
        // #endregion
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
        .environmentObject(AuthManager(forPreview: true))
        .environmentObject(UserManager())
        .environmentObject(PreviewUnreadProvider() as UnreadCountProviderBase)
        .environmentObject(JoinedPracticesStore())
}
