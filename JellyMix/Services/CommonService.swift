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
    case encodingError
}

// MARK: - HTTP Method
/// Definisce i metodi HTTP supportati
enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
}

// Modello di utility per risposte vuote
struct EmptyResponse: Codable {}

// MARK: - Common Service (Network Engine)
/// Gestisce la logica di rete generica per tutta l'app
enum CommonService {
    private static let baseURL = "https://jelly-mix-api.onrender.com/api/v1"

    /// Metodo universale per eseguire chiamate di rete
    /// - Parameters:
    ///   - urlString: L'indirizzo dell'endpoint
    ///   - method: Il metodo HTTP da utilizzare (default .get)
    ///   - body: Un oggetto Encodable da inviare (opzionale)
    /// - Returns: L'oggetto decodificato del tipo richiesto T
    static func request<T: Decodable, E: Encodable>(
        from path: String, // Ora accettiamo solo il path (es. "data-logger")
        method: HTTPMethod = .get,
        body: E? = nil as Optional<Never>
    ) async throws -> T {
        
        // Componiamo l'URL completo
        let fullURLString = path.contains("http") ? path : "\(baseURL)/\(path)"
        
        guard let url = URL(string: fullURLString) else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url, timeoutInterval: 10)
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let body = body {
            request.httpBody = try JSONEncoder().encode(body)
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.invalidResponse
        }
        
        // Se ci aspettiamo una risposta vuota e l'API non manda dati (o dati minimi)
        if T.self == EmptyResponse.self && (data.isEmpty || data.count <= 4) {
            return EmptyResponse() as! T
        }
        
        return try JSONDecoder().decode(T.self, from: data)
    }
    
    /// Metodo semplificato per il GET (per compatibilità con il codice esistente)
    static func fetch<T: Decodable>(from urlString: String) async throws -> T {
        // Chiamiamo il metodo principale passando Never come tipo del body
        return try await request(from: urlString, method: .get)
    }
}
