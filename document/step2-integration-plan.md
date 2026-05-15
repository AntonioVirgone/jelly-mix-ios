# Piano di Integrazione — Step 2: Progresso di Gioco
> JellyMix iOS · Analisi e piano di lavoro  
> Data: 2026-05-15

---

## Stato attuale del codebase

### Progresso locale — come funziona oggi

Il progresso è interamente gestito via **UserDefaults**, senza sincronizzazione server.

| Dato                  | Tipo Swift                  | Chiave UserDefaults        | Descrizione                                          |
|-----------------------|-----------------------------|----------------------------|------------------------------------------------------|
| `completedLevels`     | `Set<LevelCoordinate>`      | `"completedLevels"` (JSON) | Set di livelli completati, identificati per coord.   |
| `completedWorlds`     | `Set<Int>`                  | `"completedWorlds"` ([Int])| Set di stageNumber dei mondi interamente completati  |
| `score`               | `Int` (in GameViewModel)    | non persistito             | Solo durante la partita, si azzera al reset          |
| best score per livello| —                           | **non esiste**             | Non tracciato né localmente né su server             |

**`LevelCoordinate`** è il tipo chiave del progresso locale:
```swift
struct LevelCoordinate: Hashable, Codable {
    let stageNumber: Int   // Numero del mondo (1, 2, 3…)
    let levelIndex: Int    // Posizione del livello nel mondo (1-based)
}
```

### Flusso di sblocco livelli (`isUnlocked`)

```
stageNumber=1, levelIndex=1  → sempre sbloccato
levelIndex=1 (primo di un mondo) → richiede completedWorlds.contains(stageNumber-1)
completedWorlds.contains(stageNumber) → tutti i livelli del mondo sbloccati
altrimenti → completedLevels.contains(coord con levelIndex-1)
```

### Flusso di completamento livello (`completeLevel`)

```
completedLevels.insert(coord)
se tutti i livelli del mondo sono in completedLevels → completedWorlds.insert(stageNumber)
```

Tutto avviene in locale. In Step 2 dobbiamo aggiungere la sincronizzazione server.

---

## Analisi endpoint

### ⚠️ Problema critico: endpoint non presenti nello swagger

Lo swagger attuale (`swagger-spec.json`) **non contiene alcun endpoint `/progress`**.

Gli endpoint citati nella roadmap dello Step 1 sono:

```
POST /api/v1/progress         ← non esiste nello swagger
GET  /api/v1/progress/me      ← non esiste nello swagger
```

Questo blocca la pianificazione precisa dei modelli e del flusso. Vedi sezione **Domande aperte**.

### Endpoint esistenti utilizzabili

Il server fornisce gli ID UUID dei livelli tramite `GET /api/v1/worlds`:

```json
// LevelResponseDto (da swagger)
{
  "id": "uuid-1234",          // ID server univoco del livello
  "levelNumber": 1,           // Numero assoluto del livello
  "levelIndex": 1,            // Posizione nel mondo (1-based)
  "worldId": "uuid-world-5678" // ID del mondo padre
}
```

Questo è importante perché la chiave di progresso lato server sarà quasi certamente l'`id` UUID del livello, **non** `stageNumber + levelIndex`.

---

## Architettura proposta (da confermare con backend)

### Modello dati ipotizzato

```swift
// Body per POST /progress (da confermare)
struct ProgressUpdateBody: Encodable {
    let levelId: String     // UUID del livello completato
    let score: Int          // Punteggio ottenuto in questa partita
    let starsEarned: Int?   // Stelle (se il sistema stelle esiste)
}

// Risposta di GET /progress/me (da confermare)
struct UserProgress: Codable {
    let completedLevels: [LevelProgressEntry]
}

struct LevelProgressEntry: Codable {
    let levelId: String     // UUID del livello
    let bestScore: Int
    let completedAt: Date
}
```

### Mapping UUID ↔ LevelCoordinate

Il problema principale del design è che il progresso locale usa `LevelCoordinate(stageNumber, levelIndex)`, mentre il server usa UUID. 

Soluzione: quando i livelli sono caricati da `GET /api/v1/worlds`, `LevelData` contiene già l'`id` UUID (campo `id` nel `LevelResponseDto`). Dobbiamo aggiungere questo campo al modello locale `LevelData`:

```swift
// In LevelModels.swift — aggiungere campo id
struct LevelData: Codable {
    let id: String          // ← nuovo campo, UUID server
    let levelNumber: Int
    let levelIndex: Int
    // …resto invariato
}
```

Con questo campo disponibile, `completeLevel(stageNumber:levelIndex:)` può recuperare l'UUID e chiamare `POST /progress`.

---

## Piano di lavoro

### Task 1 — Ricevere swagger aggiornato con endpoint progress

**Dipendenza bloccante.** Senza la specifica degli endpoint non si può procedere con gli altri task. Serve conoscere:
- Struttura esatta di `POST /progress` (body e risposta)
- Struttura esatta di `GET /progress/me` (risposta)
- Se il server traccia best score o solo "completato/non completato"
- Se esiste il concetto di "stelle" (1-3 stelle per livello)

---

### Task 2 — Aggiungere `id: String` a `LevelData`

**File:** `Models/LevelModels.swift`

Aggiungere `id: String` al modello `LevelData` per avere l'UUID disponibile durante il gameplay.

```swift
struct LevelData: Codable {
    let id: String   // UUID server — usato per POST /progress
    let levelNumber: Int
    let levelIndex: Int
    // …resto invariato
}
```

Nessun impatto sui test esistenti (campo aggiuntivo opzionale in JSON).

---

### Task 3 — Modelli progresso

**File:** `Models/ProgressModels.swift` (nuovo)

Implementare i modelli Codable per request/response degli endpoint progress, sulla base della specifica ricevuta dal backend.

---

### Task 4 — `ProgressService`

**File:** `Services/ProgressService.swift` (nuovo)

```swift
enum ProgressService {
    // POST /api/v1/progress ✅
    static func reportLevelCompleted(levelId: String, score: Int) async throws -> ...

    // GET /api/v1/progress/me ✅
    static func getMyProgress() async throws -> UserProgress
}
```

Entrambi autenticati (richiedono Bearer token, come in Step 1).

---

### Task 5 — Aggiornare `completeLevel()` per sincronizzare il server

**File:** `ViewModel/GameViewModel+Levels.swift`

Dopo l'aggiornamento locale, inviare il progresso al server in background (fire-and-forget):

```swift
func completeLevel(stageNumber: Int, levelIndex: Int) {
    // Aggiornamento locale — invariato
    completedLevels.insert(LevelCoordinate(stageNumber: stageNumber, levelIndex: levelIndex))
    if let world = worlds.first(where: { $0.stageNumber == stageNumber }),
       world.levels.allSatisfy({ completedLevels.contains(...) }) {
        completedWorlds.insert(stageNumber)
    }

    // Sincronizzazione server in background — fire and forget
    let levelId = levelsByCoordinate[coord]?.id
    let currentScore = self.score
    if let levelId {
        Task {
            try? await ProgressService.reportLevelCompleted(levelId: levelId, score: currentScore)
        }
    }
}
```

**Strategia:** locale prima, server dopo. Il gioco non aspetta la risposta del server.

---

### Task 6 — Sincronizzazione progresso all'avvio

**File:** `App/JellyMixApp.swift` — aggiungere a `bootstrapUser()`

Al primo avvio (o dopo installazione su nuovo device), il server potrebbe avere un progresso più avanzato di quello locale (es. reinstallazione dell'app). Strategia:

```
GET /progress/me
    ↓
Merge con completedLevels locale: locale ∪ server
    ↓
Non si toglie mai un livello completato già presente in locale
```

Questo garantisce che:
- Il progresso non regredisce mai (locale o server, vince il più avanzato)
- Il progresso recuperato da un altro device viene acquisito

---

## Strategia offline-first

| Situazione | Comportamento |
|---|---|
| Server non raggiungibile al completamento | Il progresso locale viene salvato normalmente; la chiamata al server fallisce silenziosamente; non c'è retry automatico (Step 2) |
| Reconnessione dopo offline | Il progresso locale non viene rischedulato automaticamente (da valutare in Step 4 con la coda eventi offline) |
| GET /progress/me fallisce all'avvio | Usa solo il progresso locale; nessun blocco |
| Server ha progresso > locale (nuovo device) | Il merge in Task 6 recupera il progresso del server |

---

## Domande aperte

### 1. ⚠️ Endpoint progress non nello swagger — quando saranno disponibili?
`POST /progress` e `GET /progress/me` non esistono nel `swagger-spec.json` allegato. Prima di iniziare il Task 3+ serve lo swagger aggiornato o la specifica del contratto API.

### 2. Il server traccia il best score o solo completato/non completato?
Attualmente il client non persiste i punteggi (solo durante la partita). Se il server vuole il best score, dobbiamo aggiungere la persistenza locale in UserDefaults prima di inviarlo.

### 3. Esiste il sistema stelle (1-3 stelle per livello)?
Se sì, i criteri per le stelle (punteggio minimo?) devono essere forniti dal backend o sono già nei dati di `LevelData`.

### 4. `POST /progress` viene chiamato ad ogni completamento o in batch?
- **Singolo:** più semplice, ma richiede rete per ogni livello completato
- **Batch:** più robusto offline, ma più complesso

### 5. Conflict resolution — se server e locale divergono, quale vince?
Proposta: unione (∪) senza mai rimuovere progress già acquisito. Il progresso non può essere revocato.

### 6. Il campo `id` (UUID) è già presente nella risposta di `GET /api/v1/worlds`?
Dal swagger il campo `id` è in `LevelResponseDto`, ma il `WorldResponseDto` mostra `levels` come `array of string` (placeholder?). Confermare che i livelli restituiti in `GET /worlds` contengono effettivamente l'`id` UUID.

---

## Impatto su codice esistente

| File | Modifica richiesta | Rischio |
|---|---|---|
| `Models/LevelModels.swift` | Aggiungere `id: String` a `LevelData` | Basso — campo aggiuntivo in JSON |
| `ViewModel/GameViewModel+Levels.swift` | Modificare `completeLevel()` per inviare al server | Basso — aggiunta non invasiva |
| `App/JellyMixApp.swift` | Aggiungere `GET /progress/me` in `bootstrapUser()` | Basso — step aggiuntivo nella sequenza di avvio |
| `Services/ProgressService.swift` | Nuovo file | Nessuno |
| `Models/ProgressModels.swift` | Nuovo file | Nessuno |

---

## Prossimi step (roadmap backend)

| Step   | Funzionalità           | Endpoint                                              |
|--------|------------------------|-------------------------------------------------------|
| Step 3 | Amicizie               | `POST /friendships/invite`, `GET /friendships`, ecc.  |
| Step 4 | Sistema cuori completo | `POST /hearts/consume`, `POST /hearts/send/:id`, ecc. |
| Step 5 | GDPR                   | `DELETE /users/me`, `GET /users/me/export`            |
