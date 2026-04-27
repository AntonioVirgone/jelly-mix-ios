//
//  BoxView.swift
//  JellyMix
//
//  Created by Antonio Virgone on 21/04/26.
//

import SwiftUI

/// Box con etichetta che mostra un pezzo gelatina (es. "PROSSIMO" e "CONSERVA").
/// Per il box "CONSERVA" applica esternamente `.opacity()` e `.onTapGesture()`.
struct PieceBoxView: View {
    let label: String
    let jellyType: ElementType?
    var hasKey: Bool = false

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 6) {
            Text(label)
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundColor(.gray)

            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.6))
                .frame(width: 90, height: 90)
                .overlay(
                    Group {
                        if let type = jellyType {
                            ElementView(type: type, hasKey: hasKey)
                                .frame(width: 60, height: 60)
                        } else {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(colorScheme == .dark ? Color.white.opacity(0.8) : Color.black.opacity(0.08))
                                .frame(width: 60, height: 60)
                        }
                    }
                )
        }
    }
}

#Preview {
    HStack(spacing: 20) {
        PieceBoxView(label: "PROSSIMO", jellyType: .red)
        PieceBoxView(label: "CONSERVA", jellyType: nil)
    }
    .padding()
}
