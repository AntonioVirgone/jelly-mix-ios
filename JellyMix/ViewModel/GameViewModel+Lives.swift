//
//  GameViewModel+Lives.swift
//  JellyMix
//

import Foundation
import SwiftUI

extension GameViewModel {

    func setupLivesSystem() {
        if UserDefaults.standard.object(forKey: "savedLives") != nil {
            self.lives = UserDefaults.standard.integer(forKey: "savedLives")
            self.timeToNextLife = UserDefaults.standard.integer(forKey: "lastTimeToNextLife")
        } else {
            self.lives = maxLives
        }

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
    }

    @objc func appCameForeground() {
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
