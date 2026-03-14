import SwiftUI

private enum RankingMode {
    case personal
    case team
}

private enum RankingPeriod {
    case total
    case monthly
}

private enum RankingFilter {
    case overall
    case sameRank
    case samePrefecture
}

/// ランキング画面（サンプルデータベース）
struct RankingView: View {
    @State private var mode: RankingMode = .personal
    @State private var period: RankingPeriod = .total
    @State private var filter: RankingFilter = .overall
    
    @AppStorage("myRank") private var myRank: String = "Rank B"
    @AppStorage("myName") private var myName: String = "Hiro"
    @AppStorage("myTeamId") private var myTeamId: String = ""
    
    // 地域フィルタ用（現状は東京都で固定に近い扱い）
    private var myPrefecture: String { "東京都" }
    
    private var personalSource: [User] {
        var users = [mockUser] + mockUsers
        let myPoints = PointService.shared.currentTotalPoints()
        if myPoints > 0 {
            var me = mockUser
            me.totalPoints = myPoints
            me.monthlyPoints = PointService.shared.currentMonthlyPoints()
            users[0] = me
        }
        return users
    }
    
    private var teamSource: [SampleTeam] {
        var teams = SampleTeam.samples
        if !myTeamId.isEmpty {
            let total = PointService.shared.teamTotalPoints(teamId: myTeamId)
            let monthly = PointService.shared.teamMonthlyPoints(teamId: myTeamId)
            let myTeam = SampleTeam(
                id: myTeamId,
                name: myTeamId == "example_owner" ? "皇居ランナーズ" : "皇居ランナーズ",
                prefecture: "東京都",
                memberCount: 5,
                totalPoints: total,
                monthlyPoints: monthly
            )
            if !teams.contains(where: { $0.id == myTeamId }) {
                teams.append(myTeam)
            }
        }
        return teams
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // モード切替（個人 / チーム）
            Picker("", selection: $mode) {
                Text("個人").tag(RankingMode.personal)
                Text("チーム").tag(RankingMode.team)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.top, 12)
            
            // 期間切替（累計 / 月間）
            Picker("", selection: $period) {
                Text("累計").tag(RankingPeriod.total)
                Text("月間").tag(RankingPeriod.monthly)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            
            // フィルター（全体 / ランク別 / 地域別）
            Picker("", selection: $filter) {
                Text("全体").tag(RankingFilter.overall)
                Text("ランク別").tag(RankingFilter.sameRank)
                Text("地域別").tag(RankingFilter.samePrefecture)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            
            Divider()
            
            if mode == .personal {
                personalRankingList
            } else {
                teamRankingList
            }
        }
        .navigationTitle("ランキング")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(uiColor: .systemGroupedBackground))
    }
    
    // MARK: - 個人ランキング
    
    private var filteredPersonalUsers: [User] {
        var users = personalSource
        
        // フィルタ適用
        switch filter {
        case .overall:
            break
        case .sameRank:
            users = users.filter { $0.rank == myRank }
        case .samePrefecture:
            users = users.filter { $0.prefecture == myPrefecture }
        }
        
        // 期間ごとに並び替え
        switch period {
        case .total:
            return users.sorted { $0.totalPoints > $1.totalPoints }
        case .monthly:
            return users.sorted { $0.monthlyPoints > $1.monthlyPoints }
        }
    }
    
    private var personalRankingList: some View {
        List(Array(filteredPersonalUsers.enumerated()), id: \.element.id) { index, user in
            let isMe = user.name == myName || (index == 0 && PointService.shared.currentTotalPoints() > 0)
            HStack(spacing: 12) {
                Text("\(index + 1)")
                    .font(.system(size: 22, weight: .bold))
                    .frame(width: 32, alignment: .trailing)
                    .foregroundColor(Color(hex: "0F1A2E"))
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(user.name)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color(hex: "0F1A2E"))
                        Text(user.rank)
                            .font(.system(size: 11, weight: .semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color(hex: "0F1A2E").opacity(0.06))
                            )
                        if let tier = PointBadgeHelper.tier(forTotalPoints: user.totalPoints) {
                            Image(systemName: tier.iconName)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(tier.color)
                        }
                    }
                    Text(user.prefecture)
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    let points = (period == .total) ? user.totalPoints : user.monthlyPoints
                    Text("\(points)")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(Color(hex: "0F1A2E"))
                    Text(period == .total ? "累計pt" : "月間pt")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                }
            }
            .padding(.vertical, 4)
            .listRowBackground(isMe ? Color(hex: "2E5CFF").opacity(0.12) : Color.clear)
        }
        .listStyle(.plain)
    }
    
    // MARK: - チームランキング（サンプル）
    
    private var filteredTeams: [SampleTeam] {
        var teams = teamSource
        
        switch filter {
        case .overall:
            break
        case .sameRank:
            // チームランク別（自チームがあればそのランクと同じもの）
            if let myTeamTier = teams.first?.tier {
                teams = teams.filter { $0.tier == myTeamTier }
            }
        case .samePrefecture:
            teams = teams.filter { $0.prefecture == myPrefecture }
        }
        
        switch period {
        case .total:
            return teams.sorted { $0.totalPoints > $1.totalPoints }
        case .monthly:
            return teams.sorted { $0.monthlyPoints > $1.monthlyPoints }
        }
    }
    
    private var teamRankingList: some View {
        List(Array(filteredTeams.enumerated()), id: \.element.id) { index, team in
            let isMyTeam = team.id == myTeamId
            HStack(spacing: 12) {
                Text("\(index + 1)")
                    .font(.system(size: 22, weight: .bold))
                    .frame(width: 32, alignment: .trailing)
                    .foregroundColor(Color(hex: "0F1A2E"))
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(team.name)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color(hex: "0F1A2E"))
                        Text(team.tier.displayName)
                            .font(.system(size: 11, weight: .semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(team.tier.color.opacity(0.12))
                            )
                    }
                    Text("\(team.prefecture) / \(team.memberCount)名")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    let points = (period == .total) ? team.totalPoints : team.monthlyPoints
                    Text("\(points)")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(Color(hex: "0F1A2E"))
                    Text(period == .total ? "累計pt" : "月間pt")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                }
            }
            .padding(.vertical, 4)
            .listRowBackground(isMyTeam ? Color(hex: "2E5CFF").opacity(0.12) : Color.clear)
        }
        .listStyle(.plain)
    }
}

// MARK: - サンプルチームモデル

private struct SampleTeam: Identifiable {
    let id: String
    let name: String
    let prefecture: String
    let memberCount: Int
    let totalPoints: Int
    let monthlyPoints: Int
    
    var tier: TeamRankTier {
        TeamRankTier.tier(forTeamPoints: totalPoints)
    }
    
    static let samples: [SampleTeam] = [
        SampleTeam(
            id: "team-1",
            name: "皇居ランナーズ",
            prefecture: "東京都",
            memberCount: 8,
            totalPoints: 5200,
            monthlyPoints: 800
        ),
        SampleTeam(
            id: "team-2",
            name: "代々木モーニングクラブ",
            prefecture: "東京都",
            memberCount: 5,
            totalPoints: 3100,
            monthlyPoints: 600
        ),
        SampleTeam(
            id: "team-3",
            name: "大阪城ナイトラン",
            prefecture: "大阪府",
            memberCount: 10,
            totalPoints: 7800,
            monthlyPoints: 1200
        )
    ]
}

