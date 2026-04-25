//
//  Jelly.swift
//  JellyMix
//
//  Created by Antonio Virgone on 21/04/26.
//

import Foundation
// Jelly.swift
import SwiftUI

// MARK: - Configurazione di un Elemento
// Questa struct contiene TUTTE le info di un elemento. Per aggiungere un nuovo pezzo in futuro, ti basterà configurare questo.
struct ElementConfig {
    var name: String
    var color: Color
    var requirement: Int // 0 per ostacoli
    var isObstacle: Bool
    var hasFace: Bool // True se vogliamo disegnare la faccina carina
    var requireKeys: Int? // serve per aprire le casse
}

// MARK: - Modello Dati
// Stato dinamico di una singola gelatina (o ostacolo) sulla griglia
struct Jelly: Identifiable, Equatable {
    let id = UUID() // Fondamentale per SwiftUI per tracciare ogni singolo oggetto
    var type: ElementType
    var isDirty: Bool = false
    var isFreeze: Bool = false // serve per bloccare il merge

    var requirement: Int { type.config.requirement }
}

// Enum che definisce tutti i tipi di elementi possibili e la loro rappresentazione visiva
enum ElementType: Int, Equatable, CaseIterable, Hashable {
    // Ostacoli (valori negativi)
    case treasure = -7
    case key = -8
    case honey = -5
    case licorice = -4
    case brokenWaffle = -3
    case waffle = -2
    case ice = -1
    // Speciali
    case rainbow = 0
    // Gelatine
    case red = 1, blue = 2, green = 3, orange = 4, yellow = 5, brown = 6, black = 7
    case empty = 99

    // IL CUORE DELLA SCALABILITÀ: Tutto è definito qui!
    var config: ElementConfig {
        switch self {
        case .empty:        return ElementConfig(name: "Vuoto", color: Color.gray.opacity(0.15), requirement: 0, isObstacle: false, hasFace: false)
        case .rainbow:      return ElementConfig(name: "Arcobaleno", color: .clear, requirement: 0, isObstacle: false, hasFace: true)
        
        // Gelatine
        case .red:          return ElementConfig(name: "Rossa", color: .red, requirement: 2, isObstacle: false, hasFace: true)
        case .blue:         return ElementConfig(name: "Blu", color: .blue, requirement: 3, isObstacle: false, hasFace: true)
        case .green:        return ElementConfig(name: "Verde", color: .green, requirement: 4, isObstacle: false, hasFace: true)
        case .orange:       return ElementConfig(name: "Arancione", color: .orange, requirement: 5, isObstacle: false, hasFace: true)
        case .yellow:       return ElementConfig(name: "Gialla", color: .yellow, requirement: 6, isObstacle: false, hasFace: true)
        case .brown:        return ElementConfig(name: "Viola", color: .purple, requirement: 7, isObstacle: false, hasFace: true)
        case .black:        return ElementConfig(name: "Nera", color: .black, requirement: Int.max, isObstacle: false, hasFace: true)
            
        // Ostacoli
        case .ice:          return ElementConfig(name: "Ghiaccio", color: Color.cyan.opacity(0.5), requirement: 0, isObstacle: true, hasFace: false)
        case .waffle:       return ElementConfig(name: "Waffle", color: Color.yellow.opacity(0.8), requirement: 0, isObstacle: true, hasFace: false)
        case .brokenWaffle: return ElementConfig(name: "Waffle Rotto", color: Color.orange.opacity(0.8), requirement: 0, isObstacle: true, hasFace: false)
        case .licorice:     return ElementConfig(name: "Liquirizia", color: .gray, requirement: 0, isObstacle: true, hasFace: false)
        case .honey:        return ElementConfig(name: "Miele", color: .yellow, requirement: 0, isObstacle: true, hasFace: false)
        case .treasure:     return ElementConfig(name: "Tesoto", color: .indigo, requirement: 0, isObstacle: true, hasFace: false, requireKeys: 1)
        case .key:          return ElementConfig(name: "Chiave", color: .yellow, requirement: 0, isObstacle: true, hasFace: false)
        }
    }
}
