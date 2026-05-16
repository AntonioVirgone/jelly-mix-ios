# Guida Integrazione Mobile — Step 3: Sistema Amicizie
> JellyMix · Backend NestJS · Versione API: v1
> Prerequisito: Step 2 integrato

---

## Cosa cambia rispetto allo Step 2

### Nuovi endpoint

| Metodo | Path | Auth | Descrizione |
|---|---|---|---|
| `POST` | `/api/v1/friendships/invite` | ✅ | Genera codice invito (scadenza 7 giorni) |
| `POST` | `/api/v1/friendships/accept-invite/:code` | ✅ | Accetta invito via codice → amicizia ACCEPTED |
| `POST` | `/api/v1/friendships/request/:userId` | ✅ | Invia richiesta amicizia (crea PENDING) |
| `POST` | `/api/v1/friendships/accept/:id` | ✅ | Accetta richiesta PENDING |
| `POST` | `/api/v1/friendships/reject/:id` | ✅ | Rifiuta richiesta PENDING |
| `GET` | `/api/v1/friendships` | ✅ | Lista amici confermati |
| `GET` | `/api/v1/friendships/pending` | ✅ | Richieste ricevute in attesa |
| `DELETE` | `/api/v1/friendships/:id` | ✅ | Rimuovi amico |

### Endpoint aggiornato

| Metodo | Path | Descrizione |
|---|---|---|
| `GET` | `/api/v1/users/me/friends-progress` | Non più stub — restituisce progressi reali degli amici |

### Notifiche push attive da questo step

| Evento | Ricevuta da | `data.type` |
|---|---|---|
| Richiesta amicizia inviata (Metodo B) | Receiver | `FRIEND_REQUEST` |
| Richiesta amicizia accettata | Initiator | `FRIEND_ACCEPTED` |

---

## 1. Due metodi di aggiunta amici

### Metodo A — Link/Codice (zero friction, consigliato)

L'utente genera un codice e lo condivide via qualsiasi canale. Chi riceve il link diventa amico direttamente, senza passare per PENDING.

```
Utente A → POST /friendships/invite
         ← { code: "clxyz123abc", expiresAt: "2026-05-23T..." }

Deep link: jellymix://invite/clxyz123abc

Utente B apre il link → POST /friendships/accept-invite/clxyz123abc
                      ← { id: "...", status: "ACCEPTED", friend: { ... } }
```

### Metodo B — Ricerca username (con pending)

```
Utente A cerca B → GET /users/search?username=pippo
                 ← [{ id: "uuid-B", displayName: "Pippo", ... }]

Utente A invia richiesta → POST /friendships/request/uuid-B
                         ← { id: "uuid-friendship", status: "PENDING", ... }
                         → Push a B: "Player A vuole essere tuo amico"

Utente B vede richieste → GET /friendships/pending
                        ← [{ id: "uuid-friendship", status: "PENDING", friend: { ... } }]

Utente B accetta → POST /friendships/accept/uuid-friendship
                 ← { id: "...", status: "ACCEPTED", friend: { ... } }
                 → Push a A: "Pippo ha accettato la tua richiesta"
```

---

## 2. Schema risposta Friendship

Tutti gli endpoint che restituiscono una friendship usano questo schema:

```json
{
  "id": "uuid-della-friendship",
  "status": "ACCEPTED",
  "createdAt": "2026-05-16T08:00:00.000Z",
  "friend": {
    "id": "uuid-dell-amico",
    "playerNumber": 42,
    "displayName": "Pippo",
    "avatarCode": "avatar_03"
  }
}
```

> `friend` è sempre l'**altro** utente, non quello autenticato — il mapping è trasparente indipendentemente da chi ha iniziato l'amicizia.

---

## 3. Endpoint dettaglio

### POST /api/v1/friendships/invite ✅

Genera un codice con scadenza 7 giorni. Un utente può generare più codici (ognuno è monouso).

**Response `201`:**
```json
{
  "code": "clxyz123abc",
  "expiresAt": "2026-05-23T08:00:00.000Z"
}
```

**Deep link da costruire nel client:**
```swift
let deepLink = "jellymix://invite/\(response.code)"
// Condividi via UIActivityViewController
```

---

### POST /api/v1/friendships/accept-invite/:code ✅

Il client intercetta il deep link e chiama questo endpoint.

```
POST /api/v1/friendships/accept-invite/clxyz123abc
```

**Errori:**
```json
{ "statusCode": 404, "message": "Codice invito non valido" }
{ "statusCode": 409, "message": "Codice invito già utilizzato" }
{ "statusCode": 400, "message": "Codice invito scaduto" }
{ "statusCode": 409, "message": "Siete già amici" }
```

---

### POST /api/v1/friendships/request/:userId ✅

```
POST /api/v1/friendships/request/uuid-dell-utente-B
```

**Errori:**
```json
{ "statusCode": 400, "message": "Non puoi aggiungere te stesso" }
{ "statusCode": 404, "message": "Utente non trovato" }
{ "statusCode": 409, "message": "Siete già amici" }
{ "statusCode": 409, "message": "Esiste già una richiesta di amicizia in attesa" }
```

> La guard di simmetria blocca sia i duplicati che le richieste incrociate (A chiede B dopo che B ha già chiesto A).

---

### POST /api/v1/friendships/accept/:id ✅ — `200`

```
POST /api/v1/friendships/accept/uuid-friendship
```

Solo il **receiver** può accettare. Risponde `200` (non 201) con la friendship aggiornata.

**Errori:**
```json
{ "statusCode": 403, "message": "Non puoi accettare questa richiesta" }
{ "statusCode": 409, "message": "Richiesta non in stato PENDING" }
```

---

### POST /api/v1/friendships/reject/:id ✅ — `204`

```
POST /api/v1/friendships/reject/uuid-friendship
```

Solo il **receiver** può rifiutare. Risponde `204 No Content`.

---

### GET /api/v1/friendships ✅

Lista di tutti gli amici con status `ACCEPTED`, ordinati per data di amicizia decrescente.

**Response `200`:** array di `FriendshipResponseDto`

---

### GET /api/v1/friendships/pending ✅

Lista delle richieste **ricevute** in attesa. Non include le richieste inviate dall'utente.

**Response `200`:** array di `FriendshipResponseDto` con `status: "PENDING"`

---

### DELETE /api/v1/friendships/:id ✅ — `204`

Rimuove un amico confermato. Entrambi i membri dell'amicizia possono rimuoverla.

```
DELETE /api/v1/friendships/uuid-friendship
```

**Errori:**
```json
{ "statusCode": 403, "message": "Non puoi rimuovere questa amicizia" }
{ "statusCode": 409, "message": "Amicizia non in stato ACCEPTED" }
```

---

## 4. GET /api/v1/users/me/friends-progress ✅ (ora reale)

Restituisce il progresso di tutti gli amici confermati. Non più stub.

**Response `200`:**
```json
{
  "friends": [
    {
      "friendId": "uuid-amico",
      "displayName": "Pippo",
      "avatarCode": "avatar_03",
      "currentStageNumber": 2,
      "worlds": [
        {
          "worldId": "uuid-mondo",
          "worldName": "Oceano Colorato",
          "stageNumber": 1,
          "worldIcon": "🌊",
          "isWorldComplete": true,
          "currentLevel": {
            "levelNumber": 20,
            "levelIndex": 19
          }
        }
      ]
    }
  ]
}
```

Se l'utente non ha amici: `{ "friends": [] }`

---

## 5. Notifiche push ricevute

Da questo step il client riceverà notifiche di tipo sociale. Gestiscile nel notification handler:

```swift
// In UNUserNotificationCenterDelegate o Firebase messaging handler:
func handleNotification(data: [String: String]) {
    switch data["type"] {
    case "FRIEND_REQUEST":
        let friendshipId = data["friendshipId"] ?? ""
        // Mostra badge/alert "Hai una nuova richiesta di amicizia"
        // Naviga a /friendships/pending al tap

    case "FRIEND_ACCEPTED":
        let friendshipId = data["friendshipId"] ?? ""
        // Mostra "Il tuo amico ha accettato la richiesta"
        // Aggiorna lista amici

    default:
        break
    }
}
```

---

## 6. Flusso consigliato all'avvio (aggiornato)

```
Firebase login
    │
    ├── GET /users/me
    ├── GET /progress/me
    ├── GET /app-config/hearts
    ├── GET /worlds
    └── GET /friendships             ← NUOVO: carica lista amici
        GET /friendships/pending     ← NUOVO: badge richieste in attesa
        GET /users/me/friends-progress  ← NUOVO: feed amici
```

Le chiamate possono essere eseguite in parallelo dopo il login.

---

## 7. Gestione deep link (Metodo A)

```swift
// In SceneDelegate o App:
func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    guard let url = URLContexts.first?.url,
          url.scheme == "jellymix",
          url.host == "invite",
          let code = url.pathComponents.last else { return }

    Task {
        do {
            let friendship = try await api.acceptInvite(code: code)
            // Mostra "Ora sei amico di \(friendship.friend.displayName)!"
            // Refresh lista amici
        } catch APIError.conflict(let msg) {
            // "Siete già amici" o "Codice già utilizzato"
            showAlert(msg)
        } catch APIError.badRequest(let msg) {
            // "Codice scaduto"
            showAlert(msg)
        }
    }
}
```

---

## Allegati

- **`swagger-spec-step3.json`** — Spec OpenAPI aggiornata con tutti gli endpoint Step 1 + 2 + 3. Reimporta in Postman.
