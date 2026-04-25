//
//  BoxIconView.swift
//  JellyMix
//
//  Created by Antonio Virgone on 25/04/26.
//

import Foundation
import SwiftUI

struct BoxIconView: View {
    let labelNumber: String
    let labelImage: String
    
    var body: some View {
        HStack(spacing: 4) {
            Text(labelNumber)
                .font(.system(size: 20, weight: .bold))
            Image(labelImage)
                .resizable()
                .frame(width: 20, height: 20)
        }
        .foregroundColor(.white)
        .padding(.vertical, 8)
        .padding(.horizontal, 20)
        .background(
            Capsule().fill(Color.purple.opacity(0.8))
        )
    }
}
