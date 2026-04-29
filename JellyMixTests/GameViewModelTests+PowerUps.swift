//
//  GameViewModelTests+PowerUps.swift
//  JellyMixTests
//
//  Created by Antonio Virgone on 29/04/26.
//

import Testing
@testable import JellyMix

// MARK: - Buy & Activate

@MainActor
@Suite("PowerUps – Acquisto e Attivazione")
struct PowerUpBuyActivateTests {

    @Test("Acquisto con monete sufficienti: coins decrementati e count +1")
    func buy_withSufficientCoins_succeeds() {
        let vm = GameViewModel.makeForTesting()
        vm.coins = 1000
        vm.powerUps[.hammer] = 0

        vm.buyPowerUp(.hammer)

        #expect(vm.coins == 500)                // 1000 - 500 (cost)
        #expect(vm.powerUps[.hammer] == 1)
    }

    @Test("Acquisto con monete insufficienti: nessun cambiamento")
    func buy_withInsufficientCoins_doesNothing() {
        let vm = GameViewModel.makeForTesting()
        vm.coins = 100 // costo = 500
        vm.powerUps[.hammer] = 0

        vm.buyPowerUp(.hammer)

        #expect(vm.coins == 100)
        #expect(vm.powerUps[.hammer] == 0)
    }

    @Test("Acquisto multiplo: accumula il count correttamente")
    func buy_multiple_accumulatesCount() {
        let vm = GameViewModel.makeForTesting()
        vm.coins = 1500
        vm.powerUps[.swap] = 0

        vm.buyPowerUp(.swap)
        vm.buyPowerUp(.swap)

        #expect(vm.powerUps[.swap] == 2)
        #expect(vm.coins == 500) // 1500 - 500 - 500
    }

    @Test("Attivazione con powerup disponibile: imposta activePowerUp")
    func activate_withPowerUpAvailable_setsActive() {
        let vm = GameViewModel.makeForTesting()
        vm.powerUps[.brush] = 1

        vm.activatePowerUp(.brush)

        #expect(vm.activePowerUp == .brush)
    }

    @Test("Attivazione senza powerup: activePowerUp rimane nil")
    func activate_withNoPowerUp_doesNotActivate() {
        let vm = GameViewModel.makeForTesting()
        vm.powerUps[.hammer] = 0

        vm.activatePowerUp(.hammer)

        #expect(vm.activePowerUp == nil)
    }

    @Test("Attivazione durante game over: bloccata")
    func activate_whenGameOver_isBlocked() {
        let vm = GameViewModel.makeForTesting()
        vm.powerUps[.hammer] = 1
        vm.isGameOver = true

        vm.activatePowerUp(.hammer)

        #expect(vm.activePowerUp == nil)
    }

    @Test("Attivazione durante level completed: bloccata")
    func activate_whenLevelCompleted_isBlocked() {
        let vm = GameViewModel.makeForTesting()
        vm.powerUps[.hammer] = 1
        vm.isLevelCompleted = true

        vm.activatePowerUp(.hammer)

        #expect(vm.activePowerUp == nil)
    }
}

// MARK: - Hammer

@MainActor
@Suite("PowerUps – Hammer")
struct HammerTests {

    private func makeWithHammer() -> GameViewModel {
        let vm = GameViewModel.makeForTesting()
        vm.powerUps[.hammer] = 1
        vm.activePowerUp     = .hammer
        vm.cellTypes[0]      = .normal
        return vm
    }

    @Test("Hammer su gelatina normale: la rimuove")
    func hammer_onNormalJelly_emptiesCell() {
        let vm = makeWithHammer()
        vm.grid[0].type = .red

        vm.applyPowerUp(at: 0)

        #expect(vm.grid[0].type == .empty)
        #expect(vm.powerUps[.hammer] == 0) // consumato
    }

    @Test("Hammer su cella vuota: non viene consumato")
    func hammer_onEmptyCell_notConsumed() {
        let vm = makeWithHammer()
        vm.grid[0].type = .empty

        vm.applyPowerUp(at: 0)

        #expect(vm.grid[0].type == .empty)
        #expect(vm.powerUps[.hammer] == 1) // non consumato
    }

    @Test("Hammer su liquirizia: non ha effetto (non viene consumato)")
    func hammer_onLicorice_hasNoEffect() {
        let vm = makeWithHammer()
        vm.grid[0].type = .licorice

        vm.applyPowerUp(at: 0)

        #expect(vm.grid[0].type == .licorice)
        #expect(vm.powerUps[.hammer] == 1) // non consumato
    }

    @Test("Hammer su waffle: degrada a brokenWaffle")
    func hammer_onWaffle_degradesToBrokenWaffle() {
        let vm = makeWithHammer()
        vm.grid[0].type = .waffle

        vm.applyPowerUp(at: 0)

        #expect(vm.grid[0].type == .brokenWaffle)
        #expect(vm.powerUps[.hammer] == 0)
    }

    @Test("Hammer su brokenWaffle: lo distrugge")
    func hammer_onBrokenWaffle_destroysIt() {
        let vm = makeWithHammer()
        vm.grid[0].type = .brokenWaffle

        vm.applyPowerUp(at: 0)

        #expect(vm.grid[0].type == .empty)
        #expect(vm.powerUps[.hammer] == 0)
    }

    @Test("Hammer su ghiaccio: lo distrugge")
    func hammer_onIce_destroysIt() {
        let vm = makeWithHammer()
        vm.grid[0].type = .ice

        vm.applyPowerUp(at: 0)

        #expect(vm.grid[0].type == .empty)
        #expect(vm.powerUps[.hammer] == 0)
    }

    @Test("Hammer su cella conveyor: non viene consumato")
    func hammer_onConveyorCell_notConsumed() {
        let vm = makeWithHammer()
        vm.grid[0].type  = .red
        vm.cellTypes[0]  = .conveyor(.left) // non è .normal

        vm.applyPowerUp(at: 0)

        #expect(vm.grid[0].type == .red)     // invariata
        #expect(vm.powerUps[.hammer] == 1)   // non consumato
    }

    @Test("Hammer decrementa le mosse rimaste")
    func hammer_decrementsMovesLeft() {
        let vm = makeWithHammer()
        vm.grid[0].type = .red
        vm.movesLeft    = 10

        vm.applyPowerUp(at: 0)

        #expect(vm.movesLeft == 9)
    }

    @Test("Hammer azzera activePowerUp dopo l'uso")
    func hammer_clearsActivePowerUp() {
        let vm = makeWithHammer()
        vm.grid[0].type = .red

        vm.applyPowerUp(at: 0)

        #expect(vm.activePowerUp == nil)
    }
}

// MARK: - Swap

@MainActor
@Suite("PowerUps – Swap")
struct SwapTests {

    @Test("Swap: scambia nextJellyType con il contenuto della cella")
    func swap_exchangesNextWithCell() {
        let vm = GameViewModel.makeForTesting()
        vm.powerUps[.swap]  = 1
        vm.activePowerUp    = .swap
        vm.cellTypes[0]     = .normal
        vm.grid[0].type     = .blue
        vm.nextJellyType    = .red
        vm.nextJellyHasKey  = false

        vm.applyPowerUp(at: 0)

        // La cella riceve red (nessun merge: 1 sola red) e next diventa blue
        #expect(vm.grid[0].type  == .red)
        #expect(vm.nextJellyType == .blue)
        #expect(vm.powerUps[.swap] == 0)
    }

    @Test("Swap preserva il flag hasKey dello scambio")
    func swap_preservesKeyFlag() {
        let vm = GameViewModel.makeForTesting()
        vm.powerUps[.swap]  = 1
        vm.activePowerUp    = .swap
        vm.cellTypes[0]     = .normal
        vm.grid[0].type     = .blue
        vm.grid[0].hasKey   = true
        vm.nextJellyType    = .red
        vm.nextJellyHasKey  = false

        vm.applyPowerUp(at: 0)

        #expect(vm.nextJellyHasKey == true)  // key trasferita al next
        #expect(vm.grid[0].hasKey  == false) // cella non ha la key del next
    }

    @Test("Swap su cella vuota: non viene consumato")
    func swap_onEmptyCell_notConsumed() {
        let vm = GameViewModel.makeForTesting()
        vm.powerUps[.swap] = 1
        vm.activePowerUp   = .swap
        vm.cellTypes[0]    = .normal
        vm.grid[0].type    = .empty

        vm.applyPowerUp(at: 0)

        #expect(vm.powerUps[.swap] == 1)
    }

    @Test("Swap decrementa le mosse")
    func swap_decrementsMovesLeft() {
        let vm = GameViewModel.makeForTesting()
        vm.powerUps[.swap] = 1
        vm.activePowerUp   = .swap
        vm.cellTypes[0]    = .normal
        vm.grid[0].type    = .orange
        vm.movesLeft       = 10

        vm.applyPowerUp(at: 0)

        #expect(vm.movesLeft == 9)
    }

    @Test("Swap può innescare un merge se il pezzo scambiato crea una connessione")
    func swap_canTriggerMerge() {
        let vm = GameViewModel.makeForTesting()
        // (0,0) ha già una red; swap mette una red anche in (0,1) → 2 red → merge in blue
        vm.powerUps[.swap] = 1
        vm.activePowerUp   = .swap
        vm.cellTypes[1]    = .normal
        vm.grid[0].type    = .red   // red adiacente
        vm.grid[1].type    = .blue  // cella target dello swap
        vm.nextJellyType   = .red   // questo andrà nella cella

        vm.applyPowerUp(at: 1) // swap: red va in [1], blue va in next

        // 2 red connesse → merge in blue a [1]
        #expect(vm.grid[1].type == .blue)
        #expect(vm.grid[0].type == .empty)
    }
}

// MARK: - Magic Brush

@MainActor
@Suite("PowerUps – Magic Brush")
struct BrushTests {

    @Test("Brush: converte una gelatina in arcobaleno")
    func brush_convertsJellyToRainbow() {
        let vm = GameViewModel.makeForTesting()
        vm.powerUps[.brush] = 1
        vm.activePowerUp    = .brush
        vm.cellTypes[0]     = .normal
        vm.grid[0].type     = .red

        vm.applyPowerUp(at: 0)

        // Nessun'altra gelatina adiacente → rainbow rimane isolato, no merge
        #expect(vm.grid[0].type == .rainbow)
        #expect(vm.powerUps[.brush] == 0)
    }

    @Test("Brush su ostacolo: non ha effetto, non viene consumato")
    func brush_onObstacle_hasNoEffect() {
        let vm = GameViewModel.makeForTesting()
        vm.powerUps[.brush] = 1
        vm.activePowerUp    = .brush
        vm.cellTypes[0]     = .normal
        vm.grid[0].type     = .ice

        vm.applyPowerUp(at: 0)

        #expect(vm.grid[0].type == .ice)
        #expect(vm.powerUps[.brush] == 1) // non consumato
    }

    @Test("Brush su cella vuota: non ha effetto, non viene consumato")
    func brush_onEmptyCell_hasNoEffect() {
        let vm = GameViewModel.makeForTesting()
        vm.powerUps[.brush] = 1
        vm.activePowerUp    = .brush
        vm.cellTypes[0]     = .normal
        vm.grid[0].type     = .empty

        vm.applyPowerUp(at: 0)

        #expect(vm.grid[0].type == .empty)
        #expect(vm.powerUps[.brush] == 1)
    }

    @Test("Brush decrementa le mosse")
    func brush_decrementsMovesLeft() {
        let vm = GameViewModel.makeForTesting()
        vm.powerUps[.brush] = 1
        vm.activePowerUp    = .brush
        vm.cellTypes[0]     = .normal
        vm.grid[0].type     = .green
        vm.movesLeft        = 10

        vm.applyPowerUp(at: 0)

        #expect(vm.movesLeft == 9)
    }

    @Test("Brush azzera activePowerUp dopo l'uso")
    func brush_clearsActivePowerUp() {
        let vm = GameViewModel.makeForTesting()
        vm.powerUps[.brush] = 1
        vm.activePowerUp    = .brush
        vm.cellTypes[0]     = .normal
        vm.grid[0].type     = .red

        vm.applyPowerUp(at: 0)

        #expect(vm.activePowerUp == nil)
    }
}
