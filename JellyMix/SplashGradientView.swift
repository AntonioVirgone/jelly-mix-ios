//
//  SplashGradientView.swift
//  JellyMix
//
//  Created by Antonio Virgone on 26/04/26.
//

import Foundation
import SwiftUI

struct SplashGradientView: View {
    var body: some View {
        // Il tuo gradiente perfetto
        LinearGradient(
            colors: [
                Color.yellow.opacity(0.2),
                Color.purple.opacity(0.2),
                Color.pink.opacity(0.2)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea() // Riempie tutto lo schermo
    }
}

#Preview {
    SplashGradientView()
}
