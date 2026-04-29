//
//  GameViewModelTests+Shop.swift
//  JellyMixTests
//
//  Created by Antonio Virgone on 29/04/26.
//

import Testing
@testable import JellyMix

@MainActor
@Suite("Shop")
struct ShopTests {

    // MARK: - buyAndOpenPack

    @Test("buyAndOpenPack con monete sufficienti: ritorna 3 carte")
    func buyPack_withSufficientCoins_returnsThreeCards() {
        let vm = GameViewModel.makeForTesting()
        vm.coins = 500

        let cards = vm.buyAndOpenPack(cost: 100)

        #expect(cards != nil)
        #expect(cards?.count == 3)
    }

    @Test("buyAndOpenPack con monete sufficienti: detrae il costo")
    func buyPack_withSufficientCoins_deductsCost() {
        let vm = GameViewModel.makeForTesting()
        vm.coins = 500

        _ = vm.buyAndOpenPack(cost: 100)

        #expect(vm.coins == 400)
    }

    @Test("buyAndOpenPack con monete insufficienti: ritorna nil e non modifica coins")
    func buyPack_withInsufficientCoins_returnsNil() {
        let vm = GameViewModel.makeForTesting()
        vm.coins = 50

        let cards = vm.buyAndOpenPack(cost: 100)

        #expect(cards == nil)
        #expect(vm.coins == 50)
    }

    @Test("buyAndOpenPack: le carte restituite vengono aggiunte a unlockedJellies")
    func buyPack_unlocksReturnedCards() {
        let vm = GameViewModel.makeForTesting()
        vm.coins = 500

        let cards = vm.buyAndOpenPack(cost: 100)

        if let cards = cards {
            for card in cards {
                #expect(vm.unlockedJellies.contains(card))
            }
        }
    }

    @Test("buyAndOpenPack: costo zero non causa underflow (guard coins >= cost)")
    func buyPack_zeroCost_deductsZero() {
        let vm = GameViewModel.makeForTesting()
        vm.coins = 0

        let cards = vm.buyAndOpenPack(cost: 0)

        #expect(cards != nil)
        #expect(vm.coins == 0)
    }

    @Test("buyAndOpenPack multipli: le monete scalano correttamente ad ogni acquisto")
    func buyPack_multiplePurchases_coinsAccumulate() {
        let vm = GameViewModel.makeForTesting()
        vm.coins = 300

        _ = vm.buyAndOpenPack(cost: 100)
        _ = vm.buyAndOpenPack(cost: 100)
        _ = vm.buyAndOpenPack(cost: 100)
        let failedPack = vm.buyAndOpenPack(cost: 100)

        #expect(vm.coins == 0)
        #expect(failedPack == nil) // quarto acquisto: non ci sono più monete
    }

    // MARK: - getPullRates

    @Test("getPullRates ritorna un array non vuoto")
    func pullRates_returnsNonEmptyArray() {
        let vm = GameViewModel.makeForTesting()
        #expect(!vm.getPullRates().isEmpty)
    }

    @Test("getPullRates contiene solo ElementType validi (non .empty, non .rainbow)")
    func pullRates_containsOnlyValidJellies() {
        let vm = GameViewModel.makeForTesting()
        let invalid: Set<ElementType> = [.empty, .rainbow]

        for rate in vm.getPullRates() {
            #expect(!invalid.contains(rate))
        }
    }

    @Test("getPullRates: il ghiaccio è presente (rate più alto)")
    func pullRates_containsIce() {
        let vm = GameViewModel.makeForTesting()
        #expect(vm.getPullRates().contains(.ice))
    }
}
