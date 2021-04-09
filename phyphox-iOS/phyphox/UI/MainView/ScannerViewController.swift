//
//  ScannerViewController.swift
//  phyphox
//
//  Created by Sebastian Staacks on 23.11.18.
//  Copyright © 2018 RWTH Aachen. All rights reserved.
//

import AVFoundation
import zlib

class ScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var avCaptureSession = AVCaptureSession()
    var avPreviewLayer: AVCaptureVideoPreviewLayer?
    var error: String?
    var experimentLauncher: ExperimentController?
    
    func actualInit() {
        title = localize("newExperimentQR")
        
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancel))
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        actualInit()
    }
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        actualInit()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        guard let avCaptureDevice = AVCaptureDevice.default(for: .video) else {
            abortWithError(message: "Could not get a video capture device.")
            return
        }
        
        let avCaptureDeviceInput: AVCaptureDeviceInput
        
        do {
            avCaptureDeviceInput = try AVCaptureDeviceInput(device: avCaptureDevice)
        } catch {
            abortWithError(message: "Could not get a video capture device input.")
            return
        }
        
        let avCaptureMetadataOutput = AVCaptureMetadataOutput()
        
        guard avCaptureSession.canAddInput(avCaptureDeviceInput) else {
            abortWithError(message: "Could not add input to capture session.")
            return
        }
        avCaptureSession.addInput(avCaptureDeviceInput)
        
        guard avCaptureSession.canAddOutput(avCaptureMetadataOutput) else {
            abortWithError(message: "Could not add output to capture session.")
            return
        }
        avCaptureSession.addOutput(avCaptureMetadataOutput)
        
        avCaptureMetadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
        avCaptureMetadataOutput.metadataObjectTypes = [.qr]
        
        avPreviewLayer = AVCaptureVideoPreviewLayer(session: avCaptureSession)
        guard let previewLayer = avPreviewLayer else {
            abortWithError(message: "Unexpected error creating a video preview layer.")
            return
        }
        previewLayer.frame = view.layer.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        
        updateOrientation()
        
        avCaptureSession.startRunning()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if (!avCaptureSession.isRunning) {
            avCaptureSession.startRunning()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        if (avCaptureSession.isRunning) {
            avCaptureSession.stopRunning()
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        if let message = error {
            showMessage(title: "Scanning failed.", msg: message, endScanner: true)
        }
    }
    
    func showMessage(title: String, msg: String, endScanner: Bool) {
        avCaptureSession.stopRunning()
        let alertController = UIAlertController(title: title, message: msg, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: endScanner ? dismissScanner : {(_ action: UIAlertAction) in self.avCaptureSession.startRunning()}))
        present(alertController, animated: true)
    }
    
    func updateOrientation() {
        guard let connection = avPreviewLayer?.connection  else {
            return
        }
        
        let orientation = UIDevice.current.orientation
        
        if (connection.isVideoOrientationSupported) {
            switch(orientation) {
            case .portrait: connection.videoOrientation = .portrait
                break
            case .landscapeLeft: connection.videoOrientation = .landscapeRight
                break
            case .landscapeRight: connection.videoOrientation = .landscapeLeft
                break
            case .portraitUpsideDown: connection.videoOrientation = .portraitUpsideDown
                break
            default: connection.videoOrientation = .portrait
            }
            avPreviewLayer?.frame = self.view.bounds
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        updateOrientation()
    }
    
    var currentCRC32: UInt32 = 0
    var currentCount: Int = 0
    var currentDataPackets: [Data?] = []
    
    func handlePhyphoxRawData(raw: Data) {
        let thisCRC32 = UInt32(raw[0]) << 24 | UInt32(raw[1]) << 16 | UInt32(raw[2]) << 8 | UInt32(raw[3])
        let index = Int(raw[4])
        let count = Int(raw[5])
        if (currentDataPackets.count == 0) {
            //This is the first QR code with phyphox data.
            currentCRC32 = thisCRC32
            currentCount = count
            currentDataPackets = Array(repeating: nil, count: count)
        } else {
            //We have already scanned at least one QR code with phyphox data and are expecting more matching codes...
            guard thisCRC32 == currentCRC32 && count == currentCount && index <= count else {
                showMessage(title: localize("newExperimentQRErrorTitle"), msg: localize("newExperimentQRcrcMismatch"), endScanner: true)
                return
            }
        }
        
        currentDataPackets[index] = raw.subdata(in: 6..<raw.count)
        
        var missing = 0
        for i in 0..<count {
            if currentDataPackets[i] == nil {
                missing += 1
            }
        }
        
        if missing > 0 {
            //We are looking at a set of QR codes and need to tell the user that we need more of them...
            let message = localize("newExperimentQRCodesMissing1") + " " + String(currentCount) + " " + localize("newExperimentQRCodesMissing2") + " " + String(missing)
            showMessage(title: localize("newExperimentQR"), msg: message, endScanner: false)
            return
        } else if count > 0 {
            //The set of QR codes is complete. Check the CRC32, write the data to a file and let the experiment launcher handle the rest...
            
            var data = Data()
            for dataPacket in currentDataPackets {
                data.append(dataPacket!)
            }
            var receivedCRC32: uLong = 0
            data.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) in
                receivedCRC32 = crc32(uLong(0), ptr.baseAddress?.assumingMemoryBound(to: UInt8.self), UInt32(data.count))
            }
            
            guard thisCRC32 == receivedCRC32 else {
                showMessage(title: localize("newExperimentQRErrorTitle"), msg: localize("newExperimentQRBadCRC"), endScanner: true)
                return
            }
            
            let tmp = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("temp.phyphox")
            
            do {
                try data.write(to: tmp, options: .atomic)
            } catch {
                showMessage(title: localize("newExperimentQRErrorTitle"), msg: "Could not write QR code content to temporary file.", endScanner: true)
                return
            }

            
            dismiss(animated: true, completion: {() in _ = self.experimentLauncher?.launchExperimentByURL(tmp, chosenPeripheral: nil)})
        }
        

    }
    
    var lastRaw: Data? = nil
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        
        guard let metadataObject = (metadataObjects.first as? AVMetadataMachineReadableCodeObject) else {
            return
        }
        
        guard let internalDescriptor = (metadataObject.value(forKeyPath: "_internal.basicDescriptor") as? [String:Any]) else {
            showMessage(title: "Unexpected error.", msg: "Cannot retrieve internal QR code descriptor.", endScanner: true)
            return
        }
        
        guard let rawData = internalDescriptor["BarcodeRawData"] as? NSData else {
            showMessage(title: "Unexpected error.", msg: "Cannot retrieve raw data from internal QR code descriptor.", endScanner: true)
            return
        }
        let raw = rawData as Data
        
        //Only trigger once for each QR code
        if (lastRaw != nil && lastRaw!.elementsEqual(raw)) {
            return
        } else {
            lastRaw = raw
        }
        
        let content = metadataObject.stringValue

        if content != nil && (content!.starts(with: "phyphox://") || content!.starts(with: "http://") || content!.starts(with: "https://")) {
            //This is a URL to a phyphox experiment
            guard let url = URL.init(string: content!) else {
                showMessage(title: localize("newExperimentQRErrorTitle"), msg: localize("newExperimentQRNoExperiment"), endScanner: true)
                return
            }
            dismiss(animated: true, completion: {() in _ = self.experimentLauncher?.launchExperimentByURL(url, chosenPeripheral: nil)})
        } else {
            //The experiment is directly encoded in the QR code as a zip file
            
            //The raw data consists of 4 bits denoting the encoding (for experiments directly encoded in the QR code we only support binary, i.e. 0010), followed by 8 or 16 bits for the length of the data. Then the raw data follows padded with "ec 11"
            
            guard raw[0] & 0xf0 == 0x40 else {
                showMessage(title: "Unexpected error.", msg: "QR Code does not contain a valid URL and is not binary.", endScanner: true)
                return
            }
            
            //Shit all data by 4 bits, so the rest is byte-alligned
            var shiftedData = Data()
            for  i in 1..<raw.count {
                let byte: UInt8 = ((raw[i-1] & 0x0f) << 4) | ((raw[i] & 0xf0) >> 4)
                shiftedData.append(byte)
            }
            
            guard shiftedData.count >= 14 else {
                showMessage(title: "Unexpected error.", msg: "QR Code does not contain a valid URL and is too short to contain an experiment.", endScanner: true)
                return
            }
            
            //Now depending on the QR version we have one or two bytes indicating the size. Let's just look for our keyword "phyphox" to figure out which it is and store the remainder for further processing.
            var data: Data
            if shiftedData.subdata(in: 1..<8) == "phyphox".data(using: .utf8) {
                let length = Int(shiftedData[0])
                data = shiftedData.subdata(in: ((1+7)..<(length+1)))
            } else if shiftedData.subdata(in: 2..<9) == "phyphox".data(using: .utf8) {
                let length = (Int(shiftedData[0]) << 8) | Int(shiftedData[1])
                data = shiftedData.subdata(in: ((2+7)..<(length+2)))
            } else {
                showMessage(title: localize("newExperimentQRErrorTitle"), msg: localize("newExperimentQRNoExperiment"), endScanner: true)
                return
            }

            handlePhyphoxRawData(raw: data)
            
        }
        
    }
    
    func abortWithError(message: String) {
        error = message
    }
    
    func dismissScanner(_ action: UIAlertAction) {
        dismiss(animated: true, completion: nil)
    }
    
    @objc func cancel() {
        dismiss(animated: true, completion: nil)
    }
    
}
