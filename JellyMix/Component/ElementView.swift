//
//  ElementView.swift
//  JellyMix
//
//  Created by Antonio Virgone on 22/04/26.
//

import Foundation
import SwiftUI

struct ElementView: View {
    var type: ElementType
    var isDirty: Bool = false // Per la meccanica del miele

    // 1. Aggiungiamo questa riga per "leggere" il tema del sistema (Chiaro/Scuro)
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        let config = type.config
        
        ZStack {
            // 2. GESTIONE ESPLICITA DELLA CELLA VUOTA
            if type == .empty {
                RoundedRectangle(cornerRadius: 12)
                    // Se è dark mode usiamo bianco trasparente, altrimenti nero trasparente
                    .fill(colorScheme == .dark ? Color.white.opacity(0.8) : Color.black.opacity(0.08))
            } else if type == .rainbow {
                RoundedRectangle(cornerRadius: 12)
                    .fill(AngularGradient(colors: [.red, .orange, .yellow, .green, .blue, .purple, .red], center: .center))
            } else if config.isObstacle {
                // Sfondo semplice per ostacoli
                RoundedRectangle(cornerRadius: 12)
                    .fill(config.color)
            } else {
                // Corpo della Gelatina con gradiente morbido (Luce -> Ombra)
                JellyBodyShape()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [config.color.opacity(0.8), config.color, config.color.opacity(1.1)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            // 2. L'effetto "Glossy" (Lucidità 3D in alto a sinistra)
            if !config.isObstacle && type != .empty {
                JellyGlossHighlight()
            }
            
            // 3. Texture Ostacoli
            if config.isObstacle {
                renderObstacleTexture(for: type)
            }
            
            // 4. Le Nuove Faccine Carine (Grandi occhioni lucidi)
            if config.hasFace {
                CuteJellyFaceView()
            }
            
            // 5. Overlay Miele "Sporco"
            if isDirty {
                Image(systemName: "drop.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 20)
                    .foregroundColor(.orange)
                    .offset(x: 18, y: 18)
                    .shadow(radius: 2)
            }
            
            // 2. Texture Ostacoli (se necessario in futuro, puoi aggiungere immagini qui)
            if type == .waffle || type == .brokenWaffle {
                Image(systemName: "square.grid.3x3.fill")
                    .resizable()
                    .padding(8)
                    .foregroundColor(type == .brokenWaffle ? .brown : .orange)
            } else if type == .licorice {
                Image(systemName: "hurricane")
                    .resizable()
                    .padding(8)
                    .foregroundColor(.black)
            }
        }
        .aspectRatio(1, contentMode: .fit) // Mantiene la cella quadrata
    }
    
    // Helper per disegnare la texture sopra gli ostacoli
    @ViewBuilder
    private func renderObstacleTexture(for type: ElementType) -> some View {
        Group {
            if type == .waffle || type == .brokenWaffle {
                Image(systemName: "square.grid.3x3.fill")
                    .resizable()
                    .padding(10)
                    .foregroundColor(type == .brokenWaffle ? Color(white: 0.4) : Color(white: 0.2))
                    .opacity(0.4)
            } else if type == .ice {
                Image(systemName: "snowflake")
                    .resizable()
                    .padding(12)
                    .foregroundColor(.white)
                    .opacity(0.7)
            } else if type == .licorice {
                Image(systemName: "hurricane")
                    .resizable()
                    .padding(8)
                    .foregroundColor(.black)
                    .opacity(0.5)
            }
        }
    }
}

// MARK: - Forme Vettoriali e Sub-Views

// Una forma arrotondata speciale, leggermente più "morbida" di un semplice RoundedRectangle
struct JellyBodyShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addRoundedRect(in: rect, cornerSize: CGSize(width: rect.width * 0.25, height: rect.height * 0.25))
        return path
    }
}

// L'effetto lucido (specular highlight) in alto a sinistra
struct JellyGlossHighlight: View {
    var body: some View {
        GeometryReader { geometry in
            Ellipse()
                .fill(Color.white.opacity(0.4))
                .frame(width: geometry.size.width * 0.6, height: geometry.size.height * 0.4)
                .rotationEffect(.degrees(-15))
                .offset(x: geometry.size.width * 0.1, y: geometry.size.height * 0.1)
                .blur(radius: 2) // Rende il riflesso morbido
        }
    }
}

// Le Nuove Faccine Carine: Occhi enormi e lucidi
struct CuteJellyFaceView: View {
    var body: some View {
        VStack(spacing: 6) {
            // Occhioni Grandi (Iper-Cute)
            HStack(spacing: 16) {
                CuteEyeView(lookDirection: .bottomTrailing)
                CuteEyeView(lookDirection: .bottomLeading)
            }
            .offset(y: -4) // Sposta leggermente in alto
            
            // Sorriso Semplice
            Path { path in
                path.move(to: CGPoint(x: 0, y: 0))
                path.addQuadCurve(to: CGPoint(x: 16, y: 0), control: CGPoint(x: 8, y: 8))
            }
            .stroke(Color.black.opacity(0.7), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
            .frame(width: 16, height: 8)
        }
        .scaleEffect(0.9) // Rimpicciolisce leggermente la faccia nel complesso
    }
}

// Singolo occhio lucido con pupilla e riflesso
struct CuteEyeView: View {
    var lookDirection: Alignment
    
    var body: some View {
        Circle()
            .fill(Color.white)
            .frame(width: 24, height: 24) // Molto più grandi
            .overlay(
                // Pupilla nera che guarda in una direzione
                Circle()
                    .fill(Color.black)
                    .frame(width: 10, height: 10)
                    .overlay(
                        // Riflesso di luce bianco nella pupilla
                        Circle()
                            .fill(Color.white)
                            .frame(width: 4, height: 4)
                            .offset(x: -2, y: -2)
                    )
                    .offset(x: lookDirection == .bottomTrailing ? 5 : -5,
                            y: 5)
                , alignment: .center
            )
            .shadow(color: .black.opacity(0.1), radius: 2, y: 1)
    }
}
