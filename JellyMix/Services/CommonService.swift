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
    case patch = "PATCH"    // Aggiunto per PATCH /api/v1/users/me (Step 1)
    case delete = "DELETE"
}

// Modello di utility per risposte vuote
struct EmptyResponse: Codable {}

// MARK: - Common Service (Network Engine)
/// Gestisce la logica di rete generica per tutta l'app.
/// In Step 1 è stato aggiunto il supporto per richieste autenticate via Firebase ID Token.
enum CommonService {
    private static let baseURL = "https://jelly-mix-api.onrender.com/api/v1"
//    private static let baseURL = "https://5d1d-62-211-170-228.ngrok-free.app/api/v1"

    /// Metodo universale per eseguire chiamate di rete.
    /// - Parameters:
    ///   - path: Percorso relativo al baseURL (o URL assoluto se contiene "http")
    ///   - method: Metodo HTTP (default .get)
    ///   - body: Body Encodable opzionale
    ///   - authenticated: Se true, inietta il Firebase ID Token nell'header Authorization
    ///   - timeoutInterval: Timeout in secondi (default 10)
    static func request<T: Decodable, E: Encodable>(
        from path: String,
        method: HTTPMethod = .get,
        body: E? = nil as Optional<Never>,
        authenticated: Bool = false,
        timeoutInterval: TimeInterval = 10
    ) async throws -> T {
        try await performRequest(
            path: path, method: method, body: body,
            authenticated: authenticated, timeoutInterval: timeoutInterval,
            isRetry: false
        )
    }

    static func fetch<T: Decodable>(from urlString: String, timeoutInterval: TimeInterval = 10) async throws -> T {
        try await request(from: urlString, method: .get, timeoutInterval: timeoutInterval)
    }

    // MARK: - Private

    /// Implementazione interna con gestione retry 401.
    /// isRetry: true indica un secondo tentativo con token forzatamente refreshato.
    private static func performRequest<T: Decodable, E: Encodable>(
        path: String,
        method: HTTPMethod,
        body: E?,
        authenticated: Bool,
        timeoutInterval: TimeInterval,
        isRetry: Bool
    ) async throws -> T {
        // Costruisce l'URL: se il path è assoluto lo usa direttamente, altrimenti prefissa il baseURL
        let fullURLString = path.contains("http") ? path : "\(baseURL)/\(path)"
        guard let url = URL(string: fullURLString) else { throw APIError.invalidURL }

        var urlRequest = URLRequest(url: url, timeoutInterval: timeoutInterval)
        urlRequest.httpMethod = method.rawValue
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let body {
            urlRequest.httpBody = try JSONEncoder().encode(body)
        }

        // Inietta il Bearer token per gli endpoint autenticati.
        // isRetry=true forza il refresh del token (usato dopo un 401).
        if authenticated {
            let token = try await AuthService.shared.getIdToken(forcingRefresh: isRetry)
            urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }

        // 401: il token potrebbe essere scaduto — forza refresh e riprova una sola volta
        if http.statusCode == 401 && authenticated && !isRetry {
            return try await performRequest(
                path: path, method: method, body: body,
                authenticated: true, timeoutInterval: timeoutInterval,
                isRetry: true
            )
        }

        guard (200...299).contains(http.statusCode) else { throw APIError.invalidResponse }

        // Gestisce risposte vuote (es. 204 No Content) senza tentare il decode
        if T.self == EmptyResponse.self && (data.isEmpty || data.count <= 4) {
            return EmptyResponse() as! T
        }

        // ISO 8601 per decodificare i campi Date (createdAt, lastHeartConsumedAt, ecc.)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(T.self, from: data)
    }
}
