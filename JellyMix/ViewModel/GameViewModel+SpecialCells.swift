//
//  GameViewModel+SpecialCells.swift
//  JellyMix
//

import Foundation

extension GameViewModel {

    // MARK: - Conveyor Belts

    func processConveyors() {
        guard !cellTypes.isEmpty else { return }

        // Tracks which destination cells received a piece this turn — prevents double-moving
        var movedToIndices = Set<Int>()

        // Process each direction with the order that enables correct chaining
        for direction in [Direction.left, .right, .up, .down] {
            var indices = cellTypes.indices.filter { cellTypes[$0] == .conveyor(direction) }

            // Sort so the "leading edge" pieces move first, creating space for pieces behind
            switch direction {
            case .left:  indices.sort { $0 % gridSize < $1 % gridSize }   // ascending col
            case .right: indices.sort { $0 % gridSize > $1 % gridSize }   // descending col
            case .up:    indices.sort { $0 / gridSize < $1 / gridSize }   // ascending row
            case .down:  indices.sort { $0 / gridSize > $1 / gridSize }   // descending row
            }

            for idx in indices {
                guard grid[idx].type != .empty else { continue }
                guard !movedToIndices.contains(idx) else { continue }  // piece just landed here

                let r = idx / gridSize
                let c = idx % gridSize
                let delta = direction.delta
                let newR = r + delta.row
                let newC = c + delta.col

                guard newR >= 0 && newR < gridSize && newC >= 0 && newC < gridSize else { continue }

                let newIdx = getIndex(row: newR, col: newC)

                guard grid[newIdx].type == .empty else { continue }
                guard newIdx < cellTypes.count && !cellTypes[newIdx].isGenerator else { continue }

                grid[newIdx] = grid[idx]
                grid[idx] = Jelly(type: .empty)
                movedToIndices.insert(newIdx)
            }
        }
    }

    // MARK: - Generators

    func processGenerators() {
        guard !generatorCounters.isEmpty else { return }

        for idx in generatorCounters.keys {
            generatorCounters[idx, default: 0] += 1

            guard let counter = generatorCounters[idx], counter >= 3 else { continue }
            guard let output = cellTypes[idx].generatorOutput else { continue }

            generatorCounters[idx] = 0
            spawnFromGenerator(at: idx, generates: output)
        }
    }

    private func spawnFromGenerator(at generatorIdx: Int, generates: ElementType) {
        let r = generatorIdx / gridSize
        let c = generatorIdx % gridSize

        // Priority order: up, right, down, left
        let neighbors: [(row: Int, col: Int)] = [
            (r - 1, c), (r, c + 1), (r + 1, c), (r, c - 1)
        ]

        // 1. Try to find an empty adjacent cell
        for (nr, nc) in neighbors {
            guard nr >= 0 && nr < gridSize && nc >= 0 && nc < gridSize else { continue }
            let targetIdx = getIndex(row: nr, col: nc)
            guard grid[targetIdx].type == .empty && !cellTypes[targetIdx].isGenerator else { continue }
            grid[targetIdx].type = generates
            return
        }

        // 2. All adjacent cells occupied: push one to make room
        for (nr, nc) in neighbors {
            guard nr >= 0 && nr < gridSize && nc >= 0 && nc < gridSize else { continue }
            let neighborIdx = getIndex(row: nr, col: nc)

            // Don't push fixed obstacles (treasure, waffle, ice) or other generators
            let neighborType = grid[neighborIdx].type
            guard !cellTypes[neighborIdx].isGenerator else { continue }
            guard neighborType != .treasure && neighborType != .waffle else { continue }

            // Direction of the push: away from the generator
            let pushDR = nr - r
            let pushDC = nc - c
            let pushR = nr + pushDR
            let pushC = nc + pushDC

            if pushR < 0 || pushR >= gridSize || pushC < 0 || pushC >= gridSize {
                // Off-grid: destroy the piece
                grid[neighborIdx] = Jelly(type: .empty)
            } else {
                let pushIdx = getIndex(row: pushR, col: pushC)
                guard grid[pushIdx].type == .empty && !cellTypes[pushIdx].isGenerator else { continue }
                grid[pushIdx] = grid[neighborIdx]
                grid[neighborIdx] = Jelly(type: .empty)
            }

            grid[neighborIdx].type = generates
            return
        }
        // If no push was possible, skip this spawn
    }
}
