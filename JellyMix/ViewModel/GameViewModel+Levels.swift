//
//  GameViewModel+Levels.swift
//  JellyMix
//

import Foundation

extension GameViewModel {

    // Carica i livelli: prova l'API REST, in caso di errore usa il JSON locale.
    func loadLevels() async {
        do {
            let collection = try await WorldService.fetchWorlds()
            applyLevelCollection(collection)
        } catch {
            print("[LevelService] API non disponibile (\(error.localizedDescription)), uso JSON locale.")
            loadLevelsFromBundle()
        }
    }

    // Fallback sincrono: legge levels.json dal bundle. Usato anche dai test.
    func loadLevelsFromBundle() {
        do {
            let collection = try WorldService.loadFromBundle()
            applyLevelCollection(collection)
        } catch {
            print("[LevelService] Errore caricamento JSON locale: \(error)")
        }
    }

    func applyLevelCollection(_ collection: WorldCollection) {
        worlds = collection.sorted { $0.stageNumber < $1.stageNumber }
        allLevels.removeAll()
        let flattenedSortedLevels = collection
            .flatMap { $0.levels }
            .sorted { $0.levelNumber < $1.levelNumber }
        for lvl in flattenedSortedLevels {
            allLevels[lvl.levelNumber] = lvl
        }
        migrateProgressIfNeeded()
    }

    // MARK: - Unlock logic

    func isUnlocked(stageNumber: Int, levelIndex: Int) -> Bool {
        if stageNumber == 1 && levelIndex == 1 { return true }
        if levelIndex == 1 {
            return completedWorlds.contains(stageNumber - 1)
        }
        return completedLevels.contains(LevelCoordinate(stageNumber: stageNumber, levelIndex: levelIndex - 1))
    }

    func completeLevel(stageNumber: Int, levelIndex: Int) {
        completedLevels.insert(LevelCoordinate(stageNumber: stageNumber, levelIndex: levelIndex))
        if let world = worlds.first(where: { $0.stageNumber == stageNumber }),
           levelIndex == world.levels.count {
            completedWorlds.insert(stageNumber)
        }
    }

    func findCoordinate(forLevelNumber levelNumber: Int) -> (stageNumber: Int, levelIndex: Int)? {
        for world in worlds {
            if let level = world.levels.first(where: { $0.levelNumber == levelNumber }) {
                return (world.stageNumber, level.levelIndex)
            }
        }
        return nil
    }

    // MARK: - Migration (one-shot, da vecchio maxUnlockedLevel a Set<LevelCoordinate>)

    func migrateProgressIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: "hasCompletedMigration") else { return }
        defer { UserDefaults.standard.set(true, forKey: "hasCompletedMigration") }

        let legacyMax = UserDefaults.standard.integer(forKey: "maxUnlockedLevel")
        guard legacyMax > 1 else { return }

        let legacyCompleted = Set(1..<legacyMax)
        for world in worlds {
            for level in world.levels.sorted(by: { $0.levelIndex < $1.levelIndex }) {
                if legacyCompleted.contains(level.levelNumber) {
                    completedLevels.insert(LevelCoordinate(stageNumber: world.stageNumber, levelIndex: level.levelIndex))
                }
            }
            let worldNums = Set(world.levels.map { $0.levelNumber })
            if worldNums.isSubset(of: legacyCompleted) {
                completedWorlds.insert(world.stageNumber)
            }
        }
    }

    // Mantenuto per compatibilità con i test esistenti.
    func loadLevelsFromJSON() {
        loadLevelsFromBundle()
    }

    func resetGame(forLevel level: Int) {
        currentLevel = level
        if let coord = findCoordinate(forLevelNumber: level) {
            currentStageNumber = coord.stageNumber
            currentLevelIndex  = coord.levelIndex
        } else {
            currentStageNumber = nil
            currentLevelIndex  = nil
        }
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
            switch levelData.objective.type.uppercased() {
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
        // English identifiers (new format)
        case "CONVEYOR_LEFT":  return .conveyor(.left)
        case "CONVEYOR_RIGHT": return .conveyor(.right)
        case "CONVEYOR_UP":    return .conveyor(.up)
        case "CONVEYOR_DOWN":  return .conveyor(.down)
        case "GENERATOR_ICE":      return .generator(.ice)
        case "GENERATOR_WAFFLE":   return .generator(.waffle)
        case "GENERATOR_LICORICE": return .generator(.licorice)
        case "GENERATOR_HONEY":    return .generator(.honey)
        case "GENERATOR_RED":      return .generator(.red)
        case "GENERATOR_BLUE":     return .generator(.blue)
        case "GENERATOR_GREEN":    return .generator(.green)
        case "GENERATOR_ORANGE":   return .generator(.orange)
        case "GENERATOR_YELLOW":   return .generator(.yellow)
        case "GENERATOR_PURPLE":   return .generator(.purple)
        case "GENERATOR_ROCK":     return .generator(.rock)
        // Italian identifiers (backward compatibility)
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
