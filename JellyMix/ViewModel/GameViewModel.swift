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
        let scoreGain: Int
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

    // Valori di default usati quando il server non è raggiungibile (offline/primo avvio).
    // Vengono sovrascritti da applyServerUserData() non appena l'API risponde.
    var maxLives: Int = 5
    var secondsPerLife: Int = 300   // 5 minuti per cuore (in sync con heartRechargeMinutes * 60)

    // MARK: - User (Step 1)
    @Published var userProfile: UserProfile? = nil   // nil finché l'API non risponde
    @Published var heartsConfig: HeartsConfig? = nil // nil finché l'API non risponde
    var livesTimer: Timer?

    // MARK: - Friends (Step 3)
    @Published var friends: [Friendship] = []               // Amici confermati (ACCEPTED)
    @Published var pendingFriendships: [Friendship] = []    // Richieste ricevute in attesa
    @Published var friendsProgress: [FriendProgress] = []  // Feed progressi amici
    @Published var isLoadingFriends: Bool = false

    // Badge count per il tab amici — numero di richieste in attesa
    var pendingFriendshipsCount: Int { pendingFriendships.count }

    // MARK: - Special Cells
    @Published var cellTypes: [CellType] = []
    @Published var generatorCounters: [Int: Int] = [:]

    // MARK: - Progress
    /// Trigger atomico per lo scroll della mappa.
    /// Viene incrementato in completeLevel() DOPO che sia completedLevels che
    /// completedWorlds sono aggiornati, evitando la double-publish race condition.
    @Published var progressVersion: Int = 0

    @Published var completedLevels: Set<LevelCoordinate> = [] {
        didSet {
            if let data = try? JSONEncoder().encode(Array(completedLevels)) {
                UserDefaults.standard.set(data, forKey: "completedLevels")
            }
        }
    }
    @Published var completedWorlds: Set<Int> = [] {
        didSet { UserDefaults.standard.set(Array(completedWorlds), forKey: "completedWorlds") }
    }

    // MARK: - Internal
    var currentLevelData: LevelData? = nil
    var currentStageNumber: Int? = nil
    var currentLevelIndex: Int? = nil
    /// Lookup legacy: chiave = levelNumber. Mantenuto per compatibilità test.
    /// Per il gameplay usa `levelsByCoordinate` (collision-free).
    var allLevels: [Int: LevelData] = [:]
    /// Lookup primario per il gameplay: chiave = (stageNumber, levelIndex), nessuna collisione.
    var levelsByCoordinate: [LevelCoordinate: LevelData] = [:]
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
        if let data = UserDefaults.standard.data(forKey: "completedLevels"),
           let arr = try? JSONDecoder().decode([LevelCoordinate].self, from: data) {
            completedLevels = Set(arr)
        }
        if let arr = UserDefaults.standard.array(forKey: "completedWorlds") as? [Int] {
            completedWorlds = Set(arr)
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
