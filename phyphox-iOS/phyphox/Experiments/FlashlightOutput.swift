//
//  FlashlightOutput.swift
//  phyphox
//
//  Created by Gaurav Tripathee on 23.03.26.
//  Copyright © 2026 RWTH Aachen. All rights reserved.
//

import AVFoundation
import Foundation


class FlashlightOutput {
    private let manager = FlashlightManager()
    private var controllers: [FlashlightController] = []

    func start() {
        for controller in controllers {
            controller.start()
        }
    }

    func stop() {
        for controller in controllers {
            controller.stop()
        }
    }

    func attachController(_ controller: FlashlightController) {
        controllers.append(controller)
    }
    
    public func getInternalManager() -> FlashlightManager{
        return manager
    }

    protocol FlashlightController {
        func start()
        func stop()
        var isActive: Bool { get }
    }

    class StrobeController: FlashlightController {
        private let manager: FlashlightManager
        private let parameter: FlashlightParameter
        
        private(set) var isActive: Bool = false

        init(manager: FlashlightManager, parameter: FlashlightParameter) {
            self.manager = manager
            self.parameter = parameter
        }

        func start() {
            manager.startStrobe { [weak self] in
                return self?.parameter.getValue() ?? 0.0
            }
            isActive = true
        }

        func stop() {
            isActive = false
            manager.stopStrobe()
        }
    }

    class IntensityController: FlashlightController {
        private let manager: FlashlightManager
        private let parameter: FlashlightParameter
        
        private(set) var isActive: Bool = false

        init(manager: FlashlightManager, parameter: FlashlightParameter) {
            self.manager = manager
            self.parameter = parameter
        }

        func start() {
            isActive = true
            let val = Float(parameter.getValue() ?? 1.0)
            manager.setIntensity(val)
        }

        func stop() {
            isActive = false
            manager.turnOff()
        }
    }
}


class FlashlightManager {
    private let device = AVCaptureDevice.default(for: .video)
    
    // To ensure hardware calls don't overlap
    private let hardwareQueue = DispatchQueue(label: "de.rwth.flashlight.hardware", qos: .userInteractive)
    
    private var isStrobeActive = false
    private var currentIntensity: Float = 1.0
    private var strobeFrequency: Double = 0
    private var frequencyProvider: (() -> Double)?
    
    var hasFlash: Bool {
        return device?.hasTorch ?? false
    }

    func setIntensity(_ level: Float) {
        hardwareQueue.async { [weak self] in
            guard let self = self else { return }
            
            self.currentIntensity = level
            self.applyTorch(on: self.currentIntensity > 0, level: self.currentIntensity)
        }
    }

    func startStrobe(provider: @escaping () -> Double) {
        hardwareQueue.async { [weak self] in
            guard let self = self else { return }
            let initialFreq = provider()
                if initialFreq <= 0 { return }
            
            self.frequencyProvider = provider
            if self.isStrobeActive { return }
            
            self.isStrobeActive = true
            
            DispatchQueue.global(qos: .userInteractive).async { [weak self] in
                self?.runStrobeLoop()
            }
        }
    }

    private func runStrobeLoop() {
        while true {
            var frequency: Double = 0
            var shouldContinue = false
            var level: Float = 1.0
            
            // Atomic check of state variables
            hardwareQueue.sync {
                shouldContinue = self.isStrobeActive
                frequency = self.frequencyProvider?() ?? 0
                level = self.currentIntensity
            }
            
            if !shouldContinue || frequency <= 0 { break }
            
            let interval = 1.0 / frequency
            let halfInterval = interval / 2.0
            
            self.applyTorch(on: true, level: level)
            Thread.sleep(forTimeInterval: halfInterval)
            
            self.applyTorch(on: false, level: 0)
            Thread.sleep(forTimeInterval: halfInterval)
        }
        
        self.applyTorch(on: false, level: 0)
    }

    func stopStrobe() {
        hardwareQueue.async { [weak self] in
            self?.isStrobeActive = false
        }
    }
    
    func turnOff() {
        stopStrobe()
        hardwareQueue.async { [weak self] in
            self?.applyTorch(on: false, level: 0)
        }
    }

    // Must be called from hardwareQueue
    private func applyTorch(on: Bool, level: Float) {
        guard let device = device, device.hasTorch else {
            print("Flashlight: No device found")
            return
        }
        
        guard device.hasTorch else {
                print("Flashlight: Hardware does not support torch.")
                return
            }
        
        guard device.isTorchAvailable else {
                print("Flashlight: Torch is unavailable. Is the camera in use?")
                return
            }
        guard device.isTorchModeSupported(.on) else {
            return
        }
        
        do {
            try device.lockForConfiguration()
            if on {
                let safeLevel = max(0.01, min(level, 1.0))
                try device.setTorchModeOn(level: safeLevel)
            } else {
                device.torchMode = .off
            }
            device.unlockForConfiguration()
        } catch {
            print("Flashlight Error: \(error)")
        }
    }
}
