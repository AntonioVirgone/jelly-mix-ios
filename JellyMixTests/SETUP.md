# Setup Test Target in Xcode

I file `.swift` in questa cartella sono pronti. Prima di poterli compilare devi
aggiungere il **test target** al progetto Xcode (operazione una-tantum).

## Passi

1. Apri `JellyMix.xcodeproj` in Xcode
2. Clicca sul progetto (icona blu in alto nel Project Navigator)
3. Nella colonna **TARGETS** premi **+** (in basso a sinistra)
4. Scegli **Unit Testing Bundle** → Next
5. Imposta:
   | Campo | Valore |
   |---|---|
   | Product Name | `JellyMixTests` |
   | Team | (il tuo team) |
   | Organization Identifier | `it.vertexlab` |
   | Language | Swift |
   | Project | JellyMix |
   | Target to be Tested | **JellyMix** |
6. Clicca **Finish**

Xcode creerà `JellyMixTests/JellyMixTests.swift` (placeholder).
Puoi **eliminare quel file**: i test veri sono già qui.

## Aggiungi i file esistenti al target

7. Seleziona tutti i file `.swift` in questa cartella (inclusa `Helpers/`)
8. Nel pannello **File Inspector** (destra) → **Target Membership** → spunta `JellyMixTests`

## Verifica Build Settings del target

Nel target `JellyMixTests`:
- **Testing Framework** → Swift Testing  
- **Host Application** → JellyMix  
  _(indispensabile: carica `levels.json` da Bundle.main)_

## Esecuzione

```bash
# Da terminale
xcodebuild test \
  -project JellyMix.xcodeproj \
  -scheme JellyMix \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest'

# Oppure da Xcode: Cmd+U
```

## Note sui test

- Tutti i test usano `@MainActor` per compatibilità con `ObservableObject`
- `GameViewModel.makeForTesting()` crea istanze isolate (non legge UserDefaults persistito)
- I test con JSON (`resetGame_withKnownLevel_*`) si saltano automaticamente se il
  bundle non contiene `levels.json` (host app non collegata)
