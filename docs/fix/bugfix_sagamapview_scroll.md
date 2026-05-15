# BugFix — SagaMapView scroll errato al ritorno dal gioco

**Data:** 2026-05-15  
**File modificati:** `App/MainCoordinator.swift`, `View/SagaMapView.swift`  
**Symptom originale:** tornando dal gioco, la mappa non centrava il livello corrente (prima: Bifrost/World 8; poi dopo fix parziale: World 1 Level 3)

---

## Bug A — `currentNodeId` restituiva il livello sbagliato

### Causa

`currentNodeId` in `SagaMapView` itera su tutti i mondi/livelli e restituisce il primo che risulta "sbloccato ma non completato". La closure `isLevelCompleted` passata da `MainCoordinator` controllava solo `completedLevels`:

```swift
// SBAGLIATO
isLevelCompleted: { gameEngine.completedLevels.contains(LevelCoordinate(stageNumber: $0, levelIndex: $1)) }
```

`mergeServerProgress` può marcare un mondo come completato in `completedWorlds` usando il `serverCursor.levelIndex` del server (es. 2 su 3 livelli totali), senza inserire **tutti** i levelIndex in `completedLevels`. Risultato: il livello 1-3 risultava "sbloccato" (via `completedWorlds`) ma "non completato" (non in `completedLevels`), e `currentNodeId` lo restituiva prima del corretto livello al mondo 7.

### Fix

```swift
// CORRETTO
isLevelCompleted: { stageNumber, levelIndex in
    gameEngine.completedLevels.contains(LevelCoordinate(stageNumber: stageNumber, levelIndex: levelIndex))
    || gameEngine.completedWorlds.contains(stageNumber)
}
```

Se un mondo è in `completedWorlds`, **tutti** i suoi livelli sono considerati completati dalla UI, indipendentemente da cosa c'è in `completedLevels`.

### Regression test manuale

1. Simulare uno scenario `mergeServerProgress` con `isWorldComplete = true` e `currentLevel.levelIndex` < numero massimo di livelli del mondo.
2. Verificare che `currentNodeId` **non** punti a un livello all'interno di quel mondo.
3. Verificare che `currentNodeId` punti al primo livello del mondo successivo non completato.

---

## Bug B — `proxy.scrollTo` falliva silenziosamente

### Causa

In `MainCoordinator`, la `VStack` contenente `SagaMapView` era condizionale:

```swift
// SBAGLIATO
if currentScreen != .game {
    VStack { ... SagaMapView(...) ... }
}
```

Ogni volta che l'utente entrava in gioco, `SagaMapView` veniva **smontata completamente**. Al ritorno, veniva rimontata da zero. Il `LazyVStack` interno ripartiva senza nodi renderizzati: solo i primi 2-3 mondi venivano costruiti immediatamente. La chiamata `proxy.scrollTo("level_7_3")` (anche con il delay di 50ms) falliva silenziosamente perché il nodo non era ancora nell'albero delle view. La mappa rimaneva in cima (World 1) o nella posizione default del layout.

### Fix

La `VStack` è ora **sempre montata**. Viene nascosta tramite opacity durante il gioco, senza smontarla:

```swift
// CORRETTO
VStack { ... SagaMapView(...) ... }
    .opacity(currentScreen != .game ? 1 : 0)
    .allowsHitTesting(currentScreen != .game)
    .zIndex(0)
```

`ContentView` (il gioco) è sovrapposta con `.zIndex(1)` e rimane condizionale (`if currentScreen == .game`), così viene comunque animata in entrata/uscita.

### Perché funziona

- `SagaMapView` non viene mai smontata → `LazyVStack` mantiene i nodi già renderizzati.
- Al ritorno dal gioco `onAppear` non si riattiva (la view era rimasta montata) → nessuno scroll spurio.
- Se `progressVersion` o `worlds` cambiano (livello completato o refresh API), `onChange` in `SagaMapView` chiama `scheduleScroll` normalmente.
- Se l'utente torna indietro senza aver giocato e senza che sia arrivato un refresh, la mappa resta esattamente dove l'aveva lasciata: comportamento corretto.

### Regression test manuale

1. Aprire la mappa centrata su un livello in un mondo avanzato (es. World 7 Level 3).
2. Toccare il nodo ed entrare in `ContentView`.
3. Tornare indietro **senza** giocare.
4. Verificare che la mappa sia ancora centrata su World 7 Level 3.
5. Ripetere il test aspettando che il `backgroundRefresh` completi mentre si è in gioco (controllare il banner "Mappa aggiornata" al ritorno): la mappa deve restare centrata sul livello corretto.

---

## Architettura dello scroll (riferimento rapido)

```
scrollTrigger = progressVersion + worlds.flatMap(\.levels).count * 1000
                        │
          cambia quando: completeLevel()
                         applyLevelCollection()   ← background refresh
                         mergeServerProgress()    ← sync server

SagaMapView.onChange(of: scrollTrigger) → scheduleScroll(proxy)
SagaMapView.onChange(of: worlds.map(\.id)) → scheduleScroll(proxy)  ← catch-all
SagaMapView.onAppear → scheduleScroll(proxy)  ← primo mount / cold start

scheduleScroll:
  DispatchQueue.main.async {
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
      proxy.scrollTo(currentNodeId, anchor: .center)
    }
  }
```

`currentNodeId` = primo livello con `isUnlocked == true && isLevelCompleted == false`, iterando per `stageNumber` e `levelIndex` crescenti.

---

## Checklist se il bug si ripresenta

| Sintomo | Dove guardare |
|---|---|
| Scroll va a un livello in un mondo già completato | `isLevelCompleted` closure in `MainCoordinator` — verificare che controlli `completedWorlds` |
| Scroll va in cima (World 1) al ritorno dal gioco | `MainCoordinator` — verificare che la `VStack` sia always-mounted (no `if currentScreen != .game`) |
| Scroll non parte dopo completamento livello | `GameViewModel+Levels.swift` — verificare `progressVersion &+= 1` in `applyLevelCollection` e `progressVersion += 1` in `completeLevel` |
| `currentNodeId` è `nil` | Tutti i livelli risultano completati — probabile bug in `isLevelCompleted` che restituisce `true` dove non dovrebbe |
| Scroll parte ma arriva nel posto sbagliato | `currentNodeId` — verificare la logica di `isUnlocked` e `isLevelCompleted`; loggare il valore prima di `proxy.scrollTo` |
