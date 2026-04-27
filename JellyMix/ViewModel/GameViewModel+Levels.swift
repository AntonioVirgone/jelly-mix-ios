//
//  GameViewModel+Levels.swift
//  JellyMix
//

import Foundation

extension GameViewModel {

    func loadLevelsFromJSON() {
        guard let url = Bundle.main.url(forResource: "levels", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return }

        do {
            let collection = try JSONDecoder().decode(WorldCollection.self, from: data)
            self.worlds = collection.worlds
            for world in collection.worlds {
                for lvl in world.levels {
                    allLevels[lvl.level] = lvl
                }
            }
        } catch {
            print("Errore parsing JSON: \(error)")
        }
    }

    func resetGame(forLevel level: Int) {
        currentLevel = level
        score = 0
        keysCollected = 0
        holdPiece = nil
        holdPieceHasKey = false
        nextJellyHasKey = false
        hasHeldThisTurn = false
        isGameOver = false
        isLevelCompleted = false
        objective.current = 0

        if let levelData = allLevels[level] {
            currentAvailablePieces = levelData.availablePieces
            currentLevelData = levelData
            movesLeft = levelData.movesLimit
            maxMoves = levelData.movesLimit

            let targetType = mapStringToElementType(levelData.objective.targetColor ?? "")
            let objType: ObjectiveType
            switch levelData.objective.type {
            case "OBSTACLE": objType = .obstacle
            case "LICORICE": objType = .licorice
            default:         objType = .jelly
            }
            objective = LevelObjective(type: objType, targetColor: targetType, required: levelData.objective.required)

            var newGrid: [Jelly] = []
            for r in 0..<gridSize {
                for c in 0..<gridSize {
                    newGrid.append(Jelly(type: mapStringToElementType(levelData.grid[r][c])))
                }
            }
            grid = newGrid

        } else {
            currentLevelData = nil
            movesLeft = nil
            maxMoves = nil
            grid = Array(repeating: Jelly(type: .empty), count: totalCells)
        }

        nextJellyType = generaNuovoPezzo()
        nextJellyHasKey = shouldGenerateKeyPiece()
    }
}
