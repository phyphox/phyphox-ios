import AVFoundation
import Foundation

/// A wrapper to manage flashlight output.
/// It coordinates different control modes (Intensity vs Strobe) and handles hardware safety.
class FlashlightOutput {
    private let manager = FlashlightManager()
    private var controllers: [FlashlightController] = []

    func start() {
        controllers.forEach { $0.start() }
    }

    func stop() {
        controllers.forEach { $0.stop() }
    }

    func attachController(_ controller: FlashlightController) {
        controllers.append(controller)
    }
    
    public func getInternalManager() -> FlashlightManager {
        return manager
    }
    
    public func hasStrobeController() -> Bool {
        return controllers.contains{ $0 is StrobeController}
    }
    
    func isStrobeActiveWithFrequency() -> Bool {
        guard let strobe = controllers.first(where: { $0 is StrobeController }) as? StrobeController else {
            return false
        }
        
        return strobe.getCurrentFrequency() > 0
    }
    
    func isStrobeUsingBuffer() -> Bool {
        guard let strobe = controllers.first(where: { $0 is StrobeController }) as? StrobeController else {
            return false
        }
        return strobe.isBufferSource()
    }

    protocol FlashlightController {
        func start()
        func stop()
        var isActive: Bool { get }
    }

    // MARK: - Strobe Controller
    class StrobeController: FlashlightController {
        private let manager: FlashlightManager
        private let parameter: FlashlightParameter
        private(set) var isActive: Bool = false
        private var lastFrequency: Double = -1.0

        init(manager: FlashlightManager, parameter: FlashlightParameter) {
            self.manager = manager
            self.parameter = parameter
        }
        
        func getCurrentFrequency() -> Double { return parameter.getValue() ?? 0.0 }

        func isBufferSource() -> Bool { return parameter.isBuffer }

        func start() {
            let currentFreq = parameter.getValue() ?? 0.0
            
            if !isActive {
                isActive = true
                lastFrequency = currentFreq
                // Passes a closure to the manager so the background thread can fetch fresh data
                manager.startStrobe { [weak self] in
                    return self?.parameter.getValue() ?? 0.0
                }
            } else if abs(currentFreq - lastFrequency) > 0.0001 {
                // If freq changed while running, interrupt the loop's 'sleep' to apply new rate immediately.
                lastFrequency = currentFreq
                manager.pokeLoop()
            }
        }

        func stop() {
            guard isActive else { return }
            isActive = false
            lastFrequency = -1.0
            manager.stopStrobe()
        }
    }

    // MARK: - Intensity Controller
    class IntensityController: FlashlightController {
        private let manager: FlashlightManager
        private let parameter: FlashlightParameter
        private(set) var isActive: Bool = false
        private var lastValue: Float = -1.0

        init(manager: FlashlightManager, parameter: FlashlightParameter) {
            self.manager = manager
            self.parameter = parameter
        }

        func start() {
            isActive = true
            let val = Float(parameter.getValue() ?? 1.0)
            
            // Value-tracking prevents redundant hardware commands if start() is called in a fast loop.
            if abs(val - lastValue) > 0.001 {
                lastValue = val
                manager.setIntensity(val)
            }
        }

        func stop() {
            isActive = false
            lastValue = -1.0
            manager.turnOff()
        }
    }
}

// MARK: - Flashlight Manager Engine

/// The engine responsible for thread safety and direct interaction with AVCaptureDevice.
class FlashlightManager {
    private let device = AVCaptureDevice.default(for: .video)
    
    /// Dedicated queue for all hardware interactions to prevent UI blocking and race conditions.
    private let hardwareQueue = DispatchQueue(label: "de.rwth.flashlight.hardware", qos: .userInteractive)
    /// Used to manage the strobe timing and allow immediate interruption of "sleep" states.
    private let strobeCondition = NSCondition()
    
    private var isStrobeActive = false
    private var currentIntensity: Float = 1.0
    private var frequencyProvider: (() -> Double)?
    
    // Hardware state cache used to guard the redudent calls
    private var lastAppliedLevel: Float = -1.0
    private var lastAppliedOn: Bool = false

    
    func setIntensity(_ level: Float) {
        hardwareQueue.async { [weak self] in
            guard let self = self else { return }
            self.currentIntensity = level
            self.pokeLoop() // Ensure the loop reacts to brightness changes instantly
            
            if !self.isStrobeActive {
                self.applyTorch(on: level > 0, level: level)
            }
        }
    }

    /// Forces the background strobe thread to wake up from its current wait interval.
    func pokeLoop() {
        strobeCondition.lock()
        strobeCondition.broadcast() // Wakes any thread currently at strobeCondition.wait()
        strobeCondition.unlock()
    }

    /// Initializes and starts the background strobe thread.
    func startStrobe(provider: @escaping () -> Double) {
        hardwareQueue.async { [weak self] in
            guard let self = self else { return }
            self.frequencyProvider = provider
            
            if !self.isStrobeActive {
                self.isStrobeActive = true
                self.pokeLoop()
                DispatchQueue.global(qos: .userInteractive).async { [weak self] in
                    self?.runStrobeLoop()
                }
            }
        }
    }

    /// The core logic loop running on a background thread.
    private func runStrobeLoop() {
        // Keeps track of which phase we are in so rapid changes don't "restart" the pulse
        var isCurrentlyInOnPhase = false
        
        while true {
            strobeCondition.lock()
            
            if !self.isStrobeActive {
                self.applyTorchInQueue(on: false, level: 0)
                strobeCondition.unlock()
                break
            }
            
            let freq = self.frequencyProvider?() ?? 0
            let level = self.currentIntensity
            
            // 1. STEADY MODE
            if freq <= 0 {
                isCurrentlyInOnPhase = true
                self.applyTorchInQueue(on: level > 0, level: level)
                strobeCondition.wait(until: Date().addingTimeInterval(0.5))
                strobeCondition.unlock()
                continue
            }
            
            // 2. STROBE MODE
            let interval = 1.0 / freq
            let halfInterval = interval / 2.0
            
            // Toggle Phase
            isCurrentlyInOnPhase = !isCurrentlyInOnPhase
            
            if isCurrentlyInOnPhase {
                self.applyTorchInQueue(on: level > 0, level: level)
            } else {
                self.applyTorchInQueue(on: false, level: 0)
            }
            
            // Wait for half the interval.
            // If pokeLoop() is called, this returns early and we immediately recalculate
            // the NEXT phase using the NEW frequency.
            strobeCondition.wait(until: Date().addingTimeInterval(halfInterval))
            
            strobeCondition.unlock()
        }
    }

    func stopStrobe() {
        hardwareQueue.async { [weak self] in
            self?.isStrobeActive = false
            self?.pokeLoop()
        }
    }
    
    func turnOff() {
        stopStrobe()
        hardwareQueue.async { [weak self] in
            self?.applyTorch(on: false, level: 0)
        }
    }

    /// Ensures that strobe-thread requests are passed through the serial hardwareQueue.
    private func applyTorchInQueue(on: Bool, level: Float) {
        hardwareQueue.sync {
            self.applyTorch(on: on, level: level)
        }
    }

    /// The only point in the code that talks to AVCaptureDevice.
    private func applyTorch(on: Bool, level: Float) {
        guard let device = device, device.hasTorch, device.isTorchAvailable else { return }
        
        let safeLevel = max(0.01, min(level, 1.0))
        let targetOn = on && level > 0

        // REDUNDANCY GUARD:
        // Comparing current request with last applied hardware state.
        // This prevents the "Lag" caused by spamming hardware locks.
        if targetOn == lastAppliedOn && abs(safeLevel - lastAppliedLevel) < 0.001 && targetOn == true { return }
        if targetOn == false && lastAppliedOn == false { return }

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
            // If the hardware is locked by another process, skip this frame to keep loop timing consistent
        }
    }
}
