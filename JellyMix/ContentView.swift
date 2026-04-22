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
    @StateObject var viewModel = GameViewModel()
    
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
            // Sfondo sfumato
            LinearGradient(
                colors: [
                    Color.yellow.opacity(0.2),
                    Color.purple.opacity(0.2),
                    Color.pink.opacity(0.2)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ).ignoresSafeArea()
            
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
                    // Barra del livello (finta per ora)
                    Text("LIVELLO 1 | Missione: Distruggi 5 Ostacoli")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 20)
                        .background(Capsule().fill(LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing)))
                }.padding(.bottom, 10)
                
                // BOX CONSERVA E PROSSIMO
                HStack(spacing: 20) {
                    // Box Conserva
                    HStack {
                        // Box Prossimo
                        BoxView(text: "PROSSIMO", color: viewModel.nextJellyType.color)
                        BoxView(text: "CONSERVA", color: Color.gray.opacity(0.3))
                    }
                }
                Spacer()

                // GRIGLIA DI GIOCO 5x5 INTERATTIVA
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(0..<viewModel.totalCells, id: \.self) { index in
                        let jelly = viewModel.grid[index]
                        
                        RoundedRectangle(cornerRadius: 16)
                            .fill(jelly.type.color) // <--- Wiring qui
                            .frame(width: 60, height: 60)
                            .shadow(color: jelly.type != .empty ? .black.opacity(0.15) : .clear, radius: 4, y: 2)
                            // Aggiungiamo il gesto di tocco qui!
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
        }
    }
}

#Preview {
    ContentView()
}
