//
//  GameViewModel.swift
//  JellyMix
//
//  Created by Antonio Virgone on 21/04/26.
//

import Foundation
import SwiftUI
internal import Combine

class GameViewModel: ObservableObject {
    // Costanti della griglia
    let gridSize = 5
    let totalCells: Int
    
    // MARK: - Proprietà @Published (push dei dati alla View)
    @Published var grid: [Jelly] = []
    @Published var nextJellyType: ElementType = .red
    @Published var holdPiece: ElementType? = nil // Pezzo conservato (opzionale)
    @Published var hasHeldThisTurn: Bool = false // Impedisce scambi infiniti nello stesso turno
    @Published var score: Int = 0
    @Published var keysCollected: Int = 0
    
    // Nuove variabili per lo shop
    @Published var unlockedJellies: Set<ElementType> = [.red] // Gelatine base già sbloccate
    @Published var coins: Int = 0

    // Nuove variabili per i livelli
    @Published var currentLevel: Int = 1
    @Published var movesLeft: Int? = nil // Opzionale: nil significa mosse infinite
    @Published var maxMoves: Int? = nil // Opzionale: nil significa mosse infinite
    @Published var objective: LevelObjective = LevelObjective(type: .jelly, targetColor: .blue, required: 2)
    @Published var isGameOver: Bool = false
    @Published var isLevelCompleted: Bool = false
    
    @Published var currentAvailablePieces: [AvailablePieceData] = []
    // MARK: - Merge Animation State
    struct MergeEvent: Equatable {
        let focusIndex: Int
        let color: Color
        private let token = UUID()
        static func == (lhs: Self, rhs: Self) -> Bool { lhs.token == rhs.token }
    }
    @Published var mergeEvent: MergeEvent? = nil

    // Conserviamo i dati del livello corrente per generare i pezzi giusti
    private var currentLevelData: LevelData? = nil
    // Pubblichiamo i mondi per la SagaMapView
    @Published var worlds: [WorldData] = []
    // Dizionario di tutti i livelli caricati dal JSON
    private var allLevels: [Int: LevelData] = [:]
    private var licoriceDestroyedThisTurn: Bool = false
    
    init() {
        totalCells = gridSize * gridSize
        loadLevelsFromJSON()
        resetGame(forLevel: 1)
    }
    
    // Carica il file JSON (assicurati che il file si chiami "levels.json" nel progetto Xcode)
    private func loadLevelsFromJSON() {
        guard let url = Bundle.main.url(forResource: "levels", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return }
        
        do {
            // Decodifichiamo la WorldCollection
            let collection = try JSONDecoder().decode(WorldCollection.self, from: data)
            self.worlds = collection.worlds
            
            // "Appiattiamo" i livelli in un dizionario per l'accesso rapido durante il gioco
            for world in collection.worlds {
                for lvl in world.levels {
                    allLevels[lvl.level] = lvl
                }
            }
        } catch {
            print("Errore parsing JSON: \(error)")
        }
    }

    // Inizia o ripristina la partita (equivalente a initStage di React)
    func resetGame(forLevel level: Int) {
        // Resetta statistiche
        self.currentLevel = level
        self.score = 0
        self.keysCollected = 0
        
        // Resetta il salvataggio gelatina
        self.holdPiece = nil
        self.hasHeldThisTurn = false

        self.isGameOver = false
        self.isLevelCompleted = false
        self.objective.current = 0 // Sempre azzerato prima di caricare i dati del livello

        // Se il livello esiste nel JSON, usalo. Altrimenti fallback a griglia vuota.
        if let levelData = allLevels[level] {
            self.currentAvailablePieces = levelData.availablePieces // <--- Aggiungi questa riga
            
            self.currentLevelData = levelData
            self.movesLeft = levelData.movesLimit
            self.maxMoves = levelData.movesLimit
            
            // Imposta obiettivo
            let targetType = mapStringToElementType(levelData.objective.targetColor ?? "")
            
            var objType: ObjectiveType
            
            if levelData.objective.type == "OBSTACLE" {
                objType = .obstacle
            } else if levelData.objective.type == "LICORICE" {
                objType = .licorice
            } else {
                objType = .jelly
            }
            
            self.objective = LevelObjective(type: objType, targetColor: targetType, required: levelData.objective.required)
            
            // Popola griglia
            var newGrid: [Jelly] = []
            for r in 0..<gridSize {
                for c in 0..<gridSize {
                    let cellString = levelData.grid[r][c]
                    newGrid.append(Jelly(type: mapStringToElementType(cellString)))
                }
            }
            self.grid = newGrid
            
        } else {
            // Livello non presente nel JSON: Procedurale Base
            self.currentLevelData = nil
            self.movesLeft = nil
            self.maxMoves = nil
            
            // Inizializza la griglia vuota
            self.grid = Array(repeating: Jelly(type: .empty), count: totalCells)
        }
        self.nextJellyType = generaNuovoPezzo()
    }
    
    // Genera un nuovo pezzo per il turno successivo (per ora randomico tra base)
    // Funzione aggiornata per usare i blocchi dinamici
    func generaNuovoPezzo() -> ElementType {
        if let levelData = currentLevelData {
            // Filtra solo i pezzi sbloccati (point <= score oppure point = nil)
            let unlockedPieces = levelData.availablePieces.filter { pezzo in
                let reqPoint = pezzo.point ?? 0
                return score >= reqPoint
            }
            
            if let randomPieceStr = unlockedPieces.randomElement()?.type {
                return mapStringToElementType(randomPieceStr)
            }
        }
        
        // Fallback se non ci sono dati JSON
        return unlockedJellies.randomElement() ?? .red
    }
    
    // Helper per tradurre stringa JSON in enum
    private func mapStringToElementType(_ str: String) -> ElementType {
        switch str.uppercased() {
        case "ROSSO": return .red
        case "BLU": return .blue
        case "GREEN", "VERDE": return .green
        case "ARANCIONE": return .orange
        case "GIALLO": return .yellow
        case "GHIACCIO": return .ice
        case "WAFFLE": return .waffle
        case "LIQUIRIZIA": return .licorice
        case "MIELE": return .honey
        case "TESORO": return .treasure
        case "CHIAVE": return .key
        case "VUOTO": return .empty
        default: return .empty
        }
    }
    
    // Helper utilissimo per convertire le coordinate (riga, colonna) nell'indice dell'array piatto
    func getIndex(row: Int, col: Int) -> Int {
        return row * gridSize + col
    }
    
    // MARK: - Funzione Conserva (Hold)
    func toggleHold() {
        // Possiamo scambiare solo se non lo abbiamo già fatto in questo turno
        guard !hasHeldThisTurn && !isGameOver && !isLevelCompleted else { return }

        if let currentlyHeld = holdPiece {
            // Se c'è già un pezzo, scambiamolo con quello attuale
            let temp = nextJellyType
            nextJellyType = currentlyHeld
            holdPiece = temp
        } else {
            // Se il box è vuoto, sposta il pezzo attuale nel box e generane uno nuovo
            holdPiece = nextJellyType
            nextJellyType = generaNuovoPezzo()
        }
        
        hasHeldThisTurn = true // Blocca ulteriori scambi per questo turno
    }
    
    // MARK: - Logica Core del Gioco
    // Funzione chiamata quando l'utente tocca una cella (at row/col)
    // Sostituisce la complessa logica DFS/Merge di React per ora
    func posizionaGelatina(row: Int, col: Int) {
        guard !isGameOver && !isLevelCompleted else { return }

        let index = getIndex(row: row, col: col)

        // Controlla che la cella sia vuota prima di piazzare
        guard grid[index].type == .empty else { return }

        // Riduciamo le mosse se c'è un limite
        if let moves = movesLeft {
            movesLeft = moves - 1
        }
        
        // Piazza la gelatina del prossimo turno
        grid[index].type = nextJellyType
        hasHeldThisTurn = false // Reset del blocco Conserva

        // Eseguiamo i merge e controlliamo se meritiamo un Jolly
        let meritatoJolly = processMerges(startRow: row, startCol: col)
        
        if meritatoJolly {
            nextJellyType = .rainbow // Il prossimo pezzo sarà il Jolly!
        } else {
            nextJellyType = generaNuovoPezzo()
        }
        
        // Controlli di fine partita
        checkWinLoseConditions()
    }
    
    // MARK: - Algoritmo di Fusione (Merge) e Ostacoli
    private func processMerges(startRow: Int, startCol: Int) -> Bool {
        let currentFocus = (r: startRow, c: startCol)
        var hasMerged = true
        var earnedRainbow = false
        licoriceDestroyedThisTurn = false // Resettiamo ad ogni mossa

        while hasMerged {
            hasMerged = false
            let currentIndex = getIndex(row: currentFocus.r, col: currentFocus.c)
            let currentType = grid[currentIndex].type
            
            guard currentType != .empty && currentType.rawValue < 7 else { break }
            
            // 1. Troviamo i possibili "Target" per la fusione
            var possibleTargets: [ElementType] = []

            if currentType == .rainbow {
                // IL FIX: Il Jolly prova TUTTI i colori possibili, partendo dal livello più alto
                // per cercare la combo migliore, ignorando i vicini per evitare blocchi.
                possibleTargets = [.brown, .yellow, .orange, .green, .blue, .red]
            } else {
                possibleTargets = [currentType]
            }

            // 2. Prova a fare la fusione per ogni colore target possibile
            for targetType in possibleTargets {
                let mergeBaseType = (currentType == .rainbow) ? targetType : currentType
                let requiredToMerge = Jelly(type: mergeBaseType).requirement
                var connectedCells: [Int] = []
                var visited = Set<Int>()
                
                // DFS Ricerca
                func findConnected(r: Int, c: Int) {
                    if r < 0 || r >= gridSize || c < 0 || c >= gridSize { return }
                    let idx = getIndex(row: r, col: c)
                    if visited.contains(idx) { return }
                    
                    let cell = grid[idx]
                    if (cell.type == targetType || cell.type == .rainbow) && !cell.isFreeze {
                        visited.insert(idx)
                        connectedCells.append(idx)
                        
                        findConnected(r: r + 1, c: c)
                        findConnected(r: r - 1, c: c)
                        findConnected(r: r, c: c + 1)
                        findConnected(r: r, c: c - 1)
                    }
                }
                
                findConnected(r: currentFocus.r, c: currentFocus.c)
                
                // FIX DI SICUREZZA: Controlliamo che nel gruppo ci sia ALMENO una gelatina del colore vero.
                // Evita che 3 o 4 Jolly si uniscano tra loro senza un colore bersaglio
                let containsActualTarget = connectedCells.contains { grid[$0].type == targetType }
                
                // LA FUSIONE AVVIENE
                if connectedCells.count >= requiredToMerge && containsActualTarget {
                    if connectedCells.count > requiredToMerge { earnedRainbow = true }
                    
                    // A. Rompi ostacoli adiacenti SOLO al focus
                    // Controlla prima se c'è ghiaccio tra i vicini (per congelare il risultato)
                    var iceDestroyedThisMerge = false
                    let focusNeighbors = [
                        (currentFocus.r - 1, currentFocus.c), (currentFocus.r + 1, currentFocus.c),
                        (currentFocus.r, currentFocus.c - 1), (currentFocus.r, currentFocus.c + 1)
                    ]
                    for (nr, nc) in focusNeighbors {
                        if nr >= 0 && nr < gridSize && nc >= 0 && nc < gridSize {
                            let nIdx = getIndex(row: nr, col: nc)
                            if grid[nIdx].type == .ice { iceDestroyedThisMerge = true }
                            gestisciDistruzioneOstacolo(at: nIdx)
                        }
                    }

                    // B. Rimuovi le gelatine unite
                    for idx in connectedCells {
                        grid[idx].type = .empty
                    }

                    // C. Crea la nuova gelatina evoluta
                    let nextLevelRaw = mergeBaseType.rawValue + 1
                    if let nextType = ElementType(rawValue: nextLevelRaw) {
                        grid[currentIndex].type = nextType
                        mergeEvent = MergeEvent(focusIndex: currentIndex, color: nextType.config.color)
                        score += (mergeBaseType.rawValue * 10) * connectedCells.count

                        if objective.type == .jelly && nextType == objective.targetColor {
                            objective.current += 1
                        }

                        // Se è stato rotto un ghiaccio adiacente, congela la gelatina per 2 turni
                        if iceDestroyedThisMerge {
                            grid[currentIndex].isFreeze = true
                            grid[currentIndex].freezeTurnsLeft = 3
                        }

                        hasMerged = true
                        break // IMPORTANTE: Interrompiamo il for-loop perché abbiamo trovato una fusione valida!
                    }
                }
            }
        }
        
        processaFineTurno() // Espansione liquirizia

        return earnedRainbow
    }
    
    // Funzione Helper per rompere gli ostacoli
    private func gestisciDistruzioneOstacolo(at index: Int) {
        let type = grid[index].type
        guard type.config.isObstacle else { return }
        
        switch type {
        case .ice:
            grid[index].type = .empty
            score += 50
            if objective.type == .obstacle { objective.current += 1 }
        case .waffle:
            grid[index].type = .brokenWaffle // Si rompe a metà
            score += 20
        case .brokenWaffle:
            grid[index].type = .empty
            score += 50
            if objective.type == .obstacle { objective.current += 1 }
        case .licorice:
            grid[index].type = .empty
            licoriceDestroyedThisTurn = true
            score += 80
            if objective.type == .licorice { objective.current += 1 }
        case .honey:
            grid[index].type = .empty
            score += 60
            if objective.type == .obstacle { objective.current += 1 }
            // TODO: Aggiungeremo lo spargimento del miele
        case .treasure:
            if keysCollected > 0 {
                grid[index].type = .empty
                coins += 250 // Non è considerato un ostacolo
                keysCollected -= 1
            }
        case .key:
            grid[index].type = .empty
            keysCollected += 1
        default:
            break
        }
    }
    
    // Espansione Liquirizia a fine turno
    private func processaFineTurno() {
        // Decrementa i turni di congelamento per tutte le gelatine congelate
        for i in grid.indices where grid[i].isFreeze {
            grid[i].freezeTurnsLeft -= 1
            if grid[i].freezeTurnsLeft <= 0 {
                grid[i].isFreeze = false
                grid[i].freezeTurnsLeft = 0
            }
        }

        guard !licoriceDestroyedThisTurn else { return }
        
        let licoriceIndices = grid.indices.filter { grid[$0].type == .licorice }
        var hasExpanded = false
    
        // 1. Aumentiamo la probabilità: ogni liquirizia ha il 40% di chance di diffondersi
        for idx in licoriceIndices {
            if Double.random(in: 0...1) < 0.40 {
                if espandiLiquirizia(da: idx) {
                    hasExpanded = true
                }
            }
        }
        
        // 2. LA REGOLA D'ORO: Se sei stato "fortunato" e nessuna si è espansa con il 40%,
        // il gioco ne FORZA l'espansione di almeno una per mantenere alta la pressione!
        if !hasExpanded {
            if let randomLicorice = licoriceIndices.randomElement() {
                _ = espandiLiquirizia(da: randomLicorice)
            }
        }
    }
     
    // Helper per trovare una casella vuota vicina e infettarla
    private func espandiLiquirizia(da index: Int) -> Bool {
        let r = index / gridSize
        let c = index % gridSize
        let neighbors = [(r-1, c), (r+1, c), (r, c-1), (r, c+1)]
        
        // Troviamo i vicini validi che sono attualmente VUOTI
        let validEmpty = neighbors.filter { nr, nc in
            nr >= 0 && nr < gridSize && nc >= 0 && nc < gridSize && grid[getIndex(row: nr, col: nc)].type == .empty
        }
        
        // Ne scegliamo uno a caso e lo infettiamo
        if let target = validEmpty.randomElement() {
            grid[getIndex(row: target.0, col: target.1)].type = .licorice
            return true
        }
        return false
    }
    
    // Funzione che valuta se abbiamo vinto o perso dopo ogni mossa
    private func checkWinLoseConditions() {
        if objective.current >= objective.required {
            isLevelCompleted = true
        } else if let moves = movesLeft, moves <= 0 {
            isGameOver = true
            loseLife()
        } else if !grid.contains(where: { $0.type == .empty }) {
            isGameOver = true
            loseLife()
        }
    }
    
    // Funzione helper per convertire la stringa colore del JSON in Color di SwiftUI
    func getColor(from name: String) -> Color {
        switch name.lowercased() {
        case "pink": return .pink
        case "cyan": return .cyan
        case "orange": return .orange
        case "purple": return .purple
        case "blue": return .blue
        default: return .gray
        }
    }
    
    // MARK: - Logica Pacchetti Carte
    // Restituisce un array di carte pescate, oppure nil se non ci sono abbastanza monete
    func buyAndOpenPack(cost: Int = 100) -> [ElementType]? {
        guard coins >= cost else { return nil } // Controllo fondi
        
        coins -= cost // Paga il costo
        
        // Il "Pool" da cui pescare (escludiamo le base e gli ostacoli)
        // Puoi modificare le probabilità inserendo più copie delle comuni e meno copie delle rare!
        let pullRates: [ElementType] = getPullRates()
        
        var pulledCards: [ElementType] = []
        
        // Peschiamo 3 carte per bustina
        for _ in 0..<3 {
            if let randomCard = pullRates.randomElement() {
                pulledCards.append(randomCard)
                // Aggiungiamo la carta alla collezione del giocatore
                unlockedJellies.insert(randomCard)
            }
        }
        
        return pulledCards
    }
    
    func getPullRates() -> [ElementType] {
        var pullRates: [ElementType] = []
        
        for i in 0...100 {
            pullRates.append(.ice)
            if i <= 5 {
                pullRates.append(.black)
            } else if i <= 10 {
                pullRates.append(.brown)
            } else if i <= 25 {
                pullRates.append(.yellow)
            } else if i <= 40 {
                pullRates.append(.orange)
            } else if i <= 80 {
                pullRates.append(.yellow)
            } else if i <= 100 {
                pullRates.append(.orange)
            }
        }
        
        return pullRates
    }
    
    // MARK: - SISTEMA VITE
    @Published var lives: Int = 5 {
        didSet { UserDefaults.standard.set(lives, forKey: "savedLives") }
    }
    @Published var timeToNextLife: Int = 0 {
        didSet { UserDefaults.standard.set(timeToNextLife, forKey: "lastTimeToNextLife") }
    }
    
    let maxLives: Int = 5
    let secondsPerLife: Int = 300 // 300 secondi = 5 minuti (Parametrico!)
    private var livesTimer: Timer?
    
    func setupLivesSystem() {
        // Carica i dati salvati (o imposta il default a maxLives)
        if UserDefaults.standard.object(forKey: "savedLives") != nil {
            self.lives = UserDefaults.standard.integer(forKey: "savedLives")
            self.timeToNextLife = UserDefaults.standard.integer(forKey: "lastTimeToNextLife")
        } else {
            self.lives = maxLives
        }
        
        calcolaTempoOffline()
        avviaTimerVite()
        
        // Ascoltatori per calcolare il tempo quando l'app va in background/foreground
        NotificationCenter.default.addObserver(self, selector: #selector(appWentBackground), name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(appCameForeground), name: UIApplication.didBecomeActiveNotification, object: nil)
    }
    
    // Funzione da chiamare QUANDO SI PERDE UN LIVELLO
    func loseLife() {
        if lives > 0 {
            if lives == maxLives {
                timeToNextLife = secondsPerLife // Fa partire il timer se eravamo al massimo
            }
            lives -= 1
        }
    }
    
    private func avviaTimerVite() {
        livesTimer?.invalidate()
        livesTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if self.lives < self.maxLives {
                if self.timeToNextLife > 0 {
                    self.timeToNextLife -= 1
                } else {
                    self.lives += 1
                    if self.lives < self.maxLives {
                        self.timeToNextLife = self.secondsPerLife
                    }
                }
            } else {
                self.timeToNextLife = 0
            }
        }
    }
    
    @objc private func appWentBackground() {
        UserDefaults.standard.set(Date(), forKey: "lastExitDate")
    }
    
    @objc private func appCameForeground() {
        calcolaTempoOffline()
    }
    
    private func calcolaTempoOffline() {
        guard lives < maxLives else { return }
        guard let lastExit = UserDefaults.standard.object(forKey: "lastExitDate") as? Date else { return }
        
        var timeElapsed = Int(Date().timeIntervalSince(lastExit))
        var tempTime = timeToNextLife
        var tempLives = lives
        
        // Calcola quante vite e secondi sono passati mentre l'app era chiusa
        if timeElapsed >= tempTime {
            timeElapsed -= tempTime
            tempLives += 1
            
            let viteIntereRecuperate = timeElapsed / secondsPerLife
            tempLives += viteIntereRecuperate
            
            let resto = timeElapsed % secondsPerLife
            tempTime = secondsPerLife - resto
        } else {
            tempTime -= timeElapsed
        }
        
        // Assegna i nuovi valori
        if tempLives >= maxLives {
            self.lives = maxLives
            self.timeToNextLife = 0
        } else {
            self.lives = tempLives
            self.timeToNextLife = tempTime
        }
    }
}
