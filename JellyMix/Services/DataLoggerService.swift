//
//  DataLoggerService.swift
//  JellyMix
//
//  Created by Antonio Virgone on 07/05/26.
//

import Foundation

enum DataLoggerService {
    /// Esempio di creazione di un nuovo livello (POST)
    static func createLevel(dataLogger: DataLoggerModels) async throws {
        let endpoint = "data-logger"
        let _: EmptyResponse = try await CommonService.request(from: endpoint, method: .post, body: dataLogger)
    }
}
