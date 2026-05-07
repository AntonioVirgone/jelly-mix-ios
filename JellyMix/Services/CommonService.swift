//
//  CommonService.swift
//  JellyMix
//
//  Created by Antonio Virgone on 07/05/26.
//

import Foundation

// MARK: - API Error
/// Errori personalizzati per la gestione della rete
enum APIError: Error {
    case invalidURL
    case requestFailed
    case invalidResponse
    case decodingError
}

// MARK: - Common Service (Network Engine)
/// Gestisce la logica di rete generica per tutta l'app
enum CommonService {
    
    /// Metodo generico per eseguire chiamate GET
    /// - Parameters:
    ///   - urlString: L'indirizzo dell'endpoint
    ///   - type: Il tipo di dato che ci aspettiamo (deve essere Decodable)
    /// - Returns: L'oggetto decodificato del tipo richiesto
    static func fetch<T: Decodable>(from urlString: String) async throws -> T {
        // Validazione URL
        guard let url = URL(string: urlString) else {
            throw APIError.invalidURL
        }
        
        // Configurazione richiesta
        let request = URLRequest(url: url, timeoutInterval: 10)
        
        // Esecuzione chiamata
        let (data, response) = try await URLSession.shared.data(for: request)
        
        // Validazione risposta HTTP
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.invalidResponse
        }
        
        // Decodifica JSON
        do {
            let decodedData = try JSONDecoder().decode(T.self, from: data)
            return decodedData
        } catch {
            print("Decoding Error: \(error)")
            throw APIError.decodingError
        }
    }
}
