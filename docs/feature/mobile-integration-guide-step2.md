# Guida Integrazione Mobile — Step 2: Progresso di Gioco
> JellyMix · Backend NestJS · Versione API: v1
> Prerequisito: Step 1 integrato (Firebase Auth attivo)

---

## Cosa cambia rispetto allo Step 1

Sono disponibili due nuovi endpoint autenticati:

| Metodo | Path | Descrizione |
|---|---|---|
| `POST` | `/api/v1/progress` | Salva il progresso dopo ogni livello completato |
| `GET` | `/api/v1/progress/me` | Recupera il progresso completo dell'utente |

Aggiunto anche lo stub che verrà completato allo Step 3:

| Metodo | Path | Descrizione |
|---|---|---|
| `GET` | `/api/v1/users/me/friends-progress` | Progressi degli amici (ora restituisce `{ friends: [] }`) |

---

## 1. POST /api/v1/progress ✅

Da chiamare ogni volta che l'utente **completa un livello**. La risposta `200` contiene lo stato aggiornato dal punto di vista del server — **va letta**, non ignorata (vedi §1.3).

### Request

```
POST /api/v1/progress
Authorization: Bearer <ID_TOKEN_FIREBASE>
Content-Type: application/json
```

```json
{
  "worldId": "uuid-del-mondo",
  "levelId": "uuid-del-livello-completato",
  "isWorldComplete": false
}
```

| Campo | Tipo | Obbligatorio | Note |
|---|---|---|---|
| `worldId` | UUID | ✅ | ID del mondo corrente |
| `levelId` | UUID | ✅ | ID del livello appena completato |
| `isWorldComplete` | boolean | ❌ | `true` solo sull'ultimo livello del mondo |

### Response `200`

```json
{
  "worldId": "uuid-del-mondo",
  "worldName": "Oceano Colorato",
  "stageNumber": 1,
  "worldIcon": "🌊",
  "worldColor": "#4FC3F7",
  "isWorldComplete": false,
  "completedAt": null,
  "currentLevel": {
    "levelId": "uuid-livello",
    "levelNumber": 3,
    "levelIndex": 2
  }
}
```

### §1.3 — Perché leggere la risposta

Il body `200` riflette lo stato **autoritativo del server** dopo l'upsert. In particolare:
- Se il `levelIndex` inviato è **minore o uguale** a quello già salvato (chiamata in ritardo / retry), il server restituisce il progresso corrente **senza arretrare** — il client deve allinearsi al valore della risposta, non a quello che ha inviato.
- Se `isWorldComplete: true` viene ricevuto, il client ottiene `completedAt` compilato, utile per mostrare l'animazione di completamento mondo.

### Comportamento idempotente — importante per il client

Il server usa `levelIndex` per garantire che il progresso **non possa mai andare indietro**. Questo rende la chiamata sicura da:

- **Retry** su errore di rete
- **Sync offline** — se il device era offline e invia più progressi in batch, l'ordine non importa
- **Multi-device** — se l'utente gioca su due device, vince sempre il livello con `levelIndex` più alto

```
// Caso: device offline, invia in ritardo un livello già superato
POST /progress { levelId: "livello-5" }  // levelIndex 4, ma siamo già al levelIndex 7
→ Il server ignora il retrocesso e risponde con il progresso attuale (levelIndex 7)
```

### Quando passare `isWorldComplete: true`

Solo quando il client sa con certezza che il livello completato è l'ultimo del mondo (lo sa già dalla struttura dei livelli scaricata). Il server non calcola autonomamente il completamento.

```swift
let isLast = level.levelIndex == world.levels.max(by: { $0.levelIndex < $1.levelIndex })?.levelIndex
```

### Errori

```json
{ "statusCode": 404, "message": "World uuid non trovato" }
{ "statusCode": 400, "message": "Level uuid non trovato nel mondo uuid" }
{ "statusCode": 401, "message": "Token mancante" }
```

---

## 2. GET /api/v1/progress/me ✅

Recupera il progresso completo dell'utente su tutti i mondi sbloccati. Da chiamare all'avvio per sincronizzare lo stato tra device.

### Request

```
GET /api/v1/progress/me
Authorization: Bearer <ID_TOKEN_FIREBASE>
```

### Response `200`

```json
{
  "currentStageNumber": 2,
  "worlds": [
    {
      "worldId": "uuid-mondo-1",
      "worldName": "Oceano Colorato",
      "stageNumber": 1,
      "worldIcon": "🌊",
      "worldColor": "#4FC3F7",
      "isWorldComplete": true,
      "completedAt": "2026-05-10T14:30:00.000Z",
      "currentLevel": {
        "levelId": "uuid-ultimo-livello",
        "levelNumber": 20,
        "levelIndex": 19
      }
    },
    {
      "worldId": "uuid-mondo-2",
      "worldName": "Foresta Magica",
      "stageNumber": 2,
      "worldIcon": "🌳",
      "worldColor": "#66BB6A",
      "isWorldComplete": false,
      "completedAt": null,
      "currentLevel": {
        "levelId": "uuid-livello-corrente",
        "levelNumber": 7,
        "levelIndex": 6
      }
    }
  ]
}
```

| Campo | Note |
|---|---|
| `currentStageNumber` | `stageNumber` massimo raggiunto — utile per il feed amici. `null` se nessun progresso |
| `worlds` | Ordinati per `stageNumber` crescente |
| `currentLevel` | Ultimo livello completato nel mondo. `null` se il mondo è sbloccato ma nessun livello ancora completato |
| `isWorldComplete` | `true` se l'utente ha completato tutti i livelli del mondo |

---

## 3. GET /api/v1/users/me/friends-progress ✅ (stub)

Disponibile ma restituisce sempre lista vuota fino allo Step 3.

```
GET /api/v1/users/me/friends-progress
Authorization: Bearer <ID_TOKEN_FIREBASE>
```

```json
{ "friends": [] }
```

Integra pure l'endpoint ora — quando lo Step 3 sarà live, inizierà a restituire i progressi degli amici senza cambiamenti al path o al contratto.

---

## 4. Flusso consigliato all'avvio

```
App avviata
    │
    ▼
Firebase.signInAnonymously() (o utente già loggato)
    │
    ▼
GET /api/v1/users/me          ← profilo + cuori
    │
    ├── GET /api/v1/progress/me     ← progresso su tutti i mondi
    ├── GET /api/v1/app-config/hearts  ← parametri cuori (se non cachati)
    └── GET /api/v1/worlds          ← catalogo mondi
```

Le tre chiamate dopo il login possono essere fatte **in parallelo**.

---

## 5. Flusso completamento livello

```swift
// Dopo che l'utente completa un livello:
func onLevelCompleted(world: World, level: Level) async {
    let isLast = level.levelIndex == world.maxLevelIndex

    let body = ReportProgressBody(
        worldId: world.id,
        levelId: level.id,
        isWorldComplete: isLast
    )

    do {
        let entry = try await api.reportProgress(body)
        // Aggiorna UI con entry.currentLevel, entry.isWorldComplete
        if entry.isWorldComplete {
            // Mostra animazione completamento mondo
        }
    } catch APIError.notFound {
        // World o level non trovato — dati locali disallineati, forza refresh catalogo
        await refreshWorldsCatalog()
    }
}
```

---

## 6. Sincronizzazione multi-device

All'apertura dell'app su un secondo device (o dopo reinstallazione), `GET /progress/me` restituisce il progresso più avanzato salvato lato server.

Il client deve riconciliare il progresso locale con quello server scegliendo sempre il **più avanzato** per ogni mondo:

```swift
func reconcileProgress(local: [WorldProgress], server: MyProgressResponse) -> [WorldProgress] {
    var result = local
    for serverWorld in server.worlds {
        if let localIdx = result.firstIndex(where: { $0.worldId == serverWorld.worldId }) {
            let localLevelIndex = result[localIdx].currentLevel?.levelIndex ?? -1
            let serverLevelIndex = serverWorld.currentLevel?.levelIndex ?? -1
            if serverLevelIndex > localLevelIndex {
                result[localIdx] = WorldProgress(from: serverWorld)
            }
        } else {
            result.append(WorldProgress(from: serverWorld))
        }
    }
    return result
}
```

---

## Allegati

- **`swagger-spec-step2.json`** — Spec OpenAPI aggiornata con tutti gli endpoint Step 1 + Step 2. Reimporta in Postman per avere le nuove route.
