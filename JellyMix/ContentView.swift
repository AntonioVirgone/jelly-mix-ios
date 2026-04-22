//
//  ContentView.swift
//  JellyMix
//
//  Created by Antonio Virgone on 21/04/26.
//

import SwiftUI

// Un piccolo enum temporaneo per dare colore alla nostra griglia di test
enum JellyType {
    case empty, red, blue, green, yellow
    
    var color: Color {
        switch self {
        case .empty: return Color.gray.opacity(0.2)
        case .red: return .red
        case .blue: return .blue
        case .green: return .green
        case .yellow: return .yellow
        }
    }
}

struct ContentView: View {
    // Inizializzazione del ViewModel (@StateObject lo mantiene in vita)
    @ObservedObject var viewModel = GameViewModel()
    
    // Azione da eseguire per tornare indietro
    var onReturnToMap: () -> Void

    // 1. Aggiungi questa riga anche qui
    @Environment(\.colorScheme) var colorScheme

    // Definiamo 5 colonne flessibili per la nostra griglia
    let columns: [GridItem] = Array(repeating: .init(.flexible(), spacing: 8), count: 5)
    
    // Creiamo una griglia finta di 25 celle (@State è l'equivalente di useState in React)
    @State private var grid: [JellyType] = [
        .empty, .empty, .empty, .empty, .empty,
        .empty, .yellow, .empty, .empty, .empty,
        .empty, .empty, .empty, .empty, .empty,
        .green, .green, .empty, .empty, .empty,
        .empty, .green, .empty, .empty, .empty
    ]

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
            VStack(spacing: 30) {
                Text("JELLY MIX")
                    .font(.system(size: 40, weight: .black, design: .rounded))
                    .foregroundStyle(LinearGradient(colors: [.purple, .pink], startPoint: .leading, endPoint: .trailing))
                    .shadow(radius: 2)
                VStack(spacing: 10) {
                    Text("PUNTI: \(viewModel.score)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 20)
                        .background(Capsule().fill(Color.purple.opacity(0.8)))
                    // Barra obiettivo con dati reali
                    Text("LVL \(viewModel.currentLevel) | \(objectiveText)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 20)
                        .background(Capsule().fill(LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing)))
                }.padding(.bottom, 10)
                
                // BOX CONSERVA E PROSSIMO
                HStack(spacing: 30) {
                    // Box Prossimo
                    VStack {
                        Text("PROSSIMO")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.gray)
                        
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white.opacity(0.6))
                            .frame(width: 90, height: 90)
                            .overlay(
                                ElementView(type: viewModel.nextJellyType, isDirty: false)
                                    .frame(width: 60, height: 60)
                            )
                    }
                    // Box Conserva
                    VStack {
                        Text("CONSERVA")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.gray)
                        
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white.opacity(0.6))
                            .frame(width: 90, height: 90)
                            .overlay(
                                Group {
                                    if let held = viewModel.holdPiece {
                                        // Visualizza la gelatina conservata
                                        ElementView(type: held, isDirty: false)
                                            .frame(width: 60, height: 60)
                                    } else {
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(colorScheme == .dark ? Color.white.opacity(0.8) : Color.black.opacity(0.08))
                                            .frame(width: 60, height: 60)
                                    }
                                }
                            )
                            // Applichiamo un effetto visivo se è già stato usato in questo turno
                            .opacity(viewModel.hasHeldThisTurn ? 0.5 : 1.0)
                            .onTapGesture {
                                withAnimation(.spring()) {
                                    viewModel.toggleHold()
                                }
                            }
                    }
                }
                Spacer()

                // GRIGLIA DI GIOCO 5x5 INTERATTIVA
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(0..<viewModel.totalCells, id: \.self) { index in
                        let jelly = viewModel.grid[index]
                        
                        ElementView(type: jelly.type, isDirty: jelly.isDirty)
                            .frame(width: 60, height: 60)
                            .shadow(color: jelly.type != .empty ? .black.opacity(0.15) : .clear, radius: 4, y: 2)
                            .onTapGesture {
                                // Calcola riga e colonna dall'indice flat
                                let row = index / viewModel.gridSize
                                let col = index % viewModel.gridSize
                                viewModel.posizionaGelatina(row: row, col: col)
                            }
                    }
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
