//
//  GameViewModel+PowerUps.swift
//  JellyMix
//

import Foundation

extension GameViewModel {

    // MARK: - Shop Purchase

    func buyPowerUp(_ type: PowerUpType) {
        guard coins >= PowerUpType.cost else { return }
        coins -= PowerUpType.cost
        powerUps[type, default: 0] += 1
        savePowerUps()
    }

    // MARK: - Activation

    func activatePowerUp(_ type: PowerUpType) {
        guard (powerUps[type] ?? 0) > 0 else { return }
        guard !isGameOver && !isLevelCompleted else { return }
        activePowerUp = type
    }

    // MARK: - Application

    func applyPowerUp(at index: Int) {
        guard let powerUp = activePowerUp else { return }
        defer { activePowerUp = nil }

        guard (powerUps[powerUp] ?? 0) > 0 else { return }

        switch powerUp {
        case .hammer: applyHammer(at: index)
        case .swap:   applySwap(at: index)
        case .brush:  applyBrush(at: index)
        }
    }

    // MARK: - Hammer

    private func applyHammer(at index: Int) {
        let type = grid[index].type

        // No effect on: empty, licorice, conveyor/generator cells
        guard type != .empty && type != .licorice else { return }
        guard index < cellTypes.count && cellTypes[index] == .normal else { return }

        if type.config.isObstacle {
            gestisciDistruzioneOstacolo(at: index)
        } else {
            grid[index] = Jelly(type: .empty)
        }

        powerUps[.hammer, default: 0] -= 1
        savePowerUps()
        decrementMoves()
        checkWinLoseConditions()
    }

    // MARK: - Swap

    private func applySwap(at index: Int) {
        guard grid[index].type != .empty else { return }
        guard index < cellTypes.count && cellTypes[index] == .normal else { return }

        // Scambia PROSSIMO con il pezzo nella cella
        let oldType = grid[index].type
        let oldHasKey = grid[index].hasKey

        grid[index].type = nextJellyType
        grid[index].hasKey = nextJellyHasKey

        nextJellyType = oldType
        nextJellyHasKey = oldHasKey

        powerUps[.swap, default: 0] -= 1
        savePowerUps()

        // Il nuovo pezzo nella cella può innescare merge
        let earnedRainbow = processMerges(startRow: index / gridSize, startCol: index % gridSize)
        if earnedRainbow {
            nextJellyType = .rainbow
            nextJellyHasKey = false
        }

        decrementMoves()
        checkWinLoseConditions()
    }

    // MARK: - Magic Brush

    private func applyBrush(at index: Int) {
        let type = grid[index].type
        guard type != .empty && !type.config.isObstacle else { return }
        guard index < cellTypes.count && cellTypes[index] == .normal else { return }

        grid[index].type = .rainbow

        powerUps[.brush, default: 0] -= 1
        savePowerUps()

        let earnedRainbow = processMerges(startRow: index / gridSize, startCol: index % gridSize)
        nextJellyType = earnedRainbow ? .rainbow : generaNuovoPezzo()
        nextJellyHasKey = earnedRainbow ? false : shouldGenerateKeyPiece()

        decrementMoves()
        checkWinLoseConditions()
    }

    // MARK: - Helpers

    private func decrementMoves() {
        if let moves = movesLeft { movesLeft = moves - 1 }
    }

    // MARK: - Persistence

    func savePowerUps() {
        let dict = Dictionary(uniqueKeysWithValues: powerUps.map { ($0.key.rawValue, $0.value) })
        UserDefaults.standard.set(dict, forKey: "savedPowerUps")
    }

    func loadPowerUps() {
        var loaded: [PowerUpType: Int] = Dictionary(
            uniqueKeysWithValues: PowerUpType.allCases.map { ($0, 0) }
        )
        if let saved = UserDefaults.standard.dictionary(forKey: "savedPowerUps") as? [String: Int] {
            for type in PowerUpType.allCases {
                loaded[type] = saved[type.rawValue] ?? 0
            }
        }
        powerUps = loaded
    }
}
