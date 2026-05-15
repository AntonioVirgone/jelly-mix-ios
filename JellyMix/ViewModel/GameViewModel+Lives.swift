//
//  GameViewModel+Lives.swift
//  JellyMix
//

import Foundation
import SwiftUI

extension GameViewModel {

    // MARK: - Server sync (Step 1)

    /// Aggiorna maxLives, secondsPerLife e il conteggio cuori usando i dati del server.
    ///
    /// Strategia fonte di verità:
    /// - I parametri di configurazione (maxHearts, heartRechargeMinutes) vengono sempre aggiornati.
    /// - Il conteggio cuori viene aggiornato **solo al primo avvio del giorno** (chiave "lastLaunchDay").
    ///   Durante la sessione il valore locale prevale, per evitare reset inattesi.
    ///   In Step 4, POST /hearts/consume sincronizzerà il server ad ogni perdita.
    @MainActor
    func applyServerUserData(profile: UserProfile, config: HeartsConfig) {
        // Salva profilo e config per la ProfileView
        self.userProfile = profile
        self.heartsConfig = config

        // Aggiorna i parametri di ricarica (rimpiazza i valori hardcoded)
        self.maxLives = config.maxHearts
        self.secondsPerLife = config.heartRechargeMinutes * 60

        // Controlla se è il primo avvio del giorno (formato YYYY-MM-DD)
        let lastLaunchDay = UserDefaults.standard.string(forKey: "lastLaunchDay") ?? ""
        let today = ISO8601DateFormatter().string(from: Date()).prefix(10).description
        guard lastLaunchDay != today else { return }

        // Primo avvio del giorno: il server è fonte di verità per il conteggio cuori.
        // Calcolo lato client: cuori attuali = heartsCount + cuori ricaricati da lastHeartConsumedAt.
        UserDefaults.standard.set(today, forKey: "lastLaunchDay")
        let currentHearts: Int
        if let lastConsumed = profile.lastHeartConsumedAt {
            let minutesPassed = Int(Date().timeIntervalSince(lastConsumed) / 60)
            let recharged = minutesPassed / config.heartRechargeMinutes
            currentHearts = min(config.maxHearts, profile.heartsCount + recharged)
        } else {
            // Nessun cuore mai consumato: usa direttamente il valore del server
            currentHearts = profile.heartsCount
        }
        self.lives = currentHearts
        if currentHearts < config.maxHearts {
            self.timeToNextLife = config.heartRechargeMinutes * 60
        }
    }

    func setupLivesSystem() {
        if UserDefaults.standard.object(forKey: "savedLives") != nil {
            self.lives = UserDefaults.standard.integer(forKey: "savedLives")
            self.timeToNextLife = UserDefaults.standard.integer(forKey: "lastTimeToNextLife")
        } else {
            self.lives = maxLives
        }

        NotificationService.requestPermission()
        calcolaTempoOffline()
        avviaTimerVite()

        NotificationCenter.default.addObserver(self, selector: #selector(appWentBackground), name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(appCameForeground), name: UIApplication.didBecomeActiveNotification, object: nil)
    }

    func loseLife() {
        guard lives > 0 else { return }
        if lives == maxLives {
            timeToNextLife = secondsPerLife
        }
        lives -= 1
    }

    private func avviaTimerVite() {
        livesTimer?.invalidate()
        livesTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
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

    @objc func appWentBackground() {
        UserDefaults.standard.set(Date(), forKey: "lastExitDate")
        NotificationService.scheduleLivesRestoredNotifications(
            currentLives: lives,
            maxLives: maxLives,
            timeToNextLife: timeToNextLife,
            secondsPerLife: secondsPerLife
        )
    }

    @objc func appCameForeground() {
        NotificationService.cancelPendingLivesNotifications()
        calcolaTempoOffline()
    }

    private func calcolaTempoOffline() {
        guard lives < maxLives else { return }
        guard let lastExit = UserDefaults.standard.object(forKey: "lastExitDate") as? Date else { return }

        var timeElapsed = Int(Date().timeIntervalSince(lastExit))
        var tempTime = timeToNextLife
        var tempLives = lives

        if timeElapsed >= tempTime {
            timeElapsed -= tempTime
            tempLives += 1
            tempLives += timeElapsed / secondsPerLife
            let resto = timeElapsed % secondsPerLife
            tempTime = secondsPerLife - resto
        } else {
            tempTime -= timeElapsed
        }

        if tempLives >= maxLives {
            self.lives = maxLives
            self.timeToNextLife = 0
        } else {
            self.lives = tempLives
            self.timeToNextLife = tempTime
        }
    }
}
