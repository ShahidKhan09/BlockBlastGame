// ============================================================
// PongGame.swift – Single-file SwiftUI Pong (iOS 17+)
// Modes: Basic • Classic • Adventure • Light/Dark
// ============================================================

import SwiftUI
import AVFoundation
import CoreHaptics

// MARK: - Appearance
enum PongAppearanceMode: String, CaseIterable, Identifiable {
    case system = "System", light = "Light", dark = "Dark"
    var id: String { rawValue }
    var colorScheme: ColorScheme? {
        switch self { case .light: return .light; case .dark: return .dark; case .system: return nil }
    }
}

final class PongAppearanceStore: ObservableObject {
    static let shared = PongAppearanceStore()
    private let key = "pong_appearance_mode"
    @Published var currentMode: PongAppearanceMode = .system {
        didSet { UserDefaults.standard.set(currentMode.rawValue, forKey: key) }
    }
    private init() {
        let saved = UserDefaults.standard.string(forKey: key) ?? ""
        currentMode = PongAppearanceMode(rawValue: saved) ?? .system
    }
}

// MARK: - Haptics
final class PongHapticEngine {
    static let shared = PongHapticEngine()
    private var chEngine: CHHapticEngine?
    private init() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        chEngine = try? CHHapticEngine(); try? chEngine?.start()
        chEngine?.resetHandler = { [weak self] in try? self?.chEngine?.start() }
    }
    enum Kind { case light, medium, heavy, success, error }
    func play(_ kind: Kind) {
        DispatchQueue.main.async {
            switch kind {
            case .light: UIImpactFeedbackGenerator(style: .light).impactOccurred()
            case .medium: UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            case .heavy: UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            case .success: UINotificationFeedbackGenerator().notificationOccurred(.success)
            case .error: UINotificationFeedbackGenerator().notificationOccurred(.error)
            }
        }
    }
}

// MARK: - Sound
final class PongSoundEngine {
    static let shared = PongSoundEngine()
    private init() { try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default); try? AVAudioSession.sharedInstance().setActive(true) }
    enum SoundType { case paddleHit, wallHit, score, gameOver, powerUp, combo }
    func play(_ type: SoundType) { DispatchQueue.global(qos: .userInteractive).async { self.synthesise(type) } }
    private func synthesise(_ type: SoundType) {
        let sr: Double = 44100; let freq: Double; let dur: Double; let wf: (Double, Double) -> Float
        switch type {
        case .paddleHit: freq=480; dur=0.06; wf = { t,f in Float(sin(2*Double.pi*f*t)) }
        case .wallHit: freq=320; dur=0.05; wf = { t,f in Float(sin(2*Double.pi*f*t)) }
        case .score: freq=880; dur=0.22; wf = { t,f in Float((sin(2*Double.pi*f*t)+0.3*sin(4*Double.pi*f*t))*0.5) }
        case .gameOver: freq=220; dur=0.50; wf = { t,f in Float(sin(2*Double.pi*(f+sin(6*Double.pi*t)*40)*t)*0.6) }
        case .powerUp: freq=660; dur=0.28; wf = { t,f in Float(sin(2*Double.pi*(f+t*300)*t)*0.55) }
        case .combo: freq=1100; dur=0.15; wf = { t,f in Float(sin(2*Double.pi*f*t)*0.7) }
        }
        let fc = AVAudioFrameCount(sr * dur)
        guard let buf = AVAudioPCMBuffer(pcmFormat: AVAudioFormat(standardFormatWithSampleRate: sr, channels: 1)!, frameCapacity: fc) else { return }
        buf.frameLength = fc; let data = buf.floatChannelData![0]
        for i in 0..<Int(fc) { let t = Double(i)/sr; let env = min(1.0, min(t/0.005, (dur-t)/0.01)); data[i] = wf(t, freq) * Float(env) * 0.6 }
        let e = AVAudioEngine(); let p = AVAudioPlayerNode(); e.attach(p); e.connect(p, to: e.mainMixerNode, format: buf.format)
        try? e.start(); p.scheduleBuffer(buf); p.play(); Thread.sleep(forTimeInterval: dur + 0.05); e.stop()
    }
}

// MARK: - Game Mode
enum PongGameMode: String, CaseIterable, Identifiable {
    case basic = "BASIC", classic = "CLASSIC", adventure = "ADVENTURE"
    var id: String { rawValue }
    var subtitle: String { switch self { case .basic: return "Beginner Friendly"; case .classic: return "Pure Retro"; case .adventure: return "Power-ups + Streaks" } }
    var icon: String { switch self { case .basic: return "leaf.fill"; case .classic: return "gamecontroller.fill"; case .adventure: return "flame.fill" } }
    var color: Color { switch self { case .basic: return .neonGreen; case .classic: return .neonCyan; case .adventure: return .neonPink } }
}

// MARK: - Difficulty
enum PongDifficulty: String, CaseIterable, Identifiable {
    case easy="EASY", medium="MEDIUM", hard="HARD", insane="INSANE"
    var id: String { rawValue }
    var aiSpeed: CGFloat { [Self.easy:2.6, .medium:3.8, .hard:5.2, .insane:7.0][self]! }
    var ballSpeed: CGFloat { [Self.easy:4.2, .medium:5.2, .hard:6.4, .insane:8.0][self]! }
    var aiError: CGFloat { [Self.easy:55, .medium:28, .hard:12, .insane:2.0][self]! }
    var color: Color { switch self { case .easy: return .neonGreen; case .medium: return .neonCyan; case .hard: return .neonOrange; case .insane: return .neonPink } }
    var icon: String { switch self { case .easy: return "tortoise.fill"; case .medium: return "hare.fill"; case .hard: return "bolt.fill"; case .insane: return "flame.fill" } }
}

// MARK: - Power-ups
enum PongPowerUpKind: String, CaseIterable {
    case speedBoost="SPEED!", shrinkAI="SHRINK CPU", widePaddle="WIDE PAD", ghostBall="GHOST BALL"
    var icon: String { switch self { case .speedBoost: return "bolt.fill"; case .shrinkAI: return "arrow.up.and.down.and.arrow.left.and.right"; case .widePaddle: return "rectangle.expand.vertical"; case .ghostBall: return "eye.slash.fill" } }
    var color: Color { switch self { case .speedBoost: return .gold; case .shrinkAI: return .neonPink; case .widePaddle: return .neonCyan; case .ghostBall: return Color(hex:"BF5FFF") } }
}

struct PongActivePowerUp { let kind: PongPowerUpKind; var timeLeft: CGFloat }
struct PongFloatingPowerUp { var kind: PongPowerUpKind; var x: CGFloat; var y: CGFloat }

// MARK: - Stats
struct PongGameStats: Codable { var totalWins = 0, bestStreak = 0, totalRallies = 0, gamesPlayed = 0 }

final class PongStatsStore {
    static let shared = PongStatsStore()
    private let key = "pong_stats_v2"
    private(set) var stats: PongGameStats
    private init() {
        if let d = UserDefaults.standard.data(forKey: key), let s = try? JSONDecoder().decode(PongGameStats.self, from: d) { stats = s }
        else { stats = PongGameStats() }
    }
    func record(win: Bool, streak: Int, rallies: Int) {
        stats.gamesPlayed += 1; if win { stats.totalWins += 1 }; stats.bestStreak = max(stats.bestStreak, streak); stats.totalRallies += rallies
        if let d = try? JSONEncoder().encode(stats) { UserDefaults.standard.set(d, forKey: key) }
    }
}

// MARK: - Constants (Unified Theme)
private enum C {
    static let paddleW: CGFloat = 12; static let paddleH: CGFloat = 80
    static let ballSize: CGFloat = 14; static let paddleInset: CGFloat = 24
    static let winScore: Int = 7; static let puSize: CGFloat = 32
    static let neon = Color.neonCyan
    static let neonP = Color.neonPink
    static let bg = Color.darkBg
    static let crtGrid = Color.cellBorder.opacity(0.15)
    static let borderColor = Color.cellBorder.opacity(0.3)
    static let borderWidth: CGFloat = 2
    static let materialBg = Color.surface.opacity(0.6)
}

enum PongGamePhase { case menu, playing, paused, goal, gameOver }

// MARK: - Sub-views (Unified Theme)
struct PongBallView: View {
    let opacity: Double; let fast: Bool
    var body: some View {
        ZStack {
            Circle().fill((fast ? Color.gold : C.neon).opacity(0.28*opacity)).frame(width:C.ballSize*2.6, height:C.ballSize*2.6).blur(radius:7)
            Circle().fill(RadialGradient(colors: fast ? [.white, .gold] : [.white, C.neon], center:.topLeading, startRadius:0, endRadius:C.ballSize))
                .frame(width:C.ballSize, height:C.ballSize).shadow(color: fast ? .gold : C.neon, radius:9)
        }.opacity(opacity)
    }
}

struct PongPaddleView: View {
    let color: Color; let glowing: Bool; let h: CGFloat
    var body: some View {
        RoundedRectangle(cornerRadius:C.paddleW/2)
            .fill(LinearGradient(colors:[color.opacity(0.9),color], startPoint:.top, endPoint:.bottom))
            .frame(width:C.paddleW, height:h)
            .overlay(RoundedRectangle(cornerRadius:C.paddleW/2).stroke(.white.opacity(0.3), lineWidth:1))
            .shadow(color:color.opacity(glowing ? 1.0 : 0.5), radius:glowing ? 20 : 8)
            .scaleEffect(glowing ? 1.07 : 1.0).animation(.spring(response:0.15), value:glowing)
    }
}

struct PongPowerUpToken: View {
    let kind: PongPowerUpKind; @State private var pulse = false
    var body: some View {
        ZStack {
            Circle().fill(kind.color.opacity(0.18)).frame(width:C.puSize*1.8, height:C.puSize*1.8)
                .scaleEffect(pulse ? 1.22 : 0.88).animation(.easeInOut(duration:0.75).repeatForever(autoreverses:true), value:pulse)
            Circle().stroke(kind.color, lineWidth:2).frame(width:C.puSize, height:C.puSize)
            Image(systemName:kind.icon).font(.system(size:13, weight:.bold)).foregroundColor(kind.color)
        }.onAppear { pulse=true }
    }
}

struct PongPUTimerBar: View {
    let pus: [PongPowerUpKind: PongActivePowerUp]
    var sorted: [PongActivePowerUp] { pus.values.sorted { $0.timeLeft > $1.timeLeft } }
    var body: some View {
        VStack {
            Spacer()
            if !pus.isEmpty {
                HStack(spacing:8) { ForEach(sorted, id:\.kind.rawValue) { pu in
                    VStack(spacing:3) {
                        Image(systemName:pu.kind.icon).font(.system(size:10, weight:.bold)).foregroundColor(pu.kind.color)
                        GeometryReader { g in ZStack(alignment:.leading) {
                            RoundedRectangle(cornerRadius:2).fill(Color.cellBorder.opacity(0.3))
                            RoundedRectangle(cornerRadius:2).fill(pu.kind.color).frame(width:g.size.width * min(pu.timeLeft/5.0,1.0))
                        }}.frame(width:38, height:4)
                    }.padding(.horizontal,6).padding(.vertical,5).background(.ultraThinMaterial).clipShape(RoundedRectangle(cornerRadius:8))
                }}.padding(.bottom,18)
            }
        }
    }
}

struct PongScoreBar: View {
    @ObservedObject var vm: PongGameViewModel
    var body: some View {
        VStack {
            HStack(spacing:0) {
                VStack(spacing:2) {
                    Text("YOU").font(.system(size:10, weight:.heavy, design:.monospaced)).foregroundColor(C.neon.opacity(0.7)).kerning(3)
                    Text("\(vm.playerScore)").font(.system(size:46, weight:.black, design:.monospaced))
                        .foregroundColor(C.neon).shadow(color:C.neon, radius:12)
                        .contentTransition(.numericText()).animation(.spring(response:0.3), value:vm.playerScore)
                }.frame(maxWidth:.infinity)
                VStack(spacing:5) {
                    HStack(spacing:4) { ForEach(0..<C.winScore, id:\.self) { i in
                        RoundedRectangle(cornerRadius:2).fill(i < vm.playerScore ? C.neon : Color.cellBorder.opacity(0.3)).frame(width:6,height:6)
                            .shadow(color:i<vm.playerScore ? C.neon:.clear, radius:4) } }
                    Text("FIRST TO \(C.winScore)").font(.system(size:8, weight:.bold, design:.monospaced)).foregroundColor(.secondary).kerning(1)
                    HStack(spacing:4) { ForEach(0..<C.winScore, id:\.self) { i in
                        RoundedRectangle(cornerRadius:2).fill(i < vm.aiScore ? C.neonP : Color.cellBorder.opacity(0.3)).frame(width:6,height:6)
                            .shadow(color:i<vm.aiScore ? C.neonP:.clear, radius:4) } }
                }
                VStack(spacing:2) {
                    Text("CPU").font(.system(size:10, weight:.heavy, design:.monospaced)).foregroundColor(C.neonP.opacity(0.7)).kerning(3)
                    Text("\(vm.aiScore)").font(.system(size:46, weight:.black, design:.monospaced))
                        .foregroundColor(C.neonP).shadow(color:C.neonP, radius:12)
                        .contentTransition(.numericText()).animation(.spring(response:0.3), value:vm.aiScore)
                }.frame(maxWidth:.infinity)
            }.padding(.horizontal,8).padding(.top,56); Spacer()
        }
    }
}

struct PongStreakHUD: View {
    let streak: Int; let best: Int
    var body: some View {
        VStack { Spacer(); HStack {
            VStack(alignment:.leading, spacing:2) {
                if streak >= 3 {
                    HStack(spacing:4) {
                        Image(systemName: streak>=15 ? "flame.fill" : "bolt.fill").font(.system(size:10, weight:.black)).foregroundColor(streak>=15 ? .gold : C.neon)
                        Text("RALLY ×\(streak)").font(.system(size:11, weight:.black, design:.monospaced)).foregroundColor(streak>=15 ? .gold : C.neon).shadow(color:streak>=15 ? .gold : C.neon, radius:6)
                    }.transition(.scale.combined(with:.opacity))
                }
                if best > 0 { Text("BEST \(best)").font(.system(size:9, weight:.bold, design:.monospaced)).foregroundColor(.secondary) }
            }.padding(.leading,20).padding(.bottom,62); Spacer()
        } }.animation(.spring(response:0.3), value:streak)
    }
}

struct PongComboPopView: View {
    let text: String; @State private var scale: CGFloat = 0.4; @State private var opacity: Double = 0
    var body: some View {
        Text(text).font(.system(size:52, weight:.black, design:.monospaced))
            .foregroundStyle(LinearGradient(colors:[.gold, .neonOrange], startPoint:.topLeading, endPoint:.bottomTrailing)).shadow(color:.gold, radius:20)
            .scaleEffect(scale).opacity(opacity).onAppear { withAnimation(.spring(response:0.35, dampingFraction:0.5)) { scale=1.0; opacity=1 }; withAnimation(.easeOut(duration:0.4).delay(0.9)) { scale=1.3; opacity=0 } }
    }
}

struct PongPUPopView: View {
    let label: String; @State private var offset: CGFloat = 40; @State private var opacity: Double = 0
    var body: some View {
        VStack { Spacer()
            Text("⚡ \(label)").font(.system(size:18, weight:.black, design:.monospaced)).kerning(2).foregroundColor(.white)
                .padding(.horizontal,20).padding(.vertical,10).background(.ultraThinMaterial).clipShape(Capsule())
                .overlay(Capsule().stroke(.white.opacity(0.2), lineWidth:1)).offset(y:offset).opacity(opacity)
                .onAppear { withAnimation(.spring(response:0.4)) { offset=0; opacity=1 }; withAnimation(.easeIn(duration:0.35).delay(1.3)) { offset = -30; opacity=0 } }
            Spacer().frame(height:130)
        }
    }
}

struct PongCountdownOverlay: View {
    let count: Int; @State private var scale: CGFloat = 2.0; @State private var opacity: Double = 0
    var body: some View {
        ZStack { if count > 0 {
            Text("\(count)").font(.system(size:120, weight:.black, design:.monospaced)).foregroundColor(.white).shadow(color:C.neon, radius:30)
                .scaleEffect(scale).opacity(opacity).onAppear { scale=2.0; opacity=0; withAnimation(.easeOut(duration:0.7)) { scale=1.0; opacity=1 } }.id(count)
        }}
    }
}

struct PongPausedOverlay: View {
    let vm: PongGameViewModel
    var body: some View {
        ZStack { Color.darkBg.opacity(0.92).ignoresSafeArea()
            VStack(spacing:24) {
                Text("PAUSED").font(.system(size:38, weight:.black, design:.monospaced)).foregroundColor(.white).kerning(8)
                    .shadow(color: C.neon, radius: 15)
                Button { vm.pauseToggle() } label: { Label("RESUME", systemImage:"play.fill").font(.system(size:16, weight:.heavy, design:.monospaced)).kerning(3).foregroundColor(.darkBg).padding(.horizontal,36).padding(.vertical,14).background(C.neon).clipShape(Capsule()).shadow(color:C.neon, radius:18) }
                Button { vm.phase = .menu } label: { Text("MAIN MENU").font(.system(size:13, weight:.bold, design:.monospaced)).kerning(2).foregroundColor(.white.opacity(0.5)) }
            }
        }
    }
}

struct PongGameOverOverlay: View {
    @ObservedObject var vm: PongGameViewModel; @State private var appear=false; @State private var glow=false
    var isWin: Bool { vm.playerScore >= C.winScore }
    var body: some View {
        ZStack { Color.darkBg.opacity(0.92).ignoresSafeArea()
            if isWin { ForEach(0..<22, id:\.self) { PongConfettiDot(index:$0) } }
            VStack(spacing:20) {
                Text(isWin ? "VICTORY" : "GAME OVER").font(.system(size:40, weight:.black, design:.monospaced)).kerning(6)
                    .foregroundStyle(LinearGradient(colors:isWin ? [C.neon, .gold]:[C.neonP, .neonOrange], startPoint:.topLeading, endPoint:.bottomTrailing))
                    .shadow(color:isWin ? C.neon:C.neonP, radius:glow ? 28:10).animation(.easeInOut(duration:1.4).repeatForever(autoreverses:true), value:glow)
                    .scaleEffect(appear ? 1:0.5).opacity(appear ? 1:0)
                Text(vm.winnerText).font(.system(size:24, weight:.heavy, design:.monospaced)).foregroundColor(.white).scaleEffect(appear ? 1:0.7).opacity(appear ? 1:0)
                HStack(spacing:0) {
                    VStack(spacing:3) { Text("YOU").font(.system(size:10, weight:.heavy, design:.monospaced)).foregroundColor(C.neon.opacity(0.8)).kerning(2); Text("\(vm.playerScore)").font(.system(size:46, weight:.black, design:.monospaced)).foregroundColor(C.neon) }.frame(maxWidth:.infinity)
                    Text("–").font(.system(size:24, weight:.thin)).foregroundColor(.white.opacity(0.5))
                    VStack(spacing:3) { Text("CPU").font(.system(size:10, weight:.heavy, design:.monospaced)).foregroundColor(C.neonP.opacity(0.8)).kerning(2); Text("\(vm.aiScore)").font(.system(size:46, weight:.black, design:.monospaced)).foregroundColor(C.neonP) }.frame(maxWidth:.infinity)
                }.padding(16).background(.ultraThinMaterial).clipShape(RoundedRectangle(cornerRadius:16)).overlay(RoundedRectangle(cornerRadius:16).stroke(Color.cellBorder, lineWidth:1)).opacity(appear ? 1:0)
                HStack(spacing:10) {
                    PongMiniStatCard(icon:"flame.fill", label:"BEST STREAK", value:"\(vm.bestStreak)", color:.gold)
                    PongMiniStatCard(icon:"arrow.left.and.right", label:"RALLIES", value:"\(vm.totalRallies)", color:.neonPurple)
                }.opacity(appear ? 1:0)
                VStack(spacing:12) {
                    Button { vm.startGame() } label: { HStack { Image(systemName:"arrow.counterclockwise"); Text("PLAY AGAIN").kerning(3) }.font(.system(size:16, weight:.heavy, design:.monospaced)).foregroundColor(.darkBg).frame(maxWidth:.infinity).padding(.vertical,16).background(isWin ? C.neon : C.neonP).clipShape(RoundedRectangle(cornerRadius:14)).shadow(color:(isWin ? C.neon:C.neonP).opacity(0.6), radius:14) }
                    Button { vm.phase = .menu } label: { Text("MAIN MENU").font(.system(size:13, weight:.bold, design:.monospaced)).kerning(2).foregroundColor(.white.opacity(0.5)) }
                }.padding(.horizontal,40).opacity(appear ? 1:0).offset(y:appear ? 0:30)
            }.padding(26)
        }.onAppear { withAnimation(.spring(response:0.6, dampingFraction:0.7)) { appear=true }; glow=true }
    }
}

struct PongMiniStatCard: View {
    let icon:String; let label:String; let value:String; let color:Color
    var body: some View {
        HStack(spacing:8) {
            Image(systemName:icon).font(.system(size:14)).foregroundColor(color)
            VStack(alignment:.leading, spacing:1) { Text(value).font(.system(size:20, weight:.black, design:.monospaced)).foregroundColor(.white); Text(label).font(.system(size:8, weight:.bold, design:.monospaced)).kerning(1).foregroundColor(.white.opacity(0.5)) }
        }.padding(.horizontal,14).padding(.vertical,10).background(color.opacity(0.1)).clipShape(RoundedRectangle(cornerRadius:12)).overlay(RoundedRectangle(cornerRadius:12).stroke(color.opacity(0.25), lineWidth:1))
    }
}

struct PongConfettiDot: View {
    let index:Int; @State private var y:CGFloat = -50; @State private var opacity:Double=1
    let color:Color; let size:CGFloat; @State private var x:CGFloat
    init(index:Int) { self.index=index; color=[C.neon,C.neonP,.gold,.neonOrange,.neonCyan,.neonPurple, .neonPink][index%7]; size=CGFloat.random(in:5...13); _x=State(initialValue:CGFloat.random(in: -185...185)) }
    var body: some View { Circle().fill(color).frame(width:size,height:size).opacity(opacity).offset(x:x,y:y).onAppear { withAnimation(.easeIn(duration:1.5).delay(Double(index)*0.06)) { y=520; opacity=0 } } }
}

struct PongCRTGrid: View {
    var body: some View {
        Canvas { ctx, size in
            var y: CGFloat=0
            while y < size.height { ctx.stroke(Path { p in p.move(to:CGPoint(x:0,y:y)); p.addLine(to:CGPoint(x:size.width,y:y)) }, with:.color(Color.cellBorder.opacity(0.06)), lineWidth:1); y+=4 }
            let dash: CGFloat=12; var cy: CGFloat=0
            while cy < size.height { ctx.fill(Path(roundedRect:CGRect(x:size.width/2-2,y:cy,width:4,height:dash),cornerRadius:2), with:.color(Color.cellBorder.opacity(0.08))); cy += dash*2 }
        }
    }
}

struct PongModeCard: View {
    let mode: PongGameMode; let selected: Bool; let action: ()->Void
    var body: some View {
        Button(action: action) { VStack(spacing:8) {
            Image(systemName: mode.icon).font(.system(size: 24, weight: .bold)).foregroundColor(selected ? .white : mode.color)
            Text(mode.rawValue).font(.system(size:14, weight:.black, design:.monospaced)).foregroundColor(selected ? .white : .white)
            Text(mode.subtitle).font(.system(size:10, weight:.medium, design:.monospaced)).foregroundColor(selected ? .white.opacity(0.7) : .white.opacity(0.5))
        }.frame(maxWidth: .infinity).padding(.vertical, 16).background(selected ? mode.color : C.materialBg).clipShape(RoundedRectangle(cornerRadius: 16)) }
    }
}

struct PongDifficultyBtn: View {
    let diff: PongDifficulty; let selected: Bool; let action: ()->Void
    var body: some View {
        Button(action:action) { VStack(spacing:4) {
            Image(systemName:diff.icon).font(.system(size:14, weight:.bold)).foregroundColor(selected ? .white : diff.color)
            Text(diff.rawValue).font(.system(size:8, weight:.heavy, design:.monospaced)).kerning(1).foregroundColor(selected ? .white : diff.color.opacity(0.8))
        }.padding(.horizontal,14).padding(.vertical,10).background(selected ? diff.color : diff.color.opacity(0.15)).clipShape(RoundedRectangle(cornerRadius:12))
            .overlay(RoundedRectangle(cornerRadius:12).stroke(diff.color.opacity(selected ? 0:0.35), lineWidth:1.5))
            .shadow(color:selected ? diff.color.opacity(0.6):.clear, radius:10).scaleEffect(selected ? 1.06:1.0).animation(.spring(response:0.25), value:selected) }
    }
}

struct PongInfoPill: View {
    let icon: String; let text: String
    var body: some View {
        HStack(spacing:6) { Image(systemName:icon).font(.system(size:11)).foregroundColor(C.neon); Text(text).font(.system(size:10, weight:.bold, design:.monospaced)).kerning(1).foregroundColor(.white.opacity(0.6)) }
            .padding(.horizontal,12).padding(.vertical,7).background(.ultraThinMaterial).clipShape(Capsule()).overlay(Capsule().stroke(Color.cellBorder, lineWidth:1))
    }
}

struct PongStatCard: View {
    let label:String; let value:String; let icon:String; let color:Color
    var body: some View {
        VStack(alignment:.leading, spacing:8) {
            HStack { Image(systemName:icon).font(.system(size:13,weight:.bold)).foregroundColor(color); Spacer() }
            Text(value).font(.system(size:32, weight:.black, design:.monospaced)).foregroundColor(.white).shadow(color:color.opacity(0.5), radius:8)
            Text(label).font(.system(size:8, weight:.heavy, design:.monospaced)).kerning(1).foregroundColor(.white.opacity(0.5))
        }.padding(14).background(color.opacity(0.08)).clipShape(RoundedRectangle(cornerRadius:16)).overlay(RoundedRectangle(cornerRadius:16).stroke(color.opacity(0.2), lineWidth:1))
    }
}

// MARK: - ViewModel
@MainActor
final class PongGameViewModel: ObservableObject {
    var W: CGFloat = 390; var H: CGFloat = 844
    @Published var phase: PongGamePhase = .menu
    @Published var playerScore = 0; @Published var aiScore = 0
    @Published var playerY: CGFloat = 0; @Published var aiY: CGFloat = 0
    @Published var ballX: CGFloat = 0; @Published var ballY: CGFloat = 0
    @Published var ballTrail: [CGPoint] = []
    @Published var flashPlayer = false; @Published var flashAI = false
    @Published var countdown = 3; @Published var winnerText = ""
    @Published var gameMode: PongGameMode = .adventure; @Published var difficulty: PongDifficulty = .medium
    @Published var floatingPU: PongFloatingPowerUp? = nil
    @Published var activePUs: [PongPowerUpKind: PongActivePowerUp] = [:]
    @Published var puPopLabel = ""; @Published var showPUPop = false
    private var puCooldown: CGFloat = 14
    @Published var rallyStreak = 0; @Published var bestStreak = 0
    @Published var showCombo = false; @Published var comboText = ""
    private(set) var totalRallies = 0
    @Published var savedStats = PongStatsStore.shared.stats
    
    private var ballVX: CGFloat = 0; private var ballVY: CGFloat = 0
    private var displayLink: CADisplayLink?; private var lastTime: CFTimeInterval = 0
    private var countdownTimer: Timer?; private var goalPause = false
    
    var powerUpsEnabled: Bool { gameMode == .adventure }
    var effectivePlayerH: CGFloat { powerUpsEnabled && activePUs[.widePaddle] != nil ? C.paddleH*1.65 : C.paddleH }
    var effectiveAIH: CGFloat { powerUpsEnabled && activePUs[.shrinkAI] != nil ? C.paddleH*0.55 : C.paddleH }
    var ballOpacity: Double { powerUpsEnabled && activePUs[.ghostBall] != nil ? 0.20 : 1.0 }
    var ballIsFast: Bool { powerUpsEnabled && activePUs[.speedBoost] != nil }
    
    func setup(size: CGSize) { W = size.width; H = size.height; reset(full: true); savedStats = PongStatsStore.shared.stats }
    func startGame() { playerScore=0; aiScore=0; winnerText=""; rallyStreak=0; totalRallies=0; bestStreak=0; activePUs.removeAll(); floatingPU=nil; puCooldown=14; reset(full: false); beginCountdown() }
    func pauseToggle() { guard phase == .playing || phase == .paused else { return }; phase = phase == .playing ? .paused : .playing; if phase == .playing { startLink() } else { stopLink() } }
    func dragPaddle(to y: CGFloat) { let h = effectivePlayerH/2; playerY = max(h, min(H-h, y)) }
    private func reset(full: Bool) { playerY=H/2; aiY=H/2; placeBall(); ballTrail=[]; if full { playerScore=0; aiScore=0 } }
    private func placeBall() { ballX=W/2; ballY=H/2; let a = CGFloat.random(in: -0.4...0.4); let d: CGFloat = Bool.random() ? 1 : -1; let baseSpeed = difficulty.ballSpeed * (gameMode == .basic ? 0.85 : 1.0); ballVX = d*baseSpeed*cos(a); ballVY = baseSpeed*sin(a) }
    private func beginCountdown() { countdown=3; phase = .goal; stopLink(); countdownTimer?.invalidate(); countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] t in guard let self else { return }; Task { @MainActor in self.countdown -= 1; if self.countdown <= 0 { t.invalidate(); self.phase = .playing; self.startLink() } } } }
    private func startLink() { stopLink(); let dl = CADisplayLink(target: self, selector: #selector(tick)); dl.add(to: .main, forMode: .common); displayLink = dl; lastTime = CACurrentMediaTime() }
    private func stopLink() { displayLink?.invalidate(); displayLink = nil }
    @objc private func tick(_ dl: CADisplayLink) { guard phase == .playing, !goalPause else { return }; let dt = min(CGFloat(dl.timestamp - lastTime), 1.0/30); lastTime = dl.timestamp; update(dt: dt) }
    private func update(dt: CGFloat) {
        if powerUpsEnabled { tickPUs(dt: dt) }; let boost: CGFloat = ballIsFast ? 1.4 : 1.0
        ballX += ballVX * boost; ballY += ballVY * boost; ballTrail.append(CGPoint(x:ballX, y:ballY))
        if ballTrail.count > 14 { ballTrail.removeFirst() }; let r = C.ballSize/2
        if ballY-r < 0 { ballY=r; ballVY=abs(ballVY); PongSoundEngine.shared.play(.wallHit); PongHapticEngine.shared.play(.light) }
        if ballY+r > H { ballY=H-r; ballVY = -abs(ballVY); PongSoundEngine.shared.play(.wallHit); PongHapticEngine.shared.play(.light) }
        let pX = C.paddleInset + C.paddleW
        if ballX-r < pX && ballX-r > pX-C.paddleW*2 {
            if abs(ballY-playerY) < effectivePlayerH/2+r { ballX=pX+r; let rel=(ballY-playerY)/(effectivePlayerH/2); let ang=rel*(.pi/3.5); let spd=hypot(ballVX,ballVY)*1.04; ballVX=abs(spd*cos(ang)); ballVY=spd*sin(ang); flashPlayer=true; rallyStreak+=1; totalRallies+=1; bestStreak=max(bestStreak,rallyStreak); checkCombo(); PongSoundEngine.shared.play(.paddleHit); PongHapticEngine.shared.play(.medium); DispatchQueue.main.asyncAfter(deadline: .now()+0.12) { self.flashPlayer=false } }
        }
        let aX = W - C.paddleInset - C.paddleW
        if ballX+r > aX && ballX+r < aX+C.paddleW*2 {
            if abs(ballY-aiY) < effectiveAIH/2+r { ballX=aX-r; let rel=(ballY-aiY)/(effectiveAIH/2); let ang=rel*(.pi/3.5); let spd=hypot(ballVX,ballVY)*1.04; ballVX = -abs(spd*cos(ang)); ballVY=spd*sin(ang); flashAI=true; rallyStreak+=1; totalRallies+=1; bestStreak=max(bestStreak,rallyStreak); PongSoundEngine.shared.play(.paddleHit); PongHapticEngine.shared.play(.light); DispatchQueue.main.asyncAfter(deadline: .now()+0.12) { self.flashAI=false } }
        }
        let err = CGFloat.random(in: -difficulty.aiError...difficulty.aiError); let diff = (ballY+err)-aiY; let step = min(abs(diff), difficulty.aiSpeed + CGFloat(max(playerScore,aiScore))*0.12); aiY += diff>0 ? step : -step; aiY = max(effectiveAIH/2, min(H-effectiveAIH/2, aiY))
        if powerUpsEnabled { checkPUPickup(r: r); puCooldown -= dt; if puCooldown <= 0, floatingPU == nil { spawnPU(); puCooldown=14 } }
        if ballX < 0 { aiScore+=1; rallyStreak=0; PongSoundEngine.shared.play(.score); PongHapticEngine.shared.play(.error); handleGoal() }
        else if ballX > W { playerScore+=1; rallyStreak=0; PongSoundEngine.shared.play(.score); PongHapticEngine.shared.play(.success); handleGoal() }
    }
    private func spawnPU() { let k = PongPowerUpKind.allCases.randomElement()!; let m: CGFloat = 70; floatingPU = PongFloatingPowerUp(kind:k, x:CGFloat.random(in:W*0.3...W*0.7), y:CGFloat.random(in:m...H-m)) }
    private func checkPUPickup(r: CGFloat) { guard let pu = floatingPU else { return }; if hypot(ballX-pu.x, ballY-pu.y) < C.puSize/2+r { activePUs[pu.kind] = PongActivePowerUp(kind:pu.kind, timeLeft:5.0); puPopLabel = pu.kind.rawValue; showPUPop=true; floatingPU=nil; PongSoundEngine.shared.play(.powerUp); PongHapticEngine.shared.play(.heavy); DispatchQueue.main.asyncAfter(deadline:.now()+1.8) { self.showPUPop=false } } }
    private func tickPUs(dt: CGFloat) { var remove: [PongPowerUpKind]=[]; for k in activePUs.keys { activePUs[k]!.timeLeft -= dt; if activePUs[k]!.timeLeft<=0 { remove.append(k) } }; remove.forEach { activePUs.removeValue(forKey:$0) } }
    private func checkCombo() { let milestones = [5,10,15,20,30,50]; guard milestones.contains(rallyStreak) else { return }; comboText = rallyStreak>=30 ? "🔥 ×\(rallyStreak)" : rallyStreak>=15 ? "⚡ ×\(rallyStreak)" : "✦ ×\(rallyStreak)"; showCombo=true; PongSoundEngine.shared.play(.combo); PongHapticEngine.shared.play(.heavy); DispatchQueue.main.asyncAfter(deadline:.now()+1.6) { self.showCombo=false } }
    private func handleGoal() { goalPause=true; stopLink(); activePUs.removeAll(); floatingPU=nil; if playerScore >= C.winScore || aiScore >= C.winScore { let win = playerScore >= C.winScore; winnerText = win ? "YOU WIN! 🎉" : "AI WINS 🤖"; phase = .gameOver; PongSoundEngine.shared.play(.gameOver); PongStatsStore.shared.record(win:win, streak:bestStreak, rallies:totalRallies); savedStats = PongStatsStore.shared.stats; goalPause=false } else { phase = .goal; DispatchQueue.main.asyncAfter(deadline:.now()+1.2) { self.reset(full:false); self.goalPause=false; self.beginCountdown() } } }
    deinit { displayLink?.invalidate(); countdownTimer?.invalidate() }
}

// MARK: - SettingsView with Appearance
struct PongSettingsView: View {
    @ObservedObject var vm: PongGameViewModel; @StateObject private var appearance = PongAppearanceStore.shared
    @State private var appear = false
    var body: some View {
        ZStack { Color.darkBg.ignoresSafeArea(); PongCRTGrid()
            VStack(spacing:30) {
                Text("SETTINGS").font(.system(size:28, weight:.black, design:.monospaced)).kerning(6).foregroundColor(.white).padding(.top,30)
                    .opacity(appear ? 1 : 0).offset(y: appear ? 0 : -20)
                VStack(alignment:.leading, spacing:12) { Text("GAME MODE").font(.system(size:12, weight:.heavy, design:.monospaced)).kerning(2).foregroundColor(C.neon.opacity(0.8))
                    HStack(spacing:16) { ForEach(PongGameMode.allCases) { m in PongModeCard(mode:m, selected:vm.gameMode==m) { vm.gameMode=m; PongHapticEngine.shared.play(.light) } } } }.padding(.horizontal).opacity(appear ? 1 : 0).offset(y: appear ? 0 : 20)
                VStack(alignment:.leading, spacing:12) { Text("DIFFICULTY").font(.system(size:12, weight:.heavy, design:.monospaced)).kerning(2).foregroundColor(C.neonP.opacity(0.8))
                    HStack(spacing:12) { ForEach(PongDifficulty.allCases) { d in PongDifficultyBtn(diff:d, selected:vm.difficulty==d) { vm.difficulty=d; PongHapticEngine.shared.play(.light) } } } }.padding(.horizontal).opacity(appear ? 1 : 0).offset(y: appear ? 0 : 20)
                VStack(alignment:.leading, spacing:12) { Text("APPEARANCE").font(.system(size:12, weight:.heavy, design:.monospaced)).kerning(2).foregroundColor(.white.opacity(0.5))
                    Picker("Appearance", selection: $appearance.currentMode) { ForEach(PongAppearanceMode.allCases) { m in Text(m.rawValue).tag(m) } }.pickerStyle(.segmented).padding(.horizontal, 4)
                }.padding(.horizontal).opacity(appear ? 1 : 0).offset(y: appear ? 0 : 20)
                Spacer()
            }.animation(.spring(response:0.5, dampingFraction:0.8), value: appear)
        }.onAppear { appear = true }
    }
}

// MARK: - StatsMainView
struct PongStatsMainView: View {
    let stats: PongGameStats
    var winRate: String { guard stats.gamesPlayed>0 else { return "–" }; return "\(Int(Double(stats.totalWins)/Double(stats.gamesPlayed)*100))%" }
    var avgRallies: String { guard stats.gamesPlayed>0 else { return "–" }; return "\(stats.totalRallies / max(stats.gamesPlayed,1))" }
    var body: some View {
        ZStack { Color.darkBg.ignoresSafeArea()
            VStack(spacing:24) { Text("LIFETIME STATS").font(.system(size:22, weight:.black, design:.monospaced)).kerning(4).foregroundColor(.white).padding(.top,20)
                LazyVGrid(columns:[GridItem(.flexible()),GridItem(.flexible())], spacing:16) {
                    PongStatCard(label:"GAMES PLAYED", value:"\(stats.gamesPlayed)", icon:"gamecontroller.fill", color:C.neon)
                    PongStatCard(label:"TOTAL WINS", value:"\(stats.totalWins)", icon:"trophy.fill", color:.gold)
                    PongStatCard(label:"WIN RATE", value:winRate, icon:"percent", color:.neonOrange)
                    PongStatCard(label:"BEST STREAK", value:"\(stats.bestStreak)", icon:"flame.fill", color:C.neonP)
                    PongStatCard(label:"TOTAL RALLIES", value:"\(stats.totalRallies)", icon:"arrow.left.and.right", color:.neonPurple)
                    PongStatCard(label:"AVG RALLIES", value:avgRallies, icon:"chart.line.uptrend.xyaxis", color:.neonCyan)
                }.padding(.horizontal,22); Spacer()
            }
        }
    }
}


// MARK: - GameCanvas
struct PongGameCanvas: View {
    @ObservedObject var vm: PongGameViewModel; @State private var showMenu = true; @State private var menuOpacity: Double = 1.0
    var body: some View {
        GeometryReader { geo in ZStack {
            Rectangle().fill(C.borderColor).frame(height: C.borderWidth).position(x: geo.size.width / 2, y: 0)
            Rectangle().fill(C.borderColor).frame(height: C.borderWidth).position(x: geo.size.width / 2, y: geo.size.height)
            ForEach(Array(vm.ballTrail.enumerated()), id:\.offset) { idx, pt in Circle().fill(C.neon.opacity(Double(idx)/Double(vm.ballTrail.count)*0.35*vm.ballOpacity)).frame(width:C.ballSize*0.55, height:C.ballSize*0.55).position(pt) }
            PongBallView(opacity: vm.ballOpacity, fast: vm.ballIsFast).position(x:vm.ballX, y:vm.ballY)
            if let pu = vm.floatingPU { PongPowerUpToken(kind:pu.kind).position(x:pu.x, y:pu.y) }
            PongPaddleView(color:C.neon, glowing:vm.flashPlayer, h:vm.effectivePlayerH).position(x:C.paddleInset+C.paddleW/2, y:vm.playerY).gesture(DragGesture(minimumDistance:0).onChanged { vm.dragPaddle(to:$0.location.y) })
            PongPaddleView(color:C.neonP, glowing:vm.flashAI, h:vm.effectiveAIH).position(x:vm.W-C.paddleInset-C.paddleW/2, y:vm.aiY)
            PongPUTimerBar(pus: vm.activePUs); PongScoreBar(vm: vm); PongStreakHUD(streak: vm.rallyStreak, best: vm.bestStreak)
            if vm.showCombo { PongComboPopView(text: vm.comboText) }; if vm.showPUPop { PongPUPopView(label: vm.puPopLabel) }
            if vm.phase == .paused { PongPausedOverlay(vm: vm) }; if vm.phase == .goal { PongCountdownOverlay(count: vm.countdown) }; if vm.phase == .gameOver { PongGameOverOverlay(vm: vm) }
            if vm.phase == .playing || vm.phase == .paused {
                VStack { HStack { Spacer()
                    Button { vm.pauseToggle() } label: { Text("STOP").font(.system(size: 11, weight: .heavy, design: .monospaced)).kerning(2).foregroundColor(C.neon).padding(.horizontal, 14).padding(.vertical, 8).background(.ultraThinMaterial).clipShape(Capsule()).overlay(Capsule().stroke(C.neon.opacity(0.5), lineWidth: 1.5)) }.padding(.trailing, 12).transition(.move(edge: .trailing).combined(with: .opacity))
                }.padding(.top, 60); Spacer() }
            }
            if showMenu {
                ZStack { Color.darkBg.ignoresSafeArea()
                    VStack(spacing: 28) { Spacer()
                        Text("PONG").font(.system(size: 76, weight: .black, design: .monospaced)).foregroundStyle(LinearGradient(colors: [C.neon, .white, C.neonP], startPoint: .topLeading, endPoint: .bottomTrailing)).shadow(color: C.neon, radius: 20)
                        Spacer()
                        Button { withAnimation(.easeOut(duration: 0.4)) { showMenu = false }; vm.startGame() } label: { HStack(spacing: 12) { Image(systemName: "play.fill").font(.system(size: 20, weight: .bold)); Text("PLAY").font(.system(size: 22, weight: .black, design: .monospaced)).kerning(4) }.foregroundColor(Color.darkBg).frame(maxWidth: .infinity).padding(.vertical, 18).background(LinearGradient(colors: [C.neon, C.neon.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)).clipShape(RoundedRectangle(cornerRadius: 18)).shadow(color: C.neon.opacity(0.6), radius: 20) }.padding(.horizontal, 50)
                        HStack(spacing: 16) { PongInfoPill(icon: "hand.point.up", text: "DRAG"); PongInfoPill(icon: "bolt.fill", text: "POWER-UPS"); PongInfoPill(icon: "flame.fill", text: "STREAKS") }.padding(.bottom, 10)
                        Spacer()
                    }
                }.opacity(menuOpacity)
            }
        }}.onChange(of: vm.phase) { _, newPhase in if newPhase == .menu { withAnimation(.easeOut(duration: 0.3)) { showMenu = true; menuOpacity = 1.0 } } }
    }
}

// MARK: - Main Pong View (Embeddable)
struct PongTabBtn: View {
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
            .foregroundColor(selected ? AppTheme.accent : .white.opacity(0.4))
            .frame(maxWidth: .infinity)
        }
    }
}

struct PongGameView: View {
    @StateObject private var vm = PongGameViewModel()
    @StateObject private var appearance = PongAppearanceStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab = 0
    
    var body: some View {
        ZStack {
            Color.darkBg.ignoresSafeArea()
            
            switch selectedTab {
            case 0:
                ZStack { PongCRTGrid(); PongGameCanvas(vm: vm) }
            case 1:
                PongStatsMainView(stats: vm.savedStats)
            case 2:
                PongSettingsView(vm: vm)
            default:
                ZStack { PongCRTGrid(); PongGameCanvas(vm: vm) }
            }
            
            // Bottom Tab Bar
            VStack {
                Spacer()
                HStack(spacing: 0) {
                    PongTabBtn(icon: "gamecontroller.fill", label: "PLAY", selected: selectedTab == 0) { selectedTab = 0 }
                    PongTabBtn(icon: "chart.bar.fill", label: "STATS", selected: selectedTab == 1) { selectedTab = 1 }
                    PongTabBtn(icon: "gearshape.fill", label: "SETTINGS", selected: selectedTab == 2) { selectedTab = 2 }
                }
                .frame(height: 50)
                .background(AppTheme.surface)
                .overlay(Rectangle().frame(height: 1).foregroundColor(AppTheme.accent.opacity(0.2)), alignment: .top)
            }
            
            // Back button
            VStack {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(C.neon.opacity(0.7))
                    }
                    .padding(.leading, 16)
                    .padding(.top, 6)
                    Spacer()
                }
                Spacer()
            }
        }
        .preferredColorScheme(appearance.currentMode.colorScheme).statusBar(hidden: true)
    }
}
