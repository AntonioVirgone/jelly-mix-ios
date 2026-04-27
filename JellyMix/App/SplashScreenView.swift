//
//  SplashScreenView.swift
//  JellyMix
//
//  Created by Antonio Virgone on 26/04/26.
//

import Foundation
import SwiftUI

struct SplashScreenView: View {
    var body: some View {
        ZStack {
            GeometryReader { geo in
                Image("SplashFull")
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
                    .ignoresSafeArea()
                
                Text("JELLY MIX")
                    .font(.system(size: 60, weight: .black, design: .rounded))
                    .foregroundStyle(LinearGradient(colors: [.purple, .pink], startPoint: .leading, endPoint: .trailing))
                    .shadow(radius: 2)
                    .position(
                        x: geo.size.width / 2,
                        y: geo.size.height * 0.30 // 👈 3/4 dello schermo
                    )
            }
            .ignoresSafeArea()
        }
    }
}

#Preview {
    SplashScreenView()
}
