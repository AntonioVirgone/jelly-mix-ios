//
//  ContentView.swift
//  JellyMix
//
//  Created by Antonio Virgone on 21/04/26.
//

import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel: GameViewModel
    var onReturnToMap: () -> Void

    let columns: [GridItem] = Array(repeating: .init(.flexible(), spacing: 8), count: 5)
    @State private var gridBlurRadius: CGFloat = 0
    
    private func colorIntensity(maxMoves: Int, currentMoves: Int) -> [Color] {
        if currentMoves >= maxMoves / 2 {
            return [.orange]
        } else if currentMoves >= maxMoves / 3 {
            return [.orange, .red]
        } else {
            return [.red]
        }
    }
    
    var body: some View {
        ZStack {
            // Aggiungi un bottone "Indietro" in alto a sinistra (sopra l'header)
            VStack {
                HStack {
                    Button(action: {
                        onReturnToMap()
                    }) {
                        Image(systemName: "chevron.left.circle.fill")
                            .font(.title)
                            .foregroundColor(.white)
                            .shadow(radius: 2)
                    }
                    Spacer()
                }
                .padding()
                Spacer()
            }
            VStack() {
                Text("JELLY MIX")
                    .font(.system(size: 40, weight: .black, design: .rounded))
                    .foregroundStyle(LinearGradient(colors: [.purple, .pink], startPoint: .leading, endPoint: .trailing))
                    .shadow(radius: 2)
                HStack {
                    VStack(spacing: 10) {
                        if let moves = viewModel.movesLeft, let max = viewModel.maxMoves {
                            Text("Mosse rimaste: \(moves)")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 20)
                                .background(Capsule().fill(LinearGradient(colors: colorIntensity(maxMoves: max, currentMoves: moves), startPoint: .leading, endPoint: .trailing)))
                        }
                        
                        // Barra obiettivo con dati reali
                        Text("LVL \(viewModel.currentLevel) | \(objectiveText)")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.vertical, 12)
                            .padding(.horizontal, 20)
                            .background(Capsule().fill(LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing)))
                    }
                    VStack {
                        BoxIconView(labelNumber: "\(viewModel.coins)", labelImage: "icon_coins")
                        if viewModel.keysCollected > 0 {
                            BoxIconView(labelNumber: "\(viewModel.keysCollected)", labelImage: "icon_key")
                        }
                    }
                }
                
                // BOX CONSERVA E PROSSIMO
                HStack(spacing: 30) {
                    PieceBoxView(label: "PROSSIMO", jellyType: viewModel.nextJellyType, hasKey: viewModel.nextJellyHasKey)

                    PieceBoxView(label: "CONSERVA", jellyType: viewModel.holdPiece, hasKey: viewModel.holdPieceHasKey)
                        .opacity(viewModel.hasHeldThisTurn ? 0.5 : 1.0)
                        .onTapGesture {
                            withAnimation(.spring()) { viewModel.toggleHold() }
                        }
                }.padding()

                // LA NUOVA PROGRESS BAR
                    ScoreProgressBar(score: viewModel.score, availablePieces: viewModel.currentAvailablePieces)
                        .frame(height: 70) // Diamo spazio per le icone sopra la barra
                        .padding(.horizontal)

                // GRIGLIA DI GIOCO 5x5 INTERATTIVA
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(0..<viewModel.totalCells, id: \.self) { index in
                        let cellType = index < viewModel.cellTypes.count ? viewModel.cellTypes[index] : .normal
                        AnimatedGridCell(
                            index: index,
                            jelly: viewModel.grid[index],
                            cellType: cellType,
                            generatorTurns: viewModel.generatorCounters[index],
                            mergeEvent: viewModel.mergeEvent
                        ) {
                            let row = index / viewModel.gridSize
                            let col = index % viewModel.gridSize
                            viewModel.posizionaGelatina(row: row, col: col)
                        }
                    }
                }
                // Gooey blur pulse: breve sfocatura sull'intera griglia durante il merge
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

            // Overlay win / game-over
            if viewModel.isLevelCompleted || viewModel.isGameOver {
                Color.black.opacity(0.55).ignoresSafeArea()
                VStack(spacing: 24) {
                    Text(viewModel.isLevelCompleted ? "Livello Completato!" : "Game Over")
                        .font(.system(size: 32, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                    Text(viewModel.isLevelCompleted
                         ? "Ottimo lavoro! Torna alla mappa per continuare."
                         : "Mosse esaurite. Riprova!")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.85))
                        .multilineTextAlignment(.center)
                    if viewModel.isGameOver {
                        Button("Riprova") {
                            viewModel.resetGame(forLevel: viewModel.currentLevel)
                        }
                        .font(.headline)
                        .padding(.horizontal, 32).padding(.vertical, 12)
                        .background(Capsule().fill(Color.blue))
                        .foregroundColor(.white)
                    }
                    Button("Torna alla Mappa") { onReturnToMap() }
                        .font(.headline)
                        .padding(.horizontal, 32).padding(.vertical, 12)
                        .background(Capsule().fill(Color.purple))
                        .foregroundColor(.white)
                }
                .padding(32)
                .background(RoundedRectangle(cornerRadius: 24).fill(Color.white.opacity(0.15)))
                .padding(40)
            }
        }
    }

    private var objectiveText: String {
        let obj = viewModel.objective
        switch obj.type {
        case .jelly:
            return "Crea \(obj.required) Jelly \(obj.targetColor.config.name) (\(obj.current)/\(obj.required))"
        case .obstacle:
            return "Distruggi \(obj.required) ostacoli (\(obj.current)/\(obj.required))"
        case .licorice:
            return "Distruggi \(obj.required) liquirizie (\(obj.current)/\(obj.required))"
        }
    }
}
// MARK: - Animated grid cell con Squash & Stretch + Gooey ripple

private struct AnimatedGridCell: View {
    let index: Int
    let jelly: Jelly
    let cellType: CellType
    let generatorTurns: Int?
    let mergeEvent: GameViewModel.MergeEvent?
    let onTap: () -> Void

    @State private var squashX: CGFloat = 1.0
    @State private var squashY: CGFloat = 1.0
    @State private var rippleScale: CGFloat = 0.2
    @State private var rippleOpacity: Double = 0
    @State private var rippleColor: Color = .clear

    var body: some View {
        ZStack {
            // Sfondo cella speciale (nastro o generatore)
            CellBackgroundView(cellType: cellType, generatorTurns: generatorTurns)

            // Gooey ripple
            Circle()
                .fill(rippleColor)
                .blur(radius: 14)
                .scaleEffect(rippleScale)
                .opacity(rippleOpacity)
                .allowsHitTesting(false)

            // Celle normali: ElementView sempre (gestisce anche il rendering della cella vuota).
            // Celle speciali: ElementView solo se c'è un pezzo sopra (CellBackgroundView gestisce il resto).
            if cellType == .normal || jelly.type != .empty {
                ElementView(type: jelly.type, isDirty: jelly.isDirty, isFreeze: jelly.isFreeze, hasKey: jelly.hasKey)
                    .scaleEffect(x: squashX, y: squashY)
            }
        }
        .frame(width: 60, height: 60)
        .shadow(color: jelly.type != .empty ? .black.opacity(0.15) : .clear, radius: 4, y: 2)
        .onTapGesture { onTap() }
        .onChange(of: mergeEvent) { _, event in
            guard let event, event.focusIndex == index else { return }
            playMergeAnimation(color: event.color)
        }
    }

    private func playMergeAnimation(color: Color) {
        // Prepara il ripple
        rippleColor = color.opacity(0.6)
        rippleScale = 0.2
        rippleOpacity = 0.9

        // Fase Squash (impatto)
        withAnimation(.easeOut(duration: 0.09)) {
            squashX = 1.28
            squashY = 0.72
            rippleScale = 2.2
        }
        // Fase Stretch elastica (rimbalzo)
        withAnimation(.interpolatingSpring(stiffness: 280, damping: 14).delay(0.09)) {
            squashX = 1.0
            squashY = 1.0
        }
        // Dissolvenza ripple gooey
        withAnimation(.easeIn(duration: 0.22).delay(0.10)) {
            rippleOpacity = 0
        }
    }
}

// MARK: - Cell Background (nastri e generatori)

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
            vm.coins = 10
            vm.keysCollected = 3
            return vm
        }(),
        onReturnToMap: {}
    )
}
