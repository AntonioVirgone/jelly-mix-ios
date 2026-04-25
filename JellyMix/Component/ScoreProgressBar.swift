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
    var milestoneIconSize: CGFloat = 25     // Dimensione desiderata dell'icona (es. 30x30)
    
    // Calcoliamo il punteggio massimo della barra (il traguardo più alto)
    private var maxScore: Int {
        let points = availablePieces.compactMap { $0.point }.filter { $0 > 0 }
        return points.max() ?? 1000 // Default 1000 se non ci sono punti
    }
    
    var body: some View {
        VStack(spacing: 8) {
            GeometryReader { geometry in
                let width = geometry.size.width
                let progress = min(CGFloat(score) / CGFloat(maxScore), 1.0)
                
                ZStack(alignment: .leading) {
                    // Sfondo della barra
                    Capsule()
                        .fill(Color.black.opacity(0.1))
                        .frame(height: 12)
                    
                    // Progresso Effettivo
                    Capsule()
                        .fill(LinearGradient(colors: [.purple, .pink], startPoint: .leading, endPoint: .trailing))
                        .frame(width: width * progress, height: 12)
                        .animation(.spring(), value: score)
                    
                    // ICONE DELLE GELATINE (Milestones)
                    ForEach(availablePieces.filter { ($0.point ?? 0) > 0 }, id: \.type) { piece in
                        let position = CGFloat(piece.point!) / CGFloat(maxScore)
                        
                        VStack(spacing: 4) {
                            ElementView(type: piece.elementType, isDirty: false)
                                .frame(width: 20, height: 20)
                                .scaleEffect(milestoneIconSize / 60)
                                .shadow(radius: 2)
                                // Se la gelatina è sbloccata, è luminosa, altrimenti è semitrasparente
                                .opacity(score >= piece.point! ? 1.0 : 0.4)
                                .scaleEffect(score >= piece.point! ? 1.1 : 0.9)
                        }
                        // Posizioniamo l'icona esattamente al punto giusto della barra
                        .offset(x: (width * position) - 12, y: -25)
                    }
                }
                .offset(y: 15) // Centra la barra rispetto alle icone sopra
            }
            .frame(height: 50)
            
            // Testo punteggio corrente sotto
            Text("PUNTI: \(score)")
                .font(.system(.caption, design: .rounded))
                .fontWeight(.black)
                .foregroundColor(.purple)
        }
        .padding(.horizontal, 20)
    }
}

#Preview {
    ScoreProgressBar(score: 100, availablePieces: [AvailablePieceData.init(type: "BLU", point: 100)])
}
