//
//  LuminanceAnalyzer.swift
//  phyphox
//
//  Created by Gaurav Tripathee on 14.09.24.
//  Copyright © 2024 RWTH Aachen. All rights reserved.
//

import Foundation

//Mean of a weighted sum of the colour channels over the selected area: luma and luminance (BT.709 weights, gamma-encoded
//or linearized) and, since file format 1.21, the single colour channels red/green/blue and linearRed/Green/Blue. All of
//them share one kernel and one reduction, so the identities luma = 0.2126 red + 0.7152 green + 0.0722 blue and
//luminance = the same combination of the linear channels hold exactly per frame. Linear outputs are exposure-normalized.
class LuminanceAnalyzer: AnalyzingModule {

    //Weights of the per-pixel dot product: BT.709 for luma/luminance, a unit vector for a single colour channel
    enum Channel {
        case luma, red, green, blue

        var weights: SIMD3<Float> {
            switch self {
            case .luma: return SIMD3<Float>(0.2126, 0.7152, 0.0722)
            case .red: return SIMD3<Float>(1.0, 0.0, 0.0)
            case .green: return SIMD3<Float>(0.0, 1.0, 0.0)
            case .blue: return SIMD3<Float>(0.0, 0.0, 1.0)
            }
        }
    }

    var analysisPipelineState : MTLComputePipelineState?
    var finalSumPipelineState : MTLComputePipelineState?

    var luminanceValue : MTLBuffer?

    var result: DataBuffer?
    let linear: Bool
    let channel: Channel
    var latestResult: Double = .nan

    init(result: DataBuffer?, linear: Bool = true, channel: Channel = .luma) {
        self.result = result
        self.linear = linear
        self.channel = channel
    }

    override func loadMetal() {

        guard let metalDevice = AnalyzingModule.metalDevice else { return }

        let gpuFunctionLibrary = AnalyzingModule.gpuFunctionLibrary

        guard let luminanceFunction = gpuFunctionLibrary?.makeFunction(name:"computeWeightedChannelSum") else {
            return
        }
        do {
            analysisPipelineState = try metalDevice.makeComputePipelineState(function: luminanceFunction)
        } catch  {
            print("Failed to create pipeline analysis state, error \(error)")
        }

        let finalSum = gpuFunctionLibrary?.makeFunction(name: "computeFinalSum")
        do {
            finalSumPipelineState = try metalDevice.makeComputePipelineState(function: finalSum!)
        } catch  {
            print("Failed to create pipeline final sum state, error \(error)")
        }

    }

    override func doUpdate(metalCommandBuffer: MTLCommandBuffer,
                cameraImageTextureY: MTLTexture?,
                cameraImageTextureCbCr: MTLTexture? ) {

        if let analysisEncoding = metalCommandBuffer.makeComputeCommandEncoder() {
            analyze(analyzeEncoding : analysisEncoding,
                    analysisCommandBuffer: metalCommandBuffer,
                    cameraImageTextureY: cameraImageTextureY,
                    cameraImageTextureCbCr: cameraImageTextureCbCr)
        }


    }

    func analyze(analyzeEncoding : MTLComputeCommandEncoder,
                 analysisCommandBuffer: MTLCommandBuffer,
                 cameraImageTextureY: MTLTexture?,
                 cameraImageTextureCbCr: MTLTexture?) {

        guard let metalDevice = AnalyzingModule.metalDevice else { return }

        guard let analysisPipelineState = self.analysisPipelineState else {
            print("Failed to create analysisPipelineState")
            analyzeEncoding.endEncoding()
            return
        }

        guard let finalSumPipelineState = self.finalSumPipelineState else {
            print("Failed to create finalSumPipelineState")
            analyzeEncoding.endEncoding()
            return
        }

        let calculatedGridAndGroupSize = calculateThreadSize(selectedWidth: getSelectedArea().width, selectedHeight: getSelectedArea().height)

        let partialBufferLength = calculatedGridAndGroupSize.numOfThreadGroups

        //An empty selection has no pixels to dispatch; the result is NaN (see prepareWriteToBuffers)
        guard partialBufferLength > 0 else {
            luminanceValue = nil
            analyzeEncoding.endEncoding()
            return
        }

        analyzeEncoding.setComputePipelineState(analysisPipelineState)

        //setup buffers
        let selectionBuffer = metalDevice.makeBuffer(bytes: &selectionState, length: MemoryLayout<SelectionState>.size, options: .storageModeShared)
        let partialBuffer = metalDevice.makeBuffer(length: MemoryLayout<Float>.stride * partialBufferLength, options: .storageModeShared)!
        var partialLengthStruct = PartialBufferLength(length: partialBufferLength)
        let arrayLength = metalDevice.makeBuffer(bytes: &partialLengthStruct,length: MemoryLayout<PartialBufferLength>.size,options: .storageModeShared)
        var channelWeights = ChannelWeights(weights: channel.weights, linear: linear ? 1 : 0)
        let weightsBuffer = metalDevice.makeBuffer(bytes: &channelWeights, length: MemoryLayout<ChannelWeights>.size, options: .storageModeShared)

        analyzeEncoding.setTexture(cameraImageTextureY, index: 0)
        analyzeEncoding.setTexture(cameraImageTextureCbCr, index: 1)
        analyzeEncoding.setBuffer(partialBuffer, offset: 0, index: 0)
        analyzeEncoding.setBuffer(selectionBuffer, offset: 0, index: 1)
        analyzeEncoding.setBuffer(arrayLength, offset: 0, index: 2)
        analyzeEncoding.setBuffer(weightsBuffer, offset: 0, index: 3)

        analyzeEncoding.dispatchThreadgroups(calculatedGridAndGroupSize.gridSize,
                                             threadsPerThreadgroup: calculatedGridAndGroupSize.threadGroupSize)

        luminanceValue = metalDevice.makeBuffer(length: MemoryLayout<Float>.stride, options: .storageModeShared)!

        analyzeEncoding.setComputePipelineState(finalSumPipelineState)

        analyzeEncoding.setBuffer(partialBuffer, offset: 0, index: 0)
        analyzeEncoding.setBuffer(luminanceValue, offset: 0, index: 1)
        analyzeEncoding.setBuffer(arrayLength, offset: 0, index: 2)

        analyzeEncoding.dispatchThreadgroups(MTLSizeMake(1, 1, 1),
                                              threadsPerThreadgroup: MTLSizeMake(256, 1, 1))

        analyzeEncoding.endEncoding()

    }

    override func prepareWriteToBuffers(cameraSettings: CameraSettingsModel) {
        let area = getSelectedArea().width * getSelectedArea().height
        guard area > 0, let resultBuffer = luminanceValue?.contents().bindMemory(to: Float.self, capacity: 1) else {
            latestResult = .nan
            return
        }
        let mean = Double(resultBuffer.pointee) / Double(area)
        //Linear outputs are normalized to ISO 100, 1/60 s and f/1; the gamma-encoded ones are what the camera delivers
        let exposureFactor = linear ? pow(2.0, Double(cameraSettings.currentApertureValue))/2.0 * 100.0/Double(cameraSettings.currentIso) * (1.0/60.0)/(Double(cameraSettings.currentShutterSpeed.value)/Double(cameraSettings.currentShutterSpeed.timescale)) : 1.0
        latestResult = exposureFactor * mean
    }

    override func writeToBuffers() {
        if let zBuffer = result {
            zBuffer.append(latestResult)
        }
    }

    func calculateThreadSize(selectedWidth: Int, selectedHeight: Int) -> (threadGroupSize: MTLSize, gridSize: MTLSize, numOfThreadGroups: Int) {

        let threadGroupSize = MTLSize(width: 16, height: 16, depth: 1)
         // Dispatch the compute shader with the size of the selected bounding box
        let threadgroupsX = (selectedWidth + threadGroupSize.width - 1) / threadGroupSize.width;
        let threadgroupsY = (selectedHeight + threadGroupSize.height - 1) / threadGroupSize.height;
        let _gridSize = MTLSize(width: threadgroupsX, height: threadgroupsY, depth: 1)
        let _numThreadSize = (_gridSize.width * _gridSize.height)

        return (threadGroupSize: threadGroupSize, gridSize: _gridSize, numOfThreadGroups: _numThreadSize )

    }

    struct PartialBufferLength {
        var length : Int
    }

}
