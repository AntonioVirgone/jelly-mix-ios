//
//  LevelService.swift
//  JellyMix
//

import Foundation

enum LevelService {

    // Sostituire con l'URL reale dell'API
    static let apiURL = URL(string: "https://api.example.com/levels")!

    // Timeout per la chiamata API (secondi)
    private static let timeoutInterval: TimeInterval = 10

    // Prova a caricare i livelli dall'API REST (GET).
    // Lancia un errore in caso di rete irraggiungibile, risposta non-2xx o JSON malformato.
    static func fetchFromAPI() async throws -> WorldCollection {
        var request = URLRequest(url: apiURL, timeoutInterval: timeoutInterval)
        request.httpMethod = "GET"

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }

        return try JSONDecoder().decode(WorldCollection.self, from: data)
    }

    // Carica i livelli dal file levels.json nel bundle dell'app.
    static func loadFromBundle() throws -> WorldCollection {
        guard let url = Bundle.main.url(forResource: "levels", withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile)
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(WorldCollection.self, from: data)
    }
}
