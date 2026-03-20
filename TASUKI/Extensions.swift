import SwiftUI

extension Color {
    // 1. カラーパレット定義（ここに追加しました！）
    static let tasukiBase = Color(hex: "FFFFFF")      // Pure White
    static let tasukiPrimary = Color(hex: "0D1B40")   // Navy (Text)
    static let tasukiSurface = Color(hex: "F5F7FA")   // Light Gray (Card Background)
    static let tasukiAccent = Color(hex: "2E5CFF")    // Royal Blue
    static let tasukiDanger = Color(hex: "FF453A")    // System Red
    // 以前のダーク名を残しつつ、白ベース＋紺系トーンにマップ
    static let tasukiDarkBackground = Color(hex: "FFFFFF")
    static let tasukiDarkCard = Color(hex: "FFFFFF")
    static let tasukiDarkCardSecondary = Color(hex: "F5F7FA")
    static let tasukiMutedText = Color(hex: "6B7280")
    static let tasukiAccentOrange = Color(hex: "2E5CFF")
    
    // 互換性のためのエイリアス（既存コードとの互換性を保つため）
    static let royalBlue = Color(hex: "2E5CFF")       // Accent (tasukiAccentと同じ)
    static let midnightNavy = Color(hex: "050A14")    // Background
    static let pureWhite = Color(hex: "FFFFFF")       // Main Text (tasukiBaseと同じ)
    static let deepNavy = Color(hex: "0F1A2E")        // Card Background

    // 2. Hex変換用イニシャライザ
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

enum TasukiUI {
    static let cardCorner: CGFloat = 16
    static let cardPadding: CGFloat = 16
    static let sectionSpacing: CGFloat = 14
    static let iconSize: CGFloat = 20
}

extension View {
    func tasukiCard(corner: CGFloat = TasukiUI.cardCorner) -> some View {
        self
            .padding(TasukiUI.cardPadding)
            .background(
                RoundedRectangle(cornerRadius: corner)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 3)
            )
    }
}

// MARK: - Flow Layout (for tags)
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.frames[index].minX, y: bounds.minY + result.frames[index].minY), proposal: .unspecified)
        }
    }
    
    struct FlowResult {
        var size: CGSize = .zero
        var frames: [CGRect] = []
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                
                if currentX + size.width > maxWidth && currentX > 0 {
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                }
                
                frames.append(CGRect(x: currentX, y: currentY, width: size.width, height: size.height))
                lineHeight = max(lineHeight, size.height)
                currentX += size.width + spacing
            }
            
            self.size = CGSize(width: maxWidth, height: currentY + lineHeight)
        }
    }
}
