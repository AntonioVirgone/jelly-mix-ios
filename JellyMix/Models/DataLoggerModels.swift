//
//  DataLoggerModels.swift
//  JellyMix
//
//  Created by Antonio Virgone on 07/05/26.
//

import Foundation

struct DataLoggerModels: Codable {
    var appId: String
    var type: TypeDataLogger
}

enum TypeDataLogger: String, Codable {
    case install = "INSTALL"
    case playGame = "PLAY_GAME"
    case shop = "SHOP"
    case other = "OTHER"
}
