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
            var newCellTypes: [CellType] = Array(repeating: .normal, count: totalCells)
            var newGeneratorCounters: [Int: Int] = [:]

            for r in 0..<gridSize {
                for c in 0..<gridSize {
                    let cellStr = levelData.grid[r][c]
                    let idx = getIndex(row: r, col: c)

                    if let specialCell = mapStringToCellType(cellStr) {
                        newCellTypes[idx] = specialCell
                        newGrid.append(Jelly(type: .empty))
                        if specialCell.isGenerator {
                            newGeneratorCounters[idx] = 0
                        }
                    } else {
                        newGrid.append(Jelly(type: mapStringToElementType(cellStr)))
                    }
                }
            }

            grid = newGrid
            cellTypes = newCellTypes
            generatorCounters = newGeneratorCounters

        } else {
            currentLevelData = nil
            movesLeft = nil
            maxMoves = nil
            grid = Array(repeating: Jelly(type: .empty), count: totalCells)
            cellTypes = Array(repeating: .normal, count: totalCells)
            generatorCounters = [:]
        }

        nextJellyType = generaNuovoPezzo()
        nextJellyHasKey = shouldGenerateKeyPiece()
    }

    func mapStringToCellType(_ str: String) -> CellType? {
        switch str.uppercased() {
        case "NASTRO_SX":  return .conveyor(.left)
        case "NASTRO_DX":  return .conveyor(.right)
        case "NASTRO_SU":  return .conveyor(.up)
        case "NASTRO_GIU": return .conveyor(.down)
        case "GENERATORE_GHIACCIO":    return .generator(.ice)
        case "GENERATORE_WAFFLE":      return .generator(.waffle)
        case "GENERATORE_LIQUIRIZIA":  return .generator(.licorice)
        case "GENERATORE_MIELE":       return .generator(.honey)
        case "GENERATORE_ROSSO":       return .generator(.red)
        case "GENERATORE_BLU":         return .generator(.blue)
        case "GENERATORE_VERDE":       return .generator(.green)
        case "GENERATORE_ARANCIONE":   return .generator(.orange)
        case "GENERATORE_GIALLO":      return .generator(.yellow)
        default: return nil
        }
    }
}
