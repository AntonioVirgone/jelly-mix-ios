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

    var worlds: [WorldData]
    var isLevelUnlocked: (Int, Int) -> Bool
    var isLevelCompleted: (Int, Int) -> Bool
    var getColor: (String) -> Color
    /// Increment this value whenever progress changes to trigger an automatic scroll.
    var scrollTrigger: Int
    var onPlayLevel: (Int, Int) -> Void  // (stageNumber, levelIndex)

    @State private var scrollPositionId: String?

    // Primo nodo sbloccato ma non ancora completato (scroll target).
    private var currentNodeId: String? {
        for world in worlds.sorted(by: { $0.stageNumber < $1.stageNumber }) {
            for level in world.levels.sorted(by: { $0.levelIndex < $1.levelIndex }) {
                if isLevelUnlocked(world.stageNumber, level.levelIndex) &&
                   !isLevelCompleted(world.stageNumber, level.levelIndex) {
                    return "level_\(world.stageNumber)_\(level.levelIndex)"
                }
            }
        }
        return nil
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                Color.clear.frame(height: 50)
                ForEach(worlds) { world in
                    Section {
                        renderWorldContent(world: world)
                    } header: {
                        WorldHeaderView(world: world, color: getColor(world.color))
                    }
                }
                Color.clear.frame(height: 100)
            }
            .scrollTargetLayout()
        }
        .scrollIndicators(.hidden)
        .scrollPosition(id: $scrollPositionId, anchor: .center)
        .onAppear { scrollPositionId = currentNodeId }
        .onChange(of: scrollTrigger) { _, _ in scrollPositionId = currentNodeId }
    }

    // Ogni VStack è figlio diretto di LazyVStack (Section e ForEach sono trasparenti),
    // quindi .scrollTargetLayout() può trovare correttamente gli ID per lo scroll.
    @ViewBuilder
    private func renderWorldContent(world: WorldData) -> some View {
        let worldColor = getColor(world.color)
        let sortedLevels = world.levels.sorted { $0.levelIndex < $1.levelIndex }

        ForEach(Array(sortedLevels.enumerated()), id: \.element.levelIndex) { index, levelData in
            let isEven = index % 2 == 0
            let horizontalOffset: CGFloat = isEven ? 80 : -80

            VStack(spacing: 0) {
                HStack {
                    if !isEven { Spacer() }
                    renderLevelNode(levelData: levelData, stageNumber: world.stageNumber)
                        .offset(x: horizontalOffset)
                    if isEven { Spacer() }
                }
                .padding(.horizontal, 40)

                if index < sortedLevels.count - 1 {
                    MapPathLineView(color: worldColor.opacity(0.6), horizontalOffset: horizontalOffset)
                }
            }
            .padding(.top, index == 0 ? 50 : 30)
            .padding(.bottom, index == sortedLevels.count - 1 ? 50 : 0)
            .id("level_\(world.stageNumber)_\(levelData.levelIndex)")
        }
    }

    // Disegna il singolo nodo del livello
    @ViewBuilder
    private func renderLevelNode(levelData: LevelData, stageNumber: Int) -> some View {
        let unlocked  = isLevelUnlocked(stageNumber, levelData.levelIndex)
        let completed = isLevelCompleted(stageNumber, levelData.levelIndex)
        let isCurrent = unlocked && !completed

        Button(action: {
            if unlocked { onPlayLevel(stageNumber, levelData.levelIndex) }
        }) {
            ZStack {
                Circle()
                    .fill(
                        isCurrent
                        ? LinearGradient(colors: [.yellow, .orange], startPoint: .topLeading, endPoint: .bottomTrailing)
                        : LinearGradient(
                            colors: [unlocked ? .white : Color.gray.opacity(0.3),
                                     unlocked ? Color(white: 0.9) : Color.gray.opacity(0.5)],
                            startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .frame(width: 70, height: 70)
                    .shadow(color: isCurrent ? .orange.opacity(0.5) : .black.opacity(0.1), radius: 10, y: 5)

                Circle()
                    .stroke(isCurrent ? Color.orange : (unlocked ? Color.white : Color.gray.opacity(0.5)), lineWidth: 5)
                    .frame(width: 70, height: 70)

                Group {
                    if completed {
                        Image(systemName: "star.fill")
                            .font(.title)
                            .foregroundColor(.yellow)
                            .shadow(radius: 1)
                    } else if isCurrent {
                        Text("\(levelData.levelIndex)")
                            .font(.system(size: 32, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                            .shadow(radius: 2)
                    } else if unlocked {
                        Text("\(levelData.levelIndex)")
                            .font(.system(size: 32, weight: .black, design: .rounded))
                            .foregroundColor(.gray)
                    } else {
                        Image(systemName: "lock.fill")
                            .font(.title2)
                            .foregroundColor(.gray.opacity(0.7))
                    }
                }

                if isCurrent {
                    ElementView(type: .red)
                        .frame(width: 30, height: 30)
                        .offset(y: -45)
                        .shadow(radius: 3)
                        .transition(.scale)
                }
            }
        }
        .disabled(!unlocked)
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

struct WorldHeaderView: View {
    let world: WorldData
    let color: Color
    
    var body: some View {
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
                .fill(color)
                .shadow(color: color.opacity(0.4), radius: 8, y: 4)
        )
        .foregroundColor(.white)
        .padding(.horizontal)
        .padding(.bottom, 8)
        // ⚠️ Sfondo opaco dietro il padding per evitare bleed-through
        .background(Color(UIColor.systemBackground).opacity(0.001))
    }
}

// MARK: - Preview
#Preview {
    SagaMapView(
        worlds: [
            WorldData(id: "preview-1", name: "Valle delle Gelatine", description: nil,
                      stageNumber: 1, color: "#007700", icon: "🍓", status: "ACTIVE",
                      isActive: true, createdAt: nil, updatedAt: nil, levels: [
                LevelData(id: "l1", levelNumber: 1, levelIndex: 1, movesLimit: 10, status: nil,
                          objective: ObjectiveData(type: "JELLY", targetColor: "BLUE", required: 5),
                          grid: [], availablePieces: [], worldId: nil, createdAt: nil, updatedAt: nil),
                LevelData(id: "l2", levelNumber: 2, levelIndex: 2, movesLimit: 10, status: nil,
                          objective: ObjectiveData(type: "JELLY", targetColor: "BLUE", required: 5),
                          grid: [], availablePieces: [], worldId: nil, createdAt: nil, updatedAt: nil)
            ])
        ],
        isLevelUnlocked: { s, i in s == 1 && i == 1 },
        isLevelCompleted: { _, _ in false },
        getColor: { _ in .pink },
        scrollTrigger: 0,
        onPlayLevel: { _, _ in }
    )
}
