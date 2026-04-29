//
//   GameViewModelTests+Levels.swift
//  JellyMixTests
//
//  Created by Antonio Virgone on 29/04/26.
//

import Testing
@testable import JellyMix

// MARK: - Reset Game

@MainActor
@Suite("Levels – Reset")
struct LevelResetTests {

    @Test("resetGame: azzera score, keysCollected, isGameOver e isLevelCompleted")
    func resetGame_clearsPlayState() {
        let vm = GameViewModel.makeForTesting()
        vm.score            = 9999
        vm.keysCollected    = 7
        vm.isGameOver       = true
        vm.isLevelCompleted = true
        vm.objective.current = 5

        vm.resetGame(forLevel: 1)

        #expect(vm.score            == 0)
        #expect(vm.keysCollected    == 0)
        #expect(vm.isGameOver       == false)
        #expect(vm.isLevelCompleted == false)
        #expect(vm.objective.current == 0)
    }

    @Test("resetGame: azzera holdPiece e hasHeldThisTurn")
    func resetGame_clearsHoldState() {
        let vm = GameViewModel.makeForTesting()
        vm.holdPiece       = .orange
        vm.holdPieceHasKey = true
        vm.hasHeldThisTurn = true

        vm.resetGame(forLevel: 1)

        #expect(vm.holdPiece       == nil)
        #expect(vm.holdPieceHasKey == false)
        #expect(vm.hasHeldThisTurn == false)
    }

    @Test("resetGame con livello senza dati JSON: griglia vuota e movesLeft nil")
    func resetGame_withUnknownLevel_emptyGrid() {
        let vm = GameViewModel.makeForTesting()
        vm.resetGame(forLevel: 9999) // livello inesistente

        #expect(vm.movesLeft  == nil)
        #expect(vm.maxMoves   == nil)
        #expect(vm.grid.count == vm.totalCells)
        #expect(vm.grid.allSatisfy { $0.type == .empty })
    }

    @Test("resetGame con livello noto da JSON: applica movesLimit dal file")
    func resetGame_withKnownLevel_setsMovesLimit() throws {
        let vm = GameViewModel()
        // Se il JSON non è stato caricato (test bundle senza host app) skippiamo
        guard let levelData = vm.allLevels[1] else { return }

        vm.resetGame(forLevel: 1)

        #expect(vm.movesLeft == levelData.movesLimit)
        #expect(vm.maxMoves  == levelData.movesLimit)
    }

    @Test("resetGame con livello noto da JSON: imposta l'obiettivo correttamente")
    func resetGame_withKnownLevel_setsObjective() throws {
        let vm = GameViewModel()
        guard let levelData = vm.allLevels[1] else { return }

        vm.resetGame(forLevel: 1)

        #expect(vm.objective.required == levelData.objective.required)
        #expect(vm.objective.current  == 0)
    }

    @Test("resetGame: la griglia ha esattamente totalCells celle")
    func resetGame_gridSizeIsCorrect() {
        let vm = GameViewModel.makeForTesting()
        vm.resetGame(forLevel: 9999)

        #expect(vm.grid.count     == vm.totalCells)
        #expect(vm.cellTypes.count == vm.totalCells)
    }
}

// MARK: - String → ElementType mapping

@MainActor
@Suite("Levels – mapStringToElementType")
struct ElementTypeMappingTests {

    @Test(
        "Mappa correttamente tutte le stringhe note",
        arguments: [
            ("ROSSO",      ElementType.red),
            ("BLU",        ElementType.blue),
            ("VERDE",      ElementType.green),
            ("GREEN",      ElementType.green),
            ("ARANCIONE",  ElementType.orange),
            ("GIALLO",     ElementType.yellow),
            ("GHIACCIO",   ElementType.ice),
            ("WAFFLE",     ElementType.waffle),
            ("LIQUIRIZIA", ElementType.licorice),
            ("MIELE",      ElementType.honey),
            ("TESORO",     ElementType.treasure),
            ("VUOTO",      ElementType.empty),
        ]
    )
    func mapStringToElementType_knownStrings(input: String, expected: ElementType) {
        let vm = GameViewModel.makeForTesting()
        #expect(vm.mapStringToElementType(input) == expected)
    }

    @Test("Stringa sconosciuta → .empty")
    func mapStringToElementType_unknownString_returnsEmpty() {
        let vm = GameViewModel.makeForTesting()
        #expect(vm.mapStringToElementType("SCONOSCIUTO") == .empty)
        #expect(vm.mapStringToElementType("")            == .empty)
    }

    @Test("La mappatura è case-insensitive (uppercase interno)")
    func mapStringToElementType_caseInsensitive() {
        let vm = GameViewModel.makeForTesting()
        #expect(vm.mapStringToElementType("rosso")  == .red)
        #expect(vm.mapStringToElementType("Blu")    == .blue)
        #expect(vm.mapStringToElementType("VERDE")  == .green)
    }
}

// MARK: - String → CellType mapping

@MainActor
@Suite("Levels – mapStringToCellType")
struct CellTypeMappingTests {

    @Test(
        "Mappa correttamente i nastri trasportatori",
        arguments: [
            ("NASTRO_SX",  CellType.conveyor(.left)),
            ("NASTRO_DX",  CellType.conveyor(.right)),
            ("NASTRO_SU",  CellType.conveyor(.up)),
            ("NASTRO_GIU", CellType.conveyor(.down)),
        ]
    )
    func mapStringToCellType_conveyors(input: String, expected: CellType) {
        let vm = GameViewModel.makeForTesting()
        #expect(vm.mapStringToCellType(input) == expected)
    }

    @Test(
        "Mappa correttamente i generatori",
        arguments: [
            ("GENERATORE_GHIACCIO",   CellType.generator(.ice)),
            ("GENERATORE_WAFFLE",     CellType.generator(.waffle)),
            ("GENERATORE_LIQUIRIZIA", CellType.generator(.licorice)),
            ("GENERATORE_MIELE",      CellType.generator(.honey)),
            ("GENERATORE_ROSSO",      CellType.generator(.red)),
            ("GENERATORE_BLU",        CellType.generator(.blue)),
            ("GENERATORE_VERDE",      CellType.generator(.green)),
            ("GENERATORE_ARANCIONE",  CellType.generator(.orange)),
            ("GENERATORE_GIALLO",     CellType.generator(.yellow)),
        ]
    )
    func mapStringToCellType_generators(input: String, expected: CellType) {
        let vm = GameViewModel.makeForTesting()
        #expect(vm.mapStringToCellType(input) == expected)
    }

    @Test("Stringa sconosciuta → nil (cella normale)")
    func mapStringToCellType_unknownString_returnsNil() {
        let vm = GameViewModel.makeForTesting()
        #expect(vm.mapStringToCellType("ROSSO")    == nil) // elemento, non tipo-cella
        #expect(vm.mapStringToCellType("SCONOSCIUTO") == nil)
        #expect(vm.mapStringToCellType("")         == nil)
    }
}
