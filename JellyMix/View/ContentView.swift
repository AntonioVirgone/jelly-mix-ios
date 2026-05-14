//
//  ContentView.swift
//  JellyMix
//

import SwiftUI

// MARK: - Cell frame preference key

private struct CellFrame: Equatable {
    let index: Int
    let frame: CGRect
}

private struct CellFrameKey: PreferenceKey {
    static var defaultValue: [CellFrame] = []
    static func reduce(value: inout [CellFrame], nextValue: () -> [CellFrame]) {
        value.append(contentsOf: nextValue())
    }
}

// MARK: - Floating score model

private struct FloatingScoreItem: Identifiable {
    let id: UUID
    let value: Int
    let position: CGPoint
}

// MARK: - ContentView

struct ContentView: View {
    @ObservedObject var viewModel: GameViewModel
    var onReturnToMap: () -> Void

    let columns: [GridItem] = Array(repeating: .init(.flexible(), spacing: 8), count: 5)

    /// @GestureState resets automatically to default on gesture end — no extra @State needed.
    @GestureState private var dragState: (point: CGPoint, active: Bool) = (.zero, false)
    @State private var cellFrames: [CellFrame] = []
    @State private var floatingScores: [FloatingScoreItem] = []
    @State private var gridBlurRadius: CGFloat = 0

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 4, coordinateSpace: .global)
            .updating($dragState) { value, state, _ in
                state = (value.location, true)
            }
            .onEnded { value in
                guard let target = cellFrames.first(where: { $0.frame.contains(value.location) }) else { return }
                viewModel.posizionaGelatina(
                    row: target.index / viewModel.gridSize,
                    col: target.index % viewModel.gridSize
                )
            }
    }

    var body: some View {
        ZStack {
            VStack(spacing: 10) {
                // ── Top bar ────────────────────────────────────────────────
                GameTopBar(viewModel: viewModel, onReturnToMap: onReturnToMap)

                // ── Piece slots ────────────────────────────────────────────
                HStack(spacing: 24) {
                    GlassPieceBox(label: "PROSSIMO",
                                  jellyType: viewModel.nextJellyType,
                                  hasKey: viewModel.nextJellyHasKey)
                        .gesture(dragGesture)

                    GlassPieceBox(label: "CONSERVA",
                                  jellyType: viewModel.holdPiece,
                                  hasKey: viewModel.holdPieceHasKey)
                        .opacity(viewModel.hasHeldThisTurn ? 0.5 : 1.0)
                        .onTapGesture {
                            withAnimation(.spring()) { viewModel.toggleHold() }
                        }
                }

                // ── Objective progress bar ─────────────────────────────────
                ObjectiveProgressBar(
                    current: viewModel.objective.current,
                    required: viewModel.objective.required
                )

                // ── Game grid + power-ups ──────────────────────────────────
                VStack(spacing: 0) {
                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(0..<viewModel.totalCells, id: \.self) { index in
                            let cellType = index < viewModel.cellTypes.count
                                ? viewModel.cellTypes[index] : .normal
                            AnimatedGridCell(
                                index: index,
                                jelly: viewModel.grid[index],
                                cellType: cellType,
                                generatorTurns: viewModel.generatorCounters[index],
                                activePowerUp: viewModel.activePowerUp,
                                mergeEvent: viewModel.mergeEvent
                            ) {
                                if viewModel.activePowerUp != nil {
                                    viewModel.applyPowerUp(at: index)
                                } else {
                                    viewModel.posizionaGelatina(
                                        row: index / viewModel.gridSize,
                                        col: index % viewModel.gridSize
                                    )
                                }
                            }
                            .background(
                                GeometryReader { geo in
                                    Color.clear.preference(
                                        key: CellFrameKey.self,
                                        value: [CellFrame(index: index, frame: geo.frame(in: .global))]
                                    )
                                }
                            )
                        }
                    }
                    .onPreferenceChange(CellFrameKey.self) { cellFrames = $0 }

                    PowerUpBarView(viewModel: viewModel)
                        .padding(.top, 8)
                        .padding(.horizontal, 20)
                    
                    Spacer()
                    
                    // ── Score / jelly-unlock progress bar ──────────────────────
                    ScoreProgressBar(
                        score: viewModel.score,
                        availablePieces: viewModel.currentAvailablePieces
                    )
                    .frame(height: 70)
                    .padding(.horizontal)
                }
                .blur(radius: gridBlurRadius)
                .onChange(of: viewModel.mergeEvent) { _, event in
                    guard event != nil else { return }
                    withAnimation(.easeOut(duration: 0.07)) { gridBlurRadius = 2.5 }
                    withAnimation(.easeIn(duration: 0.18).delay(0.07)) { gridBlurRadius = 0 }
                }
                .padding(12)
                .background(Color.white.opacity(0.6))
                .cornerRadius(24)
                .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
                .frame(width: 350)
                .padding(.horizontal, 20)

                Spacer()
            }
            .padding(.top, 20)

            // ── Drag ghost (follows finger at 1.15×) ──────────────────────
            if dragState.active {
                ElementView(type: viewModel.nextJellyType, hasKey: viewModel.nextJellyHasKey)
                    .frame(width: 60, height: 60)
                    .scaleEffect(1.15)
                    .shadow(color: .black.opacity(0.3), radius: 14, y: 6)
                    .position(dragState.point)
                    .allowsHitTesting(false)
                    .animation(.none, value: dragState.point)
            }

            // ── Floating merge scores ─────────────────────────────────────
            ForEach(floatingScores) { item in
                FloatingScoreView(value: item.value)
                    .position(item.position)
            }

            // ── Win modal ─────────────────────────────────────────────────
            if viewModel.isLevelCompleted {
                WinModalView(viewModel: viewModel, onContinue: onReturnToMap)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    .zIndex(10)
            }

            // ── Game over modal ────────────────────────────────────────────
            if viewModel.isGameOver {
                GameOverModalView(viewModel: viewModel, onReturnToMap: onReturnToMap)
                    .transition(.opacity)
                    .zIndex(10)
            }
        }
        .animation(.easeOut(duration: 0.25), value: viewModel.isLevelCompleted)
        .animation(.easeOut(duration: 0.25), value: viewModel.isGameOver)
        .onChange(of: viewModel.mergeEvent) { _, event in
            guard let event, event.scoreGain > 0 else { return }
            guard let cell = cellFrames.first(where: { $0.index == event.focusIndex }) else { return }
            let item = FloatingScoreItem(
                id: UUID(),
                value: event.scoreGain,
                position: CGPoint(x: cell.frame.midX, y: cell.frame.midY - 30)
            )
            floatingScores.append(item)
            let id = item.id
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.95) {
                floatingScores.removeAll { $0.id == id }
            }
        }
    }
}

// MARK: - Game top bar

private struct GameTopBar: View {
    @ObservedObject var viewModel: GameViewModel
    let onReturnToMap: () -> Void

    private var movesColors: [Color] {
        guard let moves = viewModel.movesLeft, let max = viewModel.maxMoves else { return [.orange] }
        if moves >= max / 2 { return [.orange] }
        if moves >= max / 3 { return [Color(hex: "#ff8a2e"), .red] }
        return [.red]
    }

    private var objectiveLabel: String {
        let obj = viewModel.objective
        switch obj.type {
        case .jelly:    return "\(obj.current)/\(obj.required) \(obj.targetColor.config.name)"
        case .obstacle: return "Ostacoli \(obj.current)/\(obj.required)"
        case .licorice: return "Liquirizie \(obj.current)/\(obj.required)"
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            // Glass back button
            Button(action: onReturnToMap) {
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .overlay(Circle().stroke(Color.white.opacity(0.5), lineWidth: 1))
                        .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
                    Image(systemName: "chevron.left")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.primary)
                }
                .frame(width: 42, height: 42)
            }
            .buttonStyle(.plain)

            VStack {
                // Moves remaining
                if let moves = viewModel.movesLeft {
                    StatPill(text: "Mosse: \(moves)", colors: movesColors)
                }
                
                // Objective
                StatPill(
                    text: objectiveLabel,
                    colors: [Color(hex: "#a23ad6"), Color(hex: "#ef3f6e")]
                )
            }
            Spacer()

            VStack {
                // Coin pill
                HStack(spacing: 4) {
                    Image(systemName: "dollarsign.circle.fill")
                        .font(.system(size: 14, weight: .bold))
                    Text("\(viewModel.coins)")
                        .font(.system(size: 14, weight: .black, design: .rounded))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 11)
                .padding(.vertical, 7)
                .background(
                    Capsule().fill(
                        LinearGradient(
                            colors: [Color(hex: "#ffb31a"), Color(hex: "#f4a020")],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                )
                .shadow(color: Color(hex: "#c97a00").opacity(0.3), radius: 4, y: 2)
                
                VStack {
                    Text("Score")
                        .font(.system(.caption, design: .rounded))
                        .fontWeight(.black)
                        .foregroundColor(.white)
                    // Testo punteggio corrente sotto
                    Text("\(viewModel.score)")
                        .font(.system(.caption, design: .rounded))
                        .fontWeight(.black)
                        .foregroundColor(.white)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 15)
                .background(
                    Capsule().fill(
                        LinearGradient(
                            colors: [Color(hex: "#aa00aa"), Color(hex: "#aa00aa")],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                )
                .shadow(color: Color(hex: "#c97a00").opacity(0.3), radius: 4, y: 2)
            }
        }
        .padding(.horizontal, 16)
    }
}

private struct StatPill: View {
    let text: String
    let colors: [Color]
    var width: CGFloat? = nil // Se nil, userà maxWidth: .infinity

    var body: some View {
        Text(text)
            .font(.system(size: 22, weight: .heavy, design: .rounded))
            .foregroundColor(.white)
            .padding(.vertical, 12)
            .padding(.horizontal, 30)
            .frame(maxWidth: width == nil ? .infinity : nil) // Blocca la dimensione
            .frame(width: width)
            .background(
                Capsule().fill(
                    LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing)
                    // 4. Aggiungiamo un leggero bordo interno per dare profondità (opzionale)
                    )
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
            )
            .shadow(color: colors.last?.opacity(0.4) ?? .black.opacity(0.2), radius: 8, x: 0, y: 4)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
    }
}

// MARK: - Glass piece box (76pt)

private struct GlassPieceBox: View {
    let label: String
    let jellyType: ElementType?
    var hasKey: Bool = false

    var body: some View {
        VStack(spacing: 6) {
            Text(label)
                .font(.system(size: 10, weight: .black, design: .rounded))
                .foregroundColor(Color(hex: "#8a7a8e"))
                .kerning(0.8)

            ZStack {
                RoundedRectangle(cornerRadius: 18)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(Color.white.opacity(0.35))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Color.white.opacity(0.7), lineWidth: 1.5)
                    )
                    .shadow(color: .black.opacity(0.08), radius: 8, y: 3)
                    .frame(width: 76, height: 76)

                if let type = jellyType {
                    ElementView(type: type, hasKey: hasKey)
                        .frame(width: 52, height: 52)
                } else {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.black.opacity(0.06))
                        .frame(width: 52, height: 52)
                }
            }
        }
    }
}

// MARK: - Objective progress bar
private struct ObjectiveProgressBar: View {
    let current: Int
    let required: Int

    // Nuovi parametri per differenziare le due barre
    var colors: [Color] = [Color(hex: "#a23ad6"), Color(hex: "#ef3f6e")]
    var iconName: String? = nil

    private var progress: CGFloat {
        guard required > 0 else { return 1 }
        return min(CGFloat(current) / CGFloat(required), 1.0)
    }

    var body: some View {
        VStack(spacing: 8) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.black.opacity(0.08))
                        .overlay(
                            Capsule().stroke(Color.white.opacity(0.8), lineWidth: 1.5)
                        )
                    Capsule()
                        .fill(LinearGradient(
                            colors: colors,
                            startPoint: .leading, endPoint: .trailing
                        ))
                        .overlay(
                            Capsule()
                                .stroke(
                                    LinearGradient(
                                        colors: [.white.opacity(0.8), .clear],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    ),
                                    lineWidth: 2
                                )
                                .padding(1)
                        )
                        .frame(width: geo.size.width * progress)
                        .shadow(color: colors.last?.opacity(0.4) ?? .clear, radius: 4, x: 0, y: 2)
                        .animation(.spring(response: 0.5, dampingFraction: 0.75, blendDuration: 0), value: progress)
                }
            }
            .frame(height: 22)

            HStack(spacing: 6) {
                if let icon = iconName {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                        .foregroundColor(colors.last)
                }
                Text("\(current) / \(required)")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundColor(Color(hex: "#8a7a8e"))
            }
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - Floating score label
private struct FloatingScoreView: View {
    let value: Int
    @State private var offsetY: CGFloat = 0
    @State private var opacity: Double = 1
    @State private var scale: CGFloat = 0.2 // Partiamo piccolissimi per l'effetto pop

    var body: some View {
        Text("+\(value)")
            // 1. Font più grande e spesso
            .font(.system(size: 28, weight: .black, design: .rounded))
            
            // 2. Bordo bianco simulato con ombre (fondamentale per contrastare lo sfondo colorato)
            .shadow(color: .white, radius: 0.5, x: -1.5, y: -1.5)
            .shadow(color: .white, radius: 0.5, x: 1.5, y: 1.5)
            .shadow(color: .white, radius: 0.5, x: -1.5, y: 1.5)
            .shadow(color: .white, radius: 0.5, x: 1.5, y: -1.5)
            
            .foregroundStyle(
                LinearGradient(
                    colors: [Color(hex: "#a23ad6"), Color(hex: "#ef3f6e")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            // 4. Ombra morbida per profondità 3D
            .shadow(color: Color(hex: "#a23ad6").opacity(0.5), radius: 5, x: 0, y: 5)
                                .offset(y: offsetY)
            // Modificatori di stato
            .scaleEffect(scale)
            .offset(y: offsetY)
            .opacity(opacity)
            
            // 5. Animazioni concatenate per massima "Juiciness"
            .onAppear {
                // FASE 1: "Pop" iniziale (rimbalzo elastico)
                withAnimation(.spring(response: 0.3, dampingFraction: 0.5, blendDuration: 0)) {
                    scale = 1.2
                }
                
                // FASE 2: Ritorno alla dimensione normale
                withAnimation(.easeInOut(duration: 0.2).delay(0.2)) {
                    scale = 1.0
                }
                
                // FASE 3: Fluttuazione verso l'alto morbida e prolungata
                withAnimation(.easeOut(duration: 1.0)) {
                    offsetY = -80
                }
                
                // FASE 4: Dissolvenza ritardata
                withAnimation(.easeIn(duration: 0.3).delay(0.7)) {
                    opacity = 0
                }
            }
            .allowsHitTesting(false) // Ignora i tocchi
    }
}

// MARK: - Win modal

private struct WinModalView: View {
    let viewModel: GameViewModel
    let onContinue: () -> Void

    @State private var cardScale: CGFloat = 0.7
    @State private var jellyBob = false
    @State private var starsVisible = [false, false, false]

    var body: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()

            // 60 confetti pieces
            ZStack {
                ForEach(0..<60, id: \.self) { i in
                    ConfettiPiece(
                        color: confettiColors[i % confettiColors.count],
                        x: CGFloat((i * 41 + 7) % 360) - 180,
                        delay: Double(i % 12) * 0.04,
                        duration: 1.5 + Double(i % 10) * 0.12,
                        rotation: Double(i * 31)
                    )
                }
            }
            .allowsHitTesting(false)

            // Card
            VStack(spacing: 14) {
                Text("LIVELLO\nCOMPLETATO!")
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(hex: "#a23ad6"), Color(hex: "#ef3f6e")],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .multilineTextAlignment(.center)

                // Bobbing orange jelly
                ElementView(type: .orange)
                    .frame(width: 72, height: 72)
                    .offset(y: jellyBob ? -6 : 6)
                    .animation(
                        .easeInOut(duration: 1.4).repeatForever(autoreverses: true),
                        value: jellyBob
                    )

                // 3 popping stars
                HStack(spacing: 10) {
                    ForEach(0..<3, id: \.self) { i in
                        Image(systemName: "star.fill")
                            .font(.system(size: 36))
                            .foregroundColor(.yellow)
                            .shadow(color: .orange.opacity(0.5), radius: 6, y: 2)
                            .scaleEffect(starsVisible[i] ? 1.0 : 0.01)
                            .animation(
                                .spring(response: 0.4, dampingFraction: 0.5)
                                    .delay(0.3 + Double(i) * 0.15),
                                value: starsVisible[i]
                            )
                    }
                }

                // Coin total
                HStack(spacing: 6) {
                    Image(systemName: "dollarsign.circle.fill")
                        .font(.system(size: 18, weight: .bold))
                    Text("\(viewModel.coins) monete")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                }
                .foregroundColor(Color(hex: "#c97a00"))
                .padding(.horizontal, 18)
                .padding(.vertical, 9)
                .background(Capsule().fill(Color(hex: "#ffb31a").opacity(0.18)))

                Button(action: onContinue) {
                    Text("Continua")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            Capsule().fill(
                                LinearGradient(
                                    colors: [Color(hex: "#a23ad6"), Color(hex: "#ef3f6e")],
                                    startPoint: .leading, endPoint: .trailing
                                )
                            )
                        )
                        .shadow(color: Color(hex: "#b43cc8").opacity(0.35), radius: 10, y: 4)
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 28)
            .frame(width: 300)
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
            .scaleEffect(cardScale)
        }
        .onAppear {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.65)) { cardScale = 1.0 }
            jellyBob = true
            starsVisible = [true, true, true]
        }
    }
}

// MARK: - Game over modal

private struct GameOverModalView: View {
    @ObservedObject var viewModel: GameViewModel
    let onReturnToMap: () -> Void

    @State private var cardScale: CGFloat = 0.85

    var body: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()

            VStack(spacing: 18) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(
                        LinearGradient(colors: [.red, .pink], startPoint: .top, endPoint: .bottom)
                    )

                Text("Mosse Esaurite!")
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundColor(Color(hex: "#3a2a3e"))

                if viewModel.lives > 0 {
                    Button("Riprova") {
                        viewModel.resetGame(forLevel: viewModel.currentLevel)
                    }
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(Capsule().fill(
                        LinearGradient(colors: [.red, .pink],
                                       startPoint: .leading, endPoint: .trailing)
                    ))
                    .buttonStyle(.plain)
                }

                Button("Torna alla Mappa") { onReturnToMap() }
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(Capsule().fill(
                        LinearGradient(
                            colors: [Color(hex: "#a23ad6"), Color(hex: "#ef3f6e")],
                            startPoint: .leading, endPoint: .trailing
                        )
                    ))
                    .buttonStyle(.plain)
            }
            .padding(28)
            .frame(width: 300)
            .background(
                RoundedRectangle(cornerRadius: 28)
                    .fill(Color(hex: "#fff4e6"))
                    .overlay(
                        RoundedRectangle(cornerRadius: 28)
                            .stroke(Color.white.opacity(0.7), lineWidth: 1.5)
                    )
                    .shadow(color: .black.opacity(0.25), radius: 30, y: 10)
            )
            .scaleEffect(cardScale)
        }
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.65)) { cardScale = 1.0 }
        }
    }
}

// MARK: - Animated grid cell with sparkles

private struct AnimatedGridCell: View {
    let index: Int
    let jelly: Jelly
    let cellType: CellType
    let generatorTurns: Int?
    let activePowerUp: PowerUpType?
    let mergeEvent: GameViewModel.MergeEvent?
    let onTap: () -> Void

    @State private var squashX: CGFloat = 1.0
    @State private var squashY: CGFloat = 1.0
    @State private var rippleScale: CGFloat = 0.2
    @State private var rippleOpacity: Double = 0
    @State private var rippleColor: Color = .clear
    @State private var sparkleRadius: CGFloat = 0
    @State private var sparkleOpacity: Double = 0

    var body: some View {
        ZStack {
            CellBackgroundView(cellType: cellType, generatorTurns: generatorTurns)

            // Gooey ripple
            Circle()
                .fill(rippleColor)
                .blur(radius: 14)
                .scaleEffect(rippleScale)
                .opacity(rippleOpacity)
                .allowsHitTesting(false)

            // 8 sparkle particles (starburst on merge)
            if sparkleOpacity > 0 {
                ForEach(0..<8, id: \.self) { i in
                    let angle = Double(i) * 45.0 * .pi / 180
                    Image(systemName: "sparkle")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(rippleColor)
                        .offset(
                            x: cos(angle) * 26 * sparkleRadius,
                            y: sin(angle) * 26 * sparkleRadius
                        )
                        .opacity(sparkleOpacity)
                        .allowsHitTesting(false)
                }
            }

            if cellType == .normal || jelly.type != .empty {
                ElementView(type: jelly.type, isDirty: jelly.isDirty,
                            isFreeze: jelly.isFreeze, hasKey: jelly.hasKey)
                    .scaleEffect(x: squashX, y: squashY)
            }
        }
        .frame(width: 60, height: 60)
        .shadow(color: jelly.type != .empty ? .black.opacity(0.15) : .clear, radius: 4, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(activePowerUp.map { $0.accentColor } ?? .clear,
                        lineWidth: activePowerUp != nil ? 2 : 0)
                .opacity(activePowerUp != nil ? 0.8 : 0)
        )
        .onTapGesture { onTap() }
        .onChange(of: mergeEvent) { _, event in
            guard let event, event.focusIndex == index else { return }
            playMergeAnimation(color: event.color)
        }
    }

    private func playMergeAnimation(color: Color) {
        rippleColor = color.opacity(0.65)
        rippleScale = 0.2
        rippleOpacity = 0.9
        sparkleRadius = 0
        sparkleOpacity = 1.0

        // Squash impact
        withAnimation(.easeOut(duration: 0.09)) {
            squashX = 1.28
            squashY = 0.72
            rippleScale = 2.2
        }
        // Elastic stretch back
        withAnimation(.interpolatingSpring(stiffness: 280, damping: 14).delay(0.09)) {
            squashX = 1.0
            squashY = 1.0
        }
        // Ripple fade
        withAnimation(.easeIn(duration: 0.22).delay(0.10)) { rippleOpacity = 0 }
        // Sparkles expand then fade
        withAnimation(.easeOut(duration: 0.38)) { sparkleRadius = 1.0 }
        withAnimation(.easeIn(duration: 0.2).delay(0.22)) { sparkleOpacity = 0 }
    }
}

// MARK: - Power-up bar

private struct PowerUpBarView: View {
    @ObservedObject var viewModel: GameViewModel

    var body: some View {
        HStack(spacing: 12) {
            ForEach(PowerUpType.allCases, id: \.self) { type in
                let count = viewModel.powerUps[type] ?? 0
                let isActive = viewModel.activePowerUp == type

                Button {
                    viewModel.activatePowerUp(type)
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: type.systemImage)
                            .font(.system(size: 20, weight: .bold))
                        Text("×\(count)")
                            .font(.system(size: 10, weight: .black, design: .rounded))
                    }
                    .foregroundColor(count > 0 ? .white : .white.opacity(0.35))
                    .frame(width: 64, height: 52)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(isActive
                                  ? type.accentColor
                                  : type.accentColor.opacity(count > 0 ? 0.55 : 0.2))
                            .shadow(color: isActive ? type.accentColor.opacity(0.6) : .clear, radius: 8, y: 3)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(isActive ? Color.white.opacity(0.9) : .clear, lineWidth: 2)
                    )
                    .scaleEffect(isActive ? 1.08 : 1.0)
                    .animation(.spring(response: 0.25, dampingFraction: 0.65), value: isActive)
                }
                .disabled(count == 0)
            }
        }
    }
}

// MARK: - Cell background (conveyors and generators)

private struct CellBackgroundView: View {
    let cellType: CellType
    let generatorTurns: Int?

    var body: some View {
        switch cellType {
        case .normal:
            EmptyView()

        case .conveyor(let direction):
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.indigo.opacity(0.35))
                .overlay(
                    Image(systemName: direction.systemImage)
                        .font(.system(size: 22, weight: .black))
                        .foregroundColor(.white.opacity(0.8))
                )

        case .generator(let output):
            let turnsLeft = 3 - (generatorTurns ?? 0)
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.teal.opacity(0.4))
                .overlay(
                    VStack(spacing: 2) {
                        ElementView(type: output)
                            .frame(width: 34, height: 34)
                            .opacity(0.85)
                        Text("\(turnsLeft)")
                            .font(.system(size: 10, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.4), radius: 1)
                    }
                )
        }
    }
}

#Preview {
    ContentView(
        viewModel: {
            let vm = GameViewModel()
            vm.movesLeft = 10
            vm.coins = 120
            vm.score = 2500
            return vm
        }(),
        onReturnToMap: {}
    )
}
