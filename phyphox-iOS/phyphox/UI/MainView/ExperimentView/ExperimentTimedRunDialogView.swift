//
//  ExperimentTimedRunDialog.swift
//  phyphox
//
//  Created by Sebastian Staacks on 09.04.21.
//  Copyright © 2021 RWTH Aachen. All rights reserved.
//

import Foundation

private let ySpacing: CGFloat = 3.0
private let xSpacing: CGFloat = 10.0

private let checkboxSize = CGSize(width: 30.0, height: 30.0)
private let textfieldSize = CGSize(width: 60.0, height: 30.0)

final class ExperimentTimedRunDialogView: UIView, BEMCheckBoxDelegate {
    
    public struct AllSwitch {
        let sw: BEMCheckBox
        let la: UILabel
    }
    
    public struct BeeperSwitch {
        let sw: UISwitch
        let la: UILabel
    }
    
    public struct TimerField {
        let tf: UITextField
        let la: UILabel
    }

    public let beeperAll: AllSwitch
    public let beeperCountdown: BeeperSwitch
    public let beeperStart: BeeperSwitch
    public let beeperRunning: BeeperSwitch
    public let beeperStop: BeeperSwitch
    
    public let delay: TimerField
    public let duration: TimerField
    
    init(delay: Double, duration: Double, countdown: Bool, start: Bool, running: Bool, stop: Bool) {
                
        func setupAllSwitch(on: Bool, label: String) -> AllSwitch {
            let sw = BEMCheckBox()
            sw.boxType = .square
            sw.offAnimationType = .bounce
            sw.onAnimationType = .bounce
            sw.on = on
            sw.lineWidth = 1.0
            sw.onTintColor = kHighlightColor
            sw.onCheckColor = kHighlightColor
            sw.offFillColor = UIColor.init(white: 1.0, alpha: 0.5)


            let la = UILabel()
            la.font = UIFont.preferredFont(forTextStyle: UIFont.TextStyle.caption1)
            
            la.text = label
            la.textColor = UIColor.init(white: 0.0, alpha: 1.0)
            
            return AllSwitch(sw: sw, la: la)
        }
        
        func setupBeeperSwitch(on: Bool, label: String) -> BeeperSwitch {
            let sw = UISwitch()
            sw.setOn(on, animated: false)
            
            let la = UILabel()
            la.font = UIFont.preferredFont(forTextStyle: UIFont.TextStyle.caption1)
            
            la.text = label
            la.textColor = UIColor.init(white: 0.0, alpha: 1.0)
            
            return BeeperSwitch(sw: sw, la: la)
        }
        
        beeperAll = setupAllSwitch(on: countdown || start || running || stop, label: localize("timedRunBeeps"))
        beeperCountdown = setupBeeperSwitch(on: countdown, label: localize("beeperCountdown"))
        beeperStart = setupBeeperSwitch(on: start, label: localize("beeperStart"))
        beeperRunning = setupBeeperSwitch(on: running, label: localize("beeperRunning"))
        beeperStop = setupBeeperSwitch(on: stop, label: localize("beeperStop"))
        
        func setupTimerField(value: Double, label: String) -> TimerField {
            let tf = UITextField()
            tf.returnKeyType = .done
            tf.borderStyle = .roundedRect
            tf.keyboardType = .decimalPad
            tf.text = String(value)
            tf.textColor = UIColor.init(white: 0.0, alpha: 1.0)
            tf.backgroundColor = UIColor.init(white: 1.0, alpha: 1.0)
            
            let la = UILabel()
            la.font = UIFont.preferredFont(forTextStyle: UIFont.TextStyle.caption1)
            la.text = label
            la.textColor = UIColor.init(white: 0.0, alpha: 1.0)
            
            return TimerField(tf: tf, la: la)
        }
        
        self.delay = setupTimerField(value: delay, label: localize("timedRunStartDelay"))
        self.duration = setupTimerField(value: duration, label: localize("timedRunStopDelay"))
        
        super.init(frame: .zero)
                
        beeperAll.sw.delegate = self
        addSubview(beeperAll.sw)
        addSubview(beeperAll.la)
        
        beeperCountdown.sw.addTarget(self, action: #selector(beeperSwitchChanged), for: UIControl.Event.valueChanged)

        addSubview(beeperCountdown.sw)
        addSubview(beeperCountdown.la)

        beeperStart.sw.addTarget(self, action: #selector(beeperSwitchChanged), for: UIControl.Event.valueChanged)
        addSubview(beeperStart.sw)
        addSubview(beeperStart.la)
            
        beeperRunning.sw.addTarget(self, action: #selector(beeperSwitchChanged), for: UIControl.Event.valueChanged)
        addSubview(beeperRunning.sw)
        addSubview(beeperRunning.la)
            
        beeperStop.sw.addTarget(self, action: #selector(beeperSwitchChanged), for: UIControl.Event.valueChanged)
        addSubview(beeperStop.sw)
        addSubview(beeperStop.la)
        
        addSubview(self.delay.tf)
        addSubview(self.delay.la)
        
        addSubview(self.duration.tf)
        addSubview(self.duration.la)
    }
    
    func didTap(_ checkBox: BEMCheckBox) {
        beeperAll.sw.offFillColor = UIColor.init(white: 1.0, alpha: 0.5)
        beeperCountdown.sw.setOn(beeperAll.sw.on, animated: true)
        beeperStart.sw.setOn(beeperAll.sw.on, animated: true)
        beeperRunning.sw.setOn(beeperAll.sw.on, animated: true)
        beeperStop.sw.setOn(beeperAll.sw.on, animated: true)
    }
    
    @objc func beeperSwitchChanged(switch: UISwitch) {
        if beeperStart.sw.isOn == beeperStop.sw.isOn && beeperStart.sw.isOn == beeperRunning.sw.isOn && beeperStart.sw.isOn == beeperCountdown.sw.isOn {
            if beeperStart.sw.isOn {
                beeperAll.sw.offFillColor = UIColor.init(white: 1.0, alpha: 0.5)
                beeperAll.sw.setOn(true, animated: true)
            } else {
                beeperAll.sw.offFillColor = UIColor.init(white: 1.0, alpha: 0.5)
                beeperAll.sw.setOn(false, animated: true)
            }
        } else {
            beeperAll.sw.offFillColor = kHighlightColor.withAlphaComponent(0.5)
            beeperAll.sw.setOn(false, animated: true)
        }
    }
    
    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func sizeThatFits(_ size: CGSize) -> CGSize {
        var w: CGFloat = 0.0
        var h: CGFloat = 0.0
        
        let switchSize = checkboxSize
        
        for timer in [delay, duration] {
            let s = timer.la.sizeThatFits(size)
            
            w = max(xSpacing+s.width+xSpacing+switchSize.width+xSpacing, w)
            h += 2*ySpacing+max(s.height, switchSize.height)
        }
        
        let s = beeperAll.la.sizeThatFits(size)
        w = max(xSpacing+s.width+xSpacing+switchSize.width+xSpacing, w)
        h += 2*ySpacing+max(s.height, switchSize.height)
        
        for beeper in [beeperCountdown, beeperStart, beeperRunning, beeperStop] {
            let s = beeper.la.sizeThatFits(size)
            
            w = max(xSpacing+s.width+xSpacing+switchSize.width+xSpacing, w)
            h += 2*ySpacing+max(s.height, switchSize.height)
        }
        h += 4 * ySpacing
        
        return CGSize(width: max(w, size.width), height: h+20.0) //Need some more space so it doesn't look weird on the alert
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        var h: CGFloat = 0.0
        
        let switchSize = checkboxSize
        
        for timer in [delay, duration] {
            let s = timer.la.sizeThatFits(bounds.size)
            let tf = timer.tf
            
            let heightDelta = (textfieldSize.height-s.height)/2.0
            
            timer.la.frame = CGRect(x: xSpacing, y: h+2*ySpacing+heightDelta, width: s.width, height: s.height)
            
            tf.frame = CGRect(x: self.bounds.size.width-textfieldSize.width-xSpacing, y: timer.la.center.y-textfieldSize.height/2.0, width: textfieldSize.width, height: textfieldSize.height)
            
            h += 2*ySpacing+max(s.height, switchSize.height)
        }
        
        h += 4*ySpacing
        
        let s = beeperAll.la.sizeThatFits(bounds.size)
        let sw = beeperAll.sw
        let heightDelta = (switchSize.height-s.height)/2.0
        beeperAll.la.frame = CGRect(x: xSpacing, y: h+2*ySpacing+heightDelta, width: s.width, height: s.height)
        sw.frame = CGRect(x: self.bounds.size.width-switchSize.width-xSpacing, y: beeperAll.la.center.y-switchSize.height/2.0, width: switchSize.width, height: switchSize.height)
        
        h += 2*ySpacing+max(s.height, switchSize.height)
        
        for beeper in [beeperCountdown, beeperStart, beeperRunning, beeperStop] {
            let s = beeper.la.sizeThatFits(bounds.size)
            let sw = beeper.sw
            
            let sws = beeper.sw.sizeThatFits(bounds.size)

            let heightDelta = (sws.height-s.height)/2.0
            
            beeper.la.frame = CGRect(x: xSpacing * 4, y: h+2*ySpacing+heightDelta, width: s.width, height: s.height)
            
            sw.frame = CGRect(x: self.bounds.size.width-sws.width-xSpacing, y: beeper.la.center.y-sws.height/2.0, width: sws.width, height: sws.height)
            
            h += 2*ySpacing+max(s.height, sws.height)
        }
    }
}
