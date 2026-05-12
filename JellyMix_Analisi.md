# JellyMix
## Analisi Funzionale e Tecnica
### Documento per il Porting su Android
*v1.0 — Maggio 2026*

---

## Indice

1. [Panoramica dell'Applicazione](#1-panoramica-dellapplicazione)
2. [Architettura](#2-architettura)
   - 2.1 Pattern MVVM
   - 2.2 Struttura dei File
   - 2.3 Flusso di Avvio
   - 2.4 Navigazione
3. [Modelli Dati](#3-modelli-dati)
   - 3.1 ElementType
   - 3.2 Jelly
   - 3.3 CellType
   - 3.4 WorldData / LevelData
   - 3.5 Compatibilità Identificatori
4. [Logica di Gioco](#4-logica-di-gioco)
   - 4.1 Posizionamento · 4.2 Algoritmo Merge · 4.3 Obiettivi
   - 4.4 Fine Turno · 4.5 Nastri · 4.6 Generatori
   - 4.7 Power-Up · 4.8 Chiavi/Tesori · 4.9 Win/Lose
   - 4.10 Hold · 4.11 Sblocco Progressivo
5. [Sistema Vite](#5-sistema-vite)
6. [Negozio e Collezione](#6-negozio-e-collezione)
7. [Servizi Backend e Rete](#7-servizi-backend-e-rete)
8. [Push Notifications (FCM)](#8-push-notifications-firebase-fcm)
9. [Persistenza Locale](#9-persistenza-locale)
10. [Interfaccia Utente](#10-interfaccia-utente)
11. [Test](#11-test)
12. [Considerazioni per il Porting Android](#12-considerazioni-per-il-porting-android)
- [Appendice — Formato JSON Livello](#appendice--formato-json-livello)

---

## 1. Panoramica dell'Applicazione

JellyMix è un puzzle game mobile di tipo match-and-merge sviluppato in SwiftUI per piattaforma iOS. Il giocatore posiziona gelatine colorate su una griglia 5×5 e le combina per creare gelatine di livello superiore, superando obiettivi definiti per ogni livello. Il gioco è organizzato in mondi, ognuno con una serie di livelli progressivi.

| Proprietà | Valore |
|---|---|
| Piattaforma corrente | iOS (SwiftUI) |
| Target porting | Android (Kotlin / Jetpack Compose) |
| Pattern architetturale | MVVM (Model-View-ViewModel) |
| Griglia di gioco | 5 × 5 celle |
| Backend API | REST — https://jelly-mix-api.onrender.com/api/v1 |
| Push Notifications | Firebase Cloud Messaging (FCM) |
| Persistenza locale | UserDefaults + file JSON su Documents |
| Test | Unit test sul GameViewModel (XCTest) |

---

## 2. Architettura

### 2.1 Pattern MVVM

L'app segue il pattern MVVM con separazione netta tra:

- **Model**: strutture dati pure (`Jelly`, `LevelData`, `WorldData`, `ElementType`, …)
- **ViewModel**: `GameViewModel` — unico ViewModel centrale, suddiviso in extension per dominio
- **View**: componenti SwiftUI che osservano il ViewModel tramite `@ObservedObject` / `@Published`

### 2.2 Struttura dei File

| Cartella | Contenuto |
|---|---|
| `App/` | Entry point (`JellyMixApp`), `AppDelegate` (FCM), `SplashScreen`, `MainCoordinator` |
| `Models/` | `Jelly.swift`, `GameModels.swift`, `LevelModels.swift`, `DataLoggerModels.swift` |
| `ViewModel/` | `GameViewModel` + 6 extension: `Gameplay`, `Levels`, `Lives`, `PowerUps`, `Shop`, `SpecialCells` |
| `View/` | `ContentView` (gioco), `SagaMapView`, `ShopView`, `CollectionBookView` |
| `Component/` | `ElementView`, `BoxView`, `BoxIconView`, `LivesBarView`, `ScoreProgressBar` |
| `Services/` | `CommonService`, `WorldService`, `WorldCacheService`, `NotificationService`, `DataLoggerService` |

### 2.3 Flusso di Avvio

1. Mostra la `SplashScreen`
2. Log install all'API (solo al primo avvio — genera UUID univoco per device)
3. Carica dati locali (cache disco → bundle JSON) istantaneamente
4. Reset livello 1, mostra schermata principale dopo almeno 1 secondo
5. Background fetch con retry (max 3 tentativi, timeout 60 s) per aggiornare i mondi
6. Se il fetch ha successo: salva su disco, aggiorna ViewModel, mostra banner "Mappa aggiornata"

### 2.4 Navigazione

`MainCoordinator` gestisce la navigazione tramite un enum `AppScreen { map, game, shop, collection }`. La schermata di gioco viene sovrapposta alle altre con animazione asimmetrica. Le altre tre tab condividono una `TabBar` inferiore personalizzata sempre visibile.

---

## 3. Modelli Dati

### 3.1 ElementType

Enum centrale che rappresenta ogni tipo di elemento. Il `rawValue Int` ordina la progressione del merge (merge produce `rawValue + 1`).

La proprietà `config` restituisce un `ElementConfig` con: nome, colore, requirement, `isObstacle`, `hasFace`, `requireKeys`.

| rawValue | Nome | Categoria | Note |
|---|---|---|---|
| -7 | `treasure` | Ostacolo | Richiede chiave, dà 250 monete |
| -6 | `rock` | Ostacolo | Indistruttibile |
| -5 | `honey` | Ostacolo | Rimosso dal merge adiacente |
| -4 | `licorice` | Ostacolo | Si espande ogni turno (40%) |
| -3 | `brokenWaffle` | Ostacolo | Secondo stadio waffle |
| -2 | `waffle` | Ostacolo | Due colpi per distruggerlo |
| -1 | `ice` | Ostacolo | Rimosso dal merge adiacente; congela la cella risultante 3 turni |
| 0 | `rainbow` | Speciale | Jolly: si unisce al tipo con più connessioni adiacenti |
| 1–7 | `red`…`black` | Gelatina | Merge quando N adiacenti >= requirement (cresce col tipo) |
| 99 | `empty` | Vuoto | Cella disponibile |

### 3.2 Jelly

Struct che rappresenta lo stato dinamico di una singola cella:

| Campo | Tipo | Descrizione |
|---|---|---|
| `id` | UUID | Identificatore univoco (per le animazioni SwiftUI) |
| `type` | ElementType | Tipo corrente della cella |
| `isFreeze` | Bool | Se `true` la cella non partecipa al merge |
| `freezeTurnsLeft` | Int | Countdown turni di congelamento |
| `hasKey` | Bool | La gelatina trasporta una chiave per i tesori |
| `isDirty` | Bool | Overlay visivo miele (placeholder attuale) |

### 3.3 CellType

Enum del layer fisso della griglia (separato dal contenuto Jelly):

- `normal` — cella standard
- `conveyor(Direction)` — nastro trasportatore (`left / right / up / down`)
- `generator(ElementType)` — genera un elemento ogni 3 turni

### 3.4 WorldData / LevelData

| Campo LevelData | Tipo | Descrizione |
|---|---|---|
| `levelNumber` | Int | Numero globale del livello (usato per l'unlock) |
| `movesLimit` | Int? | Limite mosse (`nil` = illimitato) |
| `objective` | ObjectiveData | Tipo + colore target + quantità richiesta |
| `grid` | `[[String]]` | Matrice 5×5 di stringhe (es. `"RED"`, `"CONVEYOR_LEFT"`) |
| `availablePieces` | `[AvailablePieceData]` | Pezzi disponibili con soglia punteggio di sblocco |

### 3.5 Compatibilità Identificatori

Il backend ha migrato da identificatori italiani a inglesi. Il ViewModel gestisce entrambi tramite `switch` exhaustivi:

| Italiano (legacy) | Inglese (attuale) |
|---|---|
| `ROSSO / BLU / VERDE` | `RED / BLUE / GREEN` |
| `ARANCIONE / GIALLO / VIOLA` | `ORANGE / YELLOW / PURPLE` |
| `GHIACCIO / MIELE / TESORO` | `ICE / HONEY / TREASURE` |
| `LIQUIRIZIA` | `LICORICE` |
| `NASTRO_SX / DX / SU / GIU` | `CONVEYOR_LEFT / RIGHT / UP / DOWN` |
| `GENERATORE_XXX` | `GENERATOR_XXX` |

---

## 4. Logica di Gioco

### 4.1 Posizionamento

Il giocatore tappa una cella vuota per piazzare il pezzo "PROSSIMO". Guardie: cella `.empty`, non `.generator`, gioco non finito. Se presente un limite mosse, `movesLeft` viene decrementato di 1.

### 4.2 Algoritmo di Merge

Il merge è ricorsivo e si ripete finché non ci sono più combinazioni:

1. BFS/DFS dal punto di piazzamento → trova celle connesse dello stesso tipo (o rainbow)
2. Se celle connesse >= `requirement`: merge eseguito
3. Le celle mergiate diventano `.empty`, la cella focale riceve il tipo successivo (`rawValue + 1`)
4. Punteggio: `(rawValue_base × 10) × numero_celle_mergiate`
5. Se celle connesse > `requirement`: il prossimo pezzo sarà `.rainbow`
6. Loop dalla stessa cella per catene a cascata

Rainbow: tenta il merge dai tipi più alti ai più bassi (`.purple` → `.red`), agendo come jolly per qualsiasi tipo adiacente.

### 4.3 Obiettivi

| Tipo | Condizione avanzamento |
|---|---|
| `JELLY` | Ogni merge che produce il colore target incrementa `objective.current` |
| `OBSTACLE` | Distruzione di ghiaccio, `brokenWaffle`, honey |
| `LICORICE` | Distruzione di liquirizia |

### 4.4 Gestione Fine Turno

`processaFineTurno()` esegue in ordine:

1. Decremento `freezeTurnsLeft` per celle congelate (poi `isFreeze = false` a 0)
2. `processConveyors()` — spostamento pezzi sui nastri
3. `processGenerators()` — eventuali spawn
4. Espansione liquirizia: 40% per ogni licorice presente; garantita su almeno uno se nessun licorice è stato distrutto nel turno

### 4.5 Nastri Trasportatori

I nastri spostano i pezzi nella direzione configurata a ogni fine turno. L'ordinamento di processing è critico: si processa prima il nastro più vicino al bordo libero per evitare double-move. Un set `movedToIndices` impedisce che un pezzo appena arrivato venga rimosso nello stesso turno.

### 4.6 Generatori

Ogni generatore incrementa un contatore a ogni turno. Ogni 3 turni spawna il suo elemento: prima in una cella adiacente vuota (priorità: su, destra, giù, sinistra), poi provando a spingere un pezzo esistente. Se non c'è spazio, lo spawn viene saltato.

### 4.7 Power-Up

Tutti i power-up consumano 1 mossa. Il conteggio è persistito in UserDefaults.

| Power-Up | Costo | Effetto |
|---|---|---|
| Martello | 500 monete | Rimuove qualsiasi cella non vuota/non-licorice; applica la logica ostacolo se necessario |
| Scambio | 500 monete | Scambia il pezzo "PROSSIMO" con il contenuto della cella; può innescare merge a cascata |
| Pennello | 500 monete | Trasforma la cella in `.rainbow` e innesca subito il merge |

### 4.8 Sistema Chiavi e Tesori

Le gelatine con `hasKey` vengono generate casualmente (50%) quando sulla griglia ci sono tesori e il numero di chiavi in circolazione è inferiore ai tesori. Un merge che include una gelatina-chiave fa `keysCollected += 1`. Interagendo con un tesoro mentre `keysCollected > 0`: tesoro rimosso + 250 monete.

### 4.9 Condizioni Vittoria/Sconfitta

- **Vittoria**: `objective.current >= objective.required`
- **Sconfitta**: `movesLeft <= 0` (se limitato) oppure nessuna cella `.empty` rimasta
- In caso di sconfitta: `loseLife()` viene chiamato automaticamente

### 4.10 Hold (Conserva)

Il giocatore può mettere da parte il pezzo corrente una volta per turno (flag `hasHeldThisTurn`). Alla prima hold il pezzo va in riserva e viene generato un nuovo pezzo. Al secondo tap riserva e corrente vengono scambiati.

### 4.11 Sblocco Pezzi Progressivo

`availablePieces` del livello definisce soglie di punteggio (`point`). Solo i pezzi con `point <= score` corrente entrano nel pool di generazione casuale. La `ScoreProgressBar` mostra le milestone come icone sulla barra.

---

## 5. Sistema Vite

Il giocatore ha al massimo 5 vite. Una vita si perde a ogni sconfitta. Le vite si rigenerano automaticamente ogni 5 minuti (300 secondi).

| Aspetto | Implementazione iOS |
|---|---|
| Persistenza | UserDefaults: `savedLives`, `lastTimeToNextLife`, `lastExitDate` |
| Timer in-app | `Timer.scheduledTimer` ogni 1 s, decrementa `timeToNextLife` |
| Offline recovery | All'avvio calcola il tempo trascorso e aggiunge le vite maturate |
| Max vite | 5 — non superabile dal timer automatico |
| Notifiche locali | Pianificate al go-to-background, cancellate al ritorno in foreground |

### 5.1 Logica Offline

1. Al background: salva `Date()` in `lastExitDate`
2. Al riavvio: `elapsed = now - lastExitDate`
3. Si sottraggono i secondi al `timeToNextLife`; per ogni 300 s interi: +1 vita
4. Se si supera `maxLives`: `lives = 5`, `timeToNextLife = 0`

### 5.2 Notifiche Locali

`NotificationService` pianifica una `UNTimeIntervalNotificationTrigger` solo per il ripristino completo (vita finale). Ogni notifica ha identifier univoco (`life_restore_N`) per poterla cancellare selettivamente al ritorno in foreground.

---

## 6. Negozio e Collezione

### 6.1 Valuta (Monete)

Le monete si guadagnano aprendo tesori (250 monete) e tramite punteggio. Sono persistite in UserDefaults e usate per acquistare bustine e power-up.

### 6.2 Bustina di Gelatine

Costo: 100 monete. Fornisce 3 carte casuali da `getPullRates()`:

| Elemento | Probabilità approssimativa |
|---|---|
| `ice` | ~50% (riempimento del pool) |
| `black` | ~5% |
| `purple` | ~5% |
| `yellow` | ~20% |
| `orange` | ~20% |

Gli elementi ottenuti vengono aggiunti a `unlockedJellies` (persistito in UserDefaults).

### 6.3 Power-Up nel Negozio

I tre power-up (Martello, Scambio, Pennello) si acquistano a 500 monete ciascuno dalla `ShopView`.

### 6.4 CollectionBook

Griglia 3 colonne con tutti gli `ElementType` (`rawValue >= 0`, escluso `.empty`). Tipi non sbloccati appaiono come silhouette scure con nome `???`.

---

## 7. Servizi Backend e Rete

### 7.1 API REST

**Base URL**: `https://jelly-mix-api.onrender.com/api/v1`

Il server usa Render.com con cold start di 30-50 s. Il fetch usa `fetchWorldsWithRetry` (timeout 60 s, 3 tentativi con delay progressivi di 10 s e 20 s).

| Endpoint | Metodo | Descrizione |
|---|---|---|
| `GET /worlds` | GET | Tutti i mondi con livelli (`WorldCollection`) |
| `GET /worlds/{id}` | GET | Singolo mondo per ID |
| `POST /worlds` | POST | Crea un nuovo mondo |
| `PUT /worlds/{id}` | PUT | Aggiorna un mondo |
| `POST /notifications/register` | POST | Registra token FCM |
| `DELETE /notifications/token/{t}` | DELETE | Rimuove token FCM (logout) |
| `POST /data-logger` | POST | Evento analytics (`install`, `play_game`, `shop`, `other`) |

### 7.2 CommonService

Layer di rete generico con metodi `request<T,E>` e `fetch<T>`. Accetta solo HTTP 200-299. Errori tipizzati con `enum APIError`. Il body viene serializzato con `JSONEncoder`, la risposta decodificata con `JSONDecoder`.

### 7.3 Strategia di Caching

| Livello | Fonte | Quando viene usato |
|---|---|---|
| 1 - RAM | `WorldCollection` in `GameViewModel` | Durante la sessione |
| 2 - Disco | `worlds_cache.json` in Documents | All'avvio (istantaneo); aggiornato dopo ogni fetch |
| 3 - Bundle | `worlds.json` nel bundle dell'app | Primo avvio / cache corrotta / offline totale |

### 7.4 DataLogger

Al primo avvio viene generato un UUID (`appId`) e inviato con `type = INSTALL`. I tipi previsti dall'enum sono: `INSTALL`, `PLAY_GAME`, `SHOP`, `OTHER`. `DataUserService.swift` è attualmente un placeholder vuoto da implementare.

---

## 8. Push Notifications (Firebase FCM)

### 8.1 Flusso Token

1. Firebase mappa il token APNs al token FCM
2. `MessagingDelegate.didReceiveRegistrationToken` viene chiamato all'avvio e a ogni refresh
3. `NotificationService.registerFCMToken()` invia il token al backend con backoff 2s → 4s → 8s
4. Al logout (non implementato nell'UI): `unregisterFCMToken()` rimuove il token dal backend

### 8.2 Payload Gestito

L'app interpreta payload FCM con campo `type = WORLD_CREATED` o `WORLD_UPDATED`:

- **App in foreground**: banner di sistema + `backgroundRefresh()`
- **App in background** (`content-available`): `backgroundRefresh` silenzioso
- **Tap sulla notifica**: navigazione alla schermata mappa

| `Notification.Name` interna | Chi la ascolta |
|---|---|
| `mapUpdatePushReceived` | `JellyMixApp` → avvia `backgroundRefresh()` |
| `openMapFromNotification` | `MainCoordinator` → `currentScreen = .map` |

---

## 9. Persistenza Locale

| Chiave UserDefaults | Tipo | Contenuto |
|---|---|---|
| `savedCoins` | Int | Saldo monete |
| `savedUnlockedJellies` | `[Int]` | `rawValue` delle gelatine sbloccate |
| `savedPowerUps` | `[String:Int]` | Dizionario rawValue→quantità power-up |
| `savedLives` | Int | Vite persistite |
| `lastTimeToNextLife` | Int | Secondi al prossimo ripristino vita |
| `lastExitDate` | Date | Timestamp ultimo background |
| `maxUnlockedLevel` | Int | Livello massimo sbloccato (legacy) |
| `completedLevels` | Data (JSON) | `Set<LevelCoordinate>` — progressione per-mondo |
| `completedWorlds` | `[Int]` | Mondi completati integralmente |
| `appId` | String | UUID univoco per device (analytics) |
| `fcmDeviceToken` | String | Token FCM corrente |

---

## 10. Interfaccia Utente

### 10.1 Schermata di Gioco (ContentView)

Layout dall'alto al basso: pulsante Indietro, titolo, HUD (mosse, obiettivo, monete, chiavi), box PROSSIMO/CONSERVA, `ScoreProgressBar`, griglia 5×5, `PowerUpBar`. Overlay win/game-over centrato.

### 10.2 Animazioni

| Animazione | Trigger | Tecnica |
|---|---|---|
| Squash & Stretch | Merge | `scaleEffect` X/Y + `interpolatingSpring` |
| Gooey ripple | Merge | `Circle` con blur + fade opacity |
| Blur griglia | `mergeEvent` | `blur(radius)` easeOut/easeIn |
| Flip carta | Tap negozio | `rotation3DEffect` asse Y |
| Transizione schermo | cambio `AppScreen` | `asymmetric` opacity + scale |

### 10.3 Mappa Saga (SagaMapView)

Mondi ordinati per `stageNumber`, livelli in zig-zag (offset +80/-80 pt alternato). Nodi: stella (completato), numero+segnaposto gelatina (corrente), lucchetto (bloccato). `ScrollView` si auto-posiziona sul livello corrente con `scrollTo + anchor .center`. Linee di connessione: `Path` + `QuadCurve` con stroke tratteggiato.

---

## 11. Test

La suite `JellyMixTests` copre il `GameViewModel` con unit test suddivisi per dominio.

| File Test | Aspetti Coperti |
|---|---|
| `GameViewModelTests+Gameplay` | Posizionamento, merge base, hold piece, cascate |
| `GameViewModelTests+Levels` | Caricamento livelli da JSON, reset, parsing griglia, unlock per-mondo |
| `GameViewModelTests+Lives` | Perdita vita, recupero offline, timer |
| `GameViewModelTests+PowerUps` | Hammer, Swap, Brush — effetti e contatori |
| `GameViewModelTests+Shop` | Acquisto bustina, pull rates, unlock gelatine |
| `GameViewModelTests+SpecialCells` | Nastri, generatori, espansione liquirizia |

I test usano `loadLevelsFromBundle()` per evitare dipendenze di rete.

---

## 12. Considerazioni per il Porting Android

### 12.1 Mappatura Tecnologica

| Componente iOS | Equivalente Android (Kotlin) |
|---|---|
| SwiftUI View + `@ObservedObject` | Jetpack Compose + ViewModel + StateFlow |
| `ObservableObject` + `@Published` | ViewModel + `MutableStateFlow<T>` |
| UserDefaults | DataStore Preferences (o SharedPreferences) |
| `UNUserNotificationCenter` locale | NotificationManager + WorkManager / AlarmManager |
| Firebase Messaging | Firebase Messaging SDK Android (stesso backend) |
| `URLSession` async/await | Retrofit + OkHttp con Coroutines |
| Bundle JSON (`worlds.json`) | `assets/worlds.json` |
| FileManager Documents dir | `Context.filesDir` |
| `Timer.scheduledTimer` | `CountDownTimer` o `Handler.postDelayed` |
| `NotificationCenter` interno | `SharedFlow` / EventBus |
| `AppDelegate` | `FirebaseApp.initializeApp` in `Application.onCreate` |
| `LazyVGrid` 5×5 | `LazyVerticalGrid(GridCells.Fixed(5))` |
| `Animation .spring()` | `spring()` / `animateFloatAsState` in Compose |
| `rotation3DEffect` | `graphicsLayer { rotationY = ... }` |

### 12.2 Logica Portabile Direttamente

La logica di gioco è platform-agnostic e può essere estratta quasi verbatim in Kotlin:

- `processMerges()` — BFS/DFS su matrice
- `processConveyors()` e `processGenerators()`
- `espandiLiquirizia()` / `licoriceExpand()`
- `gestisciDistruzioneOstacolo()` / `handleObstacleDestruction()`
- `checkWinLoseConditions()`
- `calcolaTempoOffline()` — logica matematica identica
- `getPullRates()` e `buyAndOpenPack()`

### 12.3 Punti di Attenzione

- **Freeze post-merge con ghiaccio**: la cella risultante viene congelata 3 turni — verificare che il decremento a fine turno sia incluso
- **Ordinamento nastri**: critico per evitare double-move; testare con livelli che hanno nastri concatenati
- **Rainbow priority**: l'ordine `[.purple, .yellow, .orange, .green, .blue, .red]` in `possibleTargets` deve essere rispettato
- **Persistenza vite in background**: su Android usare `onStop()` di Activity o `lifecycleScope` per garantire il salvataggio prima di qualsiasi shutdown
- **FCM cold start**: il retry con timeout 60 s va replicato su Android
- **DataUserService è un placeholder vuoto**: da implementare su entrambe le piattaforme

### 12.4 Struttura Consigliata per Android

```
data/model/      — data class equivalenti a Jelly, ElementType, WorldData, LevelData
data/network/    — Retrofit service + DTOs
data/cache/      — Repository con Room o JSON su disco
domain/          — GameEngine.kt (logica pura, zero dipendenze Android)
ui/game/         — GameScreen composable + GameViewModel
ui/map/          — SagaMapScreen composable
ui/shop/         — ShopScreen composable
ui/collection/   — CollectionScreen composable
service/         — NotificationService, FCMService (FirebaseMessagingService)
```

---

## Appendice — Formato JSON Livello

Esempio di struttura JSON per un livello con nastri e generatori:

```json
{
  "id": "uuid-123",
  "levelNumber": 10,
  "levelIndex": 3,
  "movesLimit": 20,
  "objective": { "type": "JELLY", "targetColor": "BLUE", "required": 3 },
  "grid": [
    ["CONVEYOR_RIGHT", "EMPTY", "GENERATOR_ICE", "EMPTY", "EMPTY"],
    ["EMPTY", "RED",   "EMPTY", "BLUE",  "EMPTY"],
    ["EMPTY", "EMPTY", "EMPTY", "EMPTY", "EMPTY"],
    ["EMPTY", "WAFFLE","EMPTY", "HONEY", "EMPTY"],
    ["EMPTY", "EMPTY", "TREASURE","EMPTY","ROCK"]
  ],
  "availablePieces": [
    { "type": "RED",  "point": 0   },
    { "type": "BLUE", "point": 100 }
  ]
}
```

Valori validi per `grid`:
`RED`, `BLUE`, `GREEN`, `ORANGE`, `YELLOW`, `PURPLE`, `ICE`, `WAFFLE`, `LICORICE`, `HONEY`, `TREASURE`, `ROCK`, `EMPTY`, `CONVEYOR_LEFT/RIGHT/UP/DOWN`, `GENERATOR_<tipo>`

---

*— Fine documento —*
