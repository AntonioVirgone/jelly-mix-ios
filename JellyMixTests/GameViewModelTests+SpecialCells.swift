//
//  GameViewModelTests+SpecialCells.swift
//  JellyMixTests
//
//  Created by Antonio Virgone on 29/04/26.
//

import Testing
@testable import JellyMix

// MARK: - Conveyor Belts
//
// Griglia 5×5 – indici riga/colonna:
//   getIndex(r, c) = r*5 + c
//
// I nastri vengono processati in processConveyors(), chiamato da processaFineTurno()
// che a sua volta è invocato da processMerges() (che è il cuore di posizionaGelatina).
// Nei test richiamiamo processConveyors() direttamente per isolare il comportamento.

@MainActor
@Suite("Conveyor Belts")
struct ConveyorTests {

    @Test("Nastro LEFT: sposta la gelatina di una colonna a sinistra")
    func conveyor_left_movesJellyLeft() {
        let vm = GameViewModel.makeForTesting()
        let srcIdx  = vm.getIndex(row: 0, col: 2)
        let destIdx = vm.getIndex(row: 0, col: 1)

        vm.grid[srcIdx].type    = .red
        vm.cellTypes[srcIdx]    = .conveyor(.left)

        vm.processConveyors()

        #expect(vm.grid[destIdx].type == .red)
        #expect(vm.grid[srcIdx].type  == .empty)
    }

    @Test("Nastro RIGHT: sposta la gelatina di una colonna a destra")
    func conveyor_right_movesJellyRight() {
        let vm = GameViewModel.makeForTesting()
        let srcIdx  = vm.getIndex(row: 0, col: 1)
        let destIdx = vm.getIndex(row: 0, col: 2)

        vm.grid[srcIdx].type = .red
        vm.cellTypes[srcIdx] = .conveyor(.right)

        vm.processConveyors()

        #expect(vm.grid[destIdx].type == .red)
        #expect(vm.grid[srcIdx].type  == .empty)
    }

    @Test("Nastro UP: sposta la gelatina di una riga verso l'alto")
    func conveyor_up_movesJellyUp() {
        let vm = GameViewModel.makeForTesting()
        let srcIdx  = vm.getIndex(row: 2, col: 2)
        let destIdx = vm.getIndex(row: 1, col: 2)

        vm.grid[srcIdx].type = .blue
        vm.cellTypes[srcIdx] = .conveyor(.up)

        vm.processConveyors()

        #expect(vm.grid[destIdx].type == .blue)
        #expect(vm.grid[srcIdx].type  == .empty)
    }

    @Test("Nastro DOWN: sposta la gelatina di una riga verso il basso")
    func conveyor_down_movesJellyDown() {
        let vm = GameViewModel.makeForTesting()
        let srcIdx  = vm.getIndex(row: 1, col: 2)
        let destIdx = vm.getIndex(row: 2, col: 2)

        vm.grid[srcIdx].type = .green
        vm.cellTypes[srcIdx] = .conveyor(.down)

        vm.processConveyors()

        #expect(vm.grid[destIdx].type == .green)
        #expect(vm.grid[srcIdx].type  == .empty)
    }

    @Test("Nastro: non sposta se la destinazione è occupata")
    func conveyor_doesNotMoveToOccupiedCell() {
        let vm = GameViewModel.makeForTesting()
        let srcIdx  = vm.getIndex(row: 0, col: 2)
        let destIdx = vm.getIndex(row: 0, col: 1)

        vm.grid[srcIdx].type  = .red
        vm.grid[destIdx].type = .blue   // destinazione occupata
        vm.cellTypes[srcIdx]  = .conveyor(.left)

        vm.processConveyors()

        #expect(vm.grid[srcIdx].type  == .red)  // non si è mosso
        #expect(vm.grid[destIdx].type == .blue) // invariato
    }

    @Test("Nastro: non sposta se la destinazione è un generatore")
    func conveyor_doesNotMoveToGeneratorCell() {
        let vm = GameViewModel.makeForTesting()
        let srcIdx  = vm.getIndex(row: 0, col: 2)
        let destIdx = vm.getIndex(row: 0, col: 1)

        vm.grid[srcIdx].type  = .red
        vm.cellTypes[srcIdx]  = .conveyor(.left)
        vm.cellTypes[destIdx] = .generator(.ice) // destinazione = generatore

        vm.processConveyors()

        #expect(vm.grid[srcIdx].type  == .red)   // non si è mosso
        #expect(vm.grid[destIdx].type == .empty) // generatore: nessuna gelatina
    }

    @Test("Nastro: non sposta una cella vuota")
    func conveyor_doesNotMoveEmptyCell() {
        let vm = GameViewModel.makeForTesting()
        let srcIdx  = vm.getIndex(row: 0, col: 2)
        let destIdx = vm.getIndex(row: 0, col: 1)

        vm.grid[srcIdx].type = .empty
        vm.cellTypes[srcIdx] = .conveyor(.left)

        vm.processConveyors()

        #expect(vm.grid[srcIdx].type  == .empty)
        #expect(vm.grid[destIdx].type == .empty)
    }

    @Test("Nastro al bordo: non sposta fuori dalla griglia")
    func conveyor_atEdge_doesNotMoveOutOfBounds() {
        let vm = GameViewModel.makeForTesting()
        // Col 0 con nastro LEFT → destinazione col -1, out of bounds
        let edgeIdx = vm.getIndex(row: 0, col: 0)
        vm.grid[edgeIdx].type = .red
        vm.cellTypes[edgeIdx] = .conveyor(.left)

        vm.processConveyors()

        #expect(vm.grid[edgeIdx].type == .red) // rimasta al bordo
    }

    @Test("Nastro: preserva hasKey della gelatina spostata")
    func conveyor_preservesKeyFlag() {
        let vm = GameViewModel.makeForTesting()
        let srcIdx  = vm.getIndex(row: 0, col: 2)
        let destIdx = vm.getIndex(row: 0, col: 1)

        vm.grid[srcIdx].type   = .red
        vm.grid[srcIdx].hasKey = true
        vm.cellTypes[srcIdx]   = .conveyor(.left)

        vm.processConveyors()

        #expect(vm.grid[destIdx].type   == .red)
        #expect(vm.grid[destIdx].hasKey == true)
        #expect(vm.grid[srcIdx].hasKey  == false) // sorgente svuotata
    }

    @Test("Nastri concatenati: il leading-edge si muove prima, liberando spazio")
    func conveyor_chained_leadingEdgeMovesFirst() {
        let vm = GameViewModel.makeForTesting()
        // Due nastri LEFT in riga 0: col 1 e col 2 (entrambi con gelatina)
        // Risultato atteso: col 0 = red, col 1 = blue, col 2 = empty
        let idx0 = vm.getIndex(row: 0, col: 0) // destinazione di col1
        let idx1 = vm.getIndex(row: 0, col: 1) // nastro con red
        let idx2 = vm.getIndex(row: 0, col: 2) // nastro con blue

        vm.grid[idx1].type = .red
        vm.grid[idx2].type = .blue
        vm.cellTypes[idx1] = .conveyor(.left)
        vm.cellTypes[idx2] = .conveyor(.left)

        vm.processConveyors()

        #expect(vm.grid[idx0].type == .red)
        #expect(vm.grid[idx1].type == .blue)
        #expect(vm.grid[idx2].type == .empty)
    }
}

// MARK: - Generators
//
// Il generatore al centro (2,2) = index 12 ha priorità: su(1,2)=7, dx(2,3)=13, giù(3,2)=17, sx(2,1)=11

@MainActor
@Suite("Generators")
struct GeneratorTests {

    @Test("Generatore: non spawna prima di 3 turni")
    func generator_doesNotSpawnBeforeThreeTurns() {
        let vm = GameViewModel.makeForTesting()
        vm.cellTypes[12]         = .generator(.red)
        vm.generatorCounters[12] = 0

        vm.processGenerators() // counter → 1
        #expect(vm.generatorCounters[12] == 1)
        #expect(vm.grid.allSatisfy { $0.type == .empty })

        vm.processGenerators() // counter → 2
        #expect(vm.generatorCounters[12] == 2)
        #expect(vm.grid.allSatisfy { $0.type == .empty })
    }

    @Test("Generatore: al 3° turno spawna nella prima cella libera adiacente (su = priorità)")
    func generator_atThirdTurn_spawnsAbove() {
        let vm = GameViewModel.makeForTesting()
        vm.cellTypes[12]         = .generator(.red)
        vm.generatorCounters[12] = 2 // al prossimo processGenerators: 2+1=3 → spawn

        vm.processGenerators()

        // Priorità: su = (1,2) = idx 7
        #expect(vm.grid[7].type            == .red)
        #expect(vm.generatorCounters[12]   == 0)    // counter azzerato
    }

    @Test("Generatore: resetta il counter a 0 anche quando lo spawn fallisce")
    func generator_resetsCounterEvenOnFailedSpawn() {
        let vm = GameViewModel.makeForTesting()
        // Blocca tutti i vicini con tesori (impushable)
        vm.cellTypes[12] = .generator(.red)
        vm.generatorCounters[12] = 2
        vm.grid[7].type  = .treasure
        vm.grid[13].type = .treasure
        vm.grid[17].type = .treasure
        vm.grid[11].type = .treasure

        vm.processGenerators()

        #expect(vm.generatorCounters[12] == 0) // azzerato nonostante spawn fallito
    }

    @Test("Generatore: usa la seconda cella libera se la prima è occupata")
    func generator_usesSecondFreeNeighbor_whenFirstOccupied() {
        let vm = GameViewModel.makeForTesting()
        vm.cellTypes[12]         = .generator(.blue)
        vm.generatorCounters[12] = 2
        vm.grid[7].type          = .red // (1,2) occupata → si usa (2,3)=13

        vm.processGenerators()

        #expect(vm.grid[13].type == .blue) // secondo vicino libero (dx)
        #expect(vm.grid[7].type  == .red)  // intatto
    }

    @Test("Generatore: forza il push quando tutti i vicini sono occupati (non-fixed)")
    func generator_pushesWhenAllNeighborsFull() {
        let vm = GameViewModel.makeForTesting()
        // Centro (2,2)=12 con .blue generator
        vm.cellTypes[12]         = .generator(.blue)
        vm.generatorCounters[12] = 2

        // Occupa tutti i 4 vicini con gelatine ordinarie (pushable)
        vm.grid[7].type  = .red   // su (1,2)
        vm.grid[13].type = .red   // dx (2,3)
        vm.grid[17].type = .red   // giù (3,2)
        vm.grid[11].type = .red   // sx (2,1)

        vm.processGenerators()

        // Push del primo vicino (su=idx7) verso (0,2)=idx2; poi blue spawna a idx7
        #expect(vm.grid[2].type == .red)  // red spinto in (0,2)
        #expect(vm.grid[7].type == .blue) // nuovo elemento spawnato in (1,2)
    }

    @Test("Generatore: NON spinge tesori né waffle")
    func generator_doesNotPushTreasureOrWaffle() {
        let vm = GameViewModel.makeForTesting()
        vm.cellTypes[12]         = .generator(.red)
        vm.generatorCounters[12] = 2

        vm.grid[7].type  = .treasure // su
        vm.grid[13].type = .treasure // dx
        vm.grid[17].type = .waffle   // giù
        vm.grid[11].type = .waffle   // sx

        vm.processGenerators()

        // Nessuno spostato, nessun elemento spawnato
        #expect(vm.grid[7].type  == .treasure)
        #expect(vm.grid[13].type == .treasure)
        #expect(vm.grid[17].type == .waffle)
        #expect(vm.grid[11].type == .waffle)
    }

    @Test("Generatore: non può spawnare in una cella generatore adiacente")
    func generator_doesNotSpawnIntoAnotherGenerator() {
        let vm = GameViewModel.makeForTesting()
        vm.cellTypes[12]         = .generator(.red)
        vm.generatorCounters[12] = 2
        // Il vicino prioritario (su=7) è anch'esso un generatore
        vm.cellTypes[7]          = .generator(.blue)

        vm.processGenerators()

        // Deve usare il secondo vicino libero (dx=13)
        #expect(vm.grid[7].type  == .empty) // generatore: non usato
        #expect(vm.grid[13].type == .red)   // secondo vicino libero
    }
}
