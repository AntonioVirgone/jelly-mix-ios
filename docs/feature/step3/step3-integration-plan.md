# Integrazione Step 3 — Sistema Amicizie
> JellyMix iOS · Branch: `feature/friendships-step3`  
> Data: 2026-05-16

---

## Panoramica

Step 3 introduce il sistema amicizie completo: due metodi di aggiunta amici (link invito e ricerca username), gestione richieste pendenti, feed dei progressi degli amici, notifiche push sociali e deep link `jellymix://invite/:code`.

---

## Stato del codebase prima dello step

| Elemento | File | Stato |
|---|---|---|
| `FriendsProgressResponse` | `ProgressModels.swift` | Stub — `friends: [String]` placeholder |
| `getFriendsProgress()` | `ProgressService.swift` | Stub — restituiva `{ friends: [] }` |
| Tab Amici | `MainCoordinator.swift` | Assente |
| Deep link `jellymix://` | `Info.plist` | Schema URL non registrato |
| Push sociali | `AppDelegate.swift` | Non gestite |

---

## Nuovi endpoint integrati

| Metodo | Path | Auth | Descrizione |
|---|---|---|---|
| `POST` | `/api/v1/friendships/invite` | ✅ | Genera codice invito monouso (scadenza 7 gg) |
| `POST` | `/api/v1/friendships/accept-invite/:code` | ✅ | Accetta invito via codice → ACCEPTED diretto |
| `POST` | `/api/v1/friendships/request/:userId` | ✅ | Invia richiesta amicizia → crea PENDING |
| `POST` | `/api/v1/friendships/accept/:id` | ✅ | Accetta richiesta PENDING (200, non 201) |
| `POST` | `/api/v1/friendships/reject/:id` | ✅ | Rifiuta PENDING → 204 No Content |
| `GET` | `/api/v1/friendships` | ✅ | Lista amici ACCEPTED |
| `GET` | `/api/v1/friendships/pending` | ✅ | Richieste ricevute in attesa |
| `DELETE` | `/api/v1/friendships/:id` | ✅ | Rimuove amicizia ACCEPTED → 204 |
| `GET` | `/api/v1/users/me/friends-progress` | ✅ | Feed progressi amici (non più stub) |

---

## File creati

### `Models/FriendshipModels.swift`

Tutti i modelli Codable per il sistema amicizie:

| Struct | Uso |
|---|---|
| `FriendProfile` | Profilo pubblico amico — `id`, `playerNumber`, `displayName`, `avatarCode?` + `resolvedDisplayName` |
| `Friendship` | Record amicizia — `id`, `status` ("PENDING"/"ACCEPTED"), `createdAt`, `friend: FriendProfile` |
| `InviteResponse` | Risposta POST /invite — `code`, `expiresAt` |
| `FriendCurrentLevel` | Livello corrente amico — `levelNumber`, `levelIndex` (no `levelId`) |
| `FriendProgressEntry` | Progresso amico su un mondo — `worldId`, `stageNumber`, `isWorldComplete`, `currentLevel?` |
| `FriendProgress` | Progresso completo amico — `friendId`, `displayName`, `currentStageNumber?`, `worlds` |
| `FriendsProgressResponse` | Risposta GET /friends-progress — `friends: [FriendProgress]` |

**Nota design:** `avatarCode` è `String?` nonostante lo swagger lo marchi come `object, nullable` — il valore reale è sempre una stringa o null.

---

### `Services/FriendshipService.swift`

Wrapper per tutti gli endpoint amicizie. Tutti autenticati (`authenticated: true`).

```
generateInvite()                    → POST /friendships/invite → InviteResponse
acceptInvite(code:)                 → POST /friendships/accept-invite/:code → Friendship
sendRequest(toUserId:)              → POST /friendships/request/:userId → Friendship
acceptRequest(friendshipId:)        → POST /friendships/accept/:id → Friendship
rejectRequest(friendshipId:)        → POST /friendships/reject/:id → 204
getFriends()                        → GET /friendships → [Friendship]
getPendingRequests()                → GET /friendships/pending → [Friendship]
removeFriend(friendshipId:)         → DELETE /friendships/:id → 204
getFriendsProgress()                → GET /users/me/friends-progress → FriendsProgressResponse
```

**Nota:** `rejectRequest` e `removeFriend` rispondono 204 — decodificati con `EmptyResponse` per uniformità con `CommonService`.

---

### `ViewModel/GameViewModel+Friends.swift`

Logica di loading e mutazioni. Tutte le funzioni che modificano lo stato sono `@MainActor`.

| Funzione | Quando viene chiamata |
|---|---|
| `loadFriendsData()` | All'avvio, in `bootstrapUser()`. Tre chiamate parallele. |
| `reloadFriendsAndProgress()` | Dopo accettazione richiesta o push `FRIEND_ACCEPTED` |
| `reloadPendingFriendships()` | Dopo push `FRIEND_REQUEST` |
| `generateInviteLink()` | Dal pulsante "Genera link" in FriendsView |
| `acceptInviteCode(_:)` | Da `.onOpenURL` in JellyMixApp (deep link) |
| `sendFriendRequest(toUserId:)` | Dalla ricerca username in FriendsView |
| `acceptFriendRequest(friendshipId:)` | Dal pulsante accetta in FriendsView |
| `rejectFriendRequest(friendshipId:)` | Dal pulsante rifiuta in FriendsView |
| `removeFriend(friendshipId:)` | Dal pulsante rimuovi in FriendsView |

**Strategia aggiornamento locale:** dopo ogni mutazione, le liste locali vengono aggiornate in modo ottimistico (insert/remove immediato) prima del reload server, per evitare flickering della UI.

---

### `View/FriendsView.swift`

Vista provvisoria con tre tab interni:

| Tab | Contenuto |
|---|---|
| **Amici** | Lista `friends` con avatar iniziale, display name, mondo corrente e pulsante rimuovi |
| **In attesa** | Lista `pendingFriendships` con accept/reject inline |
| **Aggiungi** | Metodo A (genera link + `ShareLink`) + Metodo B (cerca username ≥ 3 caratteri) |

**Badge:** il tab "AMICI" nella `AppTabBar` mostra un badge rosso con il count delle richieste pendenti.  
**Pull-to-refresh:** `.refreshable` richiama `loadFriendsData()` su tutti e tre i tab.  
**Feedback:** messaggi di errore/successo effimeri (auto-dismiss dopo 3s).

---

## File modificati

### `Models/ProgressModels.swift`

Rimossa la struct `FriendsProgressResponse` placeholder (`friends: [String]`) — sostituita dalla versione definitiva in `FriendshipModels.swift`.

### `Services/ProgressService.swift`

Rimossa `getFriendsProgress()` stub — spostata in `FriendshipService.getFriendsProgress()`.

### `ViewModel/GameViewModel.swift`

Aggiunti quattro `@Published` per lo stato amicizie:

```swift
@Published var friends: [Friendship] = []
@Published var pendingFriendships: [Friendship] = []
@Published var friendsProgress: [FriendProgress] = []
@Published var isLoadingFriends: Bool = false

var pendingFriendshipsCount: Int { pendingFriendships.count }
```

### `App/JellyMixApp.swift`

**Bootstrap:** aggiunto `await gameEngine.loadFriendsData()` dopo il merge progresso (Step 2), in sequenza e non in parallelo con i worlds (i worlds devono essere caricati prima).

**Push sociali:** due nuovi `.onReceive`:
```swift
.onReceive(.friendRequestReceived) { Task { await gameEngine.reloadPendingFriendships() } }
.onReceive(.friendAccepted)        { Task { await gameEngine.reloadFriendsAndProgress() } }
```

**Deep link:** `.onOpenURL` intercetta `jellymix://invite/:code` ed esegue `acceptInviteCode(_:)`:
```swift
.onOpenURL { url in
    guard url.scheme == "jellymix", url.host == "invite",
          let code = url.pathComponents.last else { return }
    Task { try await gameEngine.acceptInviteCode(code) }
}
```

### `App/AppDelegate.swift`

`handleWorldUpdatePayload` trasformato in switch su `type`:

| `data.type` | Azione |
|---|---|
| `WORLD_CREATED` / `WORLD_UPDATED` | Comportamento invariato — posta `mapUpdatePushReceived` |
| `FRIEND_REQUEST` | Posta `friendRequestReceived` (ricarica pending) |
| `FRIEND_ACCEPTED` | Posta `friendAccepted` (ricarica amici e progressi) |

Aggiunte due `Notification.Name`:
```swift
static let friendRequestReceived = Notification.Name("friendRequestReceived")
static let friendAccepted        = Notification.Name("friendAccepted")
```

### `App/MainCoordinator.swift`

- Aggiunto `.friends` a `AppScreen`
- Aggiunta `FriendsView` nello ZStack (pattern opacity, always-mounted)
- `AppTabBar` riceve `pendingFriendshipsCount: Int` e mostra badge rosso sul tab AMICI
- Nuovo metodo `tabItemWithBadge(icon:label:screen:badgeCount:)` per il tab con badge

### `Info.plist`

Registrato lo schema URL `jellymix://` per i deep link:
```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLName</key><string>com.jellymix.invite</string>
    <key>CFBundleURLSchemes</key>
    <array><string>jellymix</string></array>
  </dict>
</array>
```

---

## Scelte di design

### Due metodi di aggiunta amici

Entrambi implementati come da specifica:
- **Metodo A (link):** zero friction — diventa amico direttamente senza stato PENDING. Ideale per condivisione su chat/social.
- **Metodo B (username):** passa per PENDING, permette accettazione/rifiuto. Richiede username di almeno 3 caratteri prima di abilitare la ricerca.

### Aggiornamento locale ottimistico

Dopo ogni mutazione (accept, reject, remove) la lista locale viene aggiornata immediatamente, poi viene fatto un reload dal server. Questo evita il delay visivo di attendere la risposta del server prima di riflettere il cambiamento in UI.

### `getFriendsProgress()` spostato da ProgressService a FriendshipService

Semanticamente è un endpoint del sistema amicizie, non del sistema progresso. Lo spostamento rende il codice più coeso.

### Push gestite via NotificationCenter (pattern esistente)

Coerente con il pattern già usato per `mapUpdatePushReceived`. AppDelegate posta la notifica, JellyMixApp la ascolta e triggera il reload. Nessuna dipendenza diretta tra AppDelegate e GameViewModel.

---

## Verifica e test

### Pre-requisiti

- Firebase Anonymous Auth abilitato in Firebase Console (altrimenti auth fallisce e nessuna chiamata autenticata funziona)
- Due account Firebase (due device o simulatore + device fisico) per testare flussi reciproci

### Test Metodo A (link invito)

1. Su Device A → tab AMICI → Aggiungi → "Genera link invito"
2. Verifica che appaia un link `jellymix://invite/XXXXX`
3. Tappa il pulsante condivisione → condividi il link su Notes o altro
4. Su Device B: apri il link → l'app si avvia → `acceptInviteCode` viene chiamato → Device B vede Device A nella lista amici
5. Su Device A: pull-to-refresh → Device B appare nella lista amici

**Errori attesi:**
- Apertura link scaduto (>7 giorni) → errore silenzioso nel log `[Friends] Accettazione invito fallita`
- Link già usato → stesso comportamento

### Test Metodo B (ricerca username)

1. Su Device A → Profilo → imposta username (es. "mario123")
2. Su Device B → AMICI → Aggiungi → cerca "mario" → appare "mario123"
3. Tappa il "+" → richiesta inviata → messaggio di successo
4. Su Device A: notifica push "Richiesta amicizia" + badge sul tab AMICI
5. Su Device A → AMICI → In attesa → accetta → Device B riceve push "Richiesta accettata"
6. Entrambi si vedono in lista amici

### Test rimozione amico

1. Lista amici → pulsante `person.badge.minus` → amico sparisce dalla lista
2. Pull-to-refresh → amico ancora assente (conferma lato server)

### Test feed progressi

1. Amico completa alcuni livelli
2. Pull-to-refresh nella lista amici → la riga mostra "Mondo X" aggiornato

### Test push sociali

1. Invia richiesta di amicizia (Metodo B) → su Device B arriva push con titolo "Nuova richiesta"
2. Il badge rosso sul tab AMICI appare senza riaprire l'app (`.onReceive` triggera il reload)

### Test deep link a freddo (app chiusa)

1. Device B con app chiusa
2. Apri link `jellymix://invite/XXXXX` da Notes/Safari
3. L'app si avvia → splash screen → `bootstrapUser()` → poi `.onOpenURL` viene chiamato
4. Amicizia creata correttamente

### Verifica log Xcode

| Log atteso | Significato |
|---|---|
| `[Auth] Signed in anonymously: <uid>` | Auth OK |
| Nessun `[FCM] Tentativo X fallito` | FCM registrato correttamente |
| Nessun errore in `FriendshipService` | Chiamate API OK |

---

## Limitazioni note

| Limitazione | Note |
|---|---|
| Due device necessari per test E2E | L'autenticazione anonima è per-device |
| Feed progressi non real-time | Richiede pull-to-refresh manuale o push evento (non implementato) |
| Nessun invio cuori tra amici | Previsto Step 4 — richiede amicizie attive (questo step) |
| Avatar non implementato | `avatarCode` nel modello c'è, ma nessun asset; usa iniziale nome come placeholder |

---

## Prossimi step

| Step | Funzionalità | Dipende da |
|---|---|---|
| Step 4 | Sistema cuori completo (`POST /hearts/consume`, `POST /hearts/send/:friendId`) | Step 3 (lista amici) |
| Step 5 | GDPR (`DELETE /users/me`, export dati) | Indipendente |
