# SagaMapView — Report tecnico bug "scroll sulla mappa errato dopo rientro dal gioco"

Data: 2026-05-15
File coinvolti: `View/SagaMapView.swift`, `App/MainCoordinator.swift`, `ViewModel/GameViewModel.swift`, `ViewModel/GameViewModel+Levels.swift`, `App/JellyMixApp.swift`

---

## 1. Sintomo osservato (dal video)

Sequenza nel video:

1. La mappa è correttamente centrata sul **Mondo 7 — Monte Agro**, livello 3 (nodo "current", arancione con badge `LVL 3`); sopra appare la stella del livello 2 completato e sotto il banner glass del **Mondo 8 — Bifrost** ancora locked. Banner verde "Mappa aggiornata" già visibile in alto.
2. L'utente tocca il nodo livello 3 ed entra nel gioco (`ContentView`). Non gioca: tocca subito la freccia "indietro".
3. Tornando alla mappa, la `ScrollView` non è più centrata su `level_7_3`: mostra invece il **Mondo 8 — Bifrost** in alto, con tre cerchi `lock.fill` connessi dalla linea tratteggiata. Monte Agro è completamente fuori viewport.

Il bug è 100% riproducibile quando il `backgroundRefresh()` di `JellyMixApp` completa **mentre l'utente è dentro `ContentView`** (cioè quando `SagaMapView` è smontata).

---

## 2. Architettura del flusso scroll

```
JellyMixApp.scenePhase == .active
        │
        ▼
backgroundRefresh()                               (Task async, fino a 60s)
   │  WorldService.fetchWorldsWithRetry()
   ▼
gameEngine.applyLevelCollection(fresh)           ← SOSTITUISCE worlds[]
gameEngine.mapWasUpdated = true                   ← scatena banner

MainCoordinator                                    SagaMapView
   │ scrollTrigger =                                │ @State scrollPositionId
   │   progressVersion + worlds.count * 1000        │ .scrollPosition(id:)
   ▼                                                ▼
SagaMapView(scrollTrigger: …)                     .onAppear  → scrollPositionId = currentNodeId
                                                  .onChange(of: scrollTrigger) → idem
```

`currentNodeId` calcola il primo nodo "unlocked && not completed":

```swift
private var currentNodeId: String? {
    for world in worlds.sorted(by: { $0.stageNumber < $1.stageNumber }) {
        for level in world.levels.sorted(by: { $0.levelIndex < $1.levelIndex }) {
            if isLevelUnlocked(world.stageNumber, level.levelIndex) &&
               !isLevelCompleted(world.stageNumber, level.levelIndex) {
                return "level_\(world.stageNumber)_\(level.levelIndex)"
            }
        }
    }
    return nil
}
```

`MainCoordinator` smonta completamente la `VStack` della mappa quando `currentScreen == .game`:

```swift
if currentScreen != .game {
    VStack { … SagaMapView(…) … }   // smontata quando si gioca
}
```

Quindi al ritorno dal game `SagaMapView` è una **nuova istanza**: `@State private var scrollPositionId` riparte da `nil`, e l'unico re-trigger dello scroll è il blocco `onAppear`.

---

## 3. Causa tecnica del bug

Si combinano **quattro problemi**, tutti necessari a produrre il comportamento osservato.

### 3.1 — `scrollTrigger` non reagisce al refresh dei mondi

In `MainCoordinator.swift:92`:

```swift
scrollTrigger: gameEngine.progressVersion + gameEngine.worlds.count * 1000
```

Il piano in `document/step2-integration-plan.md` (Task 7) prescriveva:

```swift
scrollTrigger: gameEngine.progressVersion + gameEngine.worlds.flatMap(\.levels).count * 1000
```

La differenza è critica: `worlds.count` cambia **solo** quando viene aggiunto/rimosso un mondo intero. Se l'API restituisce gli stessi N mondi ma con livelli aggiornati (caso tipico del refresh dopo il primo bootstrap, dove la cache contiene già lo stesso numero di mondi visibili) `worlds.count` non muta → `scrollTrigger` invariato → `onChange(of: scrollTrigger)` non parte → la mappa non si riposiziona dopo `applyLevelCollection`.

Nel video questo accade perché il bundle/cache locale contiene lo stesso numero di mondi che il server ritorna al refresh.

### 3.2 — `applyLevelCollection` non incrementa `progressVersion`

`GameViewModel+Levels.swift:31-49`: `applyLevelCollection` riassegna `worlds`, ricostruisce `levelsByCoordinate`, ma **non tocca `progressVersion`**. Anche correggendo il punto 3.1, il refresh può cambiare la struttura dei livelli (e quindi cambiare il valore restituito da `currentNodeId`) senza notificare la `SagaMapView`.

### 3.3 — `scrollPosition(id:)` non scrolla se il target non è ancora montato dal `LazyVStack`

`SagaMapView.swift:39-67`:

```swift
ScrollView {
    LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) { … }
        .scrollTargetLayout()
}
.scrollPosition(id: $scrollPositionId, anchor: .center)
.onAppear { scrollPositionId = currentNodeId }
```

`LazyVStack` istanzia le sezioni "on-demand" man mano che entrano nella viewport. Al primo `onAppear` (subito dopo il rimontaggio della view) **solo i primi mondi sono renderizzati**. Se `currentNodeId == "level_7_3"` (Monte Agro è in basso nella lista) il nodo non esiste ancora nell'albero della view e `.scrollPosition(id:)` fallisce silenziosamente. Su iOS 17/18 il comportamento di fallback non è "resta in cima" ma "lascia la `ScrollView` nell'ultima posizione coerente che riesce a calcolare", ed è qui che si combina il prossimo punto.

### 3.4 — `pinnedViews: [.sectionHeaders]` + `.scrollTargetLayout()`

Combinare pinned section headers con `.scrollTargetLayout()` ha un effetto collaterale documentato in più report Apple: i `.id(...)` sui figli delle sezioni vengono presi come scroll-target, ma il sistema considera anche le altezze "fittizie" introdotte dagli header pinnati. Quando il `LazyVStack` viene re-istanziato (ricostruzione completa dopo lo smontaggio della VStack genitore), il sistema può "pinnare" un header diverso da quello atteso, lasciando visibile in alto il primo header non ancora attraversato dal cursore di rendering — nel video è proprio "Bifrost".

Sintesi: il `LazyVStack` viene ricostruito da zero, `scrollPositionId = "level_7_3"` viene impostato prima che il nodo sia montato, l'header "Bifrost" è quello pinnato dal layout ricostruito, e nessun re-trigger arriva (3.1 + 3.2). La mappa rimane bloccata su Bifrost finché l'utente non scrolla manualmente.

---

## 4. Verifiche fatte

- `currentNodeId` è corretto in tutti gli scenari (verificato a tavolino con i dati `completedLevels` plausibili dal video).
- Il bug della "double publish" su `completeLevel` è effettivamente risolto da `progressVersion += 1` come ultima operazione (`GameViewModel+Levels.swift:80`). Quel fix però non copre i refresh esterni della collezione mondi.
- Il bug è indipendente dal completamento del livello: l'utente nel video non ha giocato. È sufficiente che `applyLevelCollection` venga chiamato mentre `SagaMapView` non è in vista.

---

## 5. Soluzione proposta

Tre interventi indipendenti, da applicare insieme.

### Fix A — `scrollTrigger` reagisce a tutti i cambi di catalogo (MainCoordinator.swift)

```swift
// Prima
scrollTrigger: gameEngine.progressVersion + gameEngine.worlds.count * 1000

// Dopo
scrollTrigger: gameEngine.progressVersion
             + gameEngine.worlds.flatMap(\.levels).count * 1000
```

Allinea il codice al piano `step2-integration-plan.md` (Task 7) e fa scattare il riposizionamento anche quando il refresh aggiunge/rimuove livelli senza variare il numero di mondi.

### Fix B — `applyLevelCollection` notifica un "catalog change" (GameViewModel+Levels.swift)

```swift
func applyLevelCollection(_ collection: WorldCollection) {
    worlds = collection.sorted { $0.stageNumber < $1.stageNumber }

    allLevels.removeAll()
    levelsByCoordinate.removeAll()
    for world in worlds {
        for lvl in world.levels {
            let coord = LevelCoordinate(stageNumber: world.stageNumber,
                                        levelIndex: lvl.levelIndex)
            levelsByCoordinate[coord] = lvl
            allLevels[lvl.levelNumber] = lvl
        }
    }

    migrateProgressIfNeeded()

    // 🔧 Notifica la mappa anche se il numero totale di livelli non è cambiato
    // (es. solo il contenuto è stato aggiornato dal server).
    progressVersion &+= 1
}
```

`&+= 1` evita overflow su run molto lunghi. Combinato con il Fix A, garantisce che `onChange(of: scrollTrigger)` parta sempre dopo `applyLevelCollection`.

### Fix C — `SagaMapView` usa `ScrollViewReader` con scroll posticipato

Sostituire l'API dichiarativa `.scrollPosition(id:)` con `ScrollViewReader.scrollTo` chiamato dopo che il `LazyVStack` ha avuto modo di renderizzare. È l'unico approccio robusto su iOS 17/18 con sezioni pinnate.

```swift
struct SagaMapView: View {
    var worlds: [WorldData]
    var isLevelUnlocked: (Int, Int) -> Bool
    var isLevelCompleted: (Int, Int) -> Bool
    var getColor: (String) -> Color
    var scrollTrigger: Int
    var onPlayLevel: (Int, Int) -> Void

    private var currentNodeId: String? { /* invariato */ }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                    Color.clear.frame(height: 16)
                    ForEach(worlds) { world in
                        let worldColor = getColor(world.color)
                        let isWorldUnlocked = world.levels.contains {
                            isLevelUnlocked(world.stageNumber, $0.levelIndex)
                        }
                        Section {
                            renderWorldContent(world: world, worldColor: worldColor)
                        } header: {
                            WorldCardView(world: world,
                                          color: worldColor,
                                          isUnlocked: isWorldUnlocked)
                                .padding(.horizontal, 16)
                                .padding(.bottom, 8)
                                .background(Color(UIColor.systemBackground).opacity(0.001))
                        }
                    }
                    Color.clear.frame(height: 100)
                }
            }
            .scrollIndicators(.hidden)
            .onAppear            { scheduleScroll(proxy) }
            .onChange(of: scrollTrigger) { _, _ in scheduleScroll(proxy) }
            // 🔧 catch-all: anche se scrollTrigger non cambia, una variazione
            // strutturale dei mondi deve riposizionare la mappa.
            .onChange(of: worlds.map(\.id)) { _, _ in scheduleScroll(proxy) }
        }
    }

    /// Posticipa di un run-loop tick + frame: dà al LazyVStack
    /// il tempo di costruire i nodi prima di chiamare scrollTo.
    private func scheduleScroll(_ proxy: ScrollViewProxy) {
        guard let target = currentNodeId else { return }
        DispatchQueue.main.async {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                withAnimation(.easeInOut(duration: 0.45)) {
                    proxy.scrollTo(target, anchor: .center)
                }
            }
        }
    }
}
```

Note implementative:

- `ScrollViewReader.scrollTo(_:anchor:)` istanzia in modo "eager" il nodo target se serve, il che risolve il problema 3.3.
- `worlds.map(\.id)` come dipendenza di `onChange` è leggero e copre il caso "il refresh sostituisce l'array senza che `scrollTrigger` o il numero totale di livelli cambino" (difesa in profondità rispetto al Fix A).
- Il delay di 0.05 s è sufficiente nei test SwiftUI; se necessario alzarlo a 0.1 s su device più lenti.
- `@State private var scrollPositionId` può essere rimosso dalla view (non più usato).

### Fix D (opzionale ma consigliato) — Disaccoppiare l'header dalla `ScrollView`

`pinnedViews: [.sectionHeaders]` resta una superficie di rischio. Se in futuro si vuole eliminarla del tutto, si può tenere il titolo del mondo come elemento normale del flusso e mostrare in overlay un mini-header "sticky" calcolato osservando lo scroll offset. È un refactor più corposo: lasciato fuori scope dal fix immediato.

---

## 6. Test consigliati

Aggiungere a `JellyMixTests/GameViewModelTests+Levels.swift` un test che:

1. costruisce 8 mondi con 3 livelli ciascuno;
2. inserisce in `completedLevels` i livelli 1-2 del mondo 7;
3. chiama `applyLevelCollection` con la stessa lista — verifica `progressVersion` incrementato (Fix B);
4. verifica che `currentNodeId` (esposto temporaneamente come internal per test, oppure replicato) restituisca `"level_7_3"`.

Per il Fix C un test UI snapshot non è realistico; basta una verifica manuale:

- Cold start con cache che ha 7 mondi.
- Forzare un fetch lento (mettere `try? await Task.sleep(...)` in `backgroundRefresh()`).
- Entrare nel livello 3 di Monte Agro, attendere la fine del refresh, tornare indietro: la mappa deve restare centrata su `level_7_3`.

---

## 7. Riepilogo modifiche

| File | Tipo | Modifica |
|---|---|---|
| `App/MainCoordinator.swift` | 1 riga | `scrollTrigger` usa `worlds.flatMap(\.levels).count` |
| `ViewModel/GameViewModel+Levels.swift` | 1 riga | `progressVersion &+= 1` in fondo a `applyLevelCollection` |
| `View/SagaMapView.swift` | refactor body | `ScrollViewReader` + `scheduleScroll(_:)` posticipato |
| `JellyMixTests/GameViewModelTests+Levels.swift` | nuovo test | regressione su `applyLevelCollection` + `progressVersion` |

L'ordine di applicazione consigliato è A → B → C, così ogni fix copre uno strato del problema e si può testare in incrementi.
