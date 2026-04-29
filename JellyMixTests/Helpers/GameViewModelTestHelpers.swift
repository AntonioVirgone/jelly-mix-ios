//
//  GameViewModelTestHelpers.swift
//  JellyMix
//
//  Created by Antonio Virgone on 29/04/26.
//

import Foundation
@testable import JellyMix

extension GameViewModel {
    /// Restituisce un'istanza con stato deterministico per i test:
    /// griglia 5×5 vuota, nessuna cella speciale, 20 mosse, obiettivo irraggiungibile (required=999).
    /// Usa questo factory in ogni test per garantire isolamento totale dallo stato persistito in UserDefaults.
    @MainActor
    static func makeForTesting() -> GameViewModel {
        let vm = GameViewModel()
        vm.grid         = Array(repeating: Jelly(type: .empty), count: vm.totalCells)
        vm.cellTypes    = Array(repeating: .normal,             count: vm.totalCells)
        vm.generatorCounters = [:]
        vm.movesLeft    = 20
        vm.maxMoves     = 20
        vm.score        = 0
        vm.coins        = 0
        vm.keysCollected = 0
        vm.isGameOver   = false
        vm.isLevelCompleted = false
        vm.objective    = LevelObjective(type: .jelly, targetColor: .blue, required: 999)
        vm.holdPiece    = nil
        vm.holdPieceHasKey  = false
        vm.nextJellyHasKey  = false
        vm.hasHeldThisTurn  = false
        vm.nextJellyType    = .red
        vm.lives        = 5
        vm.timeToNextLife   = 0
        vm.activePowerUp    = nil
        vm.powerUps = Dictionary(uniqueKeysWithValues: PowerUpType.allCases.map { ($0, 0) })
        return vm
    }
}
