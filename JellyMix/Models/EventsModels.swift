//
//  EventsModels.swift
//  JellyMix
//

import SwiftUI

// MARK: - Prize

enum WheelPrizeID: String {
    case hammer
    case coins
    case swap
    case jelly
    case brush
    case coinsBig = "coins-big"
    case life
    case star
}

struct WheelPrize: Identifiable {
    let id: WheelPrizeID
    let label: String
    let icon: String        // SF Symbol name
    let color: Color
    let amount: Int

    // The effect applied to GameViewModel when this prize is claimed
    var effect: PrizeEffect {
        switch id {
        case .hammer:   return .powerUp(.hammer)
        case .swap:     return .powerUp(.swap)
        case .brush:    return .powerUp(.brush)
        case .coins:    return .coins(amount)
        case .coinsBig: return .coins(amount)
        case .life:     return .life
        case .jelly:    return .noEffect   // rare jelly — cosmetic for now
        case .star:     return .noEffect   // bonus star — cosmetic for now
        }
    }
}

enum PrizeEffect {
    case powerUp(PowerUpType)
    case coins(Int)
    case life
    case noEffect
}

// MARK: - Prizes catalog (8 segments, order = wheel segment 0…7)

extension WheelPrize {
    static let all: [WheelPrize] = [
        WheelPrize(id: .hammer,   label: "Martello",    icon: "hammer.fill",             color: Color(hex: "#ff6b6b"), amount: 1),
        WheelPrize(id: .coins,    label: "50 Monete",   icon: "circle.fill",             color: Color(hex: "#ffb31a"), amount: 50),
        WheelPrize(id: .swap,     label: "Scambio",     icon: "arrow.left.arrow.right",  color: Color(hex: "#3d8cff"), amount: 1),
        WheelPrize(id: .jelly,    label: "Jelly Rara",  icon: "sparkles",                color: Color(hex: "#a35bff"), amount: 1),
        WheelPrize(id: .brush,    label: "Pennello",    icon: "paintbrush.fill",         color: Color(hex: "#c84ad6"), amount: 1),
        WheelPrize(id: .coinsBig, label: "200 Monete",  icon: "circle.fill",             color: Color(hex: "#ffce5c"), amount: 200),
        WheelPrize(id: .life,     label: "Vita Extra",  icon: "heart.fill",              color: Color(hex: "#ff4d80"), amount: 1),
        WheelPrize(id: .star,     label: "Stella Bonus",icon: "star.fill",               color: Color(hex: "#6ec8ff"), amount: 1),
    ]
}

// MARK: - Spin phase

enum SpinPhase {
    case idle
    case spinning
    case decelerating
    case revealing
}
