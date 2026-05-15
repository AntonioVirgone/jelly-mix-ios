# Piano di Integrazione — Step 2: Progresso di Gioco
> JellyMix iOS · Piano aggiornato dopo swagger-spec-step2.json  
> Data: 2026-05-15

---

## Stato attuale — cosa c'è già

| Elemento | File | Stato |
|---|---|---|
| `LevelData.id: String` | `Models/LevelModels.swift` | ✅ già presente |
| `WorldData.id: String` | `Models/LevelModels.swift` | ✅ già presente |
| `completedLevels: Set<LevelCoordinate>` | `GameViewModel.swift` | ✅ funzionante, UserDefaults |
| `completedWorlds: Set<Int>` | `GameViewModel.swift` | ✅ funzionante, UserDefaults |
| `completeLevel(stageNumber:levelIndex:)` | `GameViewModel+Levels.swift` | ✅ logica locale — da estendere con server |
| `bootstrapUser()` | `JellyMixApp.swift` | ✅ Step 1 attivo — da estendere con GET /progress/me |
| `isWorldComplete` lato client | nessuno | ❌ mancante — deve essere calcolato |

**Buona notizia:** `LevelData.id` e `WorldData.id` (UUID server) sono già presenti nel modello locale. Non è necessario modificare `LevelModels.swift`.

---

## Nuovi endpoint disponibili (da swagger-spec-step2.json)

| Metodo | Path | Auth | Descrizione |
|---|---|---|---|
| `POST` | `/api/v1/progress` | ✅ | Salva il progresso dopo ogni livello completato |
| `GET` | `/api/v1/progress/me` | ✅ | Recupera il progresso completo dell'utente |
| `GET` | `/api/v1/users/me/friends-progress` | ✅ | Stub (Step 3): restituisce `{ friends: [] }` |

### Body POST /progress (`ReportProgressDto`)
```json
{
  "worldId": "uuid-del-mondo",      // obbligatorio
  "levelId": "uuid-del-livello",    // obbligatorio
  "isWorldComplete": false          // opzionale, default false
}
```

### Risposta GET /progress/me
```json
{
  "currentStageNumber": 2,
  "worlds": [
    {
      "worldId": "uuid", "worldName": "...", "stageNumber": 1,
      "worldIcon": "🌊", "worldColor": "#4FC3F7",
      "isWorldComplete": true, "completedAt": "2026-...",
      "currentLevel": { "levelId": "uuid", "levelNumber": 3, "levelIndex": 2 }
    }
  ]
}
```

**`currentLevel`** = ultimo livello completato nel mondo. `null` se nessun livello completato.  
**L'endpoint è idempotente** — retry su errore di rete è sicuro (il server usa `levelIndex` per non tornare indietro mai).

---

## Piano di lavoro

### Task 1 — Modelli `ProgressModels.swift` (nuovo file)

**File:** `Models/ProgressModels.swift`

```swift
// Body per POST /api/v1/progress
struct ReportProgressBody: Encodable {
    let worldId: String
    let levelId: String
    let isWorldComplete: Bool
}

// Elemento mondo nella risposta di GET /progress/me
struct WorldProgressEntry: Codable {
    let worldId: String
    let worldName: String
    let stageNumber: Int
    let worldIcon: String
    let worldColor: String
    let isWorldComplete: Bool
    let completedAt: Date?
    let currentLevel: LevelProgressCursor?
}

// Puntatore all'ultimo livello completato
struct LevelProgressCursor: Codable {
    let levelId: String
    let levelNumber: Int
    let levelIndex: Int
}

// Risposta di GET /progress/me
struct MyProgressResponse: Codable {
    let currentStageNumber: Int?
    let worlds: [WorldProgressEntry]
}
```

---

### Task 2 — `ProgressService.swift` (nuovo file)

**File:** `Services/ProgressService.swift`

```swift
enum ProgressService {
    // POST /api/v1/progress ✅ — autenticato, idempotente
    static func reportLevelCompleted(
        worldId: String,
        levelId: String,
        isWorldComplete: Bool
    ) async throws {
        let body = ReportProgressBody(worldId: worldId, levelId: levelId, isWorldComplete: isWorldComplete)
        let _: EmptyResponse = try await CommonService.request(
            from: "progress",
            method: .post,
            body: body,
            authenticated: true
        )
    }

    // GET /api/v1/progress/me ✅ — autenticato
    static func getMyProgress() async throws -> MyProgressResponse {
        try await CommonService.request(from: "progress/me", authenticated: true)
    }

    // GET /api/v1/users/me/friends-progress ✅ — stub per Step 3
    static func getFriendsProgress() async throws -> FriendsProgressResponse {
        try await CommonService.request(from: "users/me/friends-progress", authenticated: true)
    }
}

// Modello stub per Step 3 — contiene sempre friends: []
struct FriendsProgressResponse: Codable {
    let friends: [String]   // placeholder, tipizzare in Step 3
}
```

---

### Task 3 — Aggiornare `completeLevel()` con sync server

**File:** `ViewModel/GameViewModel+Levels.swift`

Aggiungere la chiamata a `ProgressService.reportLevelCompleted()` dopo l'aggiornamento locale. Fire-and-forget: la logica locale non dipende dalla risposta del server.

```swift
func completeLevel(stageNumber: Int, levelIndex: Int) {
    let coord = LevelCoordinate(stageNumber: stageNumber, levelIndex: levelIndex)
    completedLevels.insert(coord)

    // Verifica se il mondo è ora completato
    var worldCompleted = false
    if let world = worlds.first(where: { $0.stageNumber == stageNumber }),
       world.levels.allSatisfy({ completedLevels.contains(LevelCoordinate(stageNumber: stageNumber, levelIndex: $0.levelIndex)) }) {
        completedWorlds.insert(stageNumber)
        worldCompleted = true
    }

    // Incrementa il trigger scroll DOPO entrambi gli aggiornamenti (fix bug mappa — vedi sezione sotto)
    progressVersion += 1

    // Sincronizza il server in background — fire and forget
    if let world = worlds.first(where: { $0.stageNumber == stageNumber }),
       let level = world.levels.first(where: { $0.levelIndex == levelIndex }) {
        let worldId = world.id
        let levelId = level.id
        let isLast  = worldCompleted
        Task {
            try? await ProgressService.reportLevelCompleted(
                worldId: worldId,
                levelId: levelId,
                isWorldComplete: isLast
            )
        }
    }
}
```

**Importante:** `progressVersion` viene incrementato come ultima operazione sullo stato locale, garantendo che `currentNodeId` in `SagaMapView` venga calcolato quando sia `completedLevels` che `completedWorlds` sono già aggiornati. Questo risolve il bug della mappa (vedi sezione dedicata).

---

### Task 4 — Aggiungere `progressVersion` a `GameViewModel`

**File:** `ViewModel/GameViewModel.swift`

```swift
// Trigger atomico per lo scroll della mappa: incrementato DOPO che sia
// completedLevels che completedWorlds sono aggiornati in completeLevel().
@Published var progressVersion: Int = 0
```

---

### Task 5 — Merge progresso server in `bootstrapUser()`

**File:** `App/JellyMixApp.swift`

Aggiungere `GET /progress/me` come chiamata parallela alle esistenti in `bootstrapUser()`. La risposta server viene usata per recuperare il progresso su un nuovo device (reinstallazione).

```swift
private func bootstrapUser() async {
    // --- Step 1: Firebase auth (invariato) ---
    do { try await AuthService.shared.signInIfNeeded() }
    catch { print("[Auth] fallito: \(error)"); return }

    // --- Step 1+2: chiamate parallele ---
    async let profileTask  = DataUserService.getMe()
    async let configTask   = DataUserService.getHeartsConfig()
    async let progressTask = ProgressService.getMyProgress()   // ← nuovo Step 2

    let profile  = try? await profileTask
    let config   = try? await configTask
    let progress = try? await progressTask

    if let profile, let config {
        await gameEngine.applyServerUserData(profile: profile, config: config)
    }
    if let progress {
        await gameEngine.mergeServerProgress(progress)         // ← nuovo Task 5
    }
    if let savedToken = UserDefaults.standard.string(forKey: "fcmDeviceToken") {
        await NotificationService.registerFCMToken(savedToken)
    }
}
```

---

### Task 6 — `mergeServerProgress()` in `GameViewModel+Levels.swift`

Strategia di merge: **locale ∪ server, vince sempre il più avanzato** (nessun progresso può regredire).

```swift
@MainActor
func mergeServerProgress(_ response: MyProgressResponse) {
    // Per ogni mondo nel progresso server: confronta con il progresso locale.
    // Si considera il levelIndex del currentLevel come indice di avanzamento.
    for worldEntry in response.worlds {
        guard let serverCurrentLevel = worldEntry.currentLevel else { continue }

        let stageNumber = worldEntry.stageNumber
        let serverLevelIndex = serverCurrentLevel.levelIndex

        // Trova il massimo levelIndex locale per questo mondo
        let localMax = completedLevels
            .filter { $0.stageNumber == stageNumber }
            .map { $0.levelIndex }
            .max() ?? 0

        if serverLevelIndex > localMax {
            // Il server è più avanzato: aggiungiamo tutti i livelli fino al serverLevelIndex
            guard let world = worlds.first(where: { $0.stageNumber == stageNumber }) else { continue }
            for level in world.levels where level.levelIndex <= serverLevelIndex {
                completedLevels.insert(LevelCoordinate(stageNumber: stageNumber, levelIndex: level.levelIndex))
            }
        }

        // Marca il mondo come completato se il server lo dice e il locale non lo sa ancora
        if worldEntry.isWorldComplete && !completedWorlds.contains(stageNumber) {
            completedWorlds.insert(stageNumber)
        }
    }
    // Segnala che il progresso è stato aggiornato (aggiorna scrollTrigger mappa)
    progressVersion += 1
}
```

---

### Task 7 — Aggiornare `scrollTrigger` in `MainCoordinator`

**File:** `App/MainCoordinator.swift`

Sostituire il trigger attuale con `progressVersion` (che viene incrementato atomicamente dopo ogni cambiamento al progresso), più `worlds.flatMap(\.levels).count` per gestire il caricamento iniziale dei livelli.

```swift
// Prima (bug):
scrollTrigger: gameEngine.completedLevels.count + gameEngine.completedWorlds.count * 1000

// Dopo (fix):
scrollTrigger: gameEngine.progressVersion + gameEngine.worlds.flatMap(\.levels).count * 1000
```

---

## Bug della mappa — analisi e fix

### Descrizione del bug

L'utente è al mondo 3 livello 2 (il livello corrente, non ancora completato). Dopo un aggiornamento, la mappa si centra sul mondo 4 livello 1 invece che sul nodo corretto.

### Causa principale — Double publish race condition

Il `scrollTrigger` attuale dipende da **due `@Published` separati**:

```swift
scrollTrigger: gameEngine.completedLevels.count + gameEngine.completedWorlds.count * 1000
```

Quando `completeLevel()` viene chiamato sull'ultimo livello di un mondo, aggiorna prima `completedLevels`, poi `completedWorlds`. SwiftUI emette due notifiche distinte (non le coalizza perché sono due variabili `@Published` separate).

**Timeline del problema:**

```
1. completeLevel(stageNumber: 3, levelIndex: 2)          ← ultimo livello del mondo 3
2. completedLevels.insert((3,2))                         ← @Published triggera
3. SwiftUI notifica il cambiamento di scrollTrigger
4. onChange(of: scrollTrigger) → currentNodeId calcolato
   - completedLevels ha (3,2) ✓
   - completedWorlds NON ha ancora 3
   - → isUnlocked(4,1) = completedWorlds.contains(3) = FALSE
   - → currentNodeId = "level_3_X" (prossimo livello del mondo 3, se esiste)
5. completedWorlds.insert(3)                             ← @Published triggera di nuovo
6. SwiftUI notifica il cambiamento di scrollTrigger
7. onChange(of: scrollTrigger) → currentNodeId calcolato di nuovo
   - completedWorlds ha ora 3
   - → isUnlocked(4,1) = completedWorlds.contains(3) = TRUE
   - → currentNodeId = "level_4_1" ← la mappa scorre qui!
```

L'utente vede la mappa centrata su (4,1) ma il nodo potrebbe ancora mostrare il lucchetto se il rendering della UI del nodo non è ancora aggiornato (il secondo @Published non ha ancora propagato il rendering dei `LevelNodeView`).

### Causa secondaria — Worlds non ancora caricati all'onAppear

`SagaMapView.onAppear` viene chiamato al primo rendering, quando `gameEngine.worlds` potrebbe essere ancora `[]` (caricamento asincrono dal server). In quel momento `currentNodeId` restituisce `nil` e nessun scroll avviene.

Quando i worlds arrivano, `scrollTrigger` non cambia (i `completedLevels/completedWorlds` sono invariati) → nessun `onChange` → la mappa rimane in cima.

### Fix

**Fix 1 — `progressVersion` come trigger atomico (Task 4 + Task 7)**

Usare `progressVersion: Int` come unico trigger per lo scroll. Viene incrementato come ultima operazione in `completeLevel()`, dopo che sia `completedLevels` che `completedWorlds` sono aggiornati. SwiftUI riceve una sola notifica quando il progresso è coerente.

**Fix 2 — worlds.flatMap in scrollTrigger (Task 7)**

Aggiungere `gameEngine.worlds.flatMap(\.levels).count * 1000` al trigger: quando i worlds vengono caricati, il trigger cambia e `currentNodeId` viene ricalcolato con i dati corretti.

---

## Domande aperte

### 1. Risposta di POST /progress
Lo swagger indica `201` ma non mostra il body della risposta. La guida mostra un corpo con `currentLevel` e `isWorldComplete`. Come gestiamo la risposta? Per ora il client la ignora (fire-and-forget) — da confermare.
ho aggiornato swagger e guida.

### 2. Score — il server lo traccia?
Attualmente il punteggio è solo locale e volatile (si azzera a ogni partita). Non è nel body di `POST /progress`. Confermare che il backend non vuole ricevere lo score in questa versione.
confermo, al momento lo score non viene elaborato dal server.

### 3. `GET /progress/me` — cosa succede se un livello completato non esiste più nel catalogo?
Se il server restituisce un `levelId` UUID che non corrisponde ad alcun livello nel `levelsByCoordinate` locale (es. livello rimosso dal catalogo), il merge deve ignorarlo silenziosamente.
esatto, l'applicazione deve essere sempre fruibie per l'utente. quindi in caso un livello viene rimosso il merge deve ignorarlo

### 4. Ordine operazioni nel bootstrap
Nella nuova sequenza parallela, `mergeServerProgress()` viene chiamato con `worlds` che potrebbe non essere ancora caricato (il GET /worlds avviene in `loadLevels()`, separato da `bootstrapUser()`). Serve coordinare i due flussi. Proposta: chiamare `mergeServerProgress()` solo dopo che `worlds` è caricato.
direi di si, non possiamo metterle in parallelo.

---

## File da creare / modificare

| Operazione | File |
|---|---|
| Crea | `Models/ProgressModels.swift` |
| Crea | `Services/ProgressService.swift` |
| Modifica | `ViewModel/GameViewModel.swift` — aggiungere `progressVersion` |
| Modifica | `ViewModel/GameViewModel+Levels.swift` — `completeLevel()` + `mergeServerProgress()` |
| Modifica | `App/JellyMixApp.swift` — `bootstrapUser()` |
| Modifica | `App/MainCoordinator.swift` — `scrollTrigger` |

---

## Prossimi step (roadmap backend)

| Step   | Funzionalità           | Endpoint                                              |
|--------|------------------------|-------------------------------------------------------|
| Step 3 | Amicizie               | `POST /friendships/invite`, `GET /friendships`, ecc.  |
| Step 4 | Sistema cuori completo | `POST /hearts/consume`, `POST /hearts/send/:id`, ecc. |
| Step 5 | GDPR                   | `DELETE /users/me`, `GET /users/me/export`            |
