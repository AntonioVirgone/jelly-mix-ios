//
//  ScoreProgressBar.swift
//  JellyMix
//
//  Created by Antonio Virgone on 25/04/26.
//

import Foundation
import SwiftUI

struct ScoreProgressBar: View {
    var score: Int
    var availablePieces: [AvailablePieceData]
    var milestoneIconSize: CGFloat = 34     // Dimensione desiderata dell'icona (es. 30x30)
    
    // Calcoliamo il punteggio massimo della barra (il traguardo più alto)
    private var maxScore: Int {
        let points = availablePieces.compactMap { $0.point }.filter { $0 > 0 }
        return points.max() ?? 1000 // Default 1000 se non ci sono punti
    }
    
    var body: some View {
        VStack(spacing: 12) {
            GeometryReader { geometry in
                let width = geometry.size.width
                let progress = min(CGFloat(score) / CGFloat(maxScore), 1.0)
                let barHeight: CGFloat = 22 // Spessore aumentato (era 12)

                ZStack(alignment: .leading) {
                    // Sfondo della barra
                    Capsule()
                        .fill(Color.black.opacity(0.08))
                        .frame(height: barHeight)
                        .overlay(
                            Capsule().stroke(Color.white.opacity(0.8), lineWidth: 1.5)
                        )
                    
                    // Progresso Effettivo
                    Capsule()
                        .fill(LinearGradient(colors: [.purple, .pink],
                                             startPoint: .leading,
                                             endPoint: .trailing))
                        .frame(width: max(0, width * progress), height: barHeight)
                        .cornerRadius(barHeight / 2)
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
                        .shadow(color: Color.pink.opacity(0.5), radius: 5, x: 0, y: 3)
                        .animation(.spring(response: 0.5, dampingFraction: 0.65, blendDuration: 0), value: score)
                    
                    // ICONE DELLE GELATINE (Milestones)
                    ForEach(availablePieces.filter { ($0.point ?? 0) > 0 }, id: \.type) { piece in
                        let point = piece.point!
                        let position = CGFloat(piece.point!) / CGFloat(maxScore)
                        let isUnlocked = score >= point

                        VStack(spacing: 4) {
                            if isUnlocked {
                                ElementView(type: piece.elementType, isDirty: false)
                                    .aspectRatio(1, contentMode: .fit)
                                    .frame(width: milestoneIconSize, height: milestoneIconSize)
                                    .scaleEffect(0.85)
                                    .shadow(color: Color.white, radius: 4)
                                    .animation(.spring(response: 0.4, dampingFraction: 0.5), value: isUnlocked)
                            } else {
                                // Pacco sorpresa per le jelly non ancora sbloccate
                                ZStack {
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(
                                            LinearGradient(
                                                colors: [Color.yellow, Color.orange], // Gradiente colorato e vivace
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                .stroke(Color.white, lineWidth: 2) // Bordo bianco più netto
                                        )
                                    
                                    Image(systemName: "gift.fill")
                                        .font(.system(size: milestoneIconSize * 0.55, weight: .bold))
                                        .foregroundColor(.white)
                                        .shadow(color: .orange.opacity(0.8), radius: 1, y: 1)
                                }
                                .frame(width: milestoneIconSize, height: milestoneIconSize)
                                .shadow(color: Color.orange.opacity(0.4), radius: 4, y: 2)
                                .animation(.spring(response: 0.4, dampingFraction: 0.5), value: isUnlocked)
                            }
                        }
                        // Posizioniamo l'icona esattamente al punto giusto della barra
                        .offset(x: (width * position) - (milestoneIconSize / 2), y: -(barHeight / 2) - 10)
                    }
                }
                .offset(y: 20) // Centra la barra rispetto alle icone sopra
            }
            .frame(height: 60)            
        }
        .padding(.horizontal, 20)
    }
}

#Preview {
    ScoreProgressBar(score: 100, availablePieces: [
        AvailablePieceData.init(type: "BLUE", point: 100),
        AvailablePieceData.init(type: "GREEN", point: 280),
        AvailablePieceData.init(type: "ORANGE", point: 390),
        AvailablePieceData.init(type: "YELLOW", point: 470)
    ])
}
