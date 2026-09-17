//
//  ExperimentFlashlightOutput.swift
//  phyphox
//
//  Created by Gaurav Tripathee on 23.03.26.
//  Copyright © 2026 RWTH Aachen. All rights reserved.
//

import AVFoundation
import Foundation

enum FlashlightParameter: Equatable {
    case buffer(buffer: DataBuffer)
    case value(value: Double?)

    func getValue() -> Double? {
        switch self {
        case .buffer(buffer: let buffer):
            return buffer.last
        case .value(value: let value):
            return value
        }
    }

    var isBuffer: Bool {
        switch self {
        case .buffer(buffer: _):
            return true
        case .value(value: _):
            return false
        }
    }
}

//Torch as experiment output, as on Android: intensity <= 0 is off, frequency <= 0 constantly on, else a strobe with
//the given dutycycle. Parameters are re-read at start and after every analysis cycle.
final class ExperimentFlashlightOutput {
    let intensity: FlashlightParameter
    let frequency: FlashlightParameter
    let dutycycle: FlashlightParameter

    //Called on the main queue when the flashlight is disabled because the device got too hot
    var onThermalWarning: (() -> Void)?
    private(set) var isOverheated = false

    private let engine = FlashlightEngine()

    //Whether the photosensitivity warning is needed (as on Android): buffer-driven or fixed positive frequency
    var usesStrobe: Bool {
        switch frequency {
        case .buffer:
            return true
        case .value(value: let value):
            return (value ?? 0.0) > 0.0
        }
    }

    init(intensity: FlashlightParameter, frequency: FlashlightParameter, dutycycle: FlashlightParameter) {
        self.intensity = intensity
        self.frequency = frequency
        self.dutycycle = dutycycle

        //Equivalent of Android's battery temperature watch, which iOS does not expose
        NotificationCenter.default.addObserver(self, selector: #selector(thermalStateDidChange), name: ProcessInfo.thermalStateDidChangeNotification, object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        engine.shutdown()
    }

    func start() {
        checkThermalState()
        engine.start()
        updateState()
    }

    func updateState() {
        guard !isOverheated else { return }
        //nil only for an empty buffer, which Android reads as NaN and zeroes ("off"); setState zeroes non-finite values too
        engine.setState(intensity: intensity.getValue() ?? Double.nan,
                        frequency: frequency.getValue() ?? Double.nan,
                        dutycycle: dutycycle.getValue() ?? Double.nan)
    }

    func stop() {
        engine.stop()
    }

    @objc private func thermalStateDidChange() {
        checkThermalState()
    }

    private func checkThermalState() {
        let state = ProcessInfo.processInfo.thermalState

        if state == .serious || state == .critical {
            if !isOverheated {
                isOverheated = true
                engine.setState(intensity: 0.0, frequency: 0.0, dutycycle: 0.5)
                DispatchQueue.main.async { [weak self] in
                    self?.onThermalWarning?()
                }
            }
        } else {
            //The next updateState turns the light back on, like Android's cooldown threshold
            isOverheated = false
        }
    }
}

//Drives the torch from its own thread on an absolute, drift-free cycle schedule that keeps its phase across frequency
//changes (as on Android). State changes wake the thread immediately.
private final class FlashlightEngine {

    private struct State: Equatable {
        var intensity: Double = 0.0
        var interval: Double = 0.0 //period in seconds, zero meaning constantly on
        var dutycycle: Double = 0.5
    }

    private let condition = NSCondition()
    private var state = State()
    private var running = false
    private var terminated = false
    private var threadStarted = false

    //Absolute strobe schedule, only touched by the engine thread
    private var nextCycleStart: TimeInterval = 0.0
    private var currentInterval: Double = 0.0

    private let device = AVCaptureDevice.default(for: .video)
    private var lastAppliedOn = false
    private var lastAppliedLevel: Float = -1.0

    func setState(intensity: Double, frequency: Double, dutycycle: Double) {
        let newState = State(intensity: intensity.isFinite ? intensity : 0.0,
                             interval: frequency > 0.0 && frequency.isFinite ? 1.0/frequency : 0.0,
                             dutycycle: dutycycle.isFinite ? dutycycle : 0.0)
        condition.lock()
        if newState != state {
            state = newState
            condition.broadcast()
        }
        condition.unlock()
    }

    func start() {
        condition.lock()
        running = true
        if !threadStarted {
            threadStarted = true
            let thread = Thread {
                self.run()
            }
            //At default priority deferred wakeups miss entire strobe phases
            thread.qualityOfService = .userInteractive
            thread.name = "phyphox flashlight"
            thread.start()
        }
        condition.broadcast()
        condition.unlock()
    }

    func stop() {
        condition.lock()
        running = false
        state = State()
        condition.broadcast()
        condition.unlock()
    }

    //Ends the engine thread for good, which also releases its reference to the engine
    func shutdown() {
        condition.lock()
        running = false
        terminated = true
        condition.broadcast()
        condition.unlock()
    }

    private func run() {
        condition.lock()
        while !terminated {
            if !running {
                condition.unlock()
                applyTorch(on: false, level: 0.0)
                condition.lock()
                while !running && !terminated {
                    condition.wait()
                }
                continue
            }

            let currentState = state

            if currentState.intensity <= 0.0 || currentState.dutycycle <= 0.0 || currentState.interval <= 0.0 || currentState.dutycycle >= 1.0 {
                //Off or constantly on (dutycycle extremes included): apply and wait for the next change
                let on = currentState.intensity > 0.0 && currentState.dutycycle > 0.0
                condition.unlock()
                applyTorch(on: on, level: Float(currentState.intensity))
                condition.lock()
                while running && !terminated && state == currentState {
                    condition.wait()
                }
                continue
            }

            //Strobe mode: keep the phase of the previous schedule if the interval changed, as on Android
            var currentCycle = currentInterval > 0.0 ? 1.0 - (nextCycleStart - ProcessInfo.processInfo.systemUptime) / currentInterval : 1.0
            if currentCycle > 1.0 {
                currentCycle -= 1.0
            }
            currentCycle = min(max(currentCycle, 0.0), 1.0)
            if currentInterval != currentState.interval {
                nextCycleStart = ProcessInfo.processInfo.systemUptime - currentCycle * currentState.interval
                currentInterval = currentState.interval
            }

            condition.unlock()
            applyTorch(on: currentCycle < currentState.dutycycle, level: Float(currentState.intensity))
            condition.lock()

            while running && !terminated && state == currentState {
                var now = ProcessInfo.processInfo.systemUptime

                //Fell behind by whole cycles: skip them but keep the phase
                if now - nextCycleStart >= currentState.interval {
                    let missedCycles = ((now - nextCycleStart) / currentState.interval).rounded(.down)
                    nextCycleStart += missedCycles * currentState.interval
                }

                if now < nextCycleStart {
                    if waitInterrupted(duration: nextCycleStart - now, unless: currentState) {
                        break
                    }
                }

                //Arriving late shortens the flash instead of dropping it
                let dutyEnd = nextCycleStart + currentState.interval * currentState.dutycycle
                now = ProcessInfo.processInfo.systemUptime
                if now < dutyEnd {
                    condition.unlock()
                    applyTorch(on: true, level: Float(currentState.intensity))
                    condition.lock()
                    let dutyDelay = dutyEnd - ProcessInfo.processInfo.systemUptime
                    if dutyDelay > 0.0 {
                        if waitInterrupted(duration: dutyDelay, unless: currentState) {
                            break
                        }
                    }
                }
                condition.unlock()
                applyTorch(on: false, level: 0.0)
                condition.lock()

                nextCycleStart += currentState.interval
            }
        }
        condition.unlock()
        applyTorch(on: false, level: 0.0)
    }

    //Waits under the held lock; true if the state or the running flag changed before the duration passed
    private func waitInterrupted(duration: TimeInterval, unless referenceState: State) -> Bool {
        let deadline = Date().addingTimeInterval(duration)
        while running && !terminated && state == referenceState {
            if !condition.wait(until: deadline) {
                return false
            }
        }
        return true
    }

    //The only place that talks to the torch hardware
    private func applyTorch(on: Bool, level: Float) {
        guard let device = device, device.hasTorch, device.isTorchAvailable else { return }

        let safeLevel = max(0.01, min(level, 1.0))
        let targetOn = on && level > 0.0

        //Already in the requested state: avoid a needless configuration lock
        if targetOn && lastAppliedOn && abs(safeLevel - lastAppliedLevel) < 0.001 {
            return
        }
        if !targetOn && !lastAppliedOn {
            return
        }

        do {
            try device.lockForConfiguration()
            if targetOn {
                try device.setTorchModeOn(level: safeLevel)
                lastAppliedLevel = safeLevel
                lastAppliedOn = true
            } else {
                device.torchMode = .off
                lastAppliedOn = false
            }
            device.unlockForConfiguration()
        } catch {
            //If the hardware is not available right now, skip this toggle to keep the loop timing
        }
    }
}
