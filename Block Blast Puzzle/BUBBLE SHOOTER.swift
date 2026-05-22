// ╔══════════════════════════════════════════════════════════════╗
// ║          BUBBLE SHOOTER — PREMIUM EDITION                   ║
// ║          iOS 17+ · SwiftUI · Single File                    ║
// ╚══════════════════════════════════════════════════════════════╝

import SwiftUI
import Combine

// MARK: ─── THEME ───────────────────────────────────────────────

struct BSTTheme {
    static let bg1        = AppTheme.background
    static let bg2        = AppTheme.backgroundGradient[1]
    static let accent     = AppTheme.accent
    static let accentSoft = AppTheme.accentSoft
    static let gold       = AppTheme.warning
    static let danger     = Color(hex: "FF2D55")
    static let cardBg     = AppTheme.surface.opacity(0.6)
    static let cardBorder = Color.white.opacity(0.10)
    static let neonPink   = AppTheme.accentAlt
    static let neonGreen  = AppTheme.success
    static let surface    = AppTheme.surface
}

// MARK: ─── BUBBLE COLOR ────────────────────────────────────────

enum BSTBubColor: Int, CaseIterable, Codable {
    case cyan, pink, green, gold, orange, purple, blue

    var base: Color {
        switch self {
        case .cyan:    return Color(hex: "00E5FF")
        case .pink:    return Color(hex: "FF6EC7")
        case .green:   return Color(hex: "39FF14")
        case .gold:    return Color(hex: "FFD700")
        case .orange:  return Color(hex: "FF6B35")
        case .purple:  return Color(hex: "BF00FF")
        case .blue:    return Color(hex: "1B6FFF")
        }
    }
    var light: Color { base.opacity(0.25) }
    var glow:  Color { base.opacity(0.50) }
    var shadow: Color { base.opacity(0.35) }
}

// MARK: ─── DATA MODELS ────────────────────────────────────────

let BSCOLS          = 9
let BSMAX_ROWS      = 10
let BSR: CGFloat    = 21          // bubble radius
let BSDIAM: CGFloat = BSR * 2
let BSDANGER_ROW    = 9

struct BSTGBubble: Identifiable, Equatable {
    let id    = UUID()
    var row, col: Int
    var color: BSTBubColor
    var popScale:   CGFloat = 1
    var popOpacity: Double  = 1
    var isPopping           = false
}

struct BSTFallBubble: Identifiable {
    let id    = UUID()
    var color: BSTBubColor
    var x, y, vx, vy: CGFloat
    var opacity: Double = 1
    var angle: Double   = 0
    var spin: Double    = Double.random(in: -4...4)
}

struct BSTProjectile {
    var color: BSTBubColor
    var x, y, vx, vy: CGFloat
    var active = false
}

struct BSTConfettiDot: Identifiable {
    let id    = UUID()
    var x, y, vx, vy: CGFloat
    var color: Color
    var size:  CGFloat
    var angle: Double = 0
    var spin:  Double
    var opacity: Double = 1
}

struct BSTPopParticle: Identifiable {
    let id    = UUID()
    var x, y, vx, vy: CGFloat
    var color: Color
    var size:  CGFloat
    var spin:  Double
    var opacity: Double = 1
}

// MARK: ─── PERSISTENCE ────────────────────────────────────────

struct BSTStats: Codable {
    var highestLevel: Int = 1
    var totalWins:    Int = 0
    var totalLosses:  Int = 0
    var bestStreak:   Int = 0
    var curStreak:    Int = 0
}

final class BSTStore {
    static let shared = BSTStore()
    private let key   = "BSStats_v2"
    func load() -> BSTStats {
        guard let d = UserDefaults.standard.data(forKey: key),
              let s = try? JSONDecoder().decode(BSTStats.self, from: d) else { return BSTStats() }
        return s
    }
    func save(_ s: BSTStats) {
        if let d = try? JSONEncoder().encode(s) { UserDefaults.standard.set(d, forKey: key) }
    }
    func reset() { UserDefaults.standard.removeObject(forKey: key) }
}

// MARK: ─── HAPTICS ────────────────────────────────────────────

final class BSTHapticEngine {
    static let shared = BSTHapticEngine()
    var enabled = true
    private let soft    = UIImpactFeedbackGenerator(style: .soft)
    private let medium  = UIImpactFeedbackGenerator(style: .medium)
    private let heavy   = UIImpactFeedbackGenerator(style: .heavy)
    private let notif   = UINotificationFeedbackGenerator()

    func shoot()    { guard enabled else { return }; medium.impactOccurred(intensity: 0.7) }
    func pop()      { guard enabled else { return }; heavy.impactOccurred(intensity: 1.0)  }
    func levelUp()  { guard enabled else { return }; notif.notificationOccurred(.success)  }
    func gameOver() { guard enabled else { return }; notif.notificationOccurred(.error)    }
    func tick()     { guard enabled else { return }; soft.impactOccurred(intensity: 0.3)   }
    func swap()     { guard enabled else { return }; soft.impactOccurred(intensity: 0.6)   }
}

// MARK: ─── GEOMETRY HELPERS ───────────────────────────────────

@inline(__always)
func BSTCellCentre(row: Int, col: Int, gridW: CGFloat) -> CGPoint {
    let spacing: CGFloat = BSDIAM * 0.97
    let rowOffset: CGFloat = (row % 2 == 0) ? 0 : BSR
    let x = BSR + rowOffset + CGFloat(col) * spacing
    let y = BSR + CGFloat(row) * (BSDIAM * 0.866)
    return CGPoint(x: x, y: y)
}

func BSTColsInRow(_ row: Int) -> Int { row % 2 == 0 ? BSCOLS : BSCOLS - 1 }

func BSTNeighbors(row: Int, col: Int) -> [(Int, Int)] {
    if row % 2 == 0 {
        return [(row-1,col-1),(row-1,col),(row,col-1),(row,col+1),(row+1,col-1),(row+1,col)]
    } else {
        return [(row-1,col),(row-1,col+1),(row,col-1),(row,col+1),(row+1,col),(row+1,col+1)]
    }
}

// MARK: ─── DISPLAY LINK BRIDGE ────────────────────────────────

final class BSTDisplayLinkBridge: NSObject {
    var onFrame: ((Double) -> Void)?
    private var link: CADisplayLink?
    private var lastTS: Double = 0

    func start() {
        link?.invalidate()
        link = CADisplayLink(target: self, selector: #selector(frame(_:)))
        link?.add(to: .main, forMode: .common)
    }
    func stop() { link?.invalidate(); link = nil }

    @objc private func frame(_ dl: CADisplayLink) {
        let dt = lastTS == 0 ? 1/60.0 : min(dl.timestamp - lastTS, 0.04)
        lastTS  = dl.timestamp
        onFrame?(dt)
    }
}

// MARK: ─── GAME PHASE ─────────────────────────────────────────

enum BSTPhase: Equatable {
    case playing
    case popping
    case levelComplete
    case gameOver
}

// MARK: ─── VIEW MODEL ─────────────────────────────────────────

@MainActor
final class BSTGameVM: ObservableObject {

    @Published var grid:        [BSTGBubble]    = []
    @Published var falls:       [BSTFallBubble] = []
    @Published var projectile:  BSTProjectile?  = nil
    @Published var confetti:    [BSTConfettiDot] = []
    @Published var popParticles:[BSTPopParticle] = []

    @Published var currentColor: BSTBubColor = .cyan
    @Published var nextColor:    BSTBubColor = .pink

    @Published var aimAngle:   Double  = -.pi / 2
    @Published var aimPts:     [CGPoint] = []
    @Published var isDragging  = false

    @Published var score:      Int = 0
    @Published var level:      Int = 1
    @Published var moves:      Int = 0
    @Published var phase:      BSTPhase = .playing

    @Published var shakeX:     CGFloat = 0
    @Published var shakeY:     CGFloat = 0
    @Published var bannerMsg:  String  = ""
    @Published var showBanner  = false
    @Published var countdown:  Int = 3

    @Published var stats:      BSTStats   = BSTStore.shared.load()

    @Published var swapsLeft: Int = 3
    @Published var predictedCellCenter: CGPoint? = nil

    var gridW:   CGFloat = 390
    var gridH:   CGFloat = 600
    var cannonY: CGFloat = 560

    private let dl    = BSTDisplayLinkBridge()
    private var timer: AnyCancellable?
    private var landQueue: DispatchWorkItem?

    var numColors: Int  { min(4 + (level - 1) / 2, 7) }
    var startRows: Int  { min(3 + level, 9) }
    var ballSpeed: CGFloat { CGFloat(520 + level * 25) }
    var target:    Int  { 500 + (level - 1) * 380 }

    init() {
        dl.onFrame = { [weak self] dt in
            guard let self else { return }
            Task { @MainActor in self.tick(dt: dt) }
        }
        newLevel()
    }

    func updateDimensions(width: CGFloat, height: CGFloat) {
        self.gridW = width
        self.gridH = height - 150
        self.cannonY = gridH - BSR * 1.5
    }

    func newLevel() {
        grid        = []
        falls       = []
        confetti    = []
        popParticles = []
        projectile  = nil
        phase       = .playing
        showBanner  = false
        swapsLeft   = 3
        predictedCellCenter = nil

        let palette = Array(BSTBubColor.allCases.prefix(numColors))
        for row in 0..<startRows {
            for col in 0..<BSTColsInRow(row) {
                grid.append(BSTGBubble(row: row, col: col,
                                    color: palette.randomElement()!))
            }
        }
        pickNext(); pickNext()
        dl.start()
    }

    func pickNext() {
        let palette = Array(BSTBubColor.allCases.prefix(numColors))
        currentColor = nextColor
        nextColor    = palette.randomElement()!
    }

    func swapBubbles() {
        guard swapsLeft > 0, phase == .playing else { return }
        let temp = currentColor
        currentColor = nextColor
        nextColor = temp
        swapsLeft -= 1
        BSTHapticEngine.shared.swap()
    }

    func drag(at pt: CGPoint) {
        isDragging = true
        let cx = gridW / 2
        let cy = cannonY
        var angle = atan2(pt.y - cy, pt.x - cx)
        angle = max(-.pi + 0.12, min(-0.12, angle))
        aimAngle = Double(angle)
        aimPts   = computeAimLine(angle: angle)
        predictedCellCenter = predictedLandingCell(angle: Double(angle))
    }

    func endDrag() {
        isDragging = false
        aimPts     = []
        predictedCellCenter = nil
        shoot()
    }

    private func computeAimLine(angle: Double) -> [CGPoint] {
        var pts   = [CGPoint]()
        let x     = gridW / 2
        let y     = cannonY
        var vx    = cos(angle) * 14.0
        let vy    = sin(angle) * 14.0
        var curX = x
        var curY = y
        pts.append(.init(x: curX, y: curY))
        for _ in 0..<90 {
            curX += vx
            curY += vy
            pts.append(.init(x: curX, y: curY))
            if curX < BSR    { curX = BSR;        vx =  abs(vx) }
            if curX > gridW - BSR { curX = gridW - BSR; vx = -abs(vx) }
            if curY < 0    { break }
        }
        return pts
    }

    func shoot() {
        guard phase == .playing, projectile == nil else { return }
        BSTHapticEngine.shared.shoot()
        let a  = aimAngle
        let sp = Double(ballSpeed)
        projectile = BSTProjectile(color: currentColor,
                                x: gridW / 2, y: cannonY,
                                vx: CGFloat(cos(a) * sp),
                                vy: CGFloat(sin(a) * sp),
                                active: true)
        moves += 1
        pickNext()
    }

    private func tick(dt: Double) {
        let f = CGFloat(dt)
        updateProjectile(f)
        updateFalls(f)
        updateConfetti(f)
        updatePopParticles(f)
    }

    private func updateProjectile(_ dt: CGFloat) {
        guard var p = projectile, p.active else { return }

        p.x += p.vx * dt
        p.y += p.vy * dt

        if p.x < BSR       { p.x = BSR;          p.vx =  abs(p.vx) }
        if p.x > gridW-BSR { p.x = gridW - BSR;  p.vx = -abs(p.vx) }

        if p.y <= BSR * 2 {
            projectile = nil
            landAt(x: p.x, y: 0, color: p.color)
            return
        }

        let thresh2: CGFloat = (BSDIAM * 0.92) * (BSDIAM * 0.92)
        for b in grid {
            let c = BSTCellCentre(row: b.row, col: b.col, gridW: gridW)
            let dx = p.x - c.x; let dy = p.y - c.y
            if dx*dx + dy*dy < thresh2 {
                projectile = nil
                landAt(x: p.x, y: p.y, color: p.color)
                return
            }
        }

        projectile = p
    }

    private func landAt(x: CGFloat, y: CGFloat, color: BSTBubColor) {
        let (row, col) = closestFreeCell(x: x, y: y)
        let nb = BSTGBubble(row: row, col: col, color: color)
        grid.append(nb)

        let matched = floodSameColor(from: nb)
        if matched.count >= 3 {
            phase = .popping
            BSTHapticEngine.shared.pop()
            score += matched.count * 10 * level

            for b in matched {
                let c = BSTCellCentre(row: b.row, col: b.col, gridW: gridW)
                spawnPopParticles(at: c, color: b.color.base)
            }

            withAnimation(.spring(response: 0.22, dampingFraction: 0.55)) {
                for id in matched.map(\.id) {
                    updateBubble(id) { $0.popScale = 1.6; $0.popOpacity = 0 }
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
                guard let self else { return }
                self.grid.removeAll { b in matched.contains(where: { $0.id == b.id }) }
                self.dropOrphans()
                self.phase = .playing
                self.checkWin()
                self.checkDanger()
            }
        } else {
            checkDanger()
        }
    }

    private func spawnPopParticles(at center: CGPoint, color: Color) {
        for _ in 0..<4 {
            let angle = Double.random(in: 0..<2 * .pi)
            let speed = CGFloat.random(in: 20...80)
            popParticles.append(BSTPopParticle(
                x: center.x, y: center.y,
                vx: cos(angle) * speed, vy: sin(angle) * speed,
                color: color,
                size: CGFloat.random(in: 3...7),
                spin: Double.random(in: -8...8),
                opacity: 1
            ))
        }
    }

    private func updatePopParticles(_ dt: CGFloat) {
        guard !popParticles.isEmpty else { return }
        let grav: CGFloat = 200
        popParticles = popParticles.compactMap { var p = $0
            p.x += p.vx * dt
            p.y += p.vy * dt
            p.vy += grav * dt
            p.opacity -= Double(dt) * 2.2
            return p.opacity > 0 ? p : nil
        }
    }

    private func closestFreeCell(x: CGFloat, y: CGFloat) -> (Int, Int) {
        var bestRow = 0, bestCol = 0, bestD = CGFloat.infinity
        for row in 0..<BSMAX_ROWS {
            for col in 0..<BSTColsInRow(row) {
                if grid.contains(where: { $0.row == row && $0.col == col }) { continue }
                let c = BSTCellCentre(row: row, col: col, gridW: gridW)
                let d = hypot(x - c.x, y - c.y)
                if d < bestD { bestD = d; bestRow = row; bestCol = col }
            }
        }
        return (bestRow, bestCol)
    }

    private func floodSameColor(from start: BSTGBubble) -> [BSTGBubble] {
        var visited = Set<UUID>([start.id])
        var queue   = [start]
        var result  = [BSTGBubble]()
        while !queue.isEmpty {
            let cur = queue.removeFirst()
            result.append(cur)
            for (nr, nc) in BSTNeighbors(row: cur.row, col: cur.col) {
                if let nb = grid.first(where: { $0.row == nr && $0.col == nc }),
                   !visited.contains(nb.id), nb.color == start.color {
                    visited.insert(nb.id)
                    queue.append(nb)
                }
            }
        }
        return result
    }

    private func dropOrphans() {
        var supported = Set<UUID>()
        var q = grid.filter { $0.row == 0 }
        q.forEach { supported.insert($0.id) }
        while !q.isEmpty {
            let cur = q.removeFirst()
            for (nr, nc) in BSTNeighbors(row: cur.row, col: cur.col) {
                if let nb = grid.first(where: { $0.row == nr && $0.col == nc }),
                   !supported.contains(nb.id) {
                    supported.insert(nb.id)
                    q.append(nb)
                }
            }
        }
        let orphans = grid.filter { !supported.contains($0.id) }
        grid.removeAll { b in orphans.contains(where: { $0.id == b.id }) }
        score += orphans.count * 5 * level
        for b in orphans {
            let c = BSTCellCentre(row: b.row, col: b.col, gridW: gridW)
            falls.append(BSTFallBubble(color: b.color, x: c.x, y: c.y,
                                    vx: .random(in: -50...50), vy: -80))
            spawnPopParticles(at: c, color: b.color.base)
        }
    }

    private func updateFalls(_ dt: CGFloat) {
        guard !falls.isEmpty else { return }
        let grav: CGFloat = 900
        falls = falls.compactMap { var b = $0
            b.vy      += grav * dt
            b.x       += b.vx * dt
            b.y       += b.vy * dt
            b.angle   += b.spin * Double(dt)
            b.opacity -= Double(dt) * 1.6
            return b.opacity > 0 ? b : nil
        }
    }

    private func updateConfetti(_ dt: CGFloat) {
        guard !confetti.isEmpty else { return }
        let grav: CGFloat = 350
        confetti = confetti.compactMap { var p = $0
            p.x       += p.vx * CGFloat(dt)
            p.y       += p.vy * CGFloat(dt)
            p.vy      += grav * CGFloat(dt)
            p.angle   += p.spin * dt
            p.opacity -= dt * 0.45
            return p.opacity > 0 ? p : nil
        }
    }

    private func predictedLandingCell(angle: Double) -> CGPoint? {
        let speed = ballSpeed
        let vx = CGFloat(cos(angle) * Double(speed))
        let vy = CGFloat(sin(angle) * Double(speed))
        var x: CGFloat = gridW / 2
        var y: CGFloat = cannonY
        let step: CGFloat = 2.0
        let maxSteps = 800
        var vxNow = vx
        let vyNow = vy

        for _ in 0..<maxSteps {
            x += vxNow * step
            y += vyNow * step
            if x < BSR { x = BSR; vxNow = abs(vxNow) }
            if x > gridW - BSR { x = gridW - BSR; vxNow = -abs(vxNow) }
            if y <= BSR * 2 { break }
            let thresh2: CGFloat = (BSDIAM * 0.92) * (BSDIAM * 0.92)
            var collided = false
            for b in grid {
                let c = BSTCellCentre(row: b.row, col: b.col, gridW: gridW)
                let dx = x - c.x; let dy = y - c.y
                if dx*dx + dy*dy < thresh2 { collided = true; break }
            }
            if collided { break }
        }
        let (row, col) = closestFreeCell(x: x, y: y)
        return BSTCellCentre(row: row, col: col, gridW: gridW)
    }

    private func checkWin() {
        guard phase == .playing else { return }
        if grid.isEmpty || score >= target { triggerWin() }
    }

    private func checkDanger() {
        guard phase == .playing else { return }
        if grid.contains(where: { $0.row >= BSDANGER_ROW }) { triggerLoss() }
    }

    private func triggerWin() {
        phase = .levelComplete
        BSTHapticEngine.shared.levelUp()
        spawnConfetti()
        stats.totalWins  += 1
        stats.curStreak  += 1
        stats.bestStreak  = max(stats.bestStreak, stats.curStreak)
        if level > stats.highestLevel { stats.highestLevel = level }
        BSTStore.shared.save(stats)
        bannerMsg  = "LEVEL \(level) CLEAR! 🎉"
        showBanner = true
        countdown  = 3
        startCountdown()
    }

    private func startCountdown() {
        var c = 3
        timer?.cancel()
        timer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                c -= 1
                self.countdown = c
                if c <= 0 {
                    self.timer?.cancel()
                    self.level  += 1
                    self.score   = 0
                    self.moves   = 0
                    withAnimation(.spring(response: 0.4)) { self.showBanner = false }
                    self.newLevel()
                }
            }
    }

    private func triggerLoss() {
        phase = .gameOver
        dl.stop()
        BSTHapticEngine.shared.gameOver()
        stats.totalLosses += 1
        stats.curStreak    = 0
        BSTStore.shared.save(stats)
        doShake()
    }

    func retryLevel() {
        score = 0; moves = 0
        withAnimation { showBanner = false }
        newLevel()
    }

    func mainMenu() {
        level = 1; score = 0; moves = 0
        withAnimation { showBanner = false }
        newLevel()
    }

    private func doShake() {
        let times: [Double] = [0, 0.05, 0.10, 0.15, 0.20, 0.25, 0.30]
        let offsets: [CGFloat] = [0, 12, -12, 10, -10, 6, 0]
        for (i, t) in times.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + t) { [weak self] in
                withAnimation(.linear(duration: 0.05)) {
                    self?.shakeX = offsets[i]
                    self?.shakeY = offsets[i] * 0.3
                }
            }
        }
    }

    private func spawnConfetti() {
        let colors: [Color] = [.red, .yellow, .green, .cyan, .purple, .orange, .pink, .white]
        confetti = (0..<100).map { _ in
            BSTConfettiDot(
                x:     .random(in: 30...gridW-30),
                y:     .random(in: -60...20),
                vx:    .random(in: -80...80),
                vy:    .random(in: 40...200),
                color: colors.randomElement()!,
                size:  .random(in: 5...12),
                spin:  .random(in: -6...6),
                opacity: 1
            )
        }
    }

    private func updateBubble(_ id: UUID, _ transform: (inout BSTGBubble) -> Void) {
        if let i = grid.firstIndex(where: { $0.id == id }) { transform(&grid[i]) }
    }
}

// MARK: ─── SIMPLE ROOT VIEW ───────────────────────────────────

struct BSTGameView: View {
    @StateObject private var vm   = BSTGameVM()
    @State private var tab: Int   = 0

    var body: some View {
        ZStack {
            switch tab {
            case 0:
                BSTGameScreen(vm: vm)
            case 1:
                BSTStatsScreen(vm: vm)
            case 2:
                BSTSettingsScreen(vm: vm)
            default:
                BSTGameScreen(vm: vm)
            }
            
            // Bottom Tab Bar
            VStack {
                Spacer()
                HStack(spacing: 0) {
                    BSTTabBtn(icon: "scope", label: "Game", selected: tab == 0) { tab = 0 }
                    BSTTabBtn(icon: "chart.bar.xaxis", label: "Stats", selected: tab == 1) { tab = 1 }
                    BSTTabBtn(icon: "slider.horizontal.3", label: "Settings", selected: tab == 2) { tab = 2 }
                }
                .frame(height: 50)
                .background(AppTheme.surface)
                .overlay(Rectangle().frame(height: 1).foregroundColor(AppTheme.accent.opacity(0.2)), alignment: .top)
            }
        }
        .background(AppTheme.background.ignoresSafeArea())
        .preferredColorScheme(.dark)
    }
}

struct BSTTabBtn: View {
    let icon: String
    let label: String
    let selected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                Text(label)
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
            }
            .foregroundColor(selected ? BSTTheme.accent : .white.opacity(0.4))
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: ─── GAME SCREEN ────────────────────────────────────────

struct BSTGameScreen: View {
    @ObservedObject var vm: BSTGameVM

    var body: some View {
        GeometryReader { geo in
            ZStack {
                BSTMeshBackground()

                BSTGameCanvas(vm: vm)
                    .offset(x: vm.shakeX, y: vm.shakeY)

                if vm.showBanner && vm.phase == .levelComplete {
                    BSTLevelClearOverlay(vm: vm)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.7).combined(with: .opacity),
                            removal: .scale(scale: 1.1).combined(with: .opacity)))
                        .zIndex(10)
                }

                if vm.phase == .gameOver {
                    BSTGameOverOverlay(vm: vm)
                        .transition(.opacity.combined(with: .scale(scale: 0.92)))
                        .zIndex(10)
                }
            }
        }
    }
}

// MARK: ─── GAME CANVAS ──────────────────────────────

struct BSTGameCanvas: View {
    @ObservedObject var vm: BSTGameVM

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {

                // HUD strip
                VStack {
                    Spacer()
                    BSTHUDStrip(vm: vm)
                        .padding(.bottom, 120)
                }
                .zIndex(5)

                // Grid bubbles
                ForEach(vm.grid) { b in
                    let c = BSTCellCentre(row: b.row, col: b.col, gridW: vm.gridW)
                    BSTPremiumBubble(color: b.color, radius: BSR)
                        .scaleEffect(b.popScale)
                        .opacity(b.popOpacity)
                        .position(c)
                }

                // Danger line
                let dangerY = BSTCellCentre(row: BSDANGER_ROW, col: 0, gridW: vm.gridW).y - BSR
                BSTDangerLine(y: dangerY, width: vm.gridW)

                // Aim line
                if vm.isDragging && vm.phase == .playing {
                    BSTAimPath(pts: vm.aimPts, color: vm.currentColor.base)
                }

                // Landing preview
                if let cellCenter = vm.predictedCellCenter, vm.isDragging && vm.phase == .playing {
                    BSTPremiumBubble(color: vm.currentColor, radius: BSR)
                        .opacity(0.4)
                        .scaleEffect(0.9)
                        .position(cellCenter)
                }

                // Projectile
                if let p = vm.projectile {
                    BSTPremiumBubble(color: p.color, radius: BSR)
                        .position(CGPoint(x: p.x, y: p.y))
                }

                // Falling bubbles
                ForEach(vm.falls) { f in
                    BSTPremiumBubble(color: f.color, radius: BSR * 0.82)
                        .rotationEffect(.radians(f.angle))
                        .opacity(f.opacity)
                        .position(CGPoint(x: f.x, y: f.y))
                }

                // Pop particles
                ForEach(vm.popParticles) { p in
                    Circle()
                        .fill(p.color)
                        .frame(width: p.size, height: p.size)
                        .opacity(p.opacity)
                        .position(CGPoint(x: p.x, y: p.y))
                }

                // Confetti
                ForEach(vm.confetti) { p in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(p.color)
                        .frame(width: p.size, height: p.size * 0.55)
                        .rotationEffect(.radians(p.angle))
                        .opacity(p.opacity)
                        .position(CGPoint(x: p.x, y: p.y))
                }

                // Cannon section
                VStack {
                    Spacer()
                    BSTCannonSection(vm: vm)
                }
                .frame(width: vm.gridW)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .local)
                    .onChanged { v in vm.drag(at: v.location) }
                    .onEnded   { _ in vm.endDrag() }
            )
            .onAppear {
                vm.updateDimensions(width: geo.size.width, height: geo.size.height)
            }
            .onChange(of: geo.size) { _, newSize in
                vm.updateDimensions(width: newSize.width, height: newSize.height)
            }
        }
    }
}

// MARK: ─── PREMIUM BUBBLE ─────────────────────────────────────

struct BSTPremiumBubble: View {
    let color:  BSTBubColor
    let radius: CGFloat

    var body: some View {
        let d = radius * 2
        ZStack {
            Circle()
                .fill(color.glow)
                .frame(width: d * 1.5, height: d * 1.5)
                .blur(radius: radius * 0.7)

            Circle()
                .fill(
                    RadialGradient(
                        stops: [
                            .init(color: color.base.opacity(0.15), location: 0),
                            .init(color: color.base,               location: 0.55),
                            .init(color: color.base.opacity(0.75), location: 1.0),
                        ],
                        center: .init(x: 0.38, y: 0.32),
                        startRadius: 0,
                        endRadius: radius * 1.4
                    )
                )
                .frame(width: d, height: d)

            Circle()
                .strokeBorder(
                    LinearGradient(colors: [.white.opacity(0.6), color.base.opacity(0.1)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 1.2
                )
                .frame(width: d, height: d)

            Ellipse()
                .fill(
                    RadialGradient(colors: [.white.opacity(0.75), .clear],
                                   center: .center, startRadius: 0, endRadius: radius * 0.6)
                )
                .frame(width: radius * 0.72, height: radius * 0.44)
                .offset(x: -radius * 0.14, y: -radius * 0.28)
                .blur(radius: 0.5)
        }
        .frame(width: d, height: d)
    }
}

// MARK: ─── AIM PATH ───────────────────────────────────────────

struct BSTAimPath: View {
    let pts:   [CGPoint]
    let color: Color

    var body: some View {
        Canvas { ctx, _ in
            guard pts.count > 2 else { return }
            var i = 0
            while i < pts.count - 1 {
                var seg = Path()
                seg.move(to: pts[i])
                seg.addLine(to: pts[min(i+1, pts.count-1)])
                let alpha = 1.0 - Double(i) / Double(pts.count)
                ctx.stroke(seg, with: .color(color.opacity(alpha * 0.55)),
                           style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [5,5]))
                i += 2
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: ─── DANGER LINE ────────────────────────────────────────

struct BSTDangerLine: View {
    let y:     CGFloat
    let width: CGFloat

    var body: some View {
        ZStack(alignment: .leading) {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [BSTTheme.danger.opacity(0.0),
                                 BSTTheme.danger.opacity(0.7),
                                 BSTTheme.danger.opacity(0.0)],
                        startPoint: .leading, endPoint: .trailing
                    )
                )
                .frame(width: width, height: 1.5)
                .position(x: width / 2, y: y)
                .blur(radius: 1)

            Text("DANGER")
                .font(.system(size: 8, weight: .black, design: .monospaced))
                .tracking(3)
                .foregroundColor(BSTTheme.danger.opacity(0.6))
                .position(x: 36, y: y - 9)
        }
        .allowsHitTesting(false)
    }
}

// MARK: ─── HUD STRIP ──────────────────────────────────────────

struct BSTHUDStrip: View {
    @ObservedObject var vm: BSTGameVM

    var body: some View {
        HStack(spacing: 12) {
            BSTHUDPill(label: "LEVEL", value: "\(vm.level)", color: BSTTheme.accent)

            VStack(spacing: 10) {
                Text("SCORE")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.5))

                Text("\(vm.score)")
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .contentTransition(.numericText())

                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.08))
                        Capsule()
                            .fill(
                                LinearGradient(colors: [BSTTheme.gold, BSTTheme.accent],
                                               startPoint: .leading, endPoint: .trailing)
                            )
                            .frame(width: g.size.width *
                                   min(1, CGFloat(vm.score) / CGFloat(vm.target)))
                    }
                }
                .frame(height: 3)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 10)
            .padding(.vertical, 14)
            .background(RoundedRectangle(cornerRadius: 24)
                            .fill(.ultraThinMaterial.opacity(0.9))
                            .overlay(RoundedRectangle(cornerRadius: 24)
                                        .stroke(BSTTheme.gold.opacity(0.2))))

            BSTHUDPill(label: "SHOTS", value: "\(vm.moves)", color: BSTTheme.neonPink)
        }
        .padding(.horizontal, 14)
    }
}

struct BSTHUDPill: View {
    let label: String
    let value: String
    let color: Color

    @State private var float = false

    var body: some View {
        VStack(spacing: 6) {
            Text(label)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.65))

            Text(value)
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundColor(.white)
                .contentTransition(.numericText())
                .offset(y: float ? -2 : 2)
                .animation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true),
                           value: float)
        }
        .frame(width: 90, height: 78)
        .background(RoundedRectangle(cornerRadius: 20)
                        .fill(.ultraThinMaterial.opacity(0.9))
                        .overlay(RoundedRectangle(cornerRadius: 20)
                                    .stroke(color.opacity(0.35), lineWidth: 1)))
        .shadow(color: color.opacity(0.15), radius: 8)
        .onAppear { float = true }
    }
}

// MARK: ─── CANNON SECTION ───────────────────────

struct BSTCannonSection: View {
    @ObservedObject var vm: BSTGameVM

    var body: some View {
        ZStack {
            Ellipse()
                .fill(BSTTheme.accent.opacity(0.08))
                .frame(width: 160, height: 28)
                .blur(radius: 8)
                .offset(y: 18)

            Capsule()
                .fill(LinearGradient(colors: [Color(hex:"1A1A2E"), Color(hex:"0D0D1A")],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: 140, height: 16)
                .overlay(Capsule().strokeBorder(BSTTheme.cardBorder, lineWidth: 1))
                .offset(y: 18)

            RoundedRectangle(cornerRadius: 5)
                .fill(LinearGradient(colors: [Color(hex:"3A3A5C"), Color(hex:"1E1E30")],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 16, height: 40)
                .overlay(RoundedRectangle(cornerRadius: 5)
                            .strokeBorder(BSTTheme.accent.opacity(0.35), lineWidth: 1))
                .shadow(color: BSTTheme.accent.opacity(0.3), radius: 6)
                .rotationEffect(.radians(vm.aimAngle + .pi/2))
                .offset(y: -2)
                .animation(.interactiveSpring(response: 0.12), value: vm.aimAngle)

            BSTPremiumBubble(color: vm.currentColor, radius: BSR)
                .offset(y: 10)
                .animation(.spring(response: 0.3), value: vm.currentColor)

            VStack(spacing: 1) {
                Text("NEXT")
                    .font(.system(size: 7, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.3))
                BSTPremiumBubble(color: vm.nextColor, radius: BSR * 0.65)
            }
            .offset(x: 60, y: 8)
            .animation(.spring(response: 0.3), value: vm.nextColor)

            Button {
                vm.swapBubbles()
            } label: {
                ZStack {
                    Circle()
                        .fill(BSTTheme.accentSoft)
                        .frame(width: 36, height: 36)
                    Image(systemName: "arrow.triangle.swap")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(BSTTheme.accent)
                }
            }
            .disabled(vm.swapsLeft == 0 || vm.phase != .playing)
            .offset(x: -90, y: 8)

            if vm.swapsLeft > 0 {
                Text("\(vm.swapsLeft)")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(4)
                    .background(Circle().fill(BSTTheme.accent.opacity(0.9)))
                    .offset(x: -90, y: -12)
            }
        }
        .frame(height: 90)
    }
}

// MARK: ─── MESH BACKGROUND ────────────────────────────────────

struct BSTMeshBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [BSTTheme.bg1, BSTTheme.bg2, Color(hex:"0A0520")],
                           startPoint: .topLeading, endPoint: .bottomTrailing)

            TimelineView(.animation(minimumInterval: 0.04)) { t in
                let s = t.date.timeIntervalSince1970
                ZStack {
                    Circle()
                        .fill(Color(hex:"1A0050").opacity(0.6))
                        .frame(width: 300)
                        .offset(x: CGFloat(sin(s * 0.18)) * 80,
                                y: CGFloat(cos(s * 0.12)) * 100 - 100)
                        .blur(radius: 90)

                    Circle()
                        .fill(Color(hex:"003A5C").opacity(0.5))
                        .frame(width: 260)
                        .offset(x: CGFloat(cos(s * 0.14)) * 70,
                                y: CGFloat(sin(s * 0.20)) * 80 + 200)
                        .blur(radius: 80)

                    Circle()
                        .fill(Color(hex:"400040").opacity(0.35))
                        .frame(width: 200)
                        .offset(x: CGFloat(sin(s * 0.22 + 1)) * 60,
                                y: CGFloat(cos(s * 0.16)) * 50 + 400)
                        .blur(radius: 70)
                }
            }

            BSTGridPattern()
                .stroke(Color.white.opacity(0.025), lineWidth: 0.5)
                .ignoresSafeArea()
        }
        .ignoresSafeArea()
    }
}

struct BSTGridPattern: Shape {
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

// MARK: ─── LEVEL CLEAR OVERLAY ────────────────────────────────

struct BSTLevelClearOverlay: View {
    @ObservedObject var vm: BSTGameVM
    @State private var starScale: CGFloat = 0.5
    @State private var starOpacity: Double = 0

    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
                .background(.ultraThinMaterial.opacity(0.3))

            VStack(spacing: 20) {
                HStack(spacing: 8) {
                    ForEach(0..<3) { i in
                        Image(systemName: "star.fill")
                            .font(.system(size: 34))
                            .foregroundStyle(
                                LinearGradient(colors: [BSTTheme.gold, Color(hex:"FFA500")],
                                               startPoint: .top, endPoint: .bottom)
                            )
                            .scaleEffect(starScale)
                            .opacity(starOpacity)
                            .shadow(color: BSTTheme.gold.opacity(0.8), radius: 12)
                            .animation(.spring(response: 0.4, dampingFraction: 0.5)
                                        .delay(Double(i) * 0.1), value: starScale)
                    }
                }

                Text("LEVEL CLEAR!")
                    .font(.system(size: 36, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(colors: [BSTTheme.gold, Color(hex:"FFA040"), BSTTheme.gold],
                                       startPoint: .leading, endPoint: .trailing)
                    )
                    .shadow(color: BSTTheme.gold.opacity(0.5), radius: 16)

                Text("Level \(vm.level) Complete")
                    .font(.system(size: 16, design: .monospaced))
                    .foregroundColor(.white.opacity(0.55))

                HStack(spacing: 6) {
                    Image(systemName: "bolt.fill")
                        .foregroundColor(BSTTheme.accent)
                    Text("\(vm.score) pts")
                        .font(.system(size: 22, weight: .bold, design: .monospaced))
                        .foregroundColor(BSTTheme.accent)
                }
                .padding(.horizontal, 20).padding(.vertical, 8)
                .background(BSTTheme.accentSoft)
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(BSTTheme.accent.opacity(0.3)))

                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.1), lineWidth: 3)
                        .frame(width: 56, height: 56)
                    Text("\(vm.countdown)")
                        .font(.system(size: 26, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .contentTransition(.numericText(countsDown: true))
                        .animation(.spring(response: 0.3), value: vm.countdown)
                    Text("next level")
                        .font(.system(size: 7, design: .monospaced))
                        .foregroundColor(.white.opacity(0.4))
                        .offset(y: 32)
                }
            }
            .padding(36)
            .background(
                RoundedRectangle(cornerRadius: 28)
                    .fill(Color(hex: "0D0A20").opacity(0.95))
                    .overlay(
                        RoundedRectangle(cornerRadius: 28)
                            .strokeBorder(
                                LinearGradient(colors: [BSTTheme.gold.opacity(0.6), BSTTheme.gold.opacity(0.1), BSTTheme.gold.opacity(0.6)],
                                               startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.5
                            )
                    )
            )
            .shadow(color: BSTTheme.gold.opacity(0.2), radius: 40)
            .padding(.horizontal, 36)
        }
        .onAppear { withAnimation { starScale = 1; starOpacity = 1 } }
    }
}

// MARK: ─── GAME OVER OVERLAY ──────────────────────────────────

struct BSTGameOverOverlay: View {
    @ObservedObject var vm: BSTGameVM
    @State private var appear = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.72).ignoresSafeArea()
                .background(.ultraThinMaterial.opacity(0.25))

            VStack(spacing: 22) {
                ZStack {
                    Circle()
                        .fill(BSTTheme.danger.opacity(0.15))
                        .frame(width: 88, height: 88)
                    Circle()
                        .stroke(BSTTheme.danger.opacity(0.4), lineWidth: 1.5)
                        .frame(width: 88, height: 88)
                    Image(systemName: "xmark")
                        .font(.system(size: 38, weight: .black))
                        .foregroundColor(BSTTheme.danger)
                }
                .scaleEffect(appear ? 1 : 0.3)
                .animation(.spring(response: 0.45, dampingFraction: 0.6), value: appear)

                VStack(spacing: 6) {
                    Text("GAME OVER")
                        .font(.system(size: 38, weight: .black, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(colors: [BSTTheme.danger, Color(hex:"FF8060")],
                                           startPoint: .leading, endPoint: .trailing)
                        )
                        .shadow(color: BSTTheme.danger.opacity(0.6), radius: 12)

                    Text("Level \(vm.level)  •  \(vm.score) pts")
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundColor(.white.opacity(0.45))
                }

                VStack(spacing: 12) {
                    Button { withAnimation { vm.retryLevel() } } label: {
                        Label("Try Again", systemImage: "arrow.clockwise")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity).frame(height: 52)
                            .background(
                                LinearGradient(colors: [BSTTheme.accent, Color(hex:"0080FF")],
                                               startPoint: .leading, endPoint: .trailing)
                            )
                            .cornerRadius(14)
                            .shadow(color: BSTTheme.accent.opacity(0.4), radius: 12)
                    }

                    Button { withAnimation { vm.mainMenu() } } label: {
                        Label("Main Menu", systemImage: "house")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white.opacity(0.65))
                            .frame(maxWidth: .infinity).frame(height: 46)
                            .background(Color.white.opacity(0.07))
                            .cornerRadius(14)
                            .overlay(RoundedRectangle(cornerRadius: 14)
                                        .stroke(Color.white.opacity(0.1)))
                    }
                }
                .padding(.horizontal, 4)
            }
            .padding(28)
            .background(
                RoundedRectangle(cornerRadius: 28)
                    .fill(Color(hex:"0A0818").opacity(0.96))
                    .overlay(
                        RoundedRectangle(cornerRadius: 28)
                            .stroke(BSTTheme.danger.opacity(0.3), lineWidth: 1)
                    )
            )
            .padding(.horizontal, 32)
            .shadow(color: BSTTheme.danger.opacity(0.15), radius: 40)
        }
        .onAppear { withAnimation(.easeOut(duration: 0.3)) { appear = true } }
    }
}

// MARK: ─── STATS SCREEN ───────────────────────────────────────

struct BSTStatsScreen: View {
    @ObservedObject var vm: BSTGameVM

    var winRate: Double {
        let t = vm.stats.totalWins + vm.stats.totalLosses
        return t > 0 ? Double(vm.stats.totalWins) / Double(t) : 0
    }

    var body: some View {
        ZStack {
            BSTMeshBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 28) {
                    VStack(spacing: 4) {
                        Text("YOUR STATS")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .tracking(4)
                            .foregroundColor(BSTTheme.accent.opacity(0.6))
                        Text("Performance")
                            .font(.system(size: 30, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                    }
                    .padding(.top, 60)

                    BSTWinRateRing(rate: winRate)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                        BSTStatTile(icon: "trophy.fill",      label: "Best Level",
                                 value: "\(vm.stats.highestLevel)",   color: BSTTheme.gold)
                        BSTStatTile(icon: "checkmark.seal.fill", label: "Total Wins",
                                 value: "\(vm.stats.totalWins)",      color: Color(hex:"00E87A"))
                        BSTStatTile(icon: "xmark.octagon.fill",  label: "Total Losses",
                                 value: "\(vm.stats.totalLosses)",    color: BSTTheme.danger)
                        BSTStatTile(icon: "flame.fill",          label: "Best Streak",
                                 value: "\(vm.stats.bestStreak)",     color: Color(hex:"FF8C00"))
                    }
                    .padding(.horizontal)

                    Spacer(minLength: 40)
                }
            }
        }
    }
}

struct BSTWinRateRing: View {
    let rate: Double
    @State private var progress: Double = 0

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.06), lineWidth: 14)
                .frame(width: 160, height: 160)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    AngularGradient(colors: [Color(hex:"00E87A"), BSTTheme.accent, Color(hex:"00E87A")],
                                    center: .center),
                    style: StrokeStyle(lineWidth: 14, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .frame(width: 160, height: 160)
                .animation(.spring(response: 1.2, dampingFraction: 0.7), value: progress)

            VStack(spacing: 2) {
                Text(String(format: "%.0f%%", progress * 100))
                    .font(.system(size: 36, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                Text("WIN RATE")
                    .font(.system(size: 9, design: .monospaced))
                    .tracking(2)
                    .foregroundColor(.white.opacity(0.4))
            }
        }
        .onAppear { progress = rate }
        .onChange(of: rate) { _, v in progress = v }
    }
}

struct BSTStatTile: View {
    let icon, label, value: String
    let color: Color

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle().fill(color.opacity(0.12)).frame(width: 44, height: 44)
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(color)
            }
            Text(value)
                .font(.system(size: 30, weight: .black, design: .rounded))
                .foregroundColor(.white)
            Text(label)
                .font(.system(size: 10, design: .monospaced))
                .tracking(0.5)
                .foregroundColor(.white.opacity(0.4))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 22)
        .background(BSTTheme.cardBg)
        .cornerRadius(18)
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(color.opacity(0.18), lineWidth: 1))
    }
}

// MARK: ─── SETTINGS SCREEN ────────────────────────────────────

struct BSTSettingsScreen: View {
    @ObservedObject var vm: BSTGameVM
    @State private var hapticsOn    = BSTHapticEngine.shared.enabled
    @State private var showAlert    = false

    var body: some View {
        ZStack {
            BSTMeshBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    VStack(spacing: 4) {
                        Text("SETTINGS")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .tracking(4)
                            .foregroundColor(BSTTheme.accent.opacity(0.6))
                        Text("Preferences")
                            .font(.system(size: 30, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                    }
                    .padding(.top, 60)

                    VStack(spacing: 0) {
                        BSTSettingsToggle(label: "Haptic Feedback",
                                       icon: "hand.tap.fill",
                                       color: Color(hex:"BF5FFF"),
                                       isOn: $hapticsOn)
                        .onChange(of: hapticsOn) { _, v in BSTHapticEngine.shared.enabled = v }
                    }
                    .background(BSTTheme.cardBg)
                    .cornerRadius(16)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(BSTTheme.cardBorder))
                    .padding(.horizontal)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("LEVEL \(vm.level) DIFFICULTY")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .tracking(1.5)
                            .foregroundColor(.white.opacity(0.35))
                            .padding(.horizontal, 4)

                        HStack(spacing: 10) {
                            BSTDiffPill(label: "Colors",  val: vm.numColors, color: Color(hex:"FF8C00"))
                            BSTDiffPill(label: "Rows",    val: vm.startRows, color: Color(hex:"1E90FF"))
                            BSTDiffPill(label: "Speed",   val: Int(vm.ballSpeed) / 10, color: Color(hex:"00E87A"))
                        }
                    }
                    .padding(.horizontal)

                    Button { showAlert = true } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "trash")
                            Text("Reset All Progress")
                        }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(BSTTheme.danger)
                        .frame(maxWidth: .infinity).frame(height: 50)
                        .background(BSTTheme.danger.opacity(0.08))
                        .cornerRadius(14)
                        .overlay(RoundedRectangle(cornerRadius: 14)
                                    .stroke(BSTTheme.danger.opacity(0.25)))
                    }
                    .padding(.horizontal)

                    Spacer(minLength: 40)
                }
            }
        }
        .alert("Reset Progress?", isPresented: $showAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                BSTStore.shared.reset()
                vm.stats = BSTStats()
                vm.level = 1; vm.score = 0; vm.moves = 0
                vm.newLevel()
            }
        } message: {
            Text("All stats will be permanently erased.")
        }
    }
}

struct BSTSettingsToggle: View {
    let label, icon: String
    let color: Color
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(color.opacity(0.15))
                    .frame(width: 34, height: 34)
                Image(systemName: icon)
                    .font(.system(size: 15))
                    .foregroundColor(color)
            }
            Text(label)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white)
            Spacer()
            Toggle("", isOn: $isOn).tint(color)
        }
        .padding(.horizontal, 16).padding(.vertical, 13)
    }
}

struct BSTDiffPill: View {
    let label: String; let val: Int; let color: Color

    var body: some View {
        VStack(spacing: 3) {
            Text("\(val)")
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity).padding(.vertical, 14)
        .background(color.opacity(0.08))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(color.opacity(0.2)))
    }
}