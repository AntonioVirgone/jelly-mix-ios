//
//  GameViewModel.swift
//  JellyMix
//
//  Created by Antonio Virgone on 21/04/26.
//

import Foundation
import SwiftUI
internal import Combine

// MARK: - Modelli per gli Obiettivi
enum ObjectiveType {
    case jelly
    case obstacle
    case licorice
}

struct LevelObjective {
    var type: ObjectiveType
    var targetColor: ElementType // Usato solo se il tipo è .jelly
    var required: Int
    var current: Int = 0
}

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
    
    // Nuove variabili per i livelli
    @Published var currentLevel: Int = 1
    @Published var movesLeft: Int? = nil // Opzionale: nil significa mosse infinite
    @Published var objective: LevelObjective = LevelObjective(type: .jelly, targetColor: .blue, required: 2)
    @Published var isGameOver: Bool = false
    @Published var isLevelCompleted: Bool = false
    
    // Conserviamo i dati del livello corrente per generare i pezzi giusti
    private var currentLevelData: LevelData? = nil
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
              let data = try? Data(contentsOf: url) else {
            print("File JSON non trovato")
            return
        }
        
        do {
            let collection = try JSONDecoder().decode(LevelCollection.self, from: data)
            for lvl in collection.levels {
                allLevels[lvl.level] = lvl
            }
        } catch {
            print("Errore nel parsing del JSON: \(error)")
        }
    }

    // Inizia o ripristina la partita (equivalente a initStage di React)
    func resetGame(forLevel level: Int) {
        // Resetta statistiche
        self.currentLevel = level
        self.score = 0
        
        // Resetta il salvataggio gelatina
        self.holdPiece = nil
        self.hasHeldThisTurn = false

        self.isGameOver = false
        self.isLevelCompleted = false
        self.objective.current = 0 // Sempre azzerato prima di caricare i dati del livello

        // Se il livello esiste nel JSON, usalo. Altrimenti fallback a griglia vuota.
        if let levelData = allLevels[level] {
            self.currentLevelData = levelData
            self.movesLeft = levelData.movesLimit
            
            // Imposta obiettivo
            let targetType = mapStringToElementType(levelData.objective.targetColor ?? "")
            let objType: ObjectiveType = levelData.objective.type == "OBSTACLE" ? .obstacle : .jelly
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
        return [.red, .blue].randomElement() ?? .red
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
            
            var targetType = currentType
            if currentType == .rainbow {
                targetType = trovaColoreMiglioreVicinanza(r: currentFocus.r, c: currentFocus.c)
                if targetType == .empty { break }
            }
            
            let mergeBaseType = (currentType == .rainbow) ? targetType : currentType
            // Adesso leggiamo requirement dal modello fluido!
            let requiredToMerge = Jelly(type: mergeBaseType).requirement
            var connectedCells: [Int] = []
            var visited = Set<Int>()
            
            func findConnected(r: Int, c: Int) {
                if r < 0 || r >= gridSize || c < 0 || c >= gridSize { return }
                let idx = getIndex(row: r, col: c)
                if visited.contains(idx) { return }
                
                let cell = grid[idx]
                if cell.type == targetType || cell.type == .rainbow {
                    visited.insert(idx)
                    connectedCells.append(idx)
                    
                    findConnected(r: r + 1, c: c)
                    findConnected(r: r - 1, c: c)
                    findConnected(r: r, c: c + 1)
                    findConnected(r: r, c: c - 1)
                }
            }
            
            findConnected(r: currentFocus.r, c: currentFocus.c)
            
            // LA FUSIONE AVVIENE
            if connectedCells.count >= requiredToMerge {
                if connectedCells.count > requiredToMerge { earnedRainbow = true }
                
                // 1. GESTIONE OSTACOLI ADIACENTI SOLO ALLA CELLA TOCCATA (currentFocus)
                let focusNeighbors = [
                    (currentFocus.r - 1, currentFocus.c),
                    (currentFocus.r + 1, currentFocus.c),
                    (currentFocus.r, currentFocus.c - 1),
                    (currentFocus.r, currentFocus.c + 1)
                ]

                for (nr, nc) in focusNeighbors {
                    if nr >= 0 && nr < gridSize && nc >= 0 && nc < gridSize {
                        let nIdx = getIndex(row: nr, col: nc)
                        gestisciDistruzioneOstacolo(at: nIdx)
                    }
                }
                
                // 2. Svuota tutte le celle coinvolte nella fusione
                for idx in connectedCells {
                    grid[idx].type = .empty
                }

                // 3. Crea la nuova gelatina evoluta
                let nextLevelRaw = mergeBaseType.rawValue + 1
                if let nextType = ElementType(rawValue: nextLevelRaw) {
                    grid[currentIndex].type = nextType
                    score += (mergeBaseType.rawValue * 10) * connectedCells.count
                    
                    if objective.type == .jelly && nextType == objective.targetColor {
                        objective.current += 1
                    }
                    
                    hasMerged = true
                }
            }
        }
        
        processaFineTurno() // Chiamata per espandere la liquirizia
        
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
        default:
            break
        }
    }
    
    // Espansione Liquirizia a fine turno
    private func processaFineTurno() {
        guard !licoriceDestroyedThisTurn else { return }
        
        let licoriceIndices = grid.indices.filter { grid[$0].type == .licorice }
        for idx in licoriceIndices {
            if Double.random(in: 0...1) < 0.20 { // 20% di probabilità
                let r = idx / gridSize
                let c = idx % gridSize
                let neighbors = [(r-1, c), (r+1, c), (r, c-1), (r, c+1)]
                let validEmpty = neighbors.filter { nr, nc in
                    nr >= 0 && nr < gridSize && nc >= 0 && nc < gridSize && grid[getIndex(row: nr, col: nc)].type == .empty
                }
                
                if let target = validEmpty.randomElement() {
                    grid[getIndex(row: target.0, col: target.1)].type = .licorice
                }
            }
        }
    }
    
    // Helper per il Jolly: trova il colore di livello più alto tra i vicini
    private func trovaColoreMiglioreVicinanza(r: Int, c: Int) -> ElementType {
        let directions = [(0,1), (0,-1), (1,0), (-1,0)]
        var bestRaw: Int = 0        // parte da 0 così qualsiasi colore reale (1-6) lo supera
        var bestType: ElementType = .empty

        for dir in directions {
            let nr = r + dir.0, nc = c + dir.1
            if nr >= 0 && nr < gridSize && nc >= 0 && nc < gridSize {
                let type = grid[getIndex(row: nr, col: nc)].type
                if type.rawValue > 0 && type.rawValue < 7 && type.rawValue > bestRaw {
                    bestRaw = type.rawValue
                    bestType = type
                }
            }
        }
        return bestType
    }
    
    // Funzione che valuta se abbiamo vinto o perso dopo ogni mossa
    private func checkWinLoseConditions() {
        if objective.current >= objective.required {
            isLevelCompleted = true
        } else if let moves = movesLeft, moves <= 0 {
            isGameOver = true
        } else if !grid.contains(where: { $0.type == .empty }) {
            isGameOver = true
        }
    }
}
