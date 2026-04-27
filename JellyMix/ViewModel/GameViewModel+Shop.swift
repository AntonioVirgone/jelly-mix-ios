//
//  GameViewModel+Shop.swift
//  JellyMix
//

import Foundation

extension GameViewModel {

    func buyAndOpenPack(cost: Int = 100) -> [ElementType]? {
        guard coins >= cost else { return nil }
        coins -= cost

        let pullRates = getPullRates()
        var pulledCards: [ElementType] = []

        for _ in 0..<3 {
            if let randomCard = pullRates.randomElement() {
                pulledCards.append(randomCard)
                unlockedJellies.insert(randomCard)
            }
        }

        return pulledCards
    }

    func getPullRates() -> [ElementType] {
        var pullRates: [ElementType] = []

        for i in 0...100 {
            pullRates.append(.ice)
            if i <= 5 {
                pullRates.append(.black)
            } else if i <= 10 {
                pullRates.append(.brown)
            } else if i <= 25 {
                pullRates.append(.yellow)
            } else if i <= 40 {
                pullRates.append(.orange)
            } else if i <= 80 {
                pullRates.append(.yellow)
            } else {
                pullRates.append(.orange)
            }
        }

        return pullRates
    }
}
