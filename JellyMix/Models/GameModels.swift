//
//  GameModels.swift
//  JellyMix
//
//  Created by Antonio Virgone on 22/04/26.
//

import Foundation

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
