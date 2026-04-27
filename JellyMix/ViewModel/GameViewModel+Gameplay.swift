//
//  GameViewModel+Gameplay.swift
//  JellyMix
//

import Foundation
import SwiftUI

extension GameViewModel {

    // MARK: - Hold
    func toggleHold() {
        guard !hasHeldThisTurn && !isGameOver && !isLevelCompleted else { return }

        if let currentlyHeld = holdPiece {
            let tempType = nextJellyType
            let tempKey = nextJellyHasKey
            nextJellyType = currentlyHeld
            nextJellyHasKey = holdPieceHasKey
            holdPiece = tempType
            holdPieceHasKey = tempKey
        } else {
            holdPiece = nextJellyType
            holdPieceHasKey = nextJellyHasKey
            nextJellyType = generaNuovoPezzo()
            nextJellyHasKey = shouldGenerateKeyPiece()
        }

        hasHeldThisTurn = true
    }

    // MARK: - Placement
    func posizionaGelatina(row: Int, col: Int) {
        guard !isGameOver && !isLevelCompleted else { return }

        let index = getIndex(row: row, col: col)
        guard grid[index].type == .empty else { return }

        if let moves = movesLeft {
            movesLeft = moves - 1
        }

        grid[index].type = nextJellyType
        grid[index].hasKey = nextJellyHasKey
        hasHeldThisTurn = false

        let earnedRainbow = processMerges(startRow: row, startCol: col)
        nextJellyType = earnedRainbow ? .rainbow : generaNuovoPezzo()
        nextJellyHasKey = earnedRainbow ? false : shouldGenerateKeyPiece()

        checkWinLoseConditions()
    }

    // MARK: - Merge
    private func processMerges(startRow: Int, startCol: Int) -> Bool {
        let currentFocus = (r: startRow, c: startCol)
        var hasMerged = true
        var earnedRainbow = false
        licoriceDestroyedThisTurn = false

        while hasMerged {
            hasMerged = false
            let currentIndex = getIndex(row: currentFocus.r, col: currentFocus.c)
            let currentType = grid[currentIndex].type

            guard currentType != .empty && currentType.rawValue < 7 else { break }

            let possibleTargets: [ElementType] = currentType == .rainbow
                ? [.brown, .yellow, .orange, .green, .blue, .red]
                : [currentType]

            for targetType in possibleTargets {
                let mergeBaseType = (currentType == .rainbow) ? targetType : currentType
                let requiredToMerge = Jelly(type: mergeBaseType).requirement
                var connectedCells: [Int] = []
                var visited = Set<Int>()

                func findConnected(r: Int, c: Int) {
                    if r < 0 || r >= gridSize || c < 0 || c >= gridSize { return }
                    let idx = getIndex(row: r, col: c)
                    if visited.contains(idx) { return }
                    let cell = grid[idx]
                    if (cell.type == targetType || cell.type == .rainbow) && !cell.isFreeze {
                        visited.insert(idx)
                        connectedCells.append(idx)
                        findConnected(r: r + 1, c: c)
                        findConnected(r: r - 1, c: c)
                        findConnected(r: r, c: c + 1)
                        findConnected(r: r, c: c - 1)
                    }
                }

                findConnected(r: currentFocus.r, c: currentFocus.c)

                let containsActualTarget = connectedCells.contains { grid[$0].type == targetType }

                if connectedCells.count >= requiredToMerge && containsActualTarget {
                    if connectedCells.count > requiredToMerge { earnedRainbow = true }

                    // Award key if any merging jelly had swallowed one
                    if connectedCells.contains(where: { grid[$0].hasKey }) {
                        keysCollected += 1
                    }

                    var iceDestroyedThisMerge = false
                    let focusNeighbors = [
                        (currentFocus.r - 1, currentFocus.c), (currentFocus.r + 1, currentFocus.c),
                        (currentFocus.r, currentFocus.c - 1), (currentFocus.r, currentFocus.c + 1)
                    ]
                    for (nr, nc) in focusNeighbors {
                        if nr >= 0 && nr < gridSize && nc >= 0 && nc < gridSize {
                            let nIdx = getIndex(row: nr, col: nc)
                            if grid[nIdx].type == .ice { iceDestroyedThisMerge = true }
                            gestisciDistruzioneOstacolo(at: nIdx)
                        }
                    }

                    for idx in connectedCells {
                        grid[idx].type = .empty
                        grid[idx].hasKey = false
                    }

                    let nextLevelRaw = mergeBaseType.rawValue + 1
                    if let nextType = ElementType(rawValue: nextLevelRaw) {
                        grid[currentIndex].type = nextType
                        mergeEvent = MergeEvent(focusIndex: currentIndex, color: nextType.config.color)
                        score += (mergeBaseType.rawValue * 10) * connectedCells.count

                        if objective.type == .jelly && nextType == objective.targetColor {
                            objective.current += 1
                        }

                        if iceDestroyedThisMerge {
                            grid[currentIndex].isFreeze = true
                            grid[currentIndex].freezeTurnsLeft = 3
                        }

                        hasMerged = true
                        break
                    }
                }
            }
        }

        processaFineTurno()
        return earnedRainbow
    }

    // MARK: - Obstacle Destruction
    private func gestisciDistruzioneOstacolo(at index: Int) {
        let type = grid[index].type
        guard type.config.isObstacle else { return }

        switch type {
        case .ice:
            grid[index].type = .empty
            score += 50
            if objective.type == .obstacle { objective.current += 1 }
        case .waffle:
            grid[index].type = .brokenWaffle
            score += 20
        case .brokenWaffle:
            grid[index].type = .empty
            score += 50
            if objective.type == .obstacle { objective.current += 1 }
        case .licorice:
            grid[index].type = .empty
            licoriceDestroyedThisTurn = true
            score += 80
            if objective.type == .licorice { objective.current += 1 }
        case .honey:
            grid[index].type = .empty
            score += 60
            if objective.type == .obstacle { objective.current += 1 }
        case .treasure:
            if keysCollected > 0 {
                grid[index].type = .empty
                coins += 250
                keysCollected -= 1
            }
        case .key:
            grid[index].type = .empty
            keysCollected += 1
        default:
            break
        }
    }

    // MARK: - End of Turn
    private func processaFineTurno() {
        for i in grid.indices where grid[i].isFreeze {
            grid[i].freezeTurnsLeft -= 1
            if grid[i].freezeTurnsLeft <= 0 {
                grid[i].isFreeze = false
                grid[i].freezeTurnsLeft = 0
            }
        }

        guard !licoriceDestroyedThisTurn else { return }

        let licoriceIndices = grid.indices.filter { grid[$0].type == .licorice }
        var hasExpanded = false

        for idx in licoriceIndices {
            if Double.random(in: 0...1) < 0.40 {
                if espandiLiquirizia(da: idx) { hasExpanded = true }
            }
        }

        if !hasExpanded, let randomLicorice = licoriceIndices.randomElement() {
            _ = espandiLiquirizia(da: randomLicorice)
        }
    }

    private func espandiLiquirizia(da index: Int) -> Bool {
        let r = index / gridSize
        let c = index % gridSize
        let neighbors = [(r-1, c), (r+1, c), (r, c-1), (r, c+1)]

        let validEmpty = neighbors.filter { nr, nc in
            nr >= 0 && nr < gridSize && nc >= 0 && nc < gridSize
                && grid[getIndex(row: nr, col: nc)].type == .empty
        }

        if let target = validEmpty.randomElement() {
            grid[getIndex(row: target.0, col: target.1)].type = .licorice
            return true
        }
        return false
    }

    // MARK: - Win/Lose
    private func checkWinLoseConditions() {
        if objective.current >= objective.required {
            isLevelCompleted = true
        } else if let moves = movesLeft, moves <= 0 {
            isGameOver = true
            loseLife()
        } else if !grid.contains(where: { $0.type == .empty }) {
            isGameOver = true
            loseLife()
        }
    }
}
