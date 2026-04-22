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
    @Published var currentLevel: Int = 1
    
    init() {
        totalCells = gridSize * gridSize
        resetGame()
    }
    
    // Inizia o ripristina la partita (equivalente a initStage di React)
    func resetGame() {
        // Inizializza la griglia vuota
        self.grid = Array(repeating: Jelly(type: .empty), count: totalCells)
        
        // Genera il pezzo per il prossimo turno
        self.nextJellyType = generaNuovoPezzo()
        
        // Resetta il salvataggio gelatina
        self.holdPiece = nil
        self.hasHeldThisTurn = false

        // Resetta statistiche
        self.score = 0
        self.currentLevel = 1
    }
    
    // Genera un nuovo pezzo per il turno successivo (per ora randomico tra base)
    func generaNuovoPezzo() -> ElementType {
        let options: [ElementType] = [.red, .blue, .green]
        return options.randomElement() ?? .red
    }
    
    // Helper utilissimo per convertire le coordinate (riga, colonna) nell'indice dell'array piatto
    func getIndex(row: Int, col: Int) -> Int {
        return row * gridSize + col
    }
    
    // MARK: - Funzione Conserva (Hold)
    func toggleHold() {
        // Possiamo scambiare solo se non lo abbiamo già fatto in questo turno
        guard !hasHeldThisTurn else { return }
        
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
        let index = getIndex(row: row, col: col)

        // Controlla che la cella sia vuota prima di piazzare
        guard grid[index].type == .empty else { return }
        
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
            
            let requiredToMerge = grid[currentIndex].requirement
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
                let nextLevelRaw = currentType.rawValue + 1
                if let nextType = ElementType(rawValue: nextLevelRaw) {
                    grid[currentIndex].type = nextType
                    
                    // 3. Aumenta il punteggio
                    score += (currentType.rawValue * 10) * connectedCells.count
                    
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
        var bestType: ElementType = .empty
        
        for dir in directions {
            let nr = r + dir.0, nc = c + dir.1
            if nr >= 0 && nr < gridSize && nc >= 0 && nc < gridSize {
                let type = grid[getIndex(row: nr, col: nc)].type
                if type.rawValue > 0 && type.rawValue < 7 {
                    if type.rawValue > bestType.rawValue { bestType = type }
                }
            }
        }
        return bestType
    }
}
