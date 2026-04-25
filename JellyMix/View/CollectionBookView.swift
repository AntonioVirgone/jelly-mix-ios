//
//  CollectionBookView.swift
//  JellyMix
//
//  Created by Antonio Virgone on 24/04/26.
//

import Foundation
import SwiftUI

struct CollectionBookView: View {
    @ObservedObject var viewModel: GameViewModel
    
    // Griglia a 3 colonne
    let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
    
    var body: some View {
        ZStack {
            VStack {
                // Header
                Text("COLLEZIONE")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(LinearGradient(colors: [.purple, .pink], startPoint: .leading, endPoint: .trailing))

                ScrollView {
                    LazyVGrid(columns: columns, spacing: 25) {
                        // Iteriamo su tutte le gelatine (escludiamo vuoto e ostacoli)
                        ForEach(ElementType.allCases.filter { $0.rawValue >= 0 && $0 != .empty }, id: \.self) { type in
                            let isUnlocked = viewModel.unlockedJellies.contains(type)
                            
                            VStack(spacing: 10) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 15)
                                        .fill(isUnlocked ? Color.white.opacity(0.1) : Color.white.opacity(0.05))
                                        .frame(height: 100)
                                    
                                    if isUnlocked {
                                        ElementView(type: type, isDirty: false)
                                            .frame(width: 60, height: 60)
                                    } else {
                                        // Silhouette per i pezzi bloccati
                                        ElementView(type: type, isDirty: false)
                                            .frame(width: 60, height: 60)
                                            .brightness(-1.0) // Diventa tutto nero
                                            .opacity(0.3)                                        
                                    }
                                }
                                
                                Text(isUnlocked ? type.config.name : "???")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundColor(isUnlocked ? .purple : .gray)
                            }
                        }
                    }
                    .padding()
                }
            }
        }
    }
}
