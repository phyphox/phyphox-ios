//
//  SpectroscopyAnalyzer.swift
//  phyphox
//
//  Created by Gaurav Tripathee on 25.06.25.
//  Copyright © 2025 RWTH Aachen. All rights reserved.
//

class SpectroscopyAnalyzer: AnalyzingModule {


    private enum Constants {
        static let kernelFunctionNameAlongX = "computeSpectrumAlongX"
        static let kernelFunctionNameAlongY = "computeSpectrumAlongY"
        static let threadGroupWidth = 256
    }

    var analysisResult: DataBuffer?
    var xAxis: DataBuffer?

    var analyzisPipelineState : MTLComputePipelineState?
    var metalOutputBuffer: MTLBuffer?
    private var latestResults: [Double] = []
    private var latestxAxis: [Double] = []

    var dispersionWidth: Int = 0
    var spectrumStartIndex: Int = 0
    //Spectrum pixels the kernel actually computed; less than dispersionWidth when the selection exceeds the frame
    var computedWidth: Int = 0
    var analysisOrientation: SpectrumOrientation = .landscape

    init(result: DataBuffer?, xAxis: DataBuffer?) {
        self.analysisResult = result
        self.xAxis = xAxis
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
        if metalOutputBuffer == nil || metalOutputBuffer!.length < requiredBytes {
            metalOutputBuffer = metalDevice.makeBuffer(length: requiredBytes, options: .storageModeShared)
        }

        let selectionBuffer = metalDevice.makeBuffer(bytes: &selectionState, length: MemoryLayout<SelectionState>.size, options: .storageModeShared)

        computeEncoder.setTexture(cameraImageTextureY, index: 0)
        computeEncoder.setTexture(cameraImageTextureCbCr, index: 1)
        computeEncoder.setBuffer(metalOutputBuffer, offset: 0, index: 0)
        computeEncoder.setBuffer(selectionBuffer, offset: 0, index: 1)

        //One thread per pixel along the dispersion axis, each averaging across the other axis
        let threadsPerThreadgroup = MTLSize(width: Constants.threadGroupWidth, height: 1, depth: 1)
        let threadgroups = MTLSize(width: (dispersionWidth + Constants.threadGroupWidth - 1) / Constants.threadGroupWidth, height: 1, depth: 1)

        computeEncoder.dispatchThreadgroups(threadgroups, threadsPerThreadgroup: threadsPerThreadgroup)
        computeEncoder.endEncoding()

    }

    override func prepareWriteToBuffers(cameraSettings: CameraSettingsModel) {

        //Like on Android, a spectrum without any contributing pixels yields empty output arrays
        guard let buffer = metalOutputBuffer, dispersionWidth > 0, computedWidth > 0 else {
            latestResults = []
            latestxAxis = []
            return
        }

        //Same exposure normalization as the luminance analyzer and Android's SpectroscopyAnalyzer
        let exposureFactor = pow(2.0, Double(cameraSettings.currentApertureValue))/2.0 * 100.0/Double(cameraSettings.currentIso) * (1.0/60.0)/(Double(cameraSettings.currentShutterSpeed.value)/Double(cameraSettings.currentShutterSpeed.timescale))

        let luminancePointer = buffer.contents().bindMemory(to: Float.self, capacity: computedWidth)

        //Fresh arrays assigned in one go: writeToBuffers may still read the previous frame's arrays on the data queue
        var results = [Double](repeating: 0.0, count: computedWidth)
        var xValues = [Double](repeating: 0.0, count: computedWidth)

        for i in 0..<computedWidth {
            results[i] = Double(luminancePointer[i]) * exposureFactor
            //Absolute pixel position along the dispersion axis (like Android), so a calibration survives moving the area
            xValues[i] = Double(spectrumStartIndex + i)
        }

        latestResults = results
        latestxAxis = xValues
    }

    override func writeToBuffers() {
        //Swapped in atomically (not clear + append) so observers never see an empty or half-written buffer
        self.xAxis?.replaceValues(latestxAxis)
        self.analysisResult?.replaceValues(latestResults)

    }

    func setAnalysisOrientation(orientation: SpectrumOrientation){
        self.analysisOrientation = orientation
    }

}
