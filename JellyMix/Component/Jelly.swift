//
//  Jelly.swift
//  JellyMix
//
//  Created by Antonio Virgone on 21/04/26.
//

import Foundation
// Jelly.swift
import SwiftUI

// MARK: - Modello Dati

// Stato dinamico di una singola gelatina (o ostacolo) sulla griglia
struct Jelly: Identifiable, Equatable {
    let id = UUID() // Fondamentale per SwiftUI per tracciare ogni singolo oggetto
    var type: ElementType
    var isDirty: Bool = false
    
    // Proprietà calcolata per ottenere il requisito di merge per un livello (da 1 a 6)
    var requirement: Int {
        // Mappatura dei requisiti di fusione (per ora fissa)
        // Livello 1 -> unisci 2, Livello 2 -> unisci 3, ecc.
        let mergeRequirements: [Int: Int] = [1: 2, 2: 3, 3: 4, 4: 5, 5: 6, 6: 7]
        return mergeRequirements[type.rawValue] ?? 0
    }
}

// Enum che definisce tutti i tipi di elementi possibili e la loro rappresentazione visiva
enum ElementType: Int, Equatable {
    // Ostacoli (valori negativi)
    case honey = -5
    case licorice = -4
    case brokenWaffle = -3
    case waffle = -2
    case ice = -1
    // Gelatine (valori da 0 a 7)
    case rainbow = 0
    case red = 1
    case blue = 2
    case green = 3
    case orange = 4
    case yellow = 5
    case brown = 6
    case black = 7
    case empty = 99 // Placeholder per cella vuota
    
    var displayName: String {
        switch self {
        case .red: return "Rossa"
        case .blue: return "Blu"
        case .green: return "Verde"
        case .orange: return "Arancione"
        case .yellow: return "Gialla"
        case .brown: return "Viola"
        case .black: return "Nera"
        case .rainbow: return "Arcobaleno"
        default: return ""
        }
    }

    // Assegnazione dei colori visivi nativi di SwiftUI per il rendering
    var color: Color {
        switch self {
        case .empty: return Color.gray.opacity(0.15) // Vuoto
        case .ice: return Color.cyan.opacity(0.5)   // Ghiaccio
        case .red: return .red
        case .blue: return .blue
        case .green: return .green
        case .orange: return .orange
        case .yellow: return .yellow
        case .brown: return .purple // Marrone temporaneo
        case .black: return .black
        default: return .clear
        }
    }
}
