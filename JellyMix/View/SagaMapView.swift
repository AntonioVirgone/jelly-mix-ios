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
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                    Color.clear.frame(height: 16)
                    ForEach(worlds) { world in
                        let worldColor = getColor(world.color)
                        let isWorldUnlocked = world.levels.contains {
                            isLevelUnlocked(world.stageNumber, $0.levelIndex)
                        }
                        Section {
                            renderWorldContent(world: world, worldColor: worldColor)
                        } header: {
                            WorldCardView(
                                world: world,
                                color: worldColor,
                                isUnlocked: isWorldUnlocked
                            )
                            .padding(.horizontal, 16)
                            .padding(.bottom, 8)
                            .background(Color(UIColor.systemBackground).opacity(0.001))
                        }
                    }
                    Color.clear.frame(height: 100)
                }
                .scrollTargetLayout()
            }
            .scrollIndicators(.hidden)
            .onAppear            { scheduleScroll(proxy) }
            .onChange(of: scrollTrigger) { _, _ in scheduleScroll(proxy) }
            // 🔧 catch-all: anche se scrollTrigger non cambia, una variazione
            // strutturale dei mondi deve riposizionare la mappa.
            .onChange(of: worlds.map(\.id)) { _, _ in scheduleScroll(proxy) }
        }
    }
    
    /// Posticipa di un run-loop tick + frame: dà al LazyVStack
    /// il tempo di costruire i nodi prima di chiamare scrollTo.
    private func scheduleScroll(_ proxy: ScrollViewProxy) {
        guard let target = currentNodeId else { return }
        DispatchQueue.main.async {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                withAnimation(.easeInOut(duration: 0.45)) {
                    proxy.scrollTo(target, anchor: .center)
                }
            }
        }
    }

    // Ogni VStack è figlio diretto di LazyVStack (Section e ForEach sono trasparenti),
    // quindi .scrollTargetLayout() può trovare correttamente gli ID per lo scroll.
    @ViewBuilder
    private func renderWorldContent(world: WorldData, worldColor: Color) -> some View {
        let sortedLevels = world.levels.sorted { $0.levelIndex < $1.levelIndex }

        ForEach(Array(sortedLevels.enumerated()), id: \.element.levelIndex) { index, levelData in
            let isEven = index % 2 == 0
            let horizontalOffset: CGFloat = isEven ? 80 : -80

            VStack(spacing: 0) {
                HStack {
                    if !isEven { Spacer() }
                    LevelNodeView(
                        levelData: levelData,
                        stageNumber: world.stageNumber,
                        isUnlocked: isLevelUnlocked(world.stageNumber, levelData.levelIndex),
                        isCompleted: isLevelCompleted(world.stageNumber, levelData.levelIndex),
                        worldColor: worldColor
                    ) {
                        onPlayLevel(world.stageNumber, levelData.levelIndex)
                    }
                    .offset(x: horizontalOffset * 0.5)
                    if isEven { Spacer() }
                }
                .padding(.horizontal, 40)

                if index < sortedLevels.count - 1 {
                    MapPathLineView(
                        color: worldColor.opacity(0.5),
                        startOffset: (-1) * horizontalOffset,
                        endOffset: (-1) * (isEven ? -80 : 80)
                    )
                }
            }
            .padding(.top, index == 0 ? 24 : 30)
            .padding(.bottom, index == sortedLevels.count - 1 ? 50 : 0)
            .id("level_\(world.stageNumber)_\(levelData.levelIndex)")
        }
    }
}

// MARK: - WorldCardView (header con shine + glass)

struct WorldCardView: View {
    let world: WorldData
    let color: Color
    let isUnlocked: Bool

    @State private var shinePhase: CGFloat = 0

    var body: some View {
        ZStack {
            if isUnlocked {
                // Colored gradient background
                RoundedRectangle(cornerRadius: 20)
                    .fill(LinearGradient(
                        colors: [color, color.opacity(0.75)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .shadow(color: color.opacity(0.45), radius: 10, y: 4)
            } else {
                // Glass background for locked worlds
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.white.opacity(0.15))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.white.opacity(0.5), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.08), radius: 8, y: 3)
            }

            // Shine sweep overlay (only on unlocked worlds)
            if isUnlocked {
                GeometryReader { geo in
                    Rectangle()
                        .fill(LinearGradient(
                            colors: [.clear, .white.opacity(0.35), .clear],
                            startPoint: .leading, endPoint: .trailing
                        ))
                        .frame(width: geo.size.width * 0.35)
                        .rotationEffect(.degrees(15))
                        .offset(x: (geo.size.width + geo.size.width * 0.35) * shinePhase - geo.size.width * 0.2)
                }
                .clipped()
                .cornerRadius(20)
                .allowsHitTesting(false)
            }

            // Content
            HStack(spacing: 14) {
                // Emoji tile
                Text(world.icon)
                    .font(.system(size: 28))
                    .frame(width: 50, height: 50)
                    .background(
                        RoundedRectangle(cornerRadius: 13)
                            .fill(Color.white.opacity(isUnlocked ? 0.22 : 0.12))
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text("MONDO \(world.stageNumber)")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .opacity(isUnlocked ? 0.75 : 0.5)
                        .kerning(1.2)
                    Text(world.name)
                        .font(.system(size: 16, weight: .black, design: .rounded))
                }

                Spacer()

                // Lock badge for locked worlds
                if !isUnlocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.secondary.opacity(0.6))
                }
            }
            .foregroundColor(isUnlocked ? .white : .secondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .frame(height: 78)
        .onAppear {
            guard isUnlocked else { return }
            withAnimation(.linear(duration: 3.5).repeatForever(autoreverses: false)) {
                shinePhase = 1.0
            }
        }
    }
}

// MARK: - LevelNodeView (3 stati: completed / current / locked)

private struct LevelNodeView: View {
    let levelData: LevelData
    let stageNumber: Int
    let isUnlocked: Bool
    let isCompleted: Bool
    let worldColor: Color
    let onTap: () -> Void

    private var isCurrent: Bool { isUnlocked && !isCompleted }

    @State private var glowPulse: CGFloat = 1.0

    var body: some View {
        Button(action: { if isUnlocked { onTap() } }) {
            ZStack {
                // Pulsing glow ring (current node only)
                if isCurrent {
                    Circle()
                        .stroke(worldColor.opacity(0.45), lineWidth: 8)
                        .frame(width: 70, height: 70)
                        .scaleEffect(glowPulse)
                        .opacity(2.0 - glowPulse)  // fades as it expands
                }

                // Circle body
                Circle()
                    .fill(nodeFill)
                    .frame(width: 70, height: 70)
                    .shadow(color: nodeShadowColor, radius: isCurrent ? 12 : 5, y: isCurrent ? 5 : 2)

                // Circle border
                Circle()
                    .stroke(nodeBorderColor, lineWidth: isCurrent ? 4 : 3)
                    .frame(width: 70, height: 70)

                // Icon / number inside
                nodeContent
            }
            // "LVL N" badge floating above current node
            .overlay(alignment: .top) {
                if isCurrent {
                    LvlBadge(number: levelData.levelIndex, color: worldColor)
                        .offset(y: -30)
                }
            }
        }
        .disabled(!isUnlocked)
        .onAppear {
            guard isCurrent else { return }
            withAnimation(.easeOut(duration: 1.2).repeatForever(autoreverses: false)) {
                glowPulse = 1.5
            }
        }
    }

    // MARK: Computed styling

    private var nodeFill: AnyShapeStyle {
        if isCompleted {
            return AnyShapeStyle(Color.white)
        } else if isCurrent {
            return AnyShapeStyle(LinearGradient(
                colors: [.yellow, .orange],
                startPoint: .topLeading, endPoint: .bottomTrailing
            ))
        } else {
            return AnyShapeStyle(Color.gray.opacity(0.18))
        }
    }

    private var nodeBorderColor: Color {
        if isCompleted { return Color(hex: "#ffd23a") }
        if isCurrent   { return .orange }
        return Color.gray.opacity(0.3)
    }

    private var nodeShadowColor: Color {
        if isCompleted { return Color(hex: "#ffd23a").opacity(0.35) }
        if isCurrent   { return .orange.opacity(0.5) }
        return .clear
    }

    @ViewBuilder
    private var nodeContent: some View {
        if isCompleted {
            Image(systemName: "star.fill")
                .font(.system(size: 26, weight: .bold))
                .foregroundColor(Color(hex: "#ffd23a"))
                .shadow(color: .orange.opacity(0.4), radius: 3, y: 1)
        } else if isCurrent {
            Text("\(levelData.levelIndex)")
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.2), radius: 2)
        } else if isUnlocked {
            Text("\(levelData.levelIndex)")
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundColor(.gray.opacity(0.55))
        } else {
            Image(systemName: "lock.fill")
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(.gray.opacity(0.45))
        }
    }
}

// MARK: - "LVL N" badge above current node

private struct LvlBadge: View {
    let number: Int
    let color: Color

    var body: some View {
        VStack(spacing: 0) {
            Text("LVL \(number)")
                .font(.system(size: 11, weight: .black, design: .rounded))
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(LinearGradient(
                            colors: [color, color.opacity(0.75)],
                            startPoint: .leading, endPoint: .trailing
                        ))
                        .shadow(color: color.opacity(0.5), radius: 4, y: 2)
                )

            // Small downward triangle pointer
            Triangle()
                .fill(color)
                .frame(width: 10, height: 6)
        }
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.closeSubpath()
        return p
    }
}

// MARK: - Dashed path between nodes

struct MapPathLineView: View {
    var color: Color
    var startOffset: CGFloat
    var endOffset: CGFloat

    var body: some View {
        GeometryReader { geometry in
            Path { path in
                let midX = geometry.size.width / 2
                
                // Questi valori controllano l'altezza della curva. Aumentarli per curve più ampie
                let startY: CGFloat = 0
                let endY: CGFloat = geometry.size.height

                let startPoint = CGPoint(x: midX + startOffset, y: startY)
                let endPoint = CGPoint(x: midX + endOffset, y: endY)
                
                path.move(to: startPoint)
                
                // Usare una curva cubica per una forma a S più morbida.
                // I punti di controllo guidano la curva orizzonrake prima di scendere
                let control1 = CGPoint(x: startPoint.x, y: startY + (endY - startY) * 0.5)
                let control2 = CGPoint(x: endPoint.x, y: startY + (endY - startY) * 0.5)
                
                path.addCurve(to: endPoint, control1: control1, control2: control2)
            }
            .stroke(color, style: StrokeStyle(lineWidth: 5, lineCap: .round, dash: [8, 10]))
        }
        .frame(height: 70)
        .offset(y: -5)
        .zIndex(-1)
    }
}

// MARK: - Preview

#Preview {
    SagaMapView(
        worlds: [
            WorldData(id: "preview-1", name: "Valle delle Gelatine", description: nil,
                      stageNumber: 1, color: "#ff5567", icon: "🍓", status: "ACTIVE",
                      isActive: true, createdAt: nil, updatedAt: nil, levels: [
                LevelData(id: "l1", levelNumber: 1, levelIndex: 1, movesLimit: 10, status: nil,
                          objective: ObjectiveData(type: "JELLY", targetColor: "BLUE", required: 5),
                          grid: [], availablePieces: [], worldId: nil, createdAt: nil, updatedAt: nil),
                LevelData(id: "l2", levelNumber: 2, levelIndex: 2, movesLimit: 10, status: nil,
                          objective: ObjectiveData(type: "JELLY", targetColor: "BLUE", required: 5),
                          grid: [], availablePieces: [], worldId: nil, createdAt: nil, updatedAt: nil),
                LevelData(id: "l3", levelNumber: 3, levelIndex: 3, movesLimit: 10, status: nil,
                          objective: ObjectiveData(type: "JELLY", targetColor: "BLUE", required: 5),
                          grid: [], availablePieces: [], worldId: nil, createdAt: nil, updatedAt: nil)
            ]),
            WorldData(id: "preview-2", name: "Scontri tra Agrumi", description: nil,
                      stageNumber: 2, color: "#ffc83a", icon: "🍋", status: "ACTIVE",
                      isActive: false, createdAt: nil, updatedAt: nil, levels: [
                LevelData(id: "l4", levelNumber: 4, levelIndex: 1, movesLimit: 10, status: nil,
                          objective: ObjectiveData(type: "JELLY", targetColor: "BLUE", required: 5),
                          grid: [], availablePieces: [], worldId: nil, createdAt: nil, updatedAt: nil)
            ])
        ],
        isLevelUnlocked: { s, i in s == 1 },
        isLevelCompleted: { s, i in s == 1 && i == 1 },
        getColor: { Color(hex: $0) },
        scrollTrigger: 0,
        onPlayLevel: { _, _ in }
    )
}
