# Guida Integrazione Mobile — Step 1: Utente e Autenticazione
> JellyMix · Backend NestJS · Versione API: v1
> Destinatario: developer mobile (iOS)

---

## Indice

1. [Base URL e Swagger](#1-base-url-e-swagger)
2. [Autenticazione Firebase — come ottenere il token](#2-autenticazione-firebase)
3. [Come inviare richieste autenticate](#3-richieste-autenticate)
4. [Endpoint disponibili in Step 1](#4-endpoint-step-1)
5. [Flusso completo primo avvio](#5-flusso-primo-avvio)
6. [Sistema cuori — logica client](#6-sistema-cuori)
7. [Gestione errori](#7-gestione-errori)

---

## 1. Base URL e Swagger

| Ambiente | Base URL |
|---|---|
| Locale | `http://localhost:3004/api/v1` |
| Produzione | `https://<dominio>/api/v1` |

**Swagger UI interattivo:** `<base>/docs`
**Spec OpenAPI JSON:** `<base>/docs-json` (o il file `swagger-spec.json` allegato a questa guida)

> Il file `swagger-spec.json` nella root del progetto è sempre aggiornato all'ultimo deploy.

---

## 2. Autenticazione Firebase

Il backend usa **Firebase Auth** per verificare l'identità degli utenti. Il client ottiene un **ID Token JWT** da Firebase e lo passa in ogni richiesta autenticata.

### 2.1 Setup Firebase nel client iOS

```swift
// Aggiungi al Podfile:
// pod 'FirebaseAuth'

import FirebaseAuth

// Crea account anonimo al primo avvio (zero friction)
func signInAnonymously() async throws {
    let result = try await Auth.auth().signInAnonymously()
    print("UID:", result.user.uid)
}
```

### 2.2 Ottenere l'ID Token

L'ID Token scade ogni **1 ora**. Firebase SDK lo rinnova automaticamente — usa sempre `getIDToken(forcingRefresh: false)` che restituisce il token valido o ne ottiene uno nuovo se scaduto.

```swift
func getIdToken() async throws -> String {
    guard let user = Auth.auth().currentUser else {
        throw AuthError.notLoggedIn
    }
    return try await user.getIDToken(forcingRefresh: false)
}
```

> **Non cachare il token manualmente.** Usa sempre `getIDToken()` prima di ogni chiamata API.

---

## 3. Richieste Autenticate

Tutti gli endpoint richiedono il token tranne quelli esplicitamente pubblici (vedi tabella al §4).

### Header obbligatorio

```
Authorization: Bearer <ID_TOKEN_FIREBASE>
```

### Esempio Swift (URLSession)

```swift
func makeAuthenticatedRequest(url: URL, method: String = "GET", body: Data? = nil) async throws -> Data {
    var request = URLRequest(url: url)
    request.httpMethod = method
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

    // Sempre fresco
    let token = try await getIdToken()
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

    if let body { request.httpBody = body }

    let (data, response) = try await URLSession.shared.data(for: request)

    guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
    if http.statusCode == 401 { throw APIError.unauthorized }
    if http.statusCode >= 400 { throw APIError.serverError(http.statusCode, data) }

    return data
}
```

### Risposta 401 — Token scaduto o mancante

```json
{ "statusCode": 401, "message": "Token mancante" }
{ "statusCode": 401, "message": "Token non valido o scaduto" }
```

Se ricevi 401, forza il refresh del token con `getIDToken(forcingRefresh: true)` e ritenta la richiesta.

---

## 4. Endpoint Step 1

### Legenda Auth
- ✅ **Richiede Firebase ID Token** nell'header `Authorization`
- ❌ **Pubblico** — nessun token necessario

---

### 4.1 Profilo Utente

#### `GET /api/v1/users/me` ✅
Restituisce il profilo completo dell'utente autenticato. Il record viene **creato automaticamente** al primo accesso (upsert sull'`AuthGuard`) — non è necessario un endpoint di registrazione separato.

**Response:**
```json
{
  "id": "uuid",
  "playerNumber": 1234,
  "displayName": "Player#1234",
  "username": null,
  "avatarCode": null,
  "heartsCount": 5,
  "maxHearts": 5,
  "lastHeartConsumedAt": null,
  "gdprConsentAt": null,
  "createdAt": "2026-05-15T10:00:00.000Z"
}
```

> `displayName` è null finché l'utente non lo imposta — il client deve mostrare il fallback `Player#\(playerNumber)`.

---

#### `PATCH /api/v1/users/me` ✅
Aggiorna displayName, username e/o avatarCode. Tutti i campi sono opzionali.

**Request body:**
```json
{
  "displayName": "Pippo",
  "username": "pippo_gioca",
  "avatarCode": "avatar_03"
}
```

**Vincoli username:**
- Lowercase, solo lettere/numeri/underscore
- 3–20 caratteri
- Univoco globalmente (409 se già in uso)

**Response:** stesso schema di `GET /users/me`

**Errori:**
```json
{ "statusCode": 409, "message": "Username già in uso" }
{ "statusCode": 400, "message": "username deve essere lowercase, 3-20 caratteri, solo lettere/numeri/underscore" }
```

---

#### `GET /api/v1/users/{id}/profile` ❌ (pubblico)
Profilo pubblico di un altro utente, da usare per deep link condivisi.

```
GET /api/v1/users/abc-uuid-123/profile
```

**Response:**
```json
{
  "id": "abc-uuid-123",
  "playerNumber": 42,
  "displayName": "Pippo",
  "avatarCode": "avatar_03"
}
```

---

#### `GET /api/v1/users/search?username=pippo` ✅
Ricerca utenti per username (match parziale, case-insensitive). Restituisce max 10 risultati. Usato per la funzione "aggiungi amico".

```
GET /api/v1/users/search?username=pip
```

**Response:** array di profili pubblici
```json
[
  { "id": "...", "playerNumber": 42, "displayName": "Pippo", "avatarCode": "avatar_03" }
]
```

---

### 4.2 Configurazione Cuori

#### `GET /api/v1/app-config/hearts` ❌ (pubblico)
Parametri server per il sistema cuori. Da chiamare all'avvio dell'app e cachare localmente.

**Response:**
```json
{
  "heartRechargeMinutes": 5,
  "maxHearts": 5,
  "maxHeartsReceivedPerDay": 10
}
```

---

### 4.3 Device Token (Notifiche Push)

#### `POST /api/v1/notifications/register` ✅
Registra il token FCM associandolo all'utente autenticato. Da chiamare dopo il login Firebase e dopo ogni aggiornamento del token FCM.

**Request body:**
```json
{
  "token": "fcm-device-token-string",
  "platform": "ios"
}
```

**Response:** `201` con il record creato/aggiornato.

---

#### `DELETE /api/v1/notifications/token/{token}` ❌ (pubblico)
Rimuovi un token FCM. Da chiamare al logout per non ricevere più notifiche.

```
DELETE /api/v1/notifications/token/fcm-device-token-string
```

**Response:** `204 No Content`

---

### 4.4 Contenuto di Gioco (tutti pubblici ❌)

Questi endpoint non richiedono autenticazione — i dati di gioco sono pubblici.

| Metodo | Path | Descrizione |
|---|---|---|
| `GET` | `/api/v1/worlds` | Lista mondi pubblicati |
| `GET` | `/api/v1/worlds/{id}` | Dettaglio mondo |
| `GET` | `/api/v1/levels` | Lista livelli pubblicati |
| `GET` | `/api/v1/levels/{id}` | Dettaglio livello |

---

## 5. Flusso Primo Avvio

```
App avviata
    │
    ▼
Firebase.signInAnonymously()
    │
    ├── (se già loggato: skip, usa utente esistente)
    │
    ▼
GET /api/v1/users/me  ← crea automaticamente il record User
    │
    ▼
GET /api/v1/app-config/hearts  ← scarica config cuori (cacheala)
    │
    ▼
POST /api/v1/notifications/register  ← registra FCM token
    │
    ▼
GET /api/v1/worlds  ← carica i contenuti di gioco
```

**Note importanti:**
- Il record `User` **si crea automaticamente** alla prima chiamata autenticata — non esiste un endpoint `POST /users/register`.
- `playerNumber` viene assegnato in modo permanente al momento della creazione — non cambia mai.
- `lastSeenAt` viene aggiornato automaticamente ad ogni richiesta autenticata.

---

## 6. Sistema Cuori — Logica Client

La ricarica cuori è **calcolata lato client** per evitare polling continuo sul server. Il server è autoritativo solo per i cuori scambiati tra amici (Step 4).

### Calcolo cuori correnti

```swift
struct HeartState {
    let heartsCount: Int          // da GET /users/me
    let maxHearts: Int            // da GET /app-config/hearts
    let rechargeMinutes: Int      // da GET /app-config/hearts
    let lastHeartConsumedAt: Date? // da GET /users/me

    var currentHearts: Int {
        guard let consumed = lastHeartConsumedAt else {
            return heartsCount  // mai consumato un cuore
        }
        let minutesPassed = Int(Date().timeIntervalSince(consumed) / 60)
        let recharged = minutesPassed / rechargeMinutes
        return min(maxHearts, heartsCount + recharged)
    }

    var minutesToNextHeart: Int? {
        guard currentHearts < maxHearts,
              let consumed = lastHeartConsumedAt else { return nil }
        let minutesPassed = Int(Date().timeIntervalSince(consumed) / 60)
        return rechargeMinutes - (minutesPassed % rechargeMinutes)
    }
}
```

### Quando aggiornare i dati server

- **All'avvio**: `GET /users/me` + `GET /app-config/hearts`
- **Dopo un livello perso**: chiamare `POST /hearts/consume` (Step 4, non ancora disponibile) — per ora decrementare localmente
- **Dopo aver ricevuto un cuore da amico**: `GET /users/me` per aggiornare `heartsCount` (Step 4)

> In Step 1 il server non ha ancora l'endpoint per consumare cuori — il client può gestirlo localmente e sincronizzarlo in Step 4.

---

## 7. Gestione Errori

| Status Code | Significato | Azione consigliata |
|---|---|---|
| `400` | Validazione fallita — vedi `message` | Mostra il messaggio all'utente |
| `401` | Token mancante o scaduto | Forza `getIDToken(forcingRefresh: true)` e ritenta |
| `404` | Risorsa non trovata | Mostra errore generico |
| `409` | Conflitto (es. username già in uso) | Chiedi username diverso |
| `500` | Errore server interno | Mostra errore generico, retry dopo delay |

### Schema errore standard

```json
{
  "statusCode": 400,
  "message": "Descrizione dell'errore",
  "error": "Bad Request"
}
```

---

## Allegati

- **`swagger-spec.json`** — Spec OpenAPI completa, importabile in Postman, Insomnia, o qualsiasi client REST.

Per importare in **Postman**: File → Import → seleziona `swagger-spec.json` → vengono create automaticamente tutte le request con i parametri corretti.

---

## Prossimi Step (per pianificazione)

| Step | Funzionalità | Nuovi endpoint |
|---|---|---|
| Step 2 | Progresso di gioco | `POST /progress`, `GET /progress/me` |
| Step 3 | Amicizie | `POST /friendships/invite`, `GET /friendships`, ecc. |
| Step 4 | Sistema cuori completo | `POST /hearts/consume`, `POST /hearts/send/:id`, ecc. |
| Step 5 | GDPR | `DELETE /users/me`, `GET /users/me/export` |
