// ╔══════════════════════════════════════════════════════════════╗
// ║          MAIN MENU — 4 GAMES LAUNCHER                        ║
// ╚══════════════════════════════════════════════════════════════╝

import SwiftUI

// MARK: - Game Item Model

enum GameType: String, CaseIterable {
    case blockBlast = "BLOCK BLAST"
    case bubbleShooter = "BUBBLE SHOOTER"
    case pong = "PONG"
    case memoryMatch = "MEMORY MATCH"
    
    var icon: String {
        switch self {
        case .blockBlast: return "square.grid.3x3.fill"
        case .bubbleShooter: return "circle.circle.fill"
        case .pong: return "gamecontroller.fill"
        case .memoryMatch: return "rectangle.3.group.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .blockBlast: return .neonCyan
        case .bubbleShooter: return .neonPink
        case .pong: return .neonGreen
        case .memoryMatch: return .gold
        }
    }
    
    var description: String {
        switch self {
        case .blockBlast: return "Classic block puzzle"
        case .bubbleShooter: return "Pop & match bubbles"
        case .pong: return "Retro paddle battle"
        case .memoryMatch: return "Find matching pairs"
        }
    }
}

// MARK: - Main Menu View

struct HomeMenuView: View {
    @State private var appear = false
    @State private var selectedGame: GameType? = nil
    
    private let games = GameType.allCases
    
    var body: some View {
        NavigationStack {
            ZStack {
                HomeMeshBackground()
                
                VStack(spacing: 0) {
                    // Title
                    ZStack {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(LinearGradient(colors: [AppTheme.accentSoft, AppTheme.accentAlt.opacity(0.12)], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(height: 96)
                            .padding(.horizontal, 20)
                            .shadow(color: Color.black.opacity(0.25), radius: 10, x: 0, y: 6)

                        VStack(spacing: 4) {
                            Text("GAME ARCADE")
                                .font(.system(size: 32, weight: .black, design: .rounded))
                                .foregroundStyle(
                                    LinearGradient(colors: [.neonCyan, .neonPink, .neonGreen], startPoint: .leading, endPoint: .trailing)
                                )
                                .shadow(color: Color.neonCyan.opacity(0.22), radius: 10)

                            Text("CHOOSE YOUR GAME")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(.white.opacity(0.45))
                                .tracking(5)
                        }
                    }
                    .padding(.top, 70)
                    .padding(.bottom, 30)
                    .opacity(appear ? 1 : 0)
                    .offset(y: appear ? 0 : -30)
                    
                    // Game Cards
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 16) {
                            ForEach(Array(games.enumerated()), id: \.offset) { index, game in
                                NavigationLink(value: game) {
                                    GameCardView(
                                        name: game.rawValue,
                                        icon: game.icon,
                                        color: game.color,
                                        description: game.description
                                    )
                                }
                                .buttonStyle(.plain)
                                .opacity(appear ? 1 : 0)
                                .offset(y: appear ? 0 : CGFloat(40 + index * 20))
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 30)
                    }
                    
                    // Footer
                    Text("TAP TO PLAY")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.25))
                        .tracking(3)
                        .padding(.bottom, 20)
                        .opacity(appear ? 1 : 0)
                }
            }
            .ignoresSafeArea()
            .preferredColorScheme(.dark)
            .navigationDestination(for: GameType.self) { game in
                gameDestination(game)
            }
            .onAppear {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                    appear = true
                }
            }
        }
    }
    
    @ViewBuilder
    private func gameDestination(_ game: GameType) -> some View {
        switch game {
        case .blockBlast:
            BlockBlastGameView()
                .ignoresSafeArea()
        case .bubbleShooter:
            BSTGameView()
                .ignoresSafeArea()
        case .pong:
            PongGameView()
                .ignoresSafeArea()
        case .memoryMatch:
            MemoryMatchGameView()
                .ignoresSafeArea()
        }
    }
}

struct BackButton: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 24))
                .foregroundColor(.white.opacity(0.7))
        }
    }
}

// MARK: - Game Card View

struct GameCardView: View {
    let name: String
    let icon: String
    let color: Color
    let description: String
    @State private var isPressed = false
    
    var body: some View {
        HStack(spacing: 18) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(color.opacity(0.15))
                    .frame(width: 60, height: 60)
                
                Image(systemName: icon)
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(color)
            }
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                
                Text(description)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.45))
            }
            
            Spacer()
            
            // Arrow
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(color.opacity(0.5))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(AppTheme.surfaceSoft)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(AppTheme.border, lineWidth: 1)
                )
        )
        .shadow(color: color.opacity(0.08), radius: 6)
        .scaleEffect(isPressed ? 0.96 : 1.0)
        .animation(.spring(response: 0.3), value: isPressed)
        .contentShape(Rectangle())
        .onLongPressGesture(minimumDuration: .infinity, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                isPressed = pressing
            }
        }, perform: {})
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(name + ", " + description))
    }
}

// MARK: - Animated Mesh Background

struct HomeMeshBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: AppTheme.backgroundGradient, startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
            
                TimelineView(.animation(minimumInterval: 0.12)) { t in
                let s = t.date.timeIntervalSince1970
                ZStack {
                    // Cyan orb
                    Circle()
                        .fill(Color.neonCyan.opacity(0.12))
                        .frame(width: 280)
                        .offset(x: CGFloat(sin(s * 0.12)) * 80,
                            y: CGFloat(cos(s * 0.09)) * 100 - 80)
                        .blur(radius: 60)
                    
                    // Pink orb
                    Circle()
                        .fill(Color.neonPink.opacity(0.10))
                        .frame(width: 240)
                        .offset(x: CGFloat(cos(s * 0.10)) * 70,
                            y: CGFloat(sin(s * 0.15)) * 80 + 300)
                        .blur(radius: 55)
                    
                    // Green orb
                    Circle()
                        .fill(Color.neonGreen.opacity(0.08))
                        .frame(width: 200)
                        .offset(x: CGFloat(sin(s * 0.18 + 1)) * 60,
                            y: CGFloat(cos(s * 0.12)) * 70 + 150)
                        .blur(radius: 50)
                    
                    // Gold orb
                    Circle()
                        .fill(Color.gold.opacity(0.07))
                        .frame(width: 180)
                        .offset(x: CGFloat(cos(s * 0.14 + 2)) * 90,
                            y: CGFloat(sin(s * 0.20)) * 60 - 50)
                        .blur(radius: 45)
                }
            }
            
            // Grid pattern overlay
            HomeGridPattern()
                .stroke(Color.white.opacity(0.03), lineWidth: 0.5)
                .ignoresSafeArea()
        }
        .ignoresSafeArea()
    }
}

struct HomeGridPattern: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let step: CGFloat = 40
        var x: CGFloat = 0
        while x <= rect.width  { p.move(to: .init(x:x, y:0)); p.addLine(to: .init(x:x, y:rect.height)); x += step }
        var y: CGFloat = 0
        while y <= rect.height { p.move(to: .init(x:0, y:y)); p.addLine(to: .init(x:rect.width, y:y)); y += step }
        return p
    }
}