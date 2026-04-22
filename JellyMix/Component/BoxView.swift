//
//  BoxView.swift
//  JellyMix
//
//  Created by Antonio Virgone on 21/04/26.
//

import Foundation
import SwiftUI

struct BoxView: View {
    var text: String
    var color: Color
    
    var body: some View {
        // Box Prossimo
        VStack {
            Text(text)
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundColor(.gray)
            
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.6))
                .frame(width: 80, height: 80)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(color) // Gelatina finta
                        .frame(width: 60, height: 60)
                )
        }
    }
}
