//
//  GameViewModelTests+Gameplay.swift
//  JellyMix
//
//  Created by Antonio Virgone on 29/04/26.
//

import Testing
@testable import JellyMix

// MARK: - Hold

@MainActor
@Suite("Hold")
struct HoldTests {

    @Test("Primo hold senza pezzo tenuto: salva il nextJellyType")
    func holdEmpty_storesCurrentPiece() {
        let vm = GameViewModel.makeForTesting()
        vm.nextJellyType = .orange
        vm.holdPiece = nil

        vm.toggleHold()

        #expect(vm.holdPiece == .orange)
        #expect(vm.hasHeldThisTurn == true)
    }

    @Test("Hold con pezzo già tenuto: scambia i due pezzi")
    func holdExisting_swapsPieces() {
        let vm = GameViewModel.makeForTesting()
        vm.nextJellyType = .red
        vm.holdPiece     = .blue

        vm.toggleHold()

        #expect(vm.holdPiece == .red)
        #expect(vm.nextJellyType == .blue)
        #expect(vm.hasHeldThisTurn == true)
    }

    @Test("Hold: bloccato se già eseguito nel turno corrente")
    func holdBlocked_whenAlreadyHeldThisTurn() {
        let vm = GameViewModel.makeForTesting()
        vm.nextJellyType   = .red
        vm.holdPiece       = .blue
        vm.hasHeldThisTurn = true

        vm.toggleHold()

        #expect(vm.holdPiece == .blue)    // invariato
        #expect(vm.nextJellyType == .red) // invariato
    }

    @Test("Hold: bloccato se isGameOver")
    func holdBlocked_whenGameOver() {
        let vm = GameViewModel.makeForTesting()
        vm.isGameOver = true

        vm.toggleHold()

        #expect(vm.holdPiece == nil)
    }

    @Test("Hold: bloccato se isLevelCompleted")
    func holdBlocked_whenLevelCompleted() {
        let vm = GameViewModel.makeForTesting()
        vm.isLevelCompleted = true

        vm.toggleHold()

        #expect(vm.holdPiece == nil)
    }

    @Test("Hold preserva il flag hasKey del pezzo tenuto")
    func holdPreservesKeyFlag() {
        let vm = GameViewModel.makeForTesting()
        vm.nextJellyType   = .red
        vm.nextJellyHasKey = true
        vm.holdPiece       = .blue
        vm.holdPieceHasKey = false

        vm.toggleHold()

        #expect(vm.holdPiece == .red)
        #expect(vm.holdPieceHasKey == true)
        #expect(vm.nextJellyType == .blue)
        #expect(vm.nextJellyHasKey == false)
    }
}

// MARK: - Placement

@MainActor
@Suite("Placement")
struct PlacementTests {

    @Test("Piazza una gelatina su cella vuota")
    func placement_onEmptyCell_placesJelly() {
        let vm = GameViewModel.makeForTesting()
        // Verde ha requirement=4: con 1 sola cella non avviene il merge
        vm.nextJellyType = .green

        vm.posizionaGelatina(row: 0, col: 0)

        #expect(vm.grid[vm.getIndex(row: 0, col: 0)].type == .green)
    }

    @Test("Bloccato su cella già occupata")
    func placement_onOccupiedCell_isBlocked() {
        let vm = GameViewModel.makeForTesting()
        vm.grid[0].type  = .blue
        vm.nextJellyType = .red

        vm.posizionaGelatina(row: 0, col: 0)

        #expect(vm.grid[0].type == .blue)
    }

    @Test("Bloccato su cella di tipo generatore")
    func placement_onGeneratorCell_isBlocked() {
        let vm = GameViewModel.makeForTesting()
        vm.cellTypes[0]  = .generator(.ice)
        vm.nextJellyType = .red

        vm.posizionaGelatina(row: 0, col: 0)

        #expect(vm.grid[0].type == .empty)
    }

    @Test("Decrementa le mosse rimanenti di 1")
    func placement_decrementsMovesLeft() {
        let vm = GameViewModel.makeForTesting()
        vm.movesLeft = 10

        vm.posizionaGelatina(row: 0, col: 0)

        #expect(vm.movesLeft == 9)
    }

    @Test("Azzera hasHeldThisTurn dopo il posizionamento")
    func placement_resetsHasHeldThisTurn() {
        let vm = GameViewModel.makeForTesting()
        vm.hasHeldThisTurn = true
        vm.nextJellyType   = .green

        vm.posizionaGelatina(row: 0, col: 0)

        #expect(vm.hasHeldThisTurn == false)
    }

    @Test("Bloccato se isGameOver")
    func placement_blockedWhenGameOver() {
        let vm = GameViewModel.makeForTesting()
        vm.isGameOver = true

        vm.posizionaGelatina(row: 0, col: 0)

        #expect(vm.grid[0].type == .empty)
    }
}

// MARK: - Merge

@MainActor
@Suite("Merge")
struct MergeTests {

    // red.requirement = 2 → servono 2 rosse per produrre 1 blu
    @Test("Merge base: 2 rosse → 1 blu al focus, score +20")
    func merge_twoReds_producesBlue() {
        let vm = GameViewModel.makeForTesting()
        // (0,0) = red preesistente; piazza red a (0,1)
        vm.grid[vm.getIndex(row: 0, col: 0)].type = .red
        vm.nextJellyType = .red

        vm.posizionaGelatina(row: 0, col: 1)

        let focusIdx = vm.getIndex(row: 0, col: 1)
        let srcIdx   = vm.getIndex(row: 0, col: 0)
        #expect(vm.grid[focusIdx].type == .blue)
        #expect(vm.grid[srcIdx].type == .empty)
        // score: (rawValue.red=1 * 10) * 2 celle = 20
        #expect(vm.score == 20)
    }

    @Test("Merge con più celle del minimo richiesto → nextJelly diventa arcobaleno")
    func merge_moreThanRequired_earnsRainbow() {
        let vm = GameViewModel.makeForTesting()
        // 3 rosse in riga → 3 > 2 → rainbow
        vm.grid[vm.getIndex(row: 0, col: 0)].type = .red
        vm.grid[vm.getIndex(row: 0, col: 1)].type = .red
        vm.nextJellyType = .red

        vm.posizionaGelatina(row: 0, col: 2)

        #expect(vm.nextJellyType == .rainbow)
    }

    @Test("Merge: gelatina con chiave → keysCollected +1")
    func merge_jellyWithKey_collectsKey() {
        let vm = GameViewModel.makeForTesting()
        vm.grid[vm.getIndex(row: 0, col: 0)].type   = .red
        vm.grid[vm.getIndex(row: 0, col: 0)].hasKey = true
        vm.nextJellyType = .red

        vm.posizionaGelatina(row: 0, col: 1)

        #expect(vm.keysCollected == 1)
    }

    @Test("Merge con ghiaccio adiacente al focus: ghiaccio distrutto e risultato congelato")
    func merge_adjacentIce_destroysIceAndFreezesResult() {
        let vm = GameViewModel.makeForTesting()
        // Merge focus a (0,1): rosso a (0,0) + piazza rosso a (0,1)
        // Ghiaccio a (1,1): adiacente al focus
        vm.grid[vm.getIndex(row: 0, col: 0)].type = .red
        vm.grid[vm.getIndex(row: 1, col: 1)].type = .ice
        vm.nextJellyType = .red

        vm.posizionaGelatina(row: 0, col: 1)

        let focusIdx = vm.getIndex(row: 0, col: 1)
        let iceIdx   = vm.getIndex(row: 1, col: 1)
        #expect(vm.grid[iceIdx].type == .empty)
        #expect(vm.grid[focusIdx].type == .blue)
        #expect(vm.grid[focusIdx].isFreeze == true)
        // processaFineTurno decrementa freezeTurnsLeft da 3 → 2
        #expect(vm.grid[focusIdx].freezeTurnsLeft == 2)
    }

    @Test("Merge scala di tipo: prodotto inizia il prossimo ciclo di merge")
    func merge_cascadesUpgrade() {
        let vm = GameViewModel.makeForTesting()
        // Prepara 2 blu adiacenti + fai un merge di 2 rosse in (0,2) che produce un blu in (0,2)
        // Poi il blu in (0,2) è adiacente a 2 altri blu → merge cascata
        // blue.requirement = 3 → servono 3 blu
        let idx0  = vm.getIndex(row: 0, col: 0)
        let idx1  = vm.getIndex(row: 0, col: 1)
        let idx2  = vm.getIndex(row: 0, col: 2) // focus merge rosso
        let idx3  = vm.getIndex(row: 0, col: 3) // blu preesistente 1
        let idx4  = vm.getIndex(row: 0, col: 4) // blu preesistente 2

        vm.grid[idx0].type = .red   // rosso 1
        vm.grid[idx1].type = .red   // rosso 2 → merge produce blu a idx2
        vm.grid[idx3].type = .blue  // blu preesistente
        vm.grid[idx4].type = .blue  // blu preesistente
        vm.nextJellyType = .red

        // 2 rosse a (0,0)+(0,1) → merge produrre blu a (0,2) (focus)
        // Poi blu a (0,2) è connesso a (0,3)+(0,4): 3 blu → merge in verde a (0,2)
        vm.posizionaGelatina(row: 0, col: 2)

        // Cascata: 3 blu (idx2, idx3, idx4) → verde a idx2
        #expect(vm.grid[idx2].type == .green)
        #expect(vm.grid[idx3].type == .empty)
        #expect(vm.grid[idx4].type == .empty)
    }

    @Test("Merge: la gelatina frozen non partecipa al merge")
    func merge_frozenJelly_doesNotParticipate() {
        let vm = GameViewModel.makeForTesting()
        // Red frozen a (0,0) → non deve partecipare al merge
        vm.grid[vm.getIndex(row: 0, col: 0)].type           = .red
        vm.grid[vm.getIndex(row: 0, col: 0)].isFreeze       = true
        vm.grid[vm.getIndex(row: 0, col: 0)].freezeTurnsLeft = 1
        vm.nextJellyType = .red

        // Piazza red a (0,1): trova solo 1 red non frozen → nessun merge
        vm.posizionaGelatina(row: 0, col: 1)

        #expect(vm.grid[vm.getIndex(row: 0, col: 1)].type == .red) // rimasta
        #expect(vm.grid[vm.getIndex(row: 0, col: 0)].type == .red) // frozen intatta
    }
}

// MARK: - Obstacle Destruction

@MainActor
@Suite("Obstacle Destruction")
struct ObstacleDestructionTests {

    @Test("Ghiaccio → cella vuota, score +50")
    func ice_emptiesAndScores() {
        let vm = GameViewModel.makeForTesting()
        vm.grid[0].type = .ice

        vm.gestisciDistruzioneOstacolo(at: 0)

        #expect(vm.grid[0].type == .empty)
        #expect(vm.score == 50)
    }

    @Test("Waffle → brokenWaffle, score +20")
    func waffle_degradesAndScores() {
        let vm = GameViewModel.makeForTesting()
        vm.grid[0].type = .waffle

        vm.gestisciDistruzioneOstacolo(at: 0)

        #expect(vm.grid[0].type == .brokenWaffle)
        #expect(vm.score == 20)
    }

    @Test("BrokenWaffle → cella vuota, score +50")
    func brokenWaffle_emptiesAndScores() {
        let vm = GameViewModel.makeForTesting()
        vm.grid[0].type = .brokenWaffle

        vm.gestisciDistruzioneOstacolo(at: 0)

        #expect(vm.grid[0].type == .empty)
        #expect(vm.score == 50)
    }

    @Test("Liquirizia → cella vuota, score +80")
    func licorice_emptiesAndScores() {
        let vm = GameViewModel.makeForTesting()
        vm.grid[0].type = .licorice

        vm.gestisciDistruzioneOstacolo(at: 0)

        #expect(vm.grid[0].type == .empty)
        #expect(vm.score == 80)
    }

    @Test("Miele → cella vuota, score +60")
    func honey_emptiesAndScores() {
        let vm = GameViewModel.makeForTesting()
        vm.grid[0].type = .honey

        vm.gestisciDistruzioneOstacolo(at: 0)

        #expect(vm.grid[0].type == .empty)
        #expect(vm.score == 60)
    }

    @Test("Tesoro con chiave disponibile → cassa aperta, coins +250")
    func treasure_withKey_awardsCoins() {
        let vm = GameViewModel.makeForTesting()
        vm.grid[0].type  = .treasure
        vm.keysCollected = 1

        vm.gestisciDistruzioneOstacolo(at: 0)

        #expect(vm.grid[0].type == .empty)
        #expect(vm.keysCollected == 0)
        #expect(vm.coins == 250)
    }

    @Test("Tesoro senza chiave → rimane intatto")
    func treasure_withoutKey_doesNothing() {
        let vm = GameViewModel.makeForTesting()
        vm.grid[0].type  = .treasure
        vm.keysCollected = 0

        vm.gestisciDistruzioneOstacolo(at: 0)

        #expect(vm.grid[0].type == .treasure)
        #expect(vm.coins == 0)
    }

    @Test("Gelatina normale → non viene toccata (non è un ostacolo)")
    func normalJelly_isIgnored() {
        let vm = GameViewModel.makeForTesting()
        vm.grid[0].type = .red

        vm.gestisciDistruzioneOstacolo(at: 0)

        #expect(vm.grid[0].type == .red) // invariata
        #expect(vm.score == 0)
    }
}

// MARK: - Win / Lose Conditions

@MainActor
@Suite("Win & Lose Conditions")
struct WinLoseTests {

    @Test("Obiettivo raggiunto → isLevelCompleted")
    func objectiveReached_setsLevelCompleted() {
        let vm = GameViewModel.makeForTesting()
        vm.objective = LevelObjective(type: .jelly, targetColor: .blue, required: 2, current: 2)

        vm.checkWinLoseConditions()

        #expect(vm.isLevelCompleted == true)
        #expect(vm.isGameOver == false)
    }

    @Test("Mosse esaurite → isGameOver")
    func movesExhausted_setsGameOver() {
        let vm = GameViewModel.makeForTesting()
        vm.movesLeft = 0

        vm.checkWinLoseConditions()

        #expect(vm.isGameOver == true)
        #expect(vm.isLevelCompleted == false)
    }

    @Test("Griglia completamente piena → isGameOver")
    func gridFull_setsGameOver() {
        let vm = GameViewModel.makeForTesting()
        vm.movesLeft = 10
        vm.grid = Array(repeating: Jelly(type: .red), count: vm.totalCells)

        vm.checkWinLoseConditions()

        #expect(vm.isGameOver == true)
    }

    @Test("Obiettivo non raggiunto, mosse rimaste, griglia non piena → nessun cambiamento")
    func midGame_noConditionTriggered() {
        let vm = GameViewModel.makeForTesting()
        vm.movesLeft = 5

        vm.checkWinLoseConditions()

        #expect(vm.isLevelCompleted == false)
        #expect(vm.isGameOver == false)
    }

    @Test("Vittoria ha precedenza sulle mosse a zero")
    func objectiveWins_takesOverMovesZero() {
        let vm = GameViewModel.makeForTesting()
        vm.objective = LevelObjective(type: .jelly, targetColor: .blue, required: 1, current: 1)
        vm.movesLeft = 0

        vm.checkWinLoseConditions()

        #expect(vm.isLevelCompleted == true)
        #expect(vm.isGameOver == false)
    }
}
