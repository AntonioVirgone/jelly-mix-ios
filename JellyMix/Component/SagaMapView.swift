//
//  SagaMapView.swift
//  JellyMix
//
//  Created by Antonio Virgone on 22/04/26.
//

import Foundation
import SwiftUI

// MARK: - Modelli per la Mappa
struct WorldMapConfig: Identifiable {
    let id: Int
    let name: String
    let levels: [Int] // Lista dei numeri di livello in questo mondo (es. 1, 2, 3)
    let color: Color
    let icon: String // Emoji o icona SF Symbol per il banner
}

// MARK: - Configurazione Dati Mappa (Esempio)
let MOCK_MAP_CONFIG: [WorldMapConfig] = [
    WorldMapConfig(id: 1, name: "Valle delle Gelatine", levels: [1, 2, 3], color: .pink, icon: "🍓"),
    WorldMapConfig(id: 2, name: "Regno di Ghiaccio", levels: [4, 5, 6], color: .cyan, icon: "🧊"),
    WorldMapConfig(id: 3, name: "Foresta di Waffle", levels: [7, 8, 9, 10], color: .orange, icon: "🧇"),
    WorldMapConfig(id: 4, name: "Mari di miele", levels: [11, 12, 13, 14], color: .brown, icon: "🧇")
]

// MARK: - Vista Mappa Saga Verticale
struct SagaMapView: View {
    var maxUnlockedLevel: Int
    var onPlayLevel: (Int) -> Void // Callback per l'azione di gioco
    
    var body: some View {
        ZStack {
            
            ScrollView {
                VStack(spacing: 0) {
                    // Spaziatore iniziale
                    Color.clear.frame(height: 50)
                    
                    ForEach(MOCK_MAP_CONFIG) { world in
                        renderWorldSection(world: world)
                    }
                    
                    // Spaziatore finale
                    Color.clear.frame(height: 100)
                }
            }
            // Nascondiamo la barra di scorrimento per un look più pulito
            .scrollIndicators(.hidden)
        }
    }
    
    // Disegna la sezione completa di un Mondo
    @ViewBuilder
    private func renderWorldSection(world: WorldMapConfig) -> some View {
        VStack(spacing: 0) {
            
            // 1. Banner del Mondo (come image_1.png)
            HStack {
                Text(world.icon)
                    .font(.title)
                VStack(alignment: .leading, spacing: 2) {
                    Text("MONDO \(world.id)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .opacity(0.8)
                    Text(world.name)
                        .font(.headline)
                        .fontWeight(.black)
                }
                Spacer()
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 15)
                    .fill(world.color)
                    .shadow(color: world.color.opacity(0.4), radius: 8, y: 4)
            )
            .foregroundColor(.white)
            .padding(.horizontal)
            .padding(.bottom, 30)
            
            // 2. Il Percorso Tortuoso dei Livelli
            LazyVStack(spacing: 30) {
                ForEach(Array(world.levels.enumerated()), id: \.element) { index, levelNum in
                    
                    // Calcolo dell'offset orizzontale per creare l'effetto tortuoso (zig-zag)
                    // I livelli dispari vanno a sinistra, i pari a destra
                    let isEven = index % 2 == 0
                    let horizontalOffset: CGFloat = isEven ? 80 : -80
                    
                    HStack {
                        if !isEven { Spacer() } // Sposta a destra se pari
                        
                        renderLevelNode(levelNum: levelNum)
                            .offset(x: horizontalOffset)
                        
                        if isEven { Spacer() } // Sposta a sinistra se dispari
                    }
                    .padding(.horizontal, 40) // Margine extra per il tortuoso
                    
                    // Disegna la linea tratteggiata di connessione tra i livelli
                    if levelNum < world.levels.last! {
                        MapPathLineView(color: world.color.opacity(0.6), horizontalOffset: horizontalOffset)
                    }
                }
            }
            .padding(.bottom, 50)
        }
    }
    
    // Disegna il singolo nodo del livello (il cerchio cliccabile)
    @ViewBuilder
    private func renderLevelNode(levelNum: Int) -> some View {
        let isUnlocked = levelNum <= maxUnlockedLevel
        let isCompleted = levelNum < maxUnlockedLevel
        let isCurrent = levelNum == maxUnlockedLevel
        
        Button(action: {
            if isUnlocked {
                onPlayLevel(levelNum)
            }
        }) {
            ZStack {
                // Cerchio di base
                Circle()
                    .fill(
                        isCurrent ?
                        // Gradiente dorato per il livello attuale
                        LinearGradient(colors: [.yellow, .orange], startPoint: .topLeading, endPoint: .bottomTrailing)
                        :
                        // Sfondo per sbloccati o bloccati
                        LinearGradient(colors: [isUnlocked ? .white : Color.gray.opacity(0.3), isUnlocked ? Color(white: 0.9) : Color.gray.opacity(0.5)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .frame(width: 70, height: 70)
                    .shadow(color: isCurrent ? .orange.opacity(0.5) : .black.opacity(0.1), radius: 10, y: 5)
                
                // Contorno
                Circle()
                    .stroke(isCurrent ? Color.orange : (isUnlocked ? Color.white : Color.gray.opacity(0.5)), lineWidth: 5)
                    .frame(width: 70, height: 70)
                
                // Contenuto: Numero o Lucchetto
                Group {
                    if isCompleted {
                        // Stella per completati
                        Image(systemName: "star.fill")
                            .font(.title)
                            .foregroundColor(.yellow)
                            .shadow(radius: 1)
                    } else if isCurrent {
                        // Numero grande e bianco per attuale
                        Text("\(levelNum)")
                            .font(.system(size: 32, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                            .shadow(radius: 2)
                    } else if isUnlocked {
                        // Numero grigio per sbloccati
                        Text("\(levelNum)")
                            .font(.system(size: 32, weight: .black, design: .rounded))
                            .foregroundColor(.gray)
                    } else {
                        // Lucchetto per bloccati
                        Image(systemName: "lock.fill")
                            .font(.title2)
                            .foregroundColor(.gray.opacity(0.7))
                    }
                }
                
                // Avatar Giocatore (Segnaposto carino sopra il livello attuale)
                if isCurrent {
                    ElementView(type: .red)
                        .frame(width: 30, height: 30)
                        .offset(y: -45)
                        .shadow(radius: 3)
                        .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: isCurrent) // Animazione fluttuante
                }
            }
        }
        .disabled(!isUnlocked)
    }
}

// Disegna la linea tratteggiata curva tra due livelli
struct MapPathLineView: View {
    var color: Color
    var horizontalOffset: CGFloat
    
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                let midX = geometry.size.width / 2
                let startY: CGFloat = -15 // Inizia leggermente sopra
                let endY: CGFloat = 15 // Finisce leggermente sotto
                
                // Curva tortuosa invertendo l'offset orizzontale
                path.move(to: CGPoint(x: midX + horizontalOffset, y: startY))
                path.addQuadCurve(to: CGPoint(x: midX - horizontalOffset, y: endY),
                                  control: CGPoint(x: midX, y: (startY + endY) / 2))
            }
            .stroke(color, style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round, dash: [10, 10])) // Tratteggio
        }
        .frame(height: 30) // Altezza dello spaziatore tra livelli
        .offset(y: -15) // Allinea al centro
    }
}

// MARK: - Preview
#Preview {
    SagaMapView(maxUnlockedLevel: 2, onPlayLevel: { _ in })
}
