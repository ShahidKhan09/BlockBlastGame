// ╔══════════════════════════════════════════════════════════════╗
// ║          MEMORY MATCH — PREMIUM EDITION                       ║
// ║          iOS 17+ · SwiftUI · Single File                       ║
// ╚══════════════════════════════════════════════════════════════╝

import SwiftUI

// MARK: ─── THEME ───────────────────────────────────────────────

enum MMTheme {
    static let bg1        = AppTheme.background
    static let bg2        = AppTheme.backgroundGradient[1]
    static let accent     = AppTheme.accent
    static let accentSoft = AppTheme.accentSoft
    static let cardBack   = AppTheme.surface
    static let cardFace   = Color(hex: "1E2A5A")
    static let gold       = AppTheme.warning
    static let success    = AppTheme.success
    static let danger     = Color(hex: "FF2D55")
    static let neonPink   = AppTheme.accentAlt
    
    static let emojis: [String] = ["🐶","🐱","🐼","🦁","🐸","🐵","🦊","🐰",
                                    "🐻","🐨","🐯","🦄","🐷","🐭","🐹","🐺"]
}

// MARK: ─── MEMORY GAME VIEW MODEL ──────────────────────────────

@MainActor
final class MMGameVM: ObservableObject {
    @Published var cards: [MMCard] = []
    @Published var flippedIndices: [Int] = []
    @Published var matchedPairs: Set<Int> = []
    @Published var moves: Int = 0
    @Published var score: Int = 0
    @Published var gameOver: Bool = false
    @Published var showWin: Bool = false
    @Published var timerCount: Int = 0
    @Published var isProcessing: Bool = false
    
    private var timer: Timer?
    var gridSize: Int { max(4, min(5, UserDefaults.standard.integer(forKey: "mm_gridSize")).isMultiple(of: 2) ? 4 : 4) }
    var pairCount: Int { 8 }
    var highScore: Int {
        get { UserDefaults.standard.integer(forKey: "mm_highScore") }
        set { UserDefaults.standard.set(newValue, forKey: "mm_highScore") }
    }
    
    func newGame() {
        cards = []
        flippedIndices = []
        matchedPairs = []
        moves = 0
        score = 0
        gameOver = false
        showWin = false
        timerCount = 0
        isProcessing = false
        timer?.invalidate()
        
        let emojiPool = Array(MMTheme.emojis.shuffled().prefix(pairCount))
        var newCards: [MMCard] = []
        for (index, emoji) in emojiPool.enumerated() {
            newCards.append(MMCard(id: index * 2, emoji: emoji, pairId: index))
            newCards.append(MMCard(id: index * 2 + 1, emoji: emoji, pairId: index))
        }
        cards = newCards.shuffled()
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.timerCount += 1 }
        }
    }
    
    func flipCard(at index: Int) {
        guard !isProcessing, !gameOver, index < cards.count, !cards[index].isMatched, !cards[index].isFlipped else { return }
        
        cards[index].isFlipped = true
        flippedIndices.append(index)
        
        if flippedIndices.count == 2 {
            moves += 1
            isProcessing = true
            checkMatch()
        }
    }
    
    private func checkMatch() {
        guard flippedIndices.count == 2 else { return }
        let first = flippedIndices[0]
        let second = flippedIndices[1]
        
        if cards[first].pairId == cards[second].pairId {
            // Match!
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                guard let self = self else { return }
                self.cards[first].isMatched = true
                self.cards[second].isMatched = true
                self.matchedPairs.insert(self.cards[first].pairId)
                self.score += 100 + max(0, 10 - self.moves / 2) * 10
                self.flippedIndices.removeAll()
                self.isProcessing = false
                
                if self.matchedPairs.count == self.pairCount {
                    self.gameOver = true
                    self.showWin = true
                    self.timer?.invalidate()
                    if self.score > self.highScore {
                        self.highScore = self.score
                    }
                }
            }
        } else {
            // No match
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                guard let self = self else { return }
                self.cards[first].isFlipped = false
                self.cards[second].isFlipped = false
                self.flippedIndices.removeAll()
                self.isProcessing = false
            }
        }
    }
    
    deinit { timer?.invalidate() }
}

// MARK: ─── MEMORY CARD MODEL ──────────────────────────────────

struct MMCard: Identifiable {
    let id: Int
    let emoji: String
    let pairId: Int
    var isFlipped: Bool = false
    var isMatched: Bool = false
}

// MARK: ─── MEMORY CARD VIEW ───────────────────────────────────

struct MMCardView: View {
    let card: MMCard
    let size: CGFloat
    
    var body: some View {
        ZStack {
            if card.isFlipped || card.isMatched {
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        LinearGradient(colors: [MMTheme.cardFace, MMTheme.cardFace.opacity(0.8)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(card.isMatched ? MMTheme.success.opacity(0.6) : MMTheme.accent.opacity(0.4), lineWidth: 2)
                    )
                Text(card.emoji)
                    .font(.system(size: size * 0.4))
                    .scaleEffect(card.isMatched ? 0.9 : 1.0)
            } else {
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        LinearGradient(colors: [MMTheme.cardBack, MMTheme.cardBack.opacity(0.7)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(MMTheme.accent.opacity(0.3), lineWidth: 1.5)
                    )
                Image(systemName: "questionmark")
                    .font(.system(size: size * 0.35, weight: .black))
                    .foregroundColor(MMTheme.accent.opacity(0.6))
            }
        }
        .frame(width: size, height: size)
        .rotation3DEffect(
            .degrees(card.isFlipped || card.isMatched ? 180 : 0),
            axis: (x: 0, y: 1, z: 0),
            perspective: 0.3
        )
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: card.isFlipped)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: card.isMatched)
    }
}

// MARK: ─── MEMORY GAME VIEW ───────────────────────────────────

struct MemoryMatchGameView: View {
    @StateObject private var vm = MMGameVM()
    @Environment(\.dismiss) private var dismiss
    
    let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 4)
    
    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()
            MMMeshBackground()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(.neonCyan.opacity(0.72))
                    }
                    Spacer()
                    VStack(spacing: 2) {
                        Text("MEMORY MATCH")
                            .font(.system(size: 18, weight: .black, design: .rounded))
                            .foregroundColor(.neonCyan)
                        Text("MATCH THE PAIRS")
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .foregroundColor(.white.opacity(0.4))
                            .tracking(3)
                    }
                    Spacer()
                    Image(systemName: "star.fill")
                        .font(.system(size: 16))
                        .foregroundColor(MMTheme.gold.opacity(0.5))
                }
                .padding(.horizontal, 20)
                .padding(.top, 50)
                .padding(.bottom, 8)
                
                // Stats bar
                HStack(spacing: 20) {
                    MMLabel(icon: "arrow.triangle.2.circlepath", value: "\(vm.moves)")
                    Spacer()
                    MMLabel(icon: "clock", value: "\(vm.timerCount)s")
                    Spacer()
                    MMLabel(icon: "star.fill", value: "\(vm.score)")
                }
                .padding(.horizontal, 30)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(AppTheme.surfaceSoft)
                        .padding(.horizontal, 16)
                )
                .padding(.bottom, 10)
                
                // Cards grid
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(Array(vm.cards.enumerated()), id: \.element.id) { index, card in
                        MMCardView(card: card, size: UIScreen.main.bounds.width / 4.8)
                            .onTapGesture { vm.flipCard(at: index) }
                    }
                }
                .padding(.horizontal, 16)
                
                Spacer()
                
                // New Game button
                Button { vm.newGame() } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.counterclockwise")
                        Text("NEW GAME")
                    }
                }
                .buttonStyle(.app(color: .neonCyan))
                .padding(.bottom, 30)
            }
            
            // Win overlay
            if vm.showWin {
                MMWinOverlay(vm: vm)
            }
        }
        .ignoresSafeArea()
        .onAppear { vm.newGame() }
    }
}

// MARK: ─── WIN OVERLAY ────────────────────────────────────────

struct MMWinOverlay: View {
    @ObservedObject var vm: MMGameVM
    @Environment(\.dismiss) var dismiss
    @State private var appear = false
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.7).ignoresSafeArea()
            
            VStack(spacing: 20) {
                HStack(spacing: 6) {
                    ForEach(0..<3) { i in
                        Image(systemName: "star.fill")
                            .font(.system(size: 40))
                            .foregroundColor(MMTheme.gold)
                            .scaleEffect(appear ? 1 : 0.3)
                            .animation(.spring(response: 0.4, dampingFraction: 0.5).delay(Double(i) * 0.15), value: appear)
                    }
                }
                
                Text("YOU WIN!")
                    .font(.system(size: 36, weight: .black, design: .rounded))
                    .foregroundColor(MMTheme.gold)
                    .shadow(color: MMTheme.gold.opacity(0.5), radius: 15)
                
                VStack(spacing: 6) {
                    MMRow(title: "Score", value: "\(vm.score)")
                    MMRow(title: "Moves", value: "\(vm.moves)")
                    MMRow(title: "Time", value: "\(vm.timerCount)s")
                    MMRow(title: "Best Score", value: "\(vm.highScore)")
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(MMTheme.cardBack.opacity(0.6))
                        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(MMTheme.gold.opacity(0.3)))
                )
                .padding(.horizontal, 30)
                
                HStack(spacing: 16) {
                    Button { vm.newGame() } label: {
                        Text("PLAY AGAIN")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(.black)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(MMTheme.accent)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    
                    Button { dismiss() } label: {
                        Text("MENU")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(.white.opacity(0.7))
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(MMTheme.cardBack.opacity(0.6))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.white.opacity(0.2)))
                    }
                }
            }
            .padding(30)
            .background(
                RoundedRectangle(cornerRadius: 28)
                    .fill(Color(hex: "0A0A1E").opacity(0.95))
                    .overlay(RoundedRectangle(cornerRadius: 28).strokeBorder(MMTheme.gold.opacity(0.4), lineWidth: 1.5))
            )
            .padding(.horizontal, 20)
            .scaleEffect(appear ? 1 : 0.8)
            .opacity(appear ? 1 : 0)
        }
        .onAppear { withAnimation(.spring(response: 0.5)) { appear = true } }
    }
}

struct MMRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundColor(.white.opacity(0.6))
            Spacer()
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(.white)
        }
    }
}

struct MMLabel: View {
    let icon: String
    let value: String
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(MMTheme.accent.opacity(0.7))
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
        }
    }
}

// MARK: ─── MESH BACKGROUND ────────────────────────────────────

struct MMMeshBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: AppTheme.backgroundGradient,
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            
            TimelineView(.animation(minimumInterval: 0.04)) { t in
                let s = t.date.timeIntervalSince1970
                ZStack {
                    Circle()
                        .fill(Color.neonCyan.opacity(0.12))
                        .frame(width: 260)
                        .offset(x: CGFloat(sin(s * 0.15)) * 70,
                                y: CGFloat(cos(s * 0.10)) * 80 - 80)
                        .blur(radius: 80)
                    
                    Circle()
                        .fill(Color.neonPink.opacity(0.10))
                        .frame(width: 220)
                        .offset(x: CGFloat(cos(s * 0.12)) * 60,
                                y: CGFloat(sin(s * 0.18)) * 70 + 250)
                        .blur(radius: 70)
                    
                    Circle()
                        .fill(Color.neonGreen.opacity(0.08))
                        .frame(width: 180)
                        .offset(x: CGFloat(sin(s * 0.20)) * 50,
                                y: CGFloat(cos(s * 0.14)) * 60 + 100)
                        .blur(radius: 60)
                }
            }
            
            MMGridPattern()
                .stroke(Color.white.opacity(0.025), lineWidth: 0.5)
                .ignoresSafeArea()
        }
        .ignoresSafeArea()
    }
}

struct MMGridPattern: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let step: CGFloat = 32
        var x: CGFloat = 0
        while x <= rect.width  { p.move(to: .init(x:x, y:0)); p.addLine(to: .init(x:x, y:rect.height)); x += step }
        var y: CGFloat = 0
        while y <= rect.height { p.move(to: .init(x:0, y:y)); p.addLine(to: .init(x:rect.width, y:y)); y += step }
        return p
    }
}