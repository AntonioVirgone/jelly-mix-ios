//
//  LevelService.swift
//  JellyMix
//

import Foundation

enum WorldService {

    static func fetchWorlds() async throws -> WorldCollection {
        return try await CommonService.fetch(from: "worlds")
    }

    // Riprova fino a maxAttempts volte con timeout esteso e delay progressivi.
    // Il timeout lungo (60s) copre il cold start di Render.com (~30-50s).
    // I delay crescenti lasciano al server il tempo di scaldarsi tra un tentativo e l'altro.
    static func fetchWorldsWithRetry(maxAttempts: Int = 3) async throws -> WorldCollection {
        // Delay progressivi: 10s → 20s tra i tentativi
        let delays: [TimeInterval] = [10, 20]
        var lastError: Error = APIError.requestFailed

        for attempt in 1...maxAttempts {
            do {
                return try await CommonService.fetch(from: "worlds", timeoutInterval: 60)
            } catch {
                lastError = error
                print("[LevelService] Tentativo \(attempt)/\(maxAttempts) fallito: \(error.localizedDescription)")
                if attempt < maxAttempts {
                    let delay = delays[min(attempt - 1, delays.count - 1)]
                    print("[LevelService] Prossimo tentativo tra \(Int(delay))s...")
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }
        throw lastError
    }

    static func loadFromBundle() throws -> WorldCollection {
        guard let url = Bundle.main.url(forResource: "worlds", withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile)
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(WorldCollection.self, from: data)
    }
}
