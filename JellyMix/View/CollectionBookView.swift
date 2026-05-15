//
//  CollectionBookView.swift
//  JellyMix
//
//  Created by Antonio Virgone on 24/04/26.
//

import Foundation
import SwiftUI

// Playable jellies shown in the collection (rawValue 0–7, excluding obstacles and empty)
private let collectionElements: [ElementType] = ElementType.allCases
    .filter { $0.rawValue >= 0 && $0.rawValue <= 7 }
    .sorted { $0.rawValue < $1.rawValue }

// MARK: - CollectionBookView

struct CollectionBookView: View {
    @ObservedObject var viewModel: GameViewModel

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 16), count: 3)

    private var unlockedCount: Int {
        collectionElements.filter { viewModel.unlockedJellies.contains($0) }.count
    }

    var body: some View {
        VStack(spacing: 0) {
            CollectionHeaderView(unlocked: unlockedCount, total: collectionElements.count)
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 20)

            ScrollView {
                LazyVGrid(columns: columns, spacing: 20) {
                    ForEach(collectionElements, id: \.self) { type in
                        CollectionTileView(
                            type: type,
                            isUnlocked: viewModel.unlockedJellies.contains(type)
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
        }
    }
}

// MARK: - Header

private struct CollectionHeaderView: View {
    let unlocked: Int
    let total: Int

    var progress: Double { total > 0 ? Double(unlocked) / Double(total) : 0 }

    var body: some View {
        VStack(spacing: 10) {
            Text("COLLEZIONE")
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundStyle(LinearGradient(
                    colors: [.purple, .pink],
                    startPoint: .leading,
                    endPoint: .trailing
                ))

            VStack(spacing: 6) {
                HStack {
                    Text("\(unlocked)/\(total) sbloccate")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(Int(progress * 100))%")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.purple)
                }

                // Progress track
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.gray.opacity(0.18))
                            .frame(height: 6)
                        Capsule()
                            .fill(LinearGradient(
                                colors: [.purple, .pink],
                                startPoint: .leading,
                                endPoint: .trailing
                            ))
                            .frame(width: geo.size.width * progress, height: 6)
                            .animation(.spring(response: 0.6, dampingFraction: 0.75), value: progress)
                    }
                }
                .frame(height: 6)
            }
        }
    }
}

// MARK: - Tile

private struct CollectionTileView: View {
    let type: ElementType
    let isUnlocked: Bool

    @State private var wobbleAngle: Double = -4

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                // Tile background
                RoundedRectangle(cornerRadius: 18)
                    .fill(tileFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(
                                isUnlocked
                                    ? type.config.color.opacity(0.35)
                                    : Color.gray.opacity(0.15),
                                lineWidth: 1.5
                            )
                    )

                // Jelly content
                if isUnlocked {
                    ElementView(type: type, isDirty: false)
                        .frame(width: 54, height: 54)
                        .rotationEffect(.degrees(wobbleAngle))
                } else {
                    ElementView(type: type, isDirty: false)
                        .frame(width: 54, height: 54)
                        .grayscale(1.0)
                        .opacity(0.22)
                }
            }
            .frame(width: 86, height: 86)
            .overlay(alignment: .bottomTrailing) {
                // Lock badge (bottom-right, 22pt)
                if !isUnlocked {
                    ZStack {
                        Circle()
                            .fill(Color(UIColor.systemBackground))
                            .frame(width: 22, height: 22)
                            .shadow(color: .black.opacity(0.08), radius: 3, y: 1)
                        Image(systemName: "lock.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.gray.opacity(0.7))
                    }
                    .offset(x: -5, y: -5)
                }
            }

            // Name label
            Text(isUnlocked ? type.config.name : "???")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(isUnlocked ? .primary : .secondary.opacity(0.5))
                .lineLimit(1)
        }
        .onAppear {
            guard isUnlocked else { return }
            withAnimation(
                .easeInOut(duration: 1.3 + Double.random(in: 0 ... 0.5))
                .repeatForever(autoreverses: true)
                .delay(Double.random(in: 0 ... 0.9))
            ) {
                wobbleAngle = 4
            }
        }
    }

    private var tileFill: AnyShapeStyle {
        if isUnlocked {
            return AnyShapeStyle(LinearGradient(
                colors: [
                    type.config.color.opacity(0.18),
                    type.config.color.opacity(0.07)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ))
        } else {
            return AnyShapeStyle(Color(UIColor.systemGray6))
        }
    }
}

// MARK: - Preview

#Preview {
    CollectionBookView(viewModel: {
        let vm = GameViewModel()
        vm.unlockedJellies = [.red, .blue, .green]
        return vm
    }())
    .preferredColorScheme(.dark)
}
