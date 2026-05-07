//
//  LevelModels.swift
//  JellyMix
//
//  Created by Antonio Virgone on 22/04/26.
//

import Foundation

// La root dell'API è un array diretto di WorldData
typealias WorldCollection = [WorldData]

struct WorldData: Codable, Identifiable {
    let id: String
    let name: String
    let description: String?
    let stageNumber: Int
    let color: String
    let icon: String
    let status: String
    let isActive: Bool
    let createdAt: String?
    let updatedAt: String?
    let levels: [LevelData]
}

struct LevelData: Codable {
    let id: String
    let levelNumber: Int
    let movesLimit: Int?
    let status: String?
    let objective: ObjectiveData
    let grid: [[String]]
    let availablePieces: [AvailablePieceData]
    let worldId: String?
    let createdAt: String?
    let updatedAt: String?
}

struct ObjectiveData: Codable {
    let type: String
    let targetColor: String?
    let required: Int
}

struct AvailablePieceData: Codable {
    let type: String
    let point: Int?
}

extension AvailablePieceData {
    var elementType: ElementType {
        switch type.uppercased() {
        // English identifiers (new format)
        case "RED":    return .red
        case "BLUE":   return .blue
        case "GREEN":  return .green
        case "ORANGE": return .orange
        case "YELLOW": return .yellow
        case "PURPLE": return .purple
        // Italian identifiers (backward compatibility)
        case "ROSSO":    return .red
        case "BLU":      return .blue
        case "VERDE":    return .green
        case "ARANCIONE": return .orange
        case "GIALLO":   return .yellow
        case "VIOLA":    return .purple
        default:         return .empty
        }
    }
}
