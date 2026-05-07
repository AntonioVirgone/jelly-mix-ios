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

    // Impostato a true quando un refresh in background porta nuovi dati.
    // MainCoordinator lo osserva per mostrare il banner "Mappa aggiornata".
    @Published var mapWasUpdated: Bool = false

    init() {
        totalCells = gridSize * gridSize
        grid = Array(repeating: Jelly(type: .empty), count: totalCells)
        cellTypes = Array(repeating: .normal, count: totalCells)
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
        // English identifiers (new format)
        case "RED":      return .red
        case "BLUE":     return .blue
        case "GREEN":    return .green
        case "ORANGE":   return .orange
        case "YELLOW":   return .yellow
        case "PURPLE":   return .purple
        case "ICE":      return .ice
        case "WAFFLE":   return .waffle
        case "LICORICE": return .licorice
        case "HONEY":    return .honey
        case "TREASURE": return .treasure
        case "ROCK":     return .rock
        case "EMPTY":    return .empty
        // Italian identifiers (backward compatibility)
        case "ROSSO":      return .red
        case "BLU":        return .blue
        case "VERDE":      return .green
        case "ARANCIONE":  return .orange
        case "GIALLO":     return .yellow
        case "VIOLA":      return .purple
        case "GHIACCIO":   return .ice
        case "LIQUIRIZIA": return .licorice
        case "MIELE":      return .honey
        case "TESORO":     return .treasure
        case "VUOTO":      return .empty
        default:           return .empty
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
        Color(hex: name)
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)

        let a, r, g, b: UInt64

        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (
                255,
                (int >> 8) * 17,
                (int >> 4 & 0xF) * 17,
                (int & 0xF) * 17
            )

        case 6: // RGB (24-bit)
            (a, r, g, b) = (
                255,
                int >> 16,
                int >> 8 & 0xFF,
                int & 0xFF
            )

        case 8: // ARGB (32-bit)
            (a, r, g, b) = (
                int >> 24,
                int >> 16 & 0xFF,
                int >> 8 & 0xFF,
                int & 0xFF
            )

        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
