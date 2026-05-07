//
//  SagaMapView.swift
//  JellyMix
//
//  Created by Antonio Virgone on 22/04/26.
//

import Foundation
import SwiftUI

// MARK: - Vista Mappa Saga Verticale
struct SagaMapView: View {
    @State private var showNoLivesAlert = false
    
    var worlds: [WorldData]
    var maxUnlockedLevel: Int
    var getColor: (String) -> Color
    var onPlayLevel: (Int) -> Void

    var body: some View {
        ZStack {
            // ScrollViewReader permette di controllare programmaticamente lo scorrimento
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 0) {
                        // Spaziatore iniziale per non coprire il primo mondo con la UI superiore
                        Color.clear.frame(height: 50)
                        
                        ForEach(worlds) { world in
                            renderWorldSection(world: world)
                        }
                        
                        // Spaziatore finale per permettere di scorrere oltre l'ultimo livello
                        Color.clear.frame(height: 100)
                    }
                    .onAppear {
                        // All'apertura, scorriamo automaticamente verso il livello attuale (maxUnlockedLevel)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            withAnimation(.easeInOut(duration: 0.5)) {
                                // .center posiziona il livello target al centro dello schermo
                                proxy.scrollTo("level_\(maxUnlockedLevel)", anchor: .center)
                            }
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }
        }
    }
    
    func timeString(from seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%02d:%02d", m, s)
    }
    
    // Disegna la sezione completa di un Mondo
    @ViewBuilder
    private func renderWorldSection(world: WorldData) -> some View {
        let worldColor = getColor(world.color)
        
        // MODIFICA: Ordiniamo i livelli del mondo prima della visualizzazione
        let sortedLevels = world.levels.sorted { $0.levelNumber < $1.levelNumber }

        VStack(spacing: 0) {
            // 1. Banner del Mondo
            HStack {
                Text(world.icon)
                    .font(.title)
                VStack(alignment: .leading, spacing: 2) {
                    Text("MONDO \(world.stageNumber)")
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
                    .fill(worldColor)
                    .shadow(color: worldColor.opacity(0.4), radius: 8, y: 4)
            )
            .foregroundColor(.white)
            .padding(.horizontal)
            .padding(.bottom, 30)
            
            // 2. Il Percorso Tortuoso dei Livelli (Zig-Zag)
            LazyVStack(spacing: 30) {
                ForEach(Array(sortedLevels.enumerated()), id: \.element.levelNumber) { index, levelData in
                    let levelNum = levelData.levelNumber
                    
                    // Calcolo dell'offset per creare l'effetto zig-zag
                    let isEven = index % 2 == 0
                    let horizontalOffset: CGFloat = isEven ? 80 : -80
                    
                    HStack {
                        if !isEven { Spacer() }
                        
                        renderLevelNode(levelNum: levelNum)
                            .offset(x: horizontalOffset)
                        
                        if isEven { Spacer() }
                    }
                    .padding(.horizontal, 40)
                    .id("level_\(levelNum)")
                    
                    // Disegna la linea di connessione se non è l'ultimo livello del mondo
                    if index < sortedLevels.count - 1 {
                        MapPathLineView(color: worldColor.opacity(0.6), horizontalOffset: horizontalOffset)
                    }
                }
            }
            .padding(.bottom, 50)
        }
    }
    
    // Disegna il singolo nodo del livello
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
                Circle()
                    .fill(
                        isCurrent ?
                        LinearGradient(colors: [.yellow, .orange], startPoint: .topLeading, endPoint: .bottomTrailing)
                        :
                        LinearGradient(colors: [isUnlocked ? .white : Color.gray.opacity(0.3), isUnlocked ? Color(white: 0.9) : Color.gray.opacity(0.5)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .frame(width: 70, height: 70)
                    .shadow(color: isCurrent ? .orange.opacity(0.5) : .black.opacity(0.1), radius: 10, y: 5)
                
                Circle()
                    .stroke(isCurrent ? Color.orange : (isUnlocked ? Color.white : Color.gray.opacity(0.5)), lineWidth: 5)
                    .frame(width: 70, height: 70)
                
                Group {
                    if isCompleted {
                        Image(systemName: "star.fill")
                            .font(.title)
                            .foregroundColor(.yellow)
                            .shadow(radius: 1)
                    } else if isCurrent {
                        Text("\(levelNum)")
                            .font(.system(size: 32, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                            .shadow(radius: 2)
                    } else if isUnlocked {
                        Text("\(levelNum)")
                            .font(.system(size: 32, weight: .black, design: .rounded))
                            .foregroundColor(.gray)
                    } else {
                        Image(systemName: "lock.fill")
                            .font(.title2)
                            .foregroundColor(.gray.opacity(0.7))
                    }
                }
                
                // Segnaposto animato sopra il livello attuale
                if isCurrent {
                    ElementView(type: .red)
                        .frame(width: 30, height: 30)
                        .offset(y: -45)
                        .shadow(radius: 3)
                        .transition(.scale)
                }
            }
        }
        .disabled(!isUnlocked)
    }
}

// Linea tratteggiata curva tra due livelli
struct MapPathLineView: View {
    var color: Color
    var horizontalOffset: CGFloat
    
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                let midX = geometry.size.width / 2
                let startY: CGFloat = -15
                let endY: CGFloat = 15
                
                path.move(to: CGPoint(x: midX + horizontalOffset, y: startY))
                path.addQuadCurve(to: CGPoint(x: midX - horizontalOffset, y: endY),
                                  control: CGPoint(x: midX, y: (startY + endY) / 2))
            }
            .stroke(color, style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round, dash: [10, 10]))
        }
        .frame(height: 30)
        .offset(y: -15)
    }
}

// MARK: - Preview
#Preview {
    SagaMapView(
        worlds: [
            WorldData(id: "preview-1", name: "Valle delle Gelatine", description: nil,
                      stageNumber: 1, color: "#007700", icon: "🍓", status: "ACTIVE",
                      isActive: true, createdAt: nil, updatedAt: nil, levels: [
                LevelData(id: "l2", levelNumber: 2, movesLimit: 10, status: nil,
                          objective: ObjectiveData(type: "JELLY", targetColor: "BLUE", required: 5),
                          grid: [], availablePieces: [], worldId: nil, createdAt: nil, updatedAt: nil),
                LevelData(id: "l1", levelNumber: 1, movesLimit: 10, status: nil,
                          objective: ObjectiveData(type: "JELLY", targetColor: "BLUE", required: 5),
                          grid: [], availablePieces: [], worldId: nil, createdAt: nil, updatedAt: nil)
            ])
        ],
        maxUnlockedLevel: 1,
        getColor: { _ in .pink },
        onPlayLevel: { _ in }
    )
}
