//
//  SpectroscopyAnalyzer.swift
//  phyphox
//
//  Created by Gaurav Tripathee on 25.06.25.
//  Copyright © 2025 RWTH Aachen. All rights reserved.
//

//One spectrum per mapped output - luminance and, since file format 1.21, linearRed/linearGreen/linearBlue - all along the
//same pixelPosition axis: one compute pass per spectrum with its channel weights, written together so the lengths match.
class SpectroscopyAnalyzer: AnalyzingModule {


    private enum Constants {
        static let kernelFunctionNameAlongX = "computeSpectrumAlongX"
        static let kernelFunctionNameAlongY = "computeSpectrumAlongY"
        static let threadGroupWidth = 256
    }

    //A mapped spectrum: its data container, the channel weights of its pass and the GPU buffer holding the last result
    private class Spectrum {
        let result: DataBuffer
        let channel: LuminanceAnalyzer.Channel
        var metalOutputBuffer: MTLBuffer?
        var latestResults: [Double] = []

        init(result: DataBuffer, channel: LuminanceAnalyzer.Channel) {
            self.result = result
            self.channel = channel
        }
    }

    var analysisResult: DataBuffer? { spectra.first(where: { $0.channel == .luma })?.result }
    var xAxis: DataBuffer?

    private var spectra: [Spectrum] = []

    var analyzisPipelineState : MTLComputePipelineState?
    private var latestxAxis: [Double] = []

    var dispersionWidth: Int = 0
    var spectrumStartIndex: Int = 0
    //Spectrum pixels the kernel actually computed; less than dispersionWidth when the selection exceeds the frame
    var computedWidth: Int = 0
    var analysisOrientation: SpectrumOrientation = .landscape

    init(result: DataBuffer?, xAxis: DataBuffer?, linearRed: DataBuffer? = nil, linearGreen: DataBuffer? = nil, linearBlue: DataBuffer? = nil) {
        self.xAxis = xAxis
        for (buffer, channel) in [(result, LuminanceAnalyzer.Channel.luma), (linearRed, .red), (linearGreen, .green), (linearBlue, .blue)] {
            if let buffer = buffer {
                spectra.append(Spectrum(result: buffer, channel: channel))
            }
        }
    }

    override func loadMetal() {
        guard let metalDevice = AnalyzingModule.metalDevice else { return }
        let gpuFunctionLibrary = AnalyzingModule.gpuFunctionLibrary

        //Textures are sensor-oriented (landscape): device held landscape to the spectrum reads along x, portrait along y
        let kernelName = analysisOrientation == .landscape ?
                            Constants.kernelFunctionNameAlongX :
                            Constants.kernelFunctionNameAlongY

        guard let readLuminanceFunction = gpuFunctionLibrary?.makeFunction(name: kernelName) else { return }

        do {
            analyzisPipelineState = try metalDevice.makeComputePipelineState(function: readLuminanceFunction)
        } catch {
            print("Failed to create pipeline analysis state, error \(error)")
        }

    }

    override func doUpdate(metalCommandBuffer: any MTLCommandBuffer, cameraImageTextureY: any MTLTexture, cameraImageTextureCbCr: any MTLTexture) {

        guard let computeEncoder = metalCommandBuffer.makeComputeCommandEncoder() else { return }

        guard let analysisPipelineState = self.analyzisPipelineState else {
            print("Failed to find pipeline state")
            computeEncoder.endEncoding()
            return
        }

        computeEncoder.setComputePipelineState(analysisPipelineState)

        analyzeTexture(computeEncoder: computeEncoder, cameraImageTextureY: cameraImageTextureY, cameraImageTextureCbCr: cameraImageTextureCbCr)

    }

    func analyzeTexture(computeEncoder : MTLComputeCommandEncoder, cameraImageTextureY: MTLTexture, cameraImageTextureCbCr: MTLTexture){
        guard let metalDevice = AnalyzingModule.metalDevice else { return }

        let selectedWidthForAnalysis = Int(selectionState.x2 - selectionState.x1)
        let selectedHeightForAnalysis = Int(selectionState.y2 - selectionState.y1)

        if analysisOrientation == .landscape {
            dispersionWidth = selectedWidthForAnalysis
            spectrumStartIndex = Int(selectionState.x1)
            //The kernel clamps the selection to the texture; restrict the read-back to the computed range (like Android
            //crops its output) so a selection exceeding the frame cannot leak stale values from the reused output buffer
            computedWidth = min(dispersionWidth, max(0, min(Int(selectionState.x2), cameraImageTextureY.width) - Int(selectionState.x1)))
        } else {
            dispersionWidth = selectedHeightForAnalysis
            spectrumStartIndex = Int(selectionState.y1)
            computedWidth = min(dispersionWidth, max(0, min(Int(selectionState.y2), cameraImageTextureY.height) - Int(selectionState.y1)))
        }

        // Ensure dimensions are valid to prevent crashes
        guard dispersionWidth > 0 else {
            computeEncoder.endEncoding()
            return
        }

        let requiredBytes = dispersionWidth * MemoryLayout<Float>.stride
        let selectionBuffer = metalDevice.makeBuffer(bytes: &selectionState, length: MemoryLayout<SelectionState>.size, options: .storageModeShared)

        //One thread per pixel along the dispersion axis, each averaging across the other axis
        let threadsPerThreadgroup = MTLSize(width: Constants.threadGroupWidth, height: 1, depth: 1)
        let threadgroups = MTLSize(width: (dispersionWidth + Constants.threadGroupWidth - 1) / Constants.threadGroupWidth, height: 1, depth: 1)

        computeEncoder.setTexture(cameraImageTextureY, index: 0)
        computeEncoder.setTexture(cameraImageTextureCbCr, index: 1)
        computeEncoder.setBuffer(selectionBuffer, offset: 0, index: 1)

        //One pass per mapped spectrum; only the weights and the output buffer change between them
        for spectrum in spectra {
            if spectrum.metalOutputBuffer == nil || spectrum.metalOutputBuffer!.length < requiredBytes {
                spectrum.metalOutputBuffer = metalDevice.makeBuffer(length: requiredBytes, options: .storageModeShared)
            }
            var channelWeights = ChannelWeights(weights: spectrum.channel.weights, linear: 1)
            let weightsBuffer = metalDevice.makeBuffer(bytes: &channelWeights, length: MemoryLayout<ChannelWeights>.size, options: .storageModeShared)

            computeEncoder.setBuffer(spectrum.metalOutputBuffer, offset: 0, index: 0)
            computeEncoder.setBuffer(weightsBuffer, offset: 0, index: 2)
            computeEncoder.dispatchThreadgroups(threadgroups, threadsPerThreadgroup: threadsPerThreadgroup)
        }
        computeEncoder.endEncoding()

    }

    override func prepareWriteToBuffers(cameraSettings: CameraSettingsModel) {

        //Like on Android, a spectrum without any contributing pixels yields empty output arrays
        guard !selectionIsEmpty, dispersionWidth > 0, computedWidth > 0 else {
            for spectrum in spectra {
                spectrum.latestResults = []
            }
            latestxAxis = []
            return
        }

        //Same exposure normalization as the luminance analyzer and Android's SpectroscopyAnalyzer
        let exposureFactor = pow(2.0, Double(cameraSettings.currentApertureValue))/2.0 * 100.0/Double(cameraSettings.currentIso) * (1.0/60.0)/(Double(cameraSettings.currentShutterSpeed.value)/Double(cameraSettings.currentShutterSpeed.timescale))

        //Fresh arrays assigned in one go: writeToBuffers may still read the previous frame's arrays on the data queue
        var xValues = [Double](repeating: 0.0, count: computedWidth)
        for i in 0..<computedWidth {
            //Absolute pixel position along the dispersion axis (like Android), so a calibration survives moving the area
            xValues[i] = Double(spectrumStartIndex + i)
        }
        latestxAxis = xValues

        for spectrum in spectra {
            guard let buffer = spectrum.metalOutputBuffer else {
                spectrum.latestResults = []
                continue
            }
            let valuePointer = buffer.contents().bindMemory(to: Float.self, capacity: computedWidth)
            var results = [Double](repeating: 0.0, count: computedWidth)
            for i in 0..<computedWidth {
                results[i] = Double(valuePointer[i]) * exposureFactor
            }
            spectrum.latestResults = results
        }
    }

    override func writeToBuffers() {
        //Swapped in atomically (not clear + append) so observers never see an empty or half-written buffer
        self.xAxis?.replaceValues(latestxAxis)
        for spectrum in spectra {
            spectrum.result.replaceValues(spectrum.latestResults)
        }

    }

    func setAnalysisOrientation(orientation: SpectrumOrientation){
        self.analysisOrientation = orientation
    }

}
