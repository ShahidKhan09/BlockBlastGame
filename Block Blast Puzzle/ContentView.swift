// BlockBlastGame.swift
// Paste this as ContentView.swift in a new Xcode iOS 17+ project.
// Delete the existing ContentView.swift content completely.

import SwiftUI
import UIKit

// MARK: - Color Extensions

extension Color {
    static let neonCyan   = Color(hex: "#00E5FF")
    static let neonPink   = Color(hex: "#FF2D78")
    static let neonOrange = Color(hex: "#FF6B35")
    static let darkBg     = Color(hex: "#0A0F2A")
    static let surface    = Color(hex: "#141B3C")
    static let cellBorder = Color(hex: "#1E2A5A")
    static let gold       = Color(hex: "#FFD700")
    static let neonGreen  = Color(hex: "#39FF14")
    static let neonPurple = Color(hex: "#BF00FF")
    static let neonYellow = Color(hex: "#FFE600")
    static let neonBlue   = Color(hex: "#1B6FFF")
    static let bloodRed   = Color(hex: "#FF0033")
    static let darkRed    = Color(hex: "#8B0000")
    static let softGreen  = Color(hex: "#90EE90")
    static let lightBlue  = Color(hex: "#87CEEB")

    static let blockColors: [Color] = [
        Color(hex: "#00E5FF"), Color(hex: "#FF2D78"), Color(hex: "#FF6B35"),
        Color(hex: "#39FF14"), Color(hex: "#BF00FF"), Color(hex: "#FFE600"),
        Color(hex: "#1B6FFF")
    ]

    init(hex: String) {
        let h = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var val: UInt64 = 0
        Scanner(string: h).scanHexInt64(&val)
        let a, r, g, b: UInt64
        switch h.count {
        case 3:
            (a,r,g,b) = (255,(val>>8)*17,(val>>4 & 0xF)*17,(val & 0xF)*17)
        case 6:
            (a,r,g,b) = (255,val>>16,val>>8 & 0xFF,val & 0xFF)
        case 8:
            (a,r,g,b) = (val>>24,val>>16 & 0xFF,val>>8 & 0xFF,val & 0xFF)
        default:
            (a,r,g,b) = (255,0,0,0)
        }
        self.init(.sRGB,
                  red:   Double(r)/255,
                  green: Double(g)/255,
                  blue:  Double(b)/255,
                  opacity: Double(a)/255)
    }
}

// MARK: - Difficulty (Campaign Stages)

enum Difficulty: String, CaseIterable, Codable {
    case beginner, easy, normal, hard, expert, ultraHard

    var gridSize: Int {
        switch self {
        case .beginner: 5
        case .easy: 6
        case .normal: 8
        case .hard: 10
        case .expert: 12
        case .ultraHard: 14
        }
    }
    
    var maxShuffles: Int {
        switch self {
        case .beginner: 10
        case .easy: 7
        case .normal: 5
        case .hard: 3
        case .expert: 2
        case .ultraHard: 1
        }
    }
    
    var multiplier: Int {
        switch self {
        case .beginner: 1
        case .easy: 2
        case .normal: 3
        case .hard: 4
        case .expert: 6
        case .ultraHard: 10
        }
    }
    
    var cellSize: CGFloat {
        switch self {
        case .beginner: 60
        case .easy: 52
        case .normal: 44
        case .hard: 36
        case .expert: 30
        case .ultraHard: 24
        }
    }
    
    var label: String {
        switch self {
        case .beginner: "BEGINNER"
        case .easy: "EASY"
        case .normal: "NORMAL"
        case .hard: "HARD"
        case .expert: "EXPERT"
        case .ultraHard: "ULTRA HARD"
        }
    }
    
    var color: Color {
        switch self {
        case .beginner: .softGreen
        case .easy: .neonGreen
        case .normal: .neonCyan
        case .hard: .neonOrange
        case .expert: .neonPink
        case .ultraHard: .bloodRed
        }
    }
    
    var targetScore: Int {
        switch self {
        case .beginner: 500
        case .easy: 1000
        case .normal: 2000
        case .hard: 4000
        case .expert: 8000
        case .ultraHard: 16000
        }
    }
    
    var description: String {
        "\(gridSize)x\(gridSize) | \(maxShuffles) shuffles | \(multiplier)x score | Target: \(targetScore)"
    }
}

// MARK: - Shape Templates

struct ShapeTemplate {
    let cells: [[Int]]
    var rows: Int { cells.count }
    var cols: Int { cells[0].count }
    var filledCells: [(Int, Int)] {
        var out: [(Int,Int)] = []
        for r in 0..<rows { for c in 0..<cols { if cells[r][c] == 1 { out.append((r,c)) } } }
        return out
    }
}

let kShapeTemplates: [ShapeTemplate] = [
    ShapeTemplate(cells: [[1]]),
    ShapeTemplate(cells: [[1,1]]),
    ShapeTemplate(cells: [[1],[1]]),
    ShapeTemplate(cells: [[1,1],[1,1]]),
    ShapeTemplate(cells: [[1,1,1]]),
    ShapeTemplate(cells: [[1],[1],[1]]),
    ShapeTemplate(cells: [[1,0],[1,0],[1,1]]),
    ShapeTemplate(cells: [[0,1],[0,1],[1,1]]),
    ShapeTemplate(cells: [[1,1,1],[0,1,0]]),
    ShapeTemplate(cells: [[0,1,1],[1,1,0]]),
    ShapeTemplate(cells: [[1,1,0],[0,1,1]]),
    ShapeTemplate(cells: [[1,1],[1,1],[1,1]]),
    ShapeTemplate(cells: [[1,1,1],[1,1,1]]),
    ShapeTemplate(cells: [[1,1],[1,0]]),
    ShapeTemplate(cells: [[0,1,0],[1,1,1],[0,1,0]]),
    ShapeTemplate(cells: [[1,1,1,1]]),
    ShapeTemplate(cells: [[1],[1],[1],[1]]),
    ShapeTemplate(cells: [[1,1,1],[1,0,0]]),
    ShapeTemplate(cells: [[1,1,1],[0,0,1]]),
    ShapeTemplate(cells: [[1,1,0],[0,1,1],[0,0,1]]),
]

// MARK: - Block

struct Block: Identifiable {
    let id = UUID()
    let template: ShapeTemplate
    let color: Color
    let colorIndex: Int

    init(colorIndex: Int) {
        self.colorIndex = colorIndex
        self.template = kShapeTemplates.randomElement()!
        self.color = Color.blockColors[colorIndex % Color.blockColors.count]
    }
}

// MARK: - Grid Cell

struct GridCell {
    var filled: Bool = false
    var color: Color = .clear
}

// MARK: - Particle

struct Particle: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var vx: CGFloat
    var vy: CGFloat
    var color: Color
    var size: CGFloat
    var life: CGFloat
}

// MARK: - Campaign Stats

struct CampaignStats: Codable {
    var currentStage: String = Difficulty.beginner.rawValue
    var highestStageReached: String = Difficulty.beginner.rawValue
    var gamesPlayed: Int = 0
    var gamesWon: Int = 0
    var totalScore: Int = 0
    var bestScore: Int = 0
    
    var winRate: Double { gamesPlayed == 0 ? 0 : Double(gamesWon)/Double(gamesPlayed)*100 }
}

// MARK: - DisplayLink Proxy

final class DisplayLinkProxy {
    var callback: ((Double) -> Void)?
    private var link: CADisplayLink?
    private var lastTS: CFTimeInterval = 0

    func start() {
        link = CADisplayLink(target: self, selector: #selector(tick))
        link?.add(to: .main, forMode: .common)
    }
    func stop() { link?.invalidate(); link = nil }

    @objc private func tick(_ dl: CADisplayLink) {
        let dt = lastTS == 0 ? 0 : dl.timestamp - lastTS
        lastTS = dl.timestamp
        callback?(dt)
    }
}

// MARK: - ViewModel

@MainActor
final class GameViewModel: ObservableObject {

    // MARK: State
    @Published var grid: [[GridCell]] = []
    @Published var gridSize: Int = 5
    @Published var queue: [Block?] = [nil, nil, nil]
    @Published var score: Int = 0
    @Published var scoreBump: Bool = false
    @Published var shufflesLeft: Int = 10
    @Published var isGameOver: Bool = false
    @Published var gameWon: Bool = false
    @Published var particles: [Particle] = []
    @Published var highlightedCells: [(Int,Int)] = []
    @Published var highlightValid: Bool = false
    @Published var draggedBlockIndex: Int? = nil
    @Published var dragLocation: CGPoint = .zero
    @Published var hapticsEnabled: Bool = true {
        didSet { UserDefaults.standard.set(hapticsEnabled, forKey: "hapticsEnabled") }
    }
    @Published var showVictory: Bool = false
    @Published var showDefeat: Bool = false
    
    // Campaign
    @Published var campaignStats: CampaignStats = CampaignStats()
    @Published var currentDifficulty: Difficulty = .beginner
    
    var gridFrame: CGRect = .zero
    private var colorCounter: Int = 0
    private let dlProxy = DisplayLinkProxy()
    private var undoStack: [(grid: [[GridCell]], queue: [Block?], score: Int)] = []
    private var maxUndoUses: Int = 3
    private var gameEnded: Bool = false
    
    var canUndo: Bool { !undoStack.isEmpty }
    var targetScore: Int { currentDifficulty.targetScore }
    var progress: Double { min(1.0, Double(score) / Double(targetScore)) }
    
    // MARK: Init
    init() {
        hapticsEnabled = UserDefaults.standard.object(forKey: "hapticsEnabled") as? Bool ?? true
        if let data = UserDefaults.standard.data(forKey: "campaignStats"),
           let s = try? JSONDecoder().decode(CampaignStats.self, from: data) {
            campaignStats = s
            if let stage = Difficulty(rawValue: campaignStats.currentStage) {
                currentDifficulty = stage
            }
        }
        resetGame()
        dlProxy.callback = { [weak self] dt in
            Task { @MainActor [weak self] in self?.stepParticles(dt: CGFloat(dt)) }
        }
        dlProxy.start()
    }
    
    // MARK: Game Reset
    func resetGame() {
        gameEnded = false
        isGameOver = false
        gameWon = false
        showVictory = false
        showDefeat = false
        
        gridSize = currentDifficulty.gridSize
        let newGrid = Array(repeating: Array(repeating: GridCell(), count: gridSize), count: gridSize)
        grid = newGrid
        score = 0
        shufflesLeft = currentDifficulty.maxShuffles
        colorCounter = 0
        queue = [nil, nil, nil]
        highlightedCells = []
        draggedBlockIndex = nil
        particles = []
        undoStack.removeAll()
        refillQueue()
        triggerHaptic(.light)
    }
    
    // MARK: Queue
    private func refillQueue() {
        for i in 0..<3 where queue[i] == nil {
            queue[i] = Block(colorIndex: colorCounter)
            colorCounter += 1
        }
    }
    
    func shuffle() {
        guard shufflesLeft > 0 && !gameEnded else {
            triggerHaptic(.error)
            return
        }
        shufflesLeft -= 1
        queue = [nil, nil, nil]
        refillQueue()
        triggerHaptic(.medium)
    }
    
    func undoLastMove() {
        guard !undoStack.isEmpty && !gameEnded else { return }
        let (prevGrid, prevQueue, prevScore) = undoStack.removeLast()
        grid = prevGrid
        queue = prevQueue
        score = prevScore
        triggerHaptic(.light)
    }
    
    // MARK: Drag
    func beginDrag(_ index: Int) {
        guard !gameEnded else { return }
        draggedBlockIndex = index
        triggerHaptic(.light)
    }
    
    func moveDrag(to location: CGPoint) {
        guard !gameEnded else { return }
        dragLocation = location
        guard let idx = draggedBlockIndex, let block = queue[idx] else {
            highlightedCells = []; return
        }
        if let origin = snapOrigin(for: location, block: block) {
            let cells = block.template.filledCells.map { (origin.0+$0.0, origin.1+$0.1) }
            highlightedCells = cells
            highlightValid = canPlace(block: block, at: origin)
        } else {
            highlightedCells = []
            highlightValid = false
        }
    }
    
    func endDrag(at location: CGPoint) {
        guard !gameEnded else { return }
        defer { clearDrag() }
        guard let idx = draggedBlockIndex, let block = queue[idx] else { return }
        guard let origin = snapOrigin(for: location, block: block),
              canPlace(block: block, at: origin) else {
            triggerHaptic(.error)
            return
        }
        saveStateForUndo()
        placeBlock(block: block, at: origin, queueIdx: idx)
    }
    
    private func clearDrag() {
        draggedBlockIndex = nil
        highlightedCells = []
        dragLocation = .zero
    }
    
    private func snapOrigin(for location: CGPoint, block: Block) -> (Int,Int)? {
        guard gridFrame != .zero else { return nil }
        let cs = currentDifficulty.cellSize
        let relX = location.x - gridFrame.minX
        let relY = location.y - gridFrame.minY
        let col = Int(floor(relX / cs)) - block.template.cols / 2
        let row = Int(floor(relY / cs)) - block.template.rows / 2
        return (row, col)
    }
    
    func canPlace(block: Block, at origin: (Int,Int)) -> Bool {
        for (dr,dc) in block.template.filledCells {
            let r = origin.0+dr, c = origin.1+dc
            if r < 0 || r >= gridSize || c < 0 || c >= gridSize { return false }
            if grid[r][c].filled { return false }
        }
        return true
    }
    
    private func placeBlock(block: Block, at origin: (Int,Int), queueIdx: Int) {
        for (dr,dc) in block.template.filledCells {
            grid[origin.0+dr][origin.1+dc] = GridCell(filled: true, color: block.color)
        }
        let pointsEarned = block.template.filledCells.count * currentDifficulty.multiplier
        bumpScore(pointsEarned)
        triggerHaptic(.rigid)
        
        let combos = clearLines(blockColor: block.color)
        if combos > 1 { triggerHaptic(.success) }
        
        queue[queueIdx] = nil
        refillQueue()
        
        // Check win condition FIRST before deadlock
        if score >= targetScore && !gameEnded {
            winGame()
            return
        }
        
        if isDeadlock() && !gameEnded {
            loseGame()
        }
    }
    
    private func winGame() {
        gameEnded = true
        gameWon = true
        isGameOver = true
        showVictory = true
        
        // Update campaign stats
        campaignStats.gamesPlayed += 1
        campaignStats.gamesWon += 1
        campaignStats.totalScore += score
        if score > campaignStats.bestScore {
            campaignStats.bestScore = score
        }
        
        // Advance to next difficulty if not last
        let allDifficulties = Difficulty.allCases
        if let currentIndex = allDifficulties.firstIndex(of: currentDifficulty),
           currentIndex + 1 < allDifficulties.count {
            let nextDifficulty = allDifficulties[currentIndex + 1]
            campaignStats.currentStage = nextDifficulty.rawValue
            if let highestIndex = allDifficulties.firstIndex(where: { $0.rawValue == campaignStats.highestStageReached }),
               currentIndex + 1 > highestIndex {
                campaignStats.highestStageReached = nextDifficulty.rawValue
            }
        }
        
        saveCampaignStats()
        triggerHaptic(.success)
        
        // Show victory message and auto-reset after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            guard let self = self else { return }
            self.showVictory = false
            // Reload with next difficulty (or current if completed all)
            if let nextStageRaw = Difficulty(rawValue: self.campaignStats.currentStage) {
                self.currentDifficulty = nextStageRaw
                self.resetGame()
            } else {
                // Campaign complete - stay at ultraHard
                self.resetGame()
            }
        }
    }
    
    private func loseGame() {
        gameEnded = true
        gameWon = false
        isGameOver = true
        showDefeat = true
        
        // Update stats (loss)
        campaignStats.gamesPlayed += 1
        campaignStats.totalScore += score
        if score > campaignStats.bestScore {
            campaignStats.bestScore = score
        }
        saveCampaignStats()
        triggerHaptic(.heavy)
        
        // Show defeat message and auto-reset after delay (retry same difficulty)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            guard let self = self else { return }
            self.showDefeat = false
            self.resetGame()  // Retry same difficulty
        }
    }
    
    private func clearLines(blockColor: Color) -> Int {
        var rows: [Int] = [], cols: [Int] = []
        for r in 0..<gridSize where grid[r].allSatisfy({ $0.filled }) { rows.append(r) }
        for c in 0..<gridSize where (0..<gridSize).allSatisfy({ grid[$0][c].filled }) { cols.append(c) }
        let total = (rows.count + cols.count) * gridSize
        if total > 0 {
            let points = total * 10 * currentDifficulty.multiplier
            bumpScore(points)
            spawnParticles(rows: rows, cols: cols, color: blockColor)
        }
        for r in rows { for c in 0..<gridSize { grid[r][c] = GridCell() } }
        for c in cols { for r in 0..<gridSize { grid[r][c] = GridCell() } }
        return rows.count + cols.count
    }
    
    private func isDeadlock() -> Bool {
        let active = queue.compactMap { $0 }
        for block in active {
            for r in 0..<gridSize { for c in 0..<gridSize {
                if canPlace(block: block, at: (r,c)) { return false }
            }}
        }
        return true
    }
    
    private func bumpScore(_ pts: Int) {
        score += pts
        scoreBump = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            self?.scoreBump = false
        }
    }
    
    private func saveStateForUndo() {
        if undoStack.count >= maxUndoUses {
            undoStack.removeFirst()
        }
        undoStack.append((grid, queue, score))
    }
    
    func saveCampaignStats() {
        if let data = try? JSONEncoder().encode(campaignStats) {
            UserDefaults.standard.set(data, forKey: "campaignStats")
        }
    }
    
    func resetCampaign() {
        campaignStats = CampaignStats()
        campaignStats.currentStage = Difficulty.beginner.rawValue
        campaignStats.highestStageReached = Difficulty.beginner.rawValue
        saveCampaignStats()
        if let stage = Difficulty(rawValue: campaignStats.currentStage) {
            currentDifficulty = stage
        }
        resetGame()
        triggerHaptic(.warning)
    }
    
    // MARK: Haptics
    enum HapticKind { case light, medium, rigid, success, error, heavy, warning }
    func triggerHaptic(_ kind: HapticKind) {
        guard hapticsEnabled else { return }
        switch kind {
        case .light:   UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case .medium:  UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        case .rigid:   UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        case .heavy:   UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        case .success: UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .error:   UINotificationFeedbackGenerator().notificationOccurred(.error)
        case .warning: UINotificationFeedbackGenerator().notificationOccurred(.warning)
        }
    }
    
    // MARK: Particles
    private func spawnParticles(rows: [Int], cols: [Int], color: Color) {
        guard gridFrame != .zero else { return }
        let cs = currentDifficulty.cellSize
        var newP: [Particle] = []
        func add(_ x: CGFloat, _ y: CGFloat) {
            let particleCount = currentDifficulty == .ultraHard ? 12 : (currentDifficulty == .expert ? 10 : 6)
            for _ in 0..<particleCount {
                let angle = CGFloat.random(in: 0..<2 * .pi)
                let speed = CGFloat.random(in: 50...160)
                newP.append(Particle(
                    x: x, y: y,
                    vx: cos(angle)*speed, vy: sin(angle)*speed,
                    color: color,
                    size: CGFloat.random(in: 4...9),
                    life: 1.0
                ))
            }
        }
        for r in rows { for c in 0..<gridSize {
            add(gridFrame.minX + CGFloat(c)*cs + cs/2,
                gridFrame.minY + CGFloat(r)*cs + cs/2)
        }}
        for c in cols { for r in 0..<gridSize {
            add(gridFrame.minX + CGFloat(c)*cs + cs/2,
                gridFrame.minY + CGFloat(r)*cs + cs/2)
        }}
        particles.append(contentsOf: newP)
    }
    
    func stepParticles(dt: CGFloat) {
        guard !particles.isEmpty else { return }
        for i in particles.indices {
            particles[i].x  += particles[i].vx * dt
            particles[i].y  += particles[i].vy * dt
            particles[i].vy += 220 * dt
            particles[i].life -= dt * 1.4
        }
        particles.removeAll { $0.life <= 0 }
    }
}

// MARK: - App Entry

@main
struct BlockBlastApp: App {
    var body: some Scene {
        WindowGroup { RootView() }
    }
}

// MARK: - Root

struct RootView: View {
    @StateObject private var vm = GameViewModel()

    var body: some View {
        TabView {
            GameRootView()
                .tabItem { Label("Campaign", systemImage: "flag.fill") }
            StatsView()
                .tabItem { Label("Stats",    systemImage: "chart.bar.fill") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
        .environmentObject(vm)
        .preferredColorScheme(.dark)
        .tint(.neonCyan)
    }
}

// MARK: - Game Root

struct GameRootView: View {
    @EnvironmentObject var vm: GameViewModel

    var body: some View {
        ZStack {
            GameContentView()

            if let idx = vm.draggedBlockIndex, let block = vm.queue[idx] {
                BlockShapeView(block: block, cs: vm.currentDifficulty.cellSize)
                    .opacity(0.8)
                    .position(vm.dragLocation)
                    .allowsHitTesting(false)
                    .ignoresSafeArea()
            }

            ParticlesView()
            
            // Victory overlay
            if vm.showVictory {
                VictoryOverlay()
            }
            
            // Defeat overlay
            if vm.showDefeat {
                DefeatOverlay()
            }
        }
        .ignoresSafeArea(edges: .top)
    }
}

// MARK: - Victory Overlay

struct VictoryOverlay: View {
    @EnvironmentObject var vm: GameViewModel
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.7).ignoresSafeArea()
            VStack(spacing: 20) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 70))
                    .foregroundColor(.gold)
                Text("VICTORY!")
                    .font(.system(size: 40, weight: .black, design: .rounded))
                    .foregroundColor(.gold)
                Text("You beat \(vm.currentDifficulty.label)!")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                // Show next stage or completion
                let allDifficulties = Difficulty.allCases
                if let currentIndex = allDifficulties.firstIndex(of: vm.currentDifficulty),
                   currentIndex + 1 < allDifficulties.count {
                    Text("Next: \(allDifficulties[currentIndex + 1].label)")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(vm.currentDifficulty.color)
                } else {
                    Text("CAMPAIGN COMPLETE!")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.gold)
                }
            }
            .padding(30)
            .background(
                RoundedRectangle(cornerRadius: 25)
                    .fill(Color.surface)
                    .overlay(RoundedRectangle(cornerRadius: 25).strokeBorder(Color.gold, lineWidth: 2))
            )
        }
    }
}

// MARK: - Defeat Overlay

struct DefeatOverlay: View {
    @EnvironmentObject var vm: GameViewModel
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.7).ignoresSafeArea()
            VStack(spacing: 20) {
                Image(systemName: "skull.fill")
                    .font(.system(size: 70))
                    .foregroundColor(.neonPink)
                Text("DEFEAT!")
                    .font(.system(size: 40, weight: .black, design: .rounded))
                    .foregroundColor(.neonPink)
                Text("You ran out of moves!")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text("Retrying \(vm.currentDifficulty.label)...")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(vm.currentDifficulty.color)
            }
            .padding(30)
            .background(
                RoundedRectangle(cornerRadius: 25)
                    .fill(Color.surface)
                    .overlay(RoundedRectangle(cornerRadius: 25).strokeBorder(Color.neonPink, lineWidth: 2))
            )
        }
    }
}

// MARK: - Game Content

struct GameContentView: View {
    @EnvironmentObject var vm: GameViewModel

    var body: some View {
        ZStack {
            Color.darkBg.ignoresSafeArea()

            VStack(spacing: 0) {
                Color.clear.frame(height: topSafeArea())

                // Header
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("BLOCK BLAST")
                            .font(.system(size: 20, weight: .black, design: .rounded))
                            .foregroundColor(vm.currentDifficulty.color)
                            .tracking(3)
                        HStack(spacing: 8) {
                            Text("STAGE: \(vm.currentDifficulty.label)")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(vm.currentDifficulty.color)
                            Image(systemName: "flag.fill")
                                .font(.system(size: 8))
                                .foregroundColor(vm.currentDifficulty.color)
                        }
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 1) {
                        Text("SCORE")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(.gray)
                            .tracking(2)
                        Text("\(vm.score)")
                            .font(.system(size: 26, weight: .black, design: .rounded))
                            .foregroundColor(.gold)
                            .scaleEffect(vm.scoreBump ? 1.4 : 1.0)
                            .animation(.spring(response: 0.2, dampingFraction: 0.45), value: vm.scoreBump)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 8)
                
                // Progress bar to target
                VStack(spacing: 4) {
                    HStack {
                        Text("TARGET: \(vm.targetScore)")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(.gray)
                        Spacer()
                        Text("\(vm.score)/\(vm.targetScore)")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(vm.currentDifficulty.color)
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.surface)
                                .frame(height: 6)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(vm.currentDifficulty.color)
                                .frame(width: geo.size.width * vm.progress, height: 6)
                        }
                    }
                    .frame(height: 6)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 8)

                GridView()
                    .padding(.horizontal, 10)

                Spacer(minLength: 6)

                Text("NEXT BLOCKS")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(.gray)
                    .tracking(3)
                    .padding(.bottom, 4)

                BlockQueueView()
                    .padding(.horizontal, 14)

                ShuffleBtn()
                    .padding(.top, 6)
                    .padding(.bottom, 10)

                UndoButton()
                    .padding(.bottom, 10)
            }
        }
    }

    private func topSafeArea() -> CGFloat {
        let scenes = UIApplication.shared.connectedScenes
        let ws = scenes.first as? UIWindowScene
        return ws?.windows.first?.safeAreaInsets.top ?? 44
    }
}

// MARK: - Grid View

struct GridView: View {
    @EnvironmentObject var vm: GameViewModel

    var body: some View {
        let cs = vm.currentDifficulty.cellSize
        let gs = vm.gridSize

        GeometryReader { geo in
            let totalW = cs * CGFloat(gs)
            let totalH = cs * CGFloat(gs)
            let ox = (geo.size.width - totalW) / 2
            let oy = (geo.size.height - totalH) / 2

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(vm.currentDifficulty == .ultraHard ? Color.darkRed.opacity(0.2) : Color.surface)
                    .frame(width: geo.size.width, height: geo.size.height)

                ForEach(0..<gs, id: \.self) { row in
                    ForEach(0..<gs, id: \.self) { col in
                        CellView(row: row, col: col, cs: cs)
                            .frame(width: cs-2, height: cs-2)
                            .position(
                                x: ox + CGFloat(col)*cs + cs/2,
                                y: oy + CGFloat(row)*cs + cs/2
                            )
                    }
                }
            }
            .background(
                GeometryReader { inner in
                    Color.clear.onAppear { updateGridFrame(geo: inner, ox: ox, oy: oy, size: totalW) }
                              .onChange(of: geo.size) { _,_ in updateGridFrame(geo: inner, ox: ox, oy: oy, size: totalW) }
                }
            )
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func updateGridFrame(geo: GeometryProxy, ox: CGFloat, oy: CGFloat, size: CGFloat) {
        let f = geo.frame(in: .global)
        vm.gridFrame = CGRect(x: f.minX + ox, y: f.minY + oy, width: size, height: size)
    }
}

// MARK: - Cell View

struct CellView: View {
    @EnvironmentObject var vm: GameViewModel
    let row: Int
    let col: Int
    let cs: CGFloat

    private var highlighted: Bool {
        vm.highlightedCells.contains { $0.0 == row && $0.1 == col }
    }
    
    private var safeCell: GridCell {
        guard row >= 0 && row < vm.grid.count && col >= 0 && col < vm.grid[row].count else {
            return GridCell()
        }
        return vm.grid[row][col]
    }

    var body: some View {
        let cell = safeCell
        let hl = highlighted

        ZStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(fillColor(cell: cell, hl: hl))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(strokeColor(cell: cell, hl: hl),
                                      lineWidth: cell.filled ? 1 : 0.5)
                )

            if cell.filled {
                RoundedRectangle(cornerRadius: 4)
                    .fill(LinearGradient(
                        colors: [.white.opacity(0.28), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
            }
        }
        .animation(.easeInOut(duration: 0.1), value: hl)
    }

    private func fillColor(cell: GridCell, hl: Bool) -> Color {
        if cell.filled { return cell.color }
        if hl { return vm.highlightValid ? Color.neonGreen.opacity(0.4) : Color.neonPink.opacity(0.4) }
        return Color.cellBorder.opacity(0.3)
    }

    private func strokeColor(cell: GridCell, hl: Bool) -> Color {
        if cell.filled { return cell.color.opacity(0.65) }
        if hl { return vm.highlightValid ? .neonGreen : .neonPink }
        return .cellBorder
    }
}

// MARK: - Block Queue

struct BlockQueueView: View {
    @EnvironmentObject var vm: GameViewModel

    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<3, id: \.self) { i in
                Group {
                    if let block = vm.queue[i] {
                        DraggableBlockView(block: block, index: i)
                            .opacity(vm.draggedBlockIndex == i ? 0.15 : 1)
                    } else {
                        Spacer().frame(maxWidth: .infinity, minHeight: 80)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(vm.currentDifficulty == .ultraHard ? Color.darkRed.opacity(0.3) : Color.surface)
                .overlay(RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(vm.currentDifficulty == .ultraHard ? Color.bloodRed.opacity(0.5) : Color.cellBorder, lineWidth: vm.currentDifficulty == .ultraHard ? 2 : 1))
        )
    }
}

// MARK: - Draggable Block

struct DraggableBlockView: View {
    @EnvironmentObject var vm: GameViewModel
    let block: Block
    let index: Int
    @State private var dragging = false

    var body: some View {
        BlockShapeView(block: block, cs: previewCS)
            .scaleEffect(dragging ? 1.08 : 1.0)
            .animation(.spring(response: 0.18), value: dragging)
            .gesture(
                DragGesture(minimumDistance: 3, coordinateSpace: .global)
                    .onChanged { v in
                        if !dragging { dragging = true; vm.beginDrag(index) }
                        vm.moveDrag(to: v.location)
                    }
                    .onEnded { v in
                        dragging = false
                        vm.endDrag(at: v.location)
                    }
            )
    }

    private var previewCS: CGFloat {
        min(16, vm.currentDifficulty.cellSize * 0.5)
    }
}

// MARK: - Block Shape View

struct BlockShapeView: View {
    let block: Block
    let cs: CGFloat

    var body: some View {
        VStack(spacing: 1) {
            ForEach(0..<block.template.rows, id: \.self) { r in
                HStack(spacing: 1) {
                    ForEach(0..<block.template.cols, id: \.self) { c in
                        if block.template.cells[r][c] == 1 {
                            ZStack {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(block.color)
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(LinearGradient(
                                        colors: [.white.opacity(0.3), .clear],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ))
                                RoundedRectangle(cornerRadius: 3)
                                    .strokeBorder(block.color.opacity(0.7), lineWidth: 0.5)
                            }
                            .frame(width: cs, height: cs)
                        } else {
                            Color.clear.frame(width: cs, height: cs)
                        }
                    }
                }
            }
        }
        .padding(8)
    }
}

// MARK: - Shuffle Button

struct ShuffleBtn: View {
    @EnvironmentObject var vm: GameViewModel

    var body: some View {
        Button { vm.shuffle() } label: {
            HStack(spacing: 8) {
                Image(systemName: "shuffle")
                    .font(.system(size: 13, weight: .bold))
                Text("Shuffle  (\(vm.shufflesLeft) left)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
            }
            .foregroundColor(vm.shufflesLeft > 0 ? vm.currentDifficulty.color : .gray)
            .padding(.horizontal, 22)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 11)
                    .fill(Color.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 11)
                            .strokeBorder(
                                vm.shufflesLeft > 0 ? vm.currentDifficulty.color.opacity(0.55) : Color.gray.opacity(0.25),
                                lineWidth: vm.currentDifficulty == .ultraHard ? 2 : 1
                            )
                    )
            )
        }
        .disabled(vm.shufflesLeft == 0 || vm.isGameOver)
    }
}

// MARK: - Undo Button

struct UndoButton: View {
    @EnvironmentObject var vm: GameViewModel

    var body: some View {
        Button(action: { vm.undoLastMove() }) {
            Text("Undo Last Move")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(vm.canUndo && !vm.isGameOver ? vm.currentDifficulty.color : .gray)
                .padding(.horizontal, 22)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: 11)
                        .fill(Color.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 11)
                                .strokeBorder(vm.canUndo && !vm.isGameOver ? vm.currentDifficulty.color.opacity(0.55) : Color.gray.opacity(0.25), lineWidth: vm.currentDifficulty == .ultraHard ? 2 : 1)
                        )
                )
        }
        .disabled(!vm.canUndo || vm.isGameOver)
    }
}

// MARK: - Particles

struct ParticlesView: View {
    @EnvironmentObject var vm: GameViewModel

    var body: some View {
        ZStack {
            ForEach(vm.particles) { p in
                Circle()
                    .fill(p.color)
                    .frame(width: p.size, height: p.size)
                    .position(x: p.x, y: p.y)
                    .opacity(Double(max(0, p.life)))
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

// MARK: - Stats View

struct StatsView: View {
    @EnvironmentObject var vm: GameViewModel

    var body: some View {
        NavigationView {
            ZStack {
                Color.darkBg.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 14) {
                        // Best score card
                        VStack(spacing: 6) {
                            Text("BEST SCORE")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(.gray)
                                .tracking(3)
                            Text("\(vm.campaignStats.bestScore)")
                                .font(.system(size: 52, weight: .black, design: .rounded))
                                .foregroundColor(.gold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(24)
                        .background(
                            RoundedRectangle(cornerRadius: 18)
                                .fill(Color.surface)
                                .overlay(RoundedRectangle(cornerRadius: 18)
                                    .strokeBorder(Color.gold.opacity(0.35), lineWidth: 1))
                        )
                        
                        // Campaign Progress
                        VStack(alignment: .leading, spacing: 10) {
                            Text("CAMPAIGN PROGRESS")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(.neonCyan)
                                .tracking(2)
                                .padding(.leading, 5)
                            
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                                ForEach(Difficulty.allCases, id: \.self) { d in
                                    let isCompleted = isStageCompleted(d)
                                    let isCurrent = vm.currentDifficulty == d
                                    
                                    HStack {
                                        Image(systemName: isCompleted ? "checkmark.circle.fill" : (isCurrent ? "flag.circle.fill" : "circle"))
                                            .font(.system(size: 14))
                                            .foregroundColor(isCompleted ? .gold : (isCurrent ? d.color : .gray))
                                        Text(d.label)
                                            .font(.system(size: 12, weight: .bold, design: .rounded))
                                            .foregroundColor(isCompleted ? .gold : (isCurrent ? d.color : .gray))
                                        Spacer()
                                        Text("\(d.targetScore)")
                                            .font(.system(size: 10, design: .monospaced))
                                            .foregroundColor(.gray)
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 8)
                                    .background(isCurrent ? d.color.opacity(0.2) : Color.surface)
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .strokeBorder(isCurrent ? d.color : Color.clear, lineWidth: 1)
                                    )
                                }
                            }
                        }
                        .padding(.horizontal, 16)

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            StatCard(label: "Total Score",   value: "\(vm.campaignStats.totalScore)",  color: .neonCyan)
                            StatCard(label: "Games Played",  value: "\(vm.campaignStats.gamesPlayed)", color: .neonOrange)
                            StatCard(label: "Games Won",     value: "\(vm.campaignStats.gamesWon)",    color: .neonGreen)
                            StatCard(label: "Win Rate",      value: String(format: "%.1f%%", vm.campaignStats.winRate), color: .neonPink)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("Campaign Stats")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.surface, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
    
    private func isStageCompleted(_ difficulty: Difficulty) -> Bool {
        let all = Difficulty.allCases
        if let currentIndex = all.firstIndex(of: vm.currentDifficulty),
           let stageIndex = all.firstIndex(of: difficulty) {
            return stageIndex < currentIndex
        }
        return false
    }
}

struct StatCard: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.system(size: 30, weight: .black, design: .rounded))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.gray)
                .tracking(1)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.surface)
                .overlay(RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(color.opacity(0.3), lineWidth: 1))
        )
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @EnvironmentObject var vm: GameViewModel
    @State private var confirmReset = false

    var body: some View {
        NavigationView {
            ZStack {
                Color.darkBg.ignoresSafeArea()
                List {
                    Section {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("CAMPAIGN MODE")
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                Text("Win to advance | Lose to retry")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(.gray)
                            }
                            Spacer()
                            Image(systemName: "flag.fill")
                                .foregroundColor(vm.currentDifficulty.color)
                        }
                        .listRowBackground(Color.surface)
                    } header: {
                        Text("GAME MODE")
                            .foregroundColor(.neonCyan)
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .tracking(2)
                    }

                    Section {
                        Toggle(isOn: $vm.hapticsEnabled) {
                            Text("Haptic Feedback")
                                .font(.system(size: 15, weight: .medium, design: .rounded))
                                .foregroundColor(.white)
                        }
                        .tint(.neonCyan)
                        .listRowBackground(Color.surface)
                    } header: {
                        Text("PREFERENCES")
                            .foregroundColor(.neonCyan)
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .tracking(2)
                    }

                    Section {
                        Button {
                            confirmReset = true
                        } label: {
                            HStack {
                                Spacer()
                                Text("Reset Campaign Progress")
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                    .foregroundColor(.neonPink)
                                Spacer()
                            }
                        }
                        .listRowBackground(Color.surface)
                    } header: {
                        Text("DATA")
                            .foregroundColor(.neonCyan)
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .tracking(2)
                    } footer: {
                        Text("This will reset your campaign to BEGINNER and erase all stats.")
                            .font(.system(size: 10, design: .rounded))
                            .foregroundColor(.gray)
                    }
                }
                .scrollContentBackground(.hidden)
                .background(Color.darkBg)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.surface, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .alert("Reset Campaign", isPresented: $confirmReset) {
                Button("Reset", role: .destructive) { vm.resetCampaign() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will erase all progress and stats. You will start from BEGINNER again.")
            }
        }
    }
}
