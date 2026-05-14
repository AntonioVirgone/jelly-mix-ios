//
//  DecorativeDotsLayer.swift
//  JellyMix
//
//  Created by Antonio Virgone on 14/05/26.
//

import Foundation
import SwiftUI

// MARK: - Decorative dots background
struct DecorativeDotsLayer: View {
    private let dotColors: [Color] = [
        Color(hex: "#ff5fa2"), Color(hex: "#ffb31a"),
        Color(hex: "#3d8cff"), Color(hex: "#3dcb5e"), Color(hex: "#a35bff")
    ]
    @State private var floating = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(0..<18, id: \.self) { i in
                    let x = CGFloat((i * 53) % 100) / 100.0 * geo.size.width
                    let y = CGFloat((i * 31) % 100) / 100.0 * geo.size.height
                    let size = CGFloat(4 + (i % 4) * 2)
                    let bobOffset: CGFloat = floating ? 5 : -5

                    Circle()
                        .fill(dotColors[i % dotColors.count])
                        .frame(width: size, height: size)
                        .position(x: x, y: y + bobOffset)
                        .animation(
                            .easeInOut(duration: Double(3) + Double(i) * 0.2)
                            .repeatForever(autoreverses: true)
                            .delay(Double(i) * 0.1),
                            value: floating
                        )
                }
            }
            .opacity(0.5)
        }
        .onAppear { floating = true }
    }
}
