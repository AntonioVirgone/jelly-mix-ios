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
    
    // MARK: - Algoritmo di Fusione (Merge)
    // Restituisce 'true' se è stata effettuata una fusione N+1
    private func processMerges(startRow: Int, startCol: Int) -> Bool {
        let currentFocus = (r: startRow, c: startCol)
        var hasMerged = true
        var earnedRainbow = false

        // Usiamo un ciclo while per gestire le reazioni a catena
        while hasMerged {
            hasMerged = false
            let currentIndex = getIndex(row: currentFocus.r, col: currentFocus.c)
            let currentType = grid[currentIndex].type
            
            // Il Jolly (0) non può innescare un merge da solo, deve essere posizionato
            // Quindi qui cerchiamo colori normali o la logica speciale del Jolly
            guard currentType != .empty && currentType.rawValue < 7 else { break }
            
            // LOGICA JOLLY: Se posizioniamo un Jolly, deve capire a quale colore adiacente unirsi
            var targetType = currentType
            if currentType == .rainbow {
                targetType = trovaColoreMiglioreVicinanza(r: currentFocus.r, c: currentFocus.c)
                if targetType == .empty { break } // Nessun vicino colorato
            }
            
            // Se è un rainbow, il requisito e il livello base sono quelli del targetType
            let mergeBaseType = (currentType == .rainbow) ? targetType : currentType
            let requiredToMerge = Jelly(type: mergeBaseType).requirement
            var connectedCells: [Int] = []
            var visited = Set<Int>()
            
            // Funzione ricorsiva (Depth-First Search) per trovare i vicini uguali
            func findConnected(r: Int, c: Int) {
                // Controllo dei bordi della griglia
                if r < 0 || r >= gridSize || c < 0 || c >= gridSize { return }
                
                let idx = getIndex(row: r, col: c)
                
                // Se l'abbiamo già visitata o non è dello stesso colore, esci
                if visited.contains(idx) { return }
                
                // Una cella è connessa se è del targetType O se è un Jolly
                let cellType = grid[idx].type
                if cellType == targetType || cellType == .rainbow {
                    visited.insert(idx)
                    connectedCells.append(idx)
                    
                    findConnected(r: r + 1, c: c)
                    findConnected(r: r - 1, c: c)
                    findConnected(r: r, c: c + 1)
                    findConnected(r: r, c: c - 1)
                }
            }
            
            // Avviamo la ricerca
            findConnected(r: currentFocus.r, c: currentFocus.c)
            
            // Se abbiamo abbastanza pezzi connessi, uniamoli!
            if connectedCells.count >= requiredToMerge {
                // 1. Pulisci tutte le celle coinvolte nella fusione
                // REGOLA N+1: se uniamo più del minimo, segnamo il premio
                if connectedCells.count > requiredToMerge {
                    earnedRainbow = true
                }
                
                for idx in connectedCells {
                    grid[idx].type = .empty
                }
                
                // 2. Crea la nuova gelatina evoluta nella posizione centrale
                let nextLevelRaw = mergeBaseType.rawValue + 1
                if let nextType = ElementType(rawValue: nextLevelRaw) {
                    grid[currentIndex].type = nextType

                    // 3. Aumenta il punteggio
                    score += (mergeBaseType.rawValue * 10) * connectedCells.count
                    
                    // AGGIORNAMENTO OBIETTIVI
                    if objective.type == .jelly && nextType == objective.targetColor {
                        objective.current += 1
                    }
                    
                    // 4. Riattiva il ciclo per controllare eventuali Combo!
                    hasMerged = true
                }
            }
        }
        
        return earnedRainbow
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
