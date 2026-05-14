//
//  EventsViewModel.swift
//  JellyMix
//

import SwiftUI
import Combine

@MainActor
class EventsViewModel: ObservableObject {

    // MARK: - Cooldown

    private static let spinKey = "jellymix-last-spin"
    //private static let cooldownSeconds: TimeInterval = 24 * 60 * 60
    private static let cooldownSeconds: TimeInterval = 5 * 60

    
    @Published private(set) var secondsUntilNextSpin: Int = 0
    private var cooldownTimer: AnyCancellable?

    var canSpin: Bool { secondsUntilNextSpin <= 0 }

    // MARK: - Wheel state

    @Published private(set) var wheelRotation: Double = 0
    @Published private(set) var phase: SpinPhase = .idle
    @Published private(set) var currentPrize: WheelPrize? = nil

    private var spinTimer: AnyCancellable?
    private var lastFrameTime: Date = .now
    private static let spinSpeed: Double = 1400   // degrees / second

    // MARK: - Init

    init() {
        refreshCooldown()
        startCooldownTick()
    }

    // MARK: - Public API

    func startSpin() {
        guard canSpin, phase == .idle else { return }
        phase = .spinning
        lastFrameTime = .now
        startSpinLoop()
    }

    func stopSpin() {
        guard phase == .spinning else { return }
        stopSpinLoop()
        phase = .decelerating

        let idx = Int.random(in: 0..<WheelPrize.all.count)
        let segDeg = 360.0 / Double(WheelPrize.all.count)

        // Segment center in wheel-local coords (0° = top)
        let targetLocal = Double(idx) * segDeg + segDeg / 2
        // To bring segment center to pointer (top), we need rotation ≡ (360 - targetLocal) mod 360
        let wantedMod = (360.0 - targetLocal + 360.0).truncatingRemainder(dividingBy: 360.0)
        let cur = (wheelRotation.truncatingRemainder(dividingBy: 360.0) + 360.0).truncatingRemainder(dividingBy: 360.0)
        let delta = (wantedMod - cur + 360.0).truncatingRemainder(dividingBy: 360.0)
        let finalRotation = wheelRotation + 4 * 360.0 + delta   // 4 full extra spins + align

        withAnimation(.timingCurve(0.15, 0.85, 0.25, 1, duration: 4.5)) {
            wheelRotation = finalRotation
        }

        // After easeOut completes, move to reveal
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.6) { [weak self] in
            guard let self else { return }
            self.currentPrize = WheelPrize.all[idx]
            self.phase = .revealing
            self.recordSpin()
        }
    }

    func claimPrize(on viewModel: GameViewModel) {
        guard let prize = currentPrize else { return }
        apply(prize: prize, to: viewModel)
        currentPrize = nil
        phase = .idle
        refreshCooldown()
        startCooldownTick()
    }

    // Dev helper — remove before shipping
    func resetCooldown() {
        UserDefaults.standard.removeObject(forKey: Self.spinKey)
        refreshCooldown()
    }

    // MARK: - Private

    private func startSpinLoop() {
        lastFrameTime = .now
        spinTimer = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self, self.phase == .spinning else { return }
                let now = Date.now
                let dt = now.timeIntervalSince(self.lastFrameTime)
                self.lastFrameTime = now
                self.wheelRotation += Self.spinSpeed * dt
            }
    }

    private func stopSpinLoop() {
        spinTimer?.cancel()
        spinTimer = nil
    }

    private func recordSpin() {
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: Self.spinKey)
        secondsUntilNextSpin = Int(Self.cooldownSeconds)
    }

    private func refreshCooldown() {
        let last = UserDefaults.standard.double(forKey: Self.spinKey)
        guard last > 0 else { secondsUntilNextSpin = 0; return }
        let elapsed = Date().timeIntervalSince1970 - last
        let remaining = Self.cooldownSeconds - elapsed
        secondsUntilNextSpin = remaining > 0 ? Int(remaining) : 0
    }

    private func startCooldownTick() {
        cooldownTimer?.cancel()
        guard secondsUntilNextSpin > 0 else { return }
        cooldownTimer = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                self.refreshCooldown()
                if self.secondsUntilNextSpin <= 0 { self.cooldownTimer?.cancel() }
            }
    }

    private func apply(prize: WheelPrize, to vm: GameViewModel) {
        switch prize.effect {
        case .coins(let amount):
            vm.coins += amount
        case .powerUp(let type):
            vm.powerUps[type, default: 0] += prize.amount
            vm.savePowerUps()
        case .life:
            vm.lives = min(vm.lives + prize.amount, vm.maxLives)
        case .noEffect:
            break
        }
    }
}
