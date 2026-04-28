//
//  GameViewModel.swift
//  JellyMix
//
//  Created by Antonio Virgone on 21/04/26.
//

import Foundation
import SwiftUI
import Combine

class GameViewModel: ObservableObject {
    let gridSize = 5
    let totalCells: Int

    // MARK: - Game State
    @Published var grid: [Jelly] = []
    @Published var nextJellyType: ElementType = .red
    @Published var nextJellyHasKey: Bool = false
    @Published var holdPiece: ElementType? = nil
    @Published var holdPieceHasKey: Bool = false
    @Published var hasHeldThisTurn: Bool = false
    @Published var score: Int = 0
    @Published var keysCollected: Int = 0

    // MARK: - Power-Ups
    @Published var powerUps: [PowerUpType: Int] = [:]
    @Published var activePowerUp: PowerUpType? = nil

    // MARK: - Shop
    @Published var unlockedJellies: Set<ElementType> = [.red] {
        didSet {
            UserDefaults.standard.set(unlockedJellies.map { $0.rawValue }, forKey: "savedUnlockedJellies")
        }
    }
    @Published var coins: Int = 0 {
        didSet { UserDefaults.standard.set(coins, forKey: "savedCoins") }
    }

    // MARK: - Level
    @Published var currentLevel: Int = 1
    @Published var movesLeft: Int? = nil
    @Published var maxMoves: Int? = nil
    @Published var objective: LevelObjective = LevelObjective(type: .jelly, targetColor: .blue, required: 2)
    @Published var isGameOver: Bool = false
    @Published var isLevelCompleted: Bool = false
    @Published var currentAvailablePieces: [AvailablePieceData] = []
    @Published var worlds: [WorldData] = []

    // MARK: - Merge Animation State
    struct MergeEvent: Equatable {
        let focusIndex: Int
        let color: Color
        private let token = UUID()
        static func == (lhs: Self, rhs: Self) -> Bool { lhs.token == rhs.token }
    }
    @Published var mergeEvent: MergeEvent? = nil

    // MARK: - Lives
    @Published var lives: Int = 5 {
        didSet { UserDefaults.standard.set(lives, forKey: "savedLives") }
    }
    @Published var timeToNextLife: Int = 0 {
        didSet { UserDefaults.standard.set(timeToNextLife, forKey: "lastTimeToNextLife") }
    }

    let maxLives: Int = 5
    let secondsPerLife: Int = 300
    var livesTimer: Timer?

    // MARK: - Special Cells
    @Published var cellTypes: [CellType] = []
    @Published var generatorCounters: [Int: Int] = [:]

    // MARK: - Internal
    var currentLevelData: LevelData? = nil
    var allLevels: [Int: LevelData] = [:]
    var licoriceDestroyedThisTurn: Bool = false

    init() {
        totalCells = gridSize * gridSize
        loadLevelsFromJSON()
        resetGame(forLevel: 1)
        coins = UserDefaults.standard.integer(forKey: "savedCoins")
        if let saved = UserDefaults.standard.array(forKey: "savedUnlockedJellies") as? [Int] {
            unlockedJellies = Set(saved.compactMap { ElementType(rawValue: $0) })
        }
        loadPowerUps()
    }

    // MARK: - Helpers

    func getIndex(row: Int, col: Int) -> Int {
        row * gridSize + col
    }

    func mapStringToElementType(_ str: String) -> ElementType {
        switch str.uppercased() {
        case "ROSSO": return .red
        case "BLU": return .blue
        case "GREEN", "VERDE": return .green
        case "ARANCIONE": return .orange
        case "GIALLO": return .yellow
        case "GHIACCIO": return .ice
        case "WAFFLE": return .waffle
        case "LIQUIRIZIA": return .licorice
        case "MIELE": return .honey
        case "TESORO": return .treasure
        case "VUOTO": return .empty
        default: return .empty
        }
    }

    func generaNuovoPezzo() -> ElementType {
        if let levelData = currentLevelData {
            let unlockedPieces = levelData.availablePieces.filter { ($0.point ?? 0) <= score }
            if let randomPieceStr = unlockedPieces.randomElement()?.type {
                return mapStringToElementType(randomPieceStr)
            }
        }
        return unlockedJellies.randomElement() ?? .red
    }

    func shouldGenerateKeyPiece() -> Bool {
        let treasureCount = grid.filter { $0.type == .treasure }.count
        guard treasureCount > 0 else { return false }

        let keysOnGrid = grid.filter { $0.hasKey }.count
        let heldKey = holdPieceHasKey ? 1 : 0
        let totalKeysInPlay = keysCollected + keysOnGrid + heldKey
        guard totalKeysInPlay < treasureCount else { return false }

        return Double.random(in: 0...1) < 0.5
    }

    func getColor(from name: String) -> Color {
        switch name.lowercased() {
        case "pink": return .pink
        case "cyan": return .cyan
        case "orange": return .orange
        case "purple": return .purple
        case "blue": return .blue
        default: return .gray
        }
    }
}
