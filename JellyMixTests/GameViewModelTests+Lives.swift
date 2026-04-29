//
//  GameViewModelTests+Lives.swift
//  JellyMixTests
//
//  Created by Antonio Virgone on 29/04/26.
//

import Testing
@testable import JellyMix

// MARK: - Lives
//
// setupLivesSystem() NON viene testato qui perché dipende da UIApplication (UIKit)
// e da Timer real-time: si tratta di integrazione, non unit test.
// Testiamo loseLife() e la logica di calcolo offline (calcolaTempoOffline è private
// e viene verificata indirettamente tramite gli effetti osservabili su lives/timeToNextLife).

@MainActor
@Suite("Lives")
struct LivesTests {

    @Test("loseLife: decrementa lives di 1")
    func loseLife_decrementsCount() {
        let vm = GameViewModel.makeForTesting()
        vm.lives = 3

        vm.loseLife()

        #expect(vm.lives == 2)
    }

    @Test("loseLife: a lives == maxLives imposta timeToNextLife = secondsPerLife")
    func loseLife_atMaxLives_startsTimer() {
        let vm = GameViewModel.makeForTesting()
        vm.lives         = vm.maxLives
        vm.timeToNextLife = 0

        vm.loseLife()

        #expect(vm.lives == vm.maxLives - 1)
        #expect(vm.timeToNextLife == vm.secondsPerLife)
    }

    @Test("loseLife: a lives < maxLives NON sovrascrive timeToNextLife esistente")
    func loseLife_belowMax_doesNotResetTimer() {
        let vm = GameViewModel.makeForTesting()
        vm.lives          = 3
        vm.timeToNextLife = 120

        vm.loseLife()

        #expect(vm.lives == 2)
        #expect(vm.timeToNextLife == 120) // invariato
    }

    @Test("loseLife: a lives == 0 non va sotto zero")
    func loseLife_atZero_doesNotGoNegative() {
        let vm = GameViewModel.makeForTesting()
        vm.lives = 0

        vm.loseLife()

        #expect(vm.lives == 0)
    }

    @Test("loseLife: a lives == 1 porta a zero senza crash")
    func loseLife_atOne_becomesZero() {
        let vm = GameViewModel.makeForTesting()
        vm.lives = 1

        vm.loseLife()

        #expect(vm.lives == 0)
    }

    @Test("checkWinLoseConditions con mosse zero chiama loseLife (lives decrementato)")
    func checkWinLose_movesZero_callsLoseLife() {
        let vm = GameViewModel.makeForTesting()
        vm.lives     = 3
        vm.movesLeft = 0

        vm.checkWinLoseConditions()

        #expect(vm.isGameOver == true)
        #expect(vm.lives == 2) // loseLife chiamato internamente
    }
}
