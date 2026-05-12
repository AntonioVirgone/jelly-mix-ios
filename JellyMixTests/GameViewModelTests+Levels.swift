//
//   GameViewModelTests+Levels.swift
//  JellyMixTests
//
//  Created by Antonio Virgone on 29/04/26.
//

import Testing
import Foundation
@testable import JellyMix

// MARK: - Helpers per i test di sblocco

private func makeWorld(stageNumber: Int, levelCount: Int, startingLevelNumber: Int = 1) -> WorldData {
    let levels = (1...levelCount).map { i in
        LevelData(
            id: "\(stageNumber)-\(i)", levelNumber: startingLevelNumber + i - 1, levelIndex: i,
            movesLimit: 10, status: nil,
            objective: ObjectiveData(type: "JELLY", targetColor: "BLUE", required: 1),
            grid: [], availablePieces: [], worldId: nil, createdAt: nil, updatedAt: nil
        )
    }
    return WorldData(id: "\(stageNumber)", name: "Mondo \(stageNumber)", description: nil,
                     stageNumber: stageNumber, color: "#FF0000", icon: "🍓",
                     status: "ACTIVE", isActive: true, createdAt: nil, updatedAt: nil, levels: levels)
}

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

// MARK: - isUnlocked / completeLevel

@MainActor
@Suite("Levels – isUnlocked")
struct UnlockTests {

    // Scenario 1: fresh install → solo Mondo 1 Livello 1 sbloccato
    @Test("fresh install: solo (1,1) sbloccato")
    func freshInstall_onlyFirstLevelUnlocked() {
        let vm = GameViewModel.makeForTesting()
        vm.applyLevelCollection([makeWorld(stageNumber: 1, levelCount: 3)])

        #expect(vm.isUnlocked(stageNumber: 1, levelIndex: 1) == true)
        #expect(vm.isUnlocked(stageNumber: 1, levelIndex: 2) == false)
        #expect(vm.isUnlocked(stageNumber: 1, levelIndex: 3) == false)
    }

    // Scenario 2: progressione normale → completa (1,1) sblocca (1,2), non (2,1)
    @Test("progressione normale: (1,1) completato → (1,2) sbloccato, (2,1) ancora bloccato")
    func progression_completingLevel1_unlocksLevel2SameWorld() {
        let vm = GameViewModel.makeForTesting()
        vm.applyLevelCollection([
            makeWorld(stageNumber: 1, levelCount: 3),
            makeWorld(stageNumber: 2, levelCount: 2, startingLevelNumber: 4)
        ])

        vm.completeLevel(stageNumber: 1, levelIndex: 1)

        #expect(vm.isUnlocked(stageNumber: 1, levelIndex: 1) == true)
        #expect(vm.isUnlocked(stageNumber: 1, levelIndex: 2) == true)
        #expect(vm.isUnlocked(stageNumber: 1, levelIndex: 3) == false)
        #expect(vm.isUnlocked(stageNumber: 2, levelIndex: 1) == false)
    }

    // Scenario 3: completare tutti i livelli del Mondo 1 sblocca Mondo 2 Livello 1
    @Test("passaggio mondo: completare Mondo 1 → (2,1) sbloccato")
    func worldTransition_completingWorld_unlocksFirstLevelNextWorld() {
        let vm = GameViewModel.makeForTesting()
        vm.applyLevelCollection([
            makeWorld(stageNumber: 1, levelCount: 2),
            makeWorld(stageNumber: 2, levelCount: 2, startingLevelNumber: 3)
        ])

        vm.completeLevel(stageNumber: 1, levelIndex: 1)
        vm.completeLevel(stageNumber: 1, levelIndex: 2)

        #expect(vm.completedWorlds.contains(1) == true)
        #expect(vm.isUnlocked(stageNumber: 2, levelIndex: 1) == true)
        #expect(vm.isUnlocked(stageNumber: 2, levelIndex: 2) == false)
    }

    // Scenario 4 (caso critico): mondo completato → nuovo livello aggiunto risulta sbloccato
    @Test("caso critico: Mondo 1 completato, nuovo livello aggiunto → risulta sbloccato")
    func criticalCase_worldCompleted_newLevelIsUnlocked() {
        let vm = GameViewModel.makeForTesting()
        // Il giocatore ha completato Mondo 1 con 2 livelli
        vm.applyLevelCollection([makeWorld(stageNumber: 1, levelCount: 2)])
        vm.completeLevel(stageNumber: 1, levelIndex: 1)
        vm.completeLevel(stageNumber: 1, levelIndex: 2)

        // Backend aggiunge un terzo livello al Mondo 1
        vm.applyLevelCollection([makeWorld(stageNumber: 1, levelCount: 3)])

        // Il nuovo livello (1,3) deve essere sbloccato perché Mondo 1 è in completedWorlds
        #expect(vm.isUnlocked(stageNumber: 1, levelIndex: 3) == true)
    }

    // Scenario 5: migrazione da vecchio maxUnlockedLevel
    @Test("migrazione: vecchio maxUnlockedLevel=3 → (1,1) e (1,2) completati, (1,3) corrente")
    func migration_legacyProgress_convertedCorrectly() {
        let vm = GameViewModel.makeForTesting()
        // Simula vecchio progresso: livelli 1 e 2 completati, 3 = corrente
        UserDefaults.standard.set(3, forKey: "maxUnlockedLevel")
        UserDefaults.standard.removeObject(forKey: "hasCompletedMigration")

        let world = makeWorld(stageNumber: 1, levelCount: 3)
        vm.applyLevelCollection([world])

        #expect(vm.completedLevels.contains(LevelCoordinate(stageNumber: 1, levelIndex: 1)) == true)
        #expect(vm.completedLevels.contains(LevelCoordinate(stageNumber: 1, levelIndex: 2)) == true)
        #expect(vm.completedLevels.contains(LevelCoordinate(stageNumber: 1, levelIndex: 3)) == false)
        #expect(vm.isUnlocked(stageNumber: 1, levelIndex: 3) == true)

        // Cleanup
        UserDefaults.standard.removeObject(forKey: "maxUnlockedLevel")
        UserDefaults.standard.removeObject(forKey: "hasCompletedMigration")
    }
}
