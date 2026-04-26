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
        GeometryReader { geo in
            Image("SplashFull")
                .resizable()
                .scaledToFill()
                .frame(width: geo.size.width, height: geo.size.height)
                .clipped()
                .ignoresSafeArea()
        }
        .ignoresSafeArea()
    }
}
