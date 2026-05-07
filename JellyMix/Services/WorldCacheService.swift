//
//  WorldCacheService.swift
//  JellyMix
//

import Foundation

enum WorldCacheService {

    private static let filename = "worlds_cache.json"

    // Salva i mondi scaricati dall'API in DocumentsDirectory.
    static func save(_ worlds: WorldCollection) throws {
        let data = try JSONEncoder().encode(worlds)
        try data.write(to: cacheURL(), options: .atomic)
    }

    // Legge la cache salvata su disco. Lancia errore se non esiste ancora.
    static func load() throws -> WorldCollection {
        let data = try Data(contentsOf: cacheURL())
        return try JSONDecoder().decode(WorldCollection.self, from: data)
    }

    // Gerarchia completa: cache disco → bundle (primo avvio / cache corrotta).
    static func loadBestAvailable() -> WorldCollection? {
        if let cached = try? load() { return cached }
        return try? LevelService.loadFromBundle()
    }

    private static func cacheURL() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(filename)
    }
}
