//
//  LevelModels.swift
//  JellyMix
//
//  Created by Antonio Virgone on 22/04/26.
//

import Foundation

// Root del JSON ora punta ai Mondi
struct WorldCollection: Codable {
    let worlds: [WorldData]
}

// Struttura del Mondo
struct WorldData: Codable, Identifiable {
    let id: Int
    let name: String
    let color: String // Salviamo come stringa (es. "pink")
    let icon: String
    let levels: [LevelData]
}

// Dati del singolo Livello
struct LevelData: Codable {
    let level: Int
    let objective: ObjectiveData
    let movesLimit: Int?
    let grid: [[String]]
    let availablePieces: [AvailablePieceData]
}

// Obiettivo
struct ObjectiveData: Codable {
    let type: String
    let targetColor: String?
    let required: Int
}

// Pezzi disponibili dinamicamente
struct AvailablePieceData: Codable {
    let type: String
    let point: Int? // nil significa che è disponibile fin da subito (0 punti)
}

extension AvailablePieceData {
    var elementType: ElementType {
        switch type.uppercased() {
        case "ROSSO": return .red
        case "BLU": return .blue
        case "GREEN", "VERDE": return .green
        case "GIALLO": return .yellow
        default: return .empty
        }
    }
}
