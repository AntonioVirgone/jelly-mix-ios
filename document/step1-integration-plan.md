# Piano di Integrazione — Step 1: Utente e Autenticazione
> JellyMix iOS · Analisi e piano di lavoro
> Data: 2026-05-15

---

## Stato attuale del codebase

### Già presente e riutilizzabile

| Elemento                             | File                                  | Note                                                    |
|--------------------------------------|---------------------------------------|---------------------------------------------------------|
| `FirebaseCore` + `FirebaseMessaging` | `App/AppDelegate.swift`               | Integrati e funzionanti                                 |
| Wrapper URLSession non autenticato   | `Services/CommonService.swift`        | Nessun header Authorization                             |
| Registrazione FCM                    | `Services/NotificationService.swift`  | Chiama già `POST /notifications/register` ma senza auth |
| Stub vuoto                           | `Services/DataUserService.swift`      | Solo `import Foundation`                                |
| Caricamento mondi/livelli            | `Services/WorldService.swift`         | Endpoint pubblici, nessuna auth necessaria              |
| Gestione cuori locale                | `ViewModel/GameViewModel+Lives.swift` | UserDefaults + Timer, valori hardcoded                  |
|--------------------------------------|---------------------------------------|---------------------------------------------------------|

### Mancante

- `FirebaseAuth` non usato — nessuna chiamata `Auth.auth()` ovunque nel progetto
- `CommonService` non inietta header `Authorization: Bearer`
- Nessun modello `UserProfile` / `HeartsConfig`
- Nessun flusso di avvio ordinato (Firebase → getMe → heartsConfig → FCM → worlds)
- Parametri cuori hardcoded: `maxLives = 5`, `secondsPerLife = 300`

---

## Piano di lavoro

### Task 1 — Verifica dipendenza FirebaseAuth

Controllare se `FirebaseAuth` è già incluso nel target (Package.swift o Podfile) insieme a `FirebaseMessaging`. È parte dello stesso SDK Firebase quindi probabilmente già disponibile, ma va verificato prima di procedere.

---

### Task 2 — `AuthService` (nuovo file)

**File:** `Services/AuthService.swift`

Responsabilità: gestire l'identità Firebase anonima e fornire token freschi a tutto il layer di rete.

```swift
actor AuthService {
    static let shared = AuthService()

    func signInIfNeeded() async throws {
        if Auth.auth().currentUser == nil {
            try await Auth.auth().signInAnonymously()
        }
    }

    func getIdToken(forcingRefresh: Bool = false) async throws -> String {
        guard let user = Auth.auth().currentUser else {
            throw AuthError.notLoggedIn
        }
        return try await user.getIDToken(forcingRefresh: forcingRefresh)
    }
}
```

- `signInIfNeeded()` al primo avvio (se già loggato, skip)
- `getIdToken(forcingRefresh: false)` chiamato da `CommonService` prima di ogni richiesta autenticata
- Nessun logout in Step 1

---

### Task 3 — Aggiornare `CommonService`

Aggiungere supporto per richieste autenticate:

- Parametro `authenticated: Bool = false` al metodo `request()`
- Se `true`: chiama `AuthService.getIdToken()` e inietta `Authorization: Bearer <token>`
- Gestione `401`: forza `forcingRefresh: true` e riprova una volta sola
- Gli endpoint pubblici (worlds, levels, app-config/hearts) continuano a funzionare senza modifiche

```swift
// Firma aggiornata
static func request<T: Decodable, E: Encodable>(
    from path: String,
    method: HTTPMethod = .get,
    body: E? = nil as Optional<Never>,
    authenticated: Bool = false,
    timeoutInterval: TimeInterval = 10
) async throws -> T
```

---

### Task 4 — Modelli `UserProfile` e `HeartsConfig`

**File:** `Models/UserModels.swift`

```swift
struct UserProfile: Codable {
    let id: String
    let playerNumber: Int
    let displayName: String?
    let username: String?
    let avatarCode: String?
    let heartsCount: Int
    let maxHearts: Int
    let lastHeartConsumedAt: Date?
    let gdprConsentAt: Date?
    let createdAt: Date

    var resolvedDisplayName: String {
        displayName ?? "Player#\(playerNumber)"
    }
}

struct HeartsConfig: Codable {
    let heartRechargeMinutes: Int
    let maxHearts: Int
    let maxHeartsReceivedPerDay: Int
}

struct PublicProfile: Codable {
    let id: String
    let playerNumber: Int
    let displayName: String?
    let avatarCode: String?
}
```

---

### Task 5 — Completare `DataUserService`

**File:** `Services/DataUserService.swift`

Endpoint da implementare:

| Metodo | Endpoint | Auth |
|---|---|---|
| `getMe()` | `GET /api/v1/users/me` | ✅ |
| `updateMe(displayName:username:avatarCode:)` | `PATCH /api/v1/users/me` | ✅ |
| `getPublicProfile(id:)` | `GET /api/v1/users/{id}/profile` | ❌ |
| `searchUsers(username:)` | `GET /api/v1/users/search?username=` | ✅ |
| `getHeartsConfig()` | `GET /api/v1/app-config/hearts` | ❌ |

---

### Task 6 — Sequenza di avvio

**File:** `App/JellyMixApp.swift` o `App/MainCoordinator.swift`

Implementare il flusso ordinato del §5 della guida:

```
App avviata
    │
    ▼
AuthService.signInIfNeeded()          ← Firebase anonymous login
    │
    ▼
GET /api/v1/users/me                  ← crea User in automatico (upsert)
    │
    ▼
GET /api/v1/app-config/hearts         ← scarica config cuori, sostituisce valori hardcoded
    │
    ▼
POST /api/v1/notifications/register   ← registra FCM token (ora autenticato)
    │
    ▼
GET /api/v1/worlds                    ← carica contenuti di gioco (già funzionante)
```

**Gestione errori avvio:**
- Firebase offline → modalità offline con valori locali di fallback
- `GET /users/me` fallisce → gioco locale senza profilo remoto, retry al prossimo avvio
- `GET /app-config/hearts` fallisce → usare valori hardcoded come fallback (`maxLives=5`, `secondsPerLife=300`)

---

### Task 7 — Sincronizzare cuori con server

Sostituire i valori hardcoded in `GameViewModel`:

- `maxLives` e `secondsPerLife` provengono da `HeartsConfig` (server), con fallback ai valori attuali se offline
- `heartsCount` e `lastHeartConsumedAt` al lancio provengono da `UserProfile`
- **Fonte di verità:** server autoritario al primo avvio del giorno; locale durante la sessione
- Il timer locale rimane invariato (il server non ha ancora `POST /hearts/consume` — previsto Step 4)
- Al rientro in foreground: confrontare stato locale con `currentHearts` calcolato dalla formula `HeartState` della guida (§6)

**Formula client per cuori correnti (da guida §6):**
```swift
let minutesPassed = Int(Date().timeIntervalSince(lastHeartConsumedAt) / 60)
let recharged = minutesPassed / rechargeMinutes
let currentHearts = min(maxHearts, heartsCount + recharged)
```

---

### Task 8 — Aggiornare registrazione FCM

`NotificationService.registerFCMToken()` attualmente chiama l'endpoint senza autenticazione. Dopo Task 3, passare `authenticated: true`. Deve essere chiamato **dopo** `AuthService.signInIfNeeded()`.

---

## Domande aperte

### 1. FirebaseAuth nelle dipendenze
`FirebaseAuth` è già incluso nel target Xcode? Va verificato nel Package.swift / Podfile prima di iniziare il Task 2. 
Si è già incluso

### 2. UI profilo utente
La guida menziona `displayName`, `username`, `avatarCode`. È prevista una schermata profilo nel redesign? Se sì, rientra in Step 1 o è differita?
Non sono ancora state disegnate le UI quindi per ora puoi creare delle view provvisorie per testare le funzionalità.

### 3. `avatarCode` — formato e lista
La guida dice "codice preset avatar" ma non fornisce la lista dei codici validi. Come vengono gestiti gli avatar lato UI? Esistono asset grafici corrispondenti nell'app?
Al momento non sono ancora presenti gli asset. Predisponi usando l'asset appicon come avatar per gli utenti. Poi questa parte la rivederemo successivamente.

### 4. Cuori — fonte di verità al primo avvio
Quando `GET /users/me` torna con `heartsCount: 5` e `lastHeartConsumedAt: null`, ma `UserDefaults` ha già uno stato diverso (utente che ha perso vite offline): **quale vince?**
Proposta: server autoritario al primo avvio del giorno, locale durante la sessione corrente.
va bene la tua proposta

### 5. GDPR consent
`gdprConsentAt` è nel modello `UserProfile`. In Step 1 serve mostrare un banner di consenso prima del login anonimo, o è differito allo Step 5?
lo gestiremo nello step 5

### 6. Offline al primo avvio assoluto
Se `signInAnonymously()` fallisce per assenza di rete (dispositivo mai connesso): blocchiamo l'app con un messaggio, o permettiamo il gioco locale senza profilo remoto?
permettiamo il gioco locale sempre

### 7. Divergenza cuori — Step 4 non ancora disponibile
La guida dice di decrementare le vite localmente per ora. Questo crea divergenza: se l'utente perde 3 vite in sessione, al prossimo `GET /users/me` il server ritornerebbe comunque `heartsCount: 5`. **Confermato che in Step 1 ignoriamo questa divergenza e la sincronizziamo in Step 4?**
confermo che lo affronteremo allo step 4.

---

## Prossimi step (roadmap backend)

| Step   | Funzionalità           | Endpoint                                              |
|--------|------------------------|-------------------------------------------------------|
| Step 2 | Progresso di gioco     | `POST /progress`, `GET /progress/me`                  |
| Step 3 | Amicizie               | `POST /friendships/invite`, `GET /friendships`, ecc.  |
| Step 4 | Sistema cuori completo | `POST /hearts/consume`, `POST /hearts/send/:id`, ecc. |
| Step 5 | GDPR                   | `DELETE /users/me`, `GET /users/me/export`            |
|--------|------------------------|-------------------------------------------------------|
