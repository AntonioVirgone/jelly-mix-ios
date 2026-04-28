//
//  GameModels.swift
//  JellyMix
//
//  Created by Antonio Virgone on 22/04/26.
//

import Foundation

// MARK: - Direzione nastro trasportatore
enum Direction: Equatable {
    case left, right, up, down

    var delta: (row: Int, col: Int) {
        switch self {
        case .left:  return (0, -1)
        case .right: return (0,  1)
        case .up:    return (-1, 0)
        case .down:  return (1,  0)
        }
    }

    var systemImage: String {
        switch self {
        case .left:  return "arrow.left"
        case .right: return "arrow.right"
        case .up:    return "arrow.up"
        case .down:  return "arrow.down"
        }
    }
}

// MARK: - Tipo di cella (strato fisso della griglia)
enum CellType: Equatable {
    case normal
    case conveyor(Direction)
    case generator(ElementType)

    var isGenerator: Bool {
        if case .generator = self { return true }
        return false
    }

    var generatorOutput: ElementType? {
        if case .generator(let t) = self { return t }
        return nil
    }

    var conveyorDirection: Direction? {
        if case .conveyor(let d) = self { return d }
        return nil
    }
}

// MARK: - Tipo di Obiettivo
enum ObjectiveType {
    case jelly
    case obstacle
    case licorice
}

// MARK: - Obiettivo del Livello
struct LevelObjective {
    var type: ObjectiveType
    var targetColor: ElementType
    var required: Int
    var current: Int = 0
}
