//
//  LevelService.swift
//  JellyMix
//

import Foundation

enum LevelService {

    private static let baseURL = "https://jelly-mix-api.onrender.com/api/v1"
        
    /// Carica i mondi dall'API usando il motore centralizzato
    static func fetchWorlds() async throws -> WorldCollection {
        let endpoint = "\(baseURL)/worlds"
        // Chiamiamo il metodo generico specificando il tipo di ritorno atteso
        return try await CommonService.fetch(from: endpoint)
    }
    
    /// Esempio di caricamento locale (fallback)
    static func loadFromBundle() throws -> WorldCollection {
        guard let url = Bundle.main.url(forResource: "worlds", withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile)
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(WorldCollection.self, from: data)
    }
}
