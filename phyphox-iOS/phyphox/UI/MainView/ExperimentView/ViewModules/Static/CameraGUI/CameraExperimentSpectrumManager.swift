//
//  CameraExperimentSpectrumManager.swift
//  phyphox
//
//  Created by Gaurav Tripathee on 10.02.26.
//  Copyright © 2026 RWTH Aachen. All rights reserved.
//

import UIKit

//Orientation of the device relative to the dispersion direction of the spectrum, selected by the
//user in the camera GUI of a spectroscopy experiment. The direction of the dispersion (i.e.
//whether blue is on the left or on the right) is deliberately not part of this: the calibration
//takes care of it. Matches Android's SpectroscopyAnalyzer.SpectrumOrientation.
enum SpectrumOrientation {
    case landscape
    case portrait
}

//Draws the icons illustrating the two orientations: a spectrum with its dispersion axis marked by
//a double-headed arrow, next to a device in landscape or portrait orientation. The artwork
//replicates the Android vector drawables spectrometer_orientation_landscape/portrait, with the
//monochrome parts drawn in a configurable color instead of white so they work on light and dark
//backgrounds.
struct SpectrumOrientationIcon {

    //Viewport size of the original artwork
    private static let artSize = CGSize(width: 285.4, height: 221.5)

    //x position, top y, bottom y and color of the bars representing the spectrum
    private static let spectrumBars: [(x: CGFloat, top: CGFloat, bottom: CGFloat, color: UIColor)] = [
        (10.4, 59.5, 109.5, UIColor(red: 0x7d/255.0, green: 0x3c/255.0, blue: 0xff/255.0, alpha: 0.45)),
        (28.4, 48.5, 120.5, UIColor(red: 0x51/255.0, green: 0x47/255.0, blue: 0xff/255.0, alpha: 0.6)),
        (46.4, 37.0, 132.0, UIColor(red: 0x29/255.0, green: 0x7d/255.0, blue: 0xff/255.0, alpha: 0.75)),
        (64.4, 28.5, 140.5, UIColor(red: 0x00/255.0, green: 0xb9/255.0, blue: 0xff/255.0, alpha: 1.0)),
        (82.4, 24.5, 144.5, UIColor(red: 0x00/255.0, green: 0xd8/255.0, blue: 0x6b/255.0, alpha: 1.0)),
        (100.4, 29.5, 139.5, UIColor(red: 0x9b/255.0, green: 0xe0/255.0, blue: 0x00/255.0, alpha: 1.0)),
        (118.4, 22.0, 147.0, UIColor(red: 0xff/255.0, green: 0xe4/255.0, blue: 0x00/255.0, alpha: 1.0)),
        (136.4, 30.5, 138.5, UIColor(red: 0xff/255.0, green: 0xb0/255.0, blue: 0x00/255.0, alpha: 1.0)),
        (154.4, 40.5, 128.5, UIColor(red: 0xff/255.0, green: 0x70/255.0, blue: 0x00/255.0, alpha: 1.0)),
        (172.4, 50.5, 118.5, UIColor(red: 0xff/255.0, green: 0x2f/255.0, blue: 0x00/255.0, alpha: 1.0)),
    ]

    static func image(for orientation: SpectrumOrientation, height: CGFloat, color: UIColor) -> UIImage {
        let scale = height / artSize.height
        let size = CGSize(width: artSize.width * scale, height: height)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            let c = context.cgContext
            c.scaleBy(x: scale, y: scale)
            drawSpectrumWithDispersionAxis(in: c, color: color)
            drawDevice(in: c, orientation: orientation, color: color)
        }
    }

    private static func drawSpectrumWithDispersionAxis(in c: CGContext, color: UIColor) {
        c.setLineCap(.round)

        for bar in spectrumBars {
            c.setLineWidth(7.0)
            c.setStrokeColor(bar.color.cgColor)
            c.move(to: CGPoint(x: bar.x, y: bar.top))
            c.addLine(to: CGPoint(x: bar.x, y: bar.bottom))
            c.strokePath()
        }

        //Double-headed arrow above the spectrum marking the dispersion axis
        c.setLineWidth(3.0)
        c.setStrokeColor(color.cgColor)
        c.move(to: CGPoint(x: 2.4, y: 9.5))
        c.addLine(to: CGPoint(x: 182.4, y: 9.5))
        c.move(to: CGPoint(x: 172.4, y: 1.5))
        c.addLine(to: CGPoint(x: 182.4, y: 9.5))
        c.addLine(to: CGPoint(x: 172.4, y: 17.5))
        c.move(to: CGPoint(x: 12.4, y: 1.5))
        c.addLine(to: CGPoint(x: 2.4, y: 9.5))
        c.addLine(to: CGPoint(x: 12.4, y: 17.5))
        c.strokePath()
    }

    private static func drawDevice(in c: CGContext, orientation: SpectrumOrientation, color: UIColor) {
        let body: CGRect
        let speaker: CGRect
        let buttonCenter: CGPoint
        switch orientation {
        case .landscape:
            body = CGRect(x: 103.4, y: 121.5, width: 180.0, height: 98.0)
            speaker = CGRect(x: 109.4, y: 156.5, width: 4.0, height: 28.0)
            buttonCenter = CGPoint(x: 273.4, y: 170.5)
        case .portrait:
            body = CGRect(x: 185.4, y: 39.5, width: 98.0, height: 180.0)
            speaker = CGRect(x: 220.4, y: 45.5, width: 28.0, height: 4.0)
            buttonCenter = CGPoint(x: 234.4, y: 209.5)
        }

        c.setLineWidth(4.0)
        c.setStrokeColor(color.cgColor)
        c.addPath(UIBezierPath(roundedRect: body, cornerRadius: 18.0).cgPath)
        c.strokePath()

        c.setFillColor(color.cgColor)
        c.addPath(UIBezierPath(roundedRect: speaker, cornerRadius: 2.0).cgPath)
        c.fillPath()
        c.addEllipse(in: CGRect(x: buttonCenter.x - 3.5, y: buttonCenter.y - 3.5, width: 7.0, height: 7.0))
        c.fillPath()
    }
}
