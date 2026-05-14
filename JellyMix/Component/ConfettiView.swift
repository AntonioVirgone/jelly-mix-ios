//
//  ConfettiView.swift
//  JellyMix
//

import SwiftUI

let confettiColors: [Color] = [
    Color(hex: "#ff5fa2"), Color(hex: "#ffb31a"),
    Color(hex: "#3d8cff"), Color(hex: "#3dcb5e"), Color(hex: "#a35bff")
]

struct ConfettiPiece: View {
    let color: Color
    let x: CGFloat
    let delay: Double
    let duration: Double
    let rotation: Double

    @State private var offsetY: CGFloat = -60
    @State private var opacity: Double = 1

    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(color)
            .frame(width: 8, height: 14)
            .rotationEffect(.degrees(rotation))
            .offset(x: x, y: offsetY)
            .opacity(opacity)
            .onAppear {
                withAnimation(
                    .easeIn(duration: duration)
                    .delay(delay)
                ) {
                    offsetY = 600
                    opacity = 0
                }
            }
    }
}
