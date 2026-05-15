//
//  ShopView.swift
//  JellyMix
//

import SwiftUI

// MARK: - Pack opening state machine

private enum PackState: Equatable {
    case idle
    case shaking
    case bursting
    case revealing
}

// MARK: - PowerUpType helpers (local to ShopView)

private extension PowerUpType {
    var shopDescription: String {
        switch self {
        case .hammer: return "Distruggi qualsiasi cella della griglia"
        case .swap:   return "Scambia il prossimo pezzo con una cella"
        case .brush:  return "Trasforma il pezzo corrente in Arcobaleno"
        }
    }
}

// MARK: - ShopView

struct ShopView: View {
    @ObservedObject var viewModel: GameViewModel

    @State private var packState: PackState = .idle
    @State private var pulledCards: [ElementType] = []
    @State private var packScale: CGFloat = 1.0
    @State private var packOpacity: Double = 1.0
    @State private var packOffset: CGFloat = 0

    var body: some View {
        ZStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    // ── Header ────────────────────────────────────────────
                    ShopHeaderView(coins: viewModel.coins)

                    // ── Pack card ─────────────────────────────────────────
                    PackCard(
                        viewModel: viewModel,
                        packState: packState,
                        packScale: packScale,
                        packOpacity: packOpacity,
                        packOffset: packOffset,
                        onOpen: triggerPackOpen
                    )

                    // ── Power-ups section ─────────────────────────────────
                    PowerUpsSection(viewModel: viewModel)

                    Spacer(minLength: 32)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
            }

            // ── Pack reveal overlay ───────────────────────────────────────
            if packState == .revealing {
                PackRevealOverlay(cards: pulledCards) {
                    withAnimation(.easeOut(duration: 0.2)) { packState = .idle }
                    packScale = 1.0
                    packOpacity = 1.0
                }
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                .zIndex(10)
            }
        }
        .animation(.easeOut(duration: 0.25), value: packState == .revealing)
    }

    // MARK: - Pack open sequence

    private func triggerPackOpen() {
        guard packState == .idle, viewModel.coins >= 100 else { return }
        pulledCards = viewModel.buyAndOpenPack(cost: 100) ?? []
        packState = .shaking
        runShakeAnimation()
    }

    private func runShakeAnimation() {
        // 9 steps × 0.1s = 0.9s total shake
        let offsets: [CGFloat] = [-9, 9, -7, 7, -5, 5, -3, 3, 0]
        for (i, offset) in offsets.enumerated() {
            withAnimation(.easeInOut(duration: 0.09).delay(Double(i) * 0.1)) {
                packOffset = offset
            }
        }
        // After shake → burst
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.95) {
            packState = .bursting
            withAnimation(.easeOut(duration: 0.35)) {
                packScale = 1.35
                packOpacity = 0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                packState = .revealing
            }
        }
    }
}

// MARK: - Shop header

private struct ShopHeaderView: View {
    let coins: Int

    var body: some View {
        ZStack {
            Text("NEGOZIO")
                .font(.system(size: 34, weight: .black, design: .rounded))
                .foregroundStyle(LinearGradient(
                    colors: [Color(hex: "#a23ad6"), Color(hex: "#ef3f6e")],
                    startPoint: .leading, endPoint: .trailing
                ))

            HStack {
                Spacer()
                HStack(spacing: 5) {
                    Image(systemName: "dollarsign.circle.fill")
                        .font(.system(size: 14, weight: .bold))
                    Text("\(coins)")
                        .font(.system(size: 15, weight: .black, design: .rounded))
                }
                .foregroundColor(.white)
                .padding(.vertical, 8)
                .padding(.horizontal, 14)
                .background(Capsule().fill(LinearGradient(
                    colors: [Color(hex: "#ffb31a"), Color(hex: "#f4a020")],
                    startPoint: .leading, endPoint: .trailing
                )))
                .shadow(color: Color(hex: "#c97a00").opacity(0.3), radius: 4, y: 2)
            }
        }
        .padding(.top, 8)
    }
}

// MARK: - Pack card

private struct PackCard: View {
    @ObservedObject var viewModel: GameViewModel
    let packState: PackState
    let packScale: CGFloat
    let packOpacity: Double
    let packOffset: CGFloat
    let onOpen: () -> Void

    private let canAfford: Bool

    init(viewModel: GameViewModel, packState: PackState, packScale: CGFloat,
         packOpacity: Double, packOffset: CGFloat, onOpen: @escaping () -> Void) {
        self.viewModel = viewModel
        self.packState = packState
        self.packScale = packScale
        self.packOpacity = packOpacity
        self.packOffset = packOffset
        self.onOpen = onOpen
        self.canAfford = viewModel.coins >= 100
    }

    var body: some View {
        VStack(spacing: 18) {
            // Title
            Text("Bustina di Gelatine")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(LinearGradient(
                    colors: [Color(hex: "#a23ad6"), Color(hex: "#ef3f6e")],
                    startPoint: .leading, endPoint: .trailing
                ))

            Text("3 carte casuali, incluse le rare!")
                .font(.system(size: 13, design: .rounded))
                .foregroundColor(Color(hex: "#8a7a8e"))
                .multilineTextAlignment(.center)

            // Pack visual with sparkles
            PackVisual(
                scale: packScale,
                opacity: packOpacity,
                offset: packOffset
            )

            // Open button
            Button(action: onOpen) {
                HStack(spacing: 6) {
                    Text("Apri Bustina")
                        .font(.system(size: 16, weight: .black, design: .rounded))
                    Text("— 100")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                    Image(systemName: "dollarsign.circle.fill")
                        .font(.system(size: 15, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    Capsule().fill(canAfford
                        ? LinearGradient(colors: [Color(hex: "#3d8cff"), Color(hex: "#a35bff")],
                                         startPoint: .leading, endPoint: .trailing)
                        : LinearGradient(colors: [Color.gray.opacity(0.5), Color.gray.opacity(0.4)],
                                         startPoint: .leading, endPoint: .trailing)
                    )
                )
                .shadow(color: canAfford ? Color(hex: "#3d8cff").opacity(0.4) : .clear, radius: 8, y: 3)
            }
            .buttonStyle(.plain)
            .disabled(!canAfford || packState != .idle)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 22)
        .background(
            RoundedRectangle(cornerRadius: 28)
                .fill(LinearGradient(
                    colors: [
                        Color(red: 1, green: 0.37, blue: 0.64, opacity: 0.18),
                        Color(red: 0.64, green: 0.36, blue: 1.0, opacity: 0.18)
                    ],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28))
                .overlay(
                    RoundedRectangle(cornerRadius: 28)
                        .stroke(Color.white.opacity(0.65), lineWidth: 1.5)
                )
                .shadow(color: Color(hex: "#b43cc8").opacity(0.15), radius: 16, y: 6)
        )
    }
}

// MARK: - Pack visual (bustina + sparkles)

private struct PackVisual: View {
    let scale: CGFloat
    let opacity: Double
    let offset: CGFloat

    @State private var sparkPulse = false
    @State private var floatOffset: CGFloat = 5 // Per l'animazione fluttuante

    var body: some View {
        ZStack {
            // 4 decorative sparkles at corners
            ForEach(0..<8, id: \.self) { i in
                let positions: [(CGFloat, CGFloat)] = [
                    (-58, -30),
                    (61, -50),
                    (-68, 35),
                    (58, 30),
                    (30, 65),
                    (-30, 65),
                    (30, -65),
                    (-30, -65)]
                let isEven = i % 2 == 0

                Image(systemName: "sparkle")
                    .font(.system(size: isEven ? 20 : 14, weight: .bold))
                    .foregroundColor([Color(hex: "#a23ad6"), Color(hex: "#ef3f6e"),
                                      Color(hex: "#ffb31a"), Color(hex: "#3d8cff"),
                                      Color(hex: "#a23ad6"), Color(hex: "#ef3f6e"),
                                      Color(hex: "#ffb31a"), Color(hex: "#3d8cff")][i])
                    .scaleEffect(sparkPulse ? 1.2 : 0.5)
                    .opacity(sparkPulse ? 1.0 : 0.2)
                    .offset(x: positions[i].0, y: positions[i].1)
                    .animation(
                        .easeInOut(duration: 0.9)
                            .repeatForever(autoreverses: true)
                            .delay(Double(i) * 0.25),
                        value: sparkPulse
                    )
            }

            // Pack body
            ZStack {
                // Sfondo Dorato (Se preferisci Argento, usa: #FFFFFF, #D7DDE8, #757F9A)
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "#a23ad6"), Color(hex: "#6a1fa8"), Color(hex: "#FF8C00")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    // Ombra dorata/aranciata per far risaltare il bagliore
                    .shadow(color: Color(hex: "#FF8C00").opacity(0.5), radius: 15, y: 10)
                
                // Bordo interno smussato (Effetto 3D)
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [.white, .white.opacity(0.2), Color(hex: "#FF8C00").opacity(0.5)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
                    .padding(1)

                // Decorazione geometrica interna (Incisione)
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .padding(12)
                
                // Icona Mistero Centrale (Puoi usare "star.fill", "diamond.fill" o "questionmark")
                Image(systemName: "star.fill")
                    .font(.system(size: 44, weight: .black))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, Color(hex: "#FFF4E0")],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: Color(hex: "#FF8C00").opacity(0.6), radius: 5, y: 3)

                // Riflesso di luce (Gloss / Glass Overlay) in alto a sinistra
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [.white.opacity(0.6), .clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .mask(
                        // Maschera diagonale per tagliare il riflesso a metà
                        GeometryReader { geo in
                            Path { path in
                                path.move(to: CGPoint(x: 0, y: 0))
                                path.addLine(to: CGPoint(x: geo.size.width * 0.8, y: 0))
                                path.addLine(to: CGPoint(x: 0, y: geo.size.height * 0.7))
                                path.closeSubpath()
                            }
                        }
                    )
            }
            .frame(width: 110, height: 130)
            .offset(y: floatOffset) // Applica il movimento fluttuante al Token
        }
        .frame(width: 150, height: 170)
        .scaleEffect(scale)
        .opacity(opacity)
        .offset(x: offset)
        .onAppear {
            sparkPulse = true
            // Avvia l'animazione di fluttuazione continua
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                floatOffset = -5
            }
        }
    }
}

// MARK: - Power-ups section

private struct PowerUpsSection: View {
    @ObservedObject var viewModel: GameViewModel

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Text("Potenziamenti")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(LinearGradient(
                        colors: [Color(hex: "#a23ad6"), Color(hex: "#ef3f6e")],
                        startPoint: .leading, endPoint: .trailing
                    ))
                Spacer()
            }

            VStack(spacing: 10) {
                ForEach(PowerUpType.allCases, id: \.self) { type in
                    PowerUpShopRow(type: type, viewModel: viewModel)
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 28)
                .fill(LinearGradient(
                    colors: [
                        Color(red: 1, green: 0.37, blue: 0.22, opacity: 0.14),
                        Color(red: 1, green: 0.37, blue: 0.64, opacity: 0.14)
                    ],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28))
                .overlay(
                    RoundedRectangle(cornerRadius: 28)
                        .stroke(Color.white.opacity(0.65), lineWidth: 1.5)
                )
                .shadow(color: Color(hex: "#ef3f6e").opacity(0.12), radius: 12, y: 4)
        )
    }
}

// MARK: - Power-up row

private struct PowerUpShopRow: View {
    let type: PowerUpType
    @ObservedObject var viewModel: GameViewModel
    @State private var bumpScale: CGFloat = 1.0

    var body: some View {
        let count = viewModel.powerUps[type] ?? 0
        let canAfford = viewModel.coins >= PowerUpType.cost

        HStack(spacing: 14) {
            // Colored icon tile
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(type.accentColor.opacity(0.18))
                    .frame(width: 46, height: 46)
                Image(systemName: type.systemImage)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(type.accentColor)
            }

            // Name + description
            VStack(alignment: .leading, spacing: 3) {
                Text(type.displayName)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: "#3a2a3e"))
                Text(type.shopDescription)
                    .font(.system(size: 11, design: .rounded))
                    .foregroundColor(Color(hex: "#8a7a8e"))
                    .lineLimit(2)
            }

            Spacer()

            // Owned badge + buy button
            VStack(spacing: 5) {
                // Owned count
                Text("×\(count)")
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundColor(type.accentColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(type.accentColor.opacity(0.12)))

                // Price pill
                Button(action: {
                    viewModel.buyPowerUp(type)
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.5)) { bumpScale = 1.2 }
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.5).delay(0.1)) { bumpScale = 1.0 }
                }) {
                    HStack(spacing: 3) {
                        Text("\(PowerUpType.cost)")
                            .font(.system(size: 11, weight: .black, design: .rounded))
                        Image(systemName: "dollarsign.circle.fill")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(canAfford
                        ? LinearGradient(colors: [type.accentColor, type.accentColor.opacity(0.75)],
                                         startPoint: .leading, endPoint: .trailing)
                        : LinearGradient(colors: [Color.gray.opacity(0.4), Color.gray.opacity(0.3)],
                                         startPoint: .leading, endPoint: .trailing)
                    ))
                }
                .buttonStyle(.plain)
                .disabled(!canAfford)
                .scaleEffect(bumpScale)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.55))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.7), lineWidth: 1)
                )
        )
    }
}

// MARK: - Pack reveal overlay

private struct PackRevealOverlay: View {
    let cards: [ElementType]
    let onClose: () -> Void

    @State private var overlayOpacity: Double = 0

    var body: some View {
        ZStack {
            Color.black.opacity(0.65)
                .ignoresSafeArea()
                .onTapGesture { }  // block pass-through taps

            VStack(spacing: 24) {
                Text("HAI OTTENUTO")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: "#8a7a8e"))
                    .kerning(2)

                HStack(spacing: 16) {
                    ForEach(Array(cards.enumerated()), id: \.offset) { i, card in
                        RevealCardView(jellyType: card, flipDelay: 0.3 + Double(i) * 0.25)
                            .frame(width: 90, height: 135)
                    }
                }

                Button(action: onClose) {
                    Text("Fantastico!")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(Capsule().fill(LinearGradient(
                            colors: [Color(hex: "#a23ad6"), Color(hex: "#ef3f6e")],
                            startPoint: .leading, endPoint: .trailing
                        )))
                        .shadow(color: Color(hex: "#b43cc8").opacity(0.35), radius: 10, y: 4)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 24)
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 32)
            .background(
                RoundedRectangle(cornerRadius: 28)
                    .fill(LinearGradient(
                        colors: [Color(hex: "#fff4e6"), Color(hex: "#f0e6f7")],
                        startPoint: .top, endPoint: .bottom
                    ))
                    .overlay(
                        RoundedRectangle(cornerRadius: 28)
                            .stroke(Color.white.opacity(0.7), lineWidth: 1.5)
                    )
                    .shadow(color: .black.opacity(0.25), radius: 30, y: 10)
            )
            .opacity(overlayOpacity)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.25)) { overlayOpacity = 1 }
        }
    }
}

// MARK: - Reveal card (auto-flip with delay)

private struct RevealCardView: View {
    let jellyType: ElementType
    let flipDelay: Double

    @State private var isFlipped = false
    @State private var glowPulse = false

    var body: some View {
        ZStack {
            // Back face
            RoundedRectangle(cornerRadius: 15)
                .fill(LinearGradient(
                    colors: [Color(hex: "#a23ad6"), Color(hex: "#3d1a6e")],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
                .overlay(
                    Image(systemName: "star.circle.fill")
                        .font(.system(size: 38))
                        .foregroundColor(.white.opacity(0.25))
                )
                .shadow(color: .black.opacity(0.2), radius: 6, y: 3)
                .opacity(isFlipped ? 0 : 1)

            // Front face
            RoundedRectangle(cornerRadius: 15)
                .fill(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(jellyType.config.color.opacity(0.4), lineWidth: 2)
                )
                .shadow(
                    color: jellyType.config.color.opacity(glowPulse ? 0.6 : 0.2),
                    radius: glowPulse ? 14 : 6, y: 3
                )
                .overlay(
                    VStack(spacing: 10) {
                        Text(jellyType.config.name.uppercased())
                            .font(.system(size: 9, weight: .black, design: .rounded))
                            .foregroundColor(jellyType.config.color.opacity(0.7))
                            .kerning(1.5)
                            .padding(.top, 12)

                        Spacer()

                        ElementView(type: jellyType)
                            .frame(width: 56, height: 56)

                        Spacer()
                    }
                )
                .rotation3DEffect(.degrees(-180), axis: (x: 0, y: 1, z: 0))
                .opacity(isFlipped ? 1 : 0)
        }
        .rotation3DEffect(.degrees(isFlipped ? 180 : 0), axis: (x: 0, y: 1, z: 0))
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + flipDelay) {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.72)) {
                    isFlipped = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                        glowPulse = true
                    }
                }
            }
        }
    }
}

#Preview {
    ShopView(viewModel: {
        let vm = GameViewModel()
        vm.coins = 600
        vm.powerUps[.hammer] = 2
        return vm
    }())
}
