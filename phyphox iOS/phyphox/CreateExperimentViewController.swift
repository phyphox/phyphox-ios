//
//  CreateExperimentViewController.swift
//  phyphox
//
//  Created by Jonas Gessner on 03.04.16.
//  Copyright © 2016 Jonas Gessner. All rights reserved.
//  By Order of RWTH Aachen.
//

import UIKit

struct MapSensorType: OptionSetType {
    let rawValue: Int
    
    static let None = MapSensorType(rawValue: 0)
    
    static let Accelerometer = MapSensorType(rawValue: 1 << 0) //1
    static let LinearAccelerometer = MapSensorType(rawValue: 1 << 1) //2
    static let Gyroscope = MapSensorType(rawValue: 1 << 2) //4
    static let Magnetometer = MapSensorType(rawValue: 1 << 3) //8
    static let Barometer = MapSensorType(rawValue: 1 << 4) //16
}

class CreateExperimentViewController: UITableViewController {
    private var selectedSensors = MapSensorType.None
    private var experimentTitle: String?
    private var bufferSizeString: String?
    private var rateString: String?
    
    init() {
        super.init(style: .Grouped)
        
        tableView.registerClass(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        tableView.registerClass(TextFieldTableViewCell.self, forCellReuseIdentifier: "TextCell")
        
        tableView.keyboardDismissMode = .OnDrag
        
        title = NSLocalizedString("newExperiment", comment: "")
        
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .Save, target: self, action: #selector(save))
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .Cancel, target: self, action: #selector(cancel))
        
        self.navigationItem.rightBarButtonItem!.enabled = false
    }
    
    required convenience init?(coder aDecoder: NSCoder) {
        self.init()
    }
    
    func cancel() {
        self.navigationController!.dismissViewControllerAnimated(true, completion: nil)
    }
    
    func save() {
        guard let title = experimentTitle, let size = Int(bufferSizeString!), let rate = Double(rateString!.stringByReplacingOccurrencesOfString(",", withString: ".")) else {
            let hud = JGProgressHUD(style: .Dark)
            hud.interactionType = .BlockTouchesOnHUDView
            hud.indicatorView = JGProgressHUDErrorIndicatorView()
            
            hud.textLabel.text = "Invalid input"
            
            hud.showInView(self.navigationController!.view)
            hud.dismissAfterDelay(3.0)
            
            return
        }
        
        let selected = selectedSensors
        
        let hud = JGProgressHUD(style: .Dark)
        hud.interactionType = .BlockTouchesOnHUDView
        hud.showInView(self.presentingViewController!.view)
        
        do {
            try SimpleExperimentSerializer.writeSimpleExperiment(title: title, bufferSize: size, rate: rate, sensors: selected)
            hud.dismiss()
        }
        catch let error as NSError {
            
            hud.indicatorView = JGProgressHUDErrorIndicatorView()
            
            hud.textLabel.text = "Failed to create Experiment: \(error.localizedDescription)"
            
            hud.dismissAfterDelay(3.0)
        }
        
        self.navigationController!.dismissViewControllerAnimated(true, completion: nil)
    }
    
    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 4
    }
    
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section < 3 {
            return 1
        }
        else {
            return 5
        }
    }
    
    override func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
//        case 0:
//            return "Title"
//        case 1:
//            return "Buffer Size"
//        case 2:
//            return "Sensor Refresh Rate"
        case 3:
            return NSLocalizedString("newExperimentInputSensors", comment: "")
        default:
            return nil
        }
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        if indexPath.section == 3 {
            let cell = tableView.dequeueReusableCellWithIdentifier("Cell", forIndexPath: indexPath)
            
            switch indexPath.row {
            case 0:
                cell.textLabel!.text = NSLocalizedString("sensorAccelerometer", comment: "")
                cell.accessoryType = selectedSensors.contains(.Accelerometer) ? .Checkmark : .None
            case 1:
                cell.textLabel!.text = NSLocalizedString("sensorLinearAcceleration", comment: "")
                cell.accessoryType = selectedSensors.contains(.LinearAccelerometer) ? .Checkmark : .None
            case 2:
                cell.textLabel!.text = NSLocalizedString("sensorGyroscope", comment: "")
                cell.accessoryType = selectedSensors.contains(.Gyroscope) ? .Checkmark : .None
            case 3:
                cell.textLabel!.text = NSLocalizedString("sensorMagneticField", comment: "")
                cell.accessoryType = selectedSensors.contains(.Magnetometer) ? .Checkmark : .None
            case 4:
                cell.textLabel!.text = NSLocalizedString("sensorPressure", comment: "")
                cell.accessoryType = selectedSensors.contains(.Barometer) ? .Checkmark : .None
            default:
                break
            }
            
            return cell
        }
        else {
            let cell = tableView.dequeueReusableCellWithIdentifier("TextCell", forIndexPath: indexPath) as! TextFieldTableViewCell
            
            if indexPath.section == 0 {
                cell.textField.placeholder = NSLocalizedString("newExperimentInputTitle", comment: "")
                cell.textField.keyboardType = .Default
                cell.textField.text = experimentTitle
            }
            else if indexPath.section == 1 {
                cell.textField.placeholder = NSLocalizedString("newExperimentInputBufferSize", comment: "")
                cell.textField.keyboardType = .DecimalPad
                cell.textField.text = bufferSizeString
            }
            else if indexPath.section == 2 {
                cell.textField.placeholder = NSLocalizedString("newExperimentInputRate", comment: "")
                cell.textField.keyboardType = .DecimalPad
                cell.textField.text = rateString
            }
            
            cell.editingEndedCallback = { [unowned self] in
                self.updateSaveButton()
            }
            
            cell.editingChangedCallback = { [unowned self, unowned cell] in
                if indexPath.section == 0 {
                    self.experimentTitle = cell.textField.text
                }
                else if indexPath.section == 1 {
                    self.bufferSizeString = cell.textField.text
                }
                else if indexPath.section == 2 {
                    self.rateString = cell.textField.text
                }
                
                self.updateSaveButton()
            }
            
            return cell
        }
    }
    
    func updateSaveButton() {
        let titleCellCheck = experimentTitle?.characters.count > 0
        let sizeCellCheck = bufferSizeString?.characters.count > 0
        let rateCellCheck = rateString?.characters.count > 0
        
        self.navigationItem.rightBarButtonItem!.enabled = titleCellCheck && sizeCellCheck && rateCellCheck && selectedSensors != .None
    }
    
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        tableView.deselectRowAtIndexPath(indexPath, animated: true)
        
        if indexPath.section == 3 {
            var t: MapSensorType! = nil
            
            switch indexPath.row {
            case 0:
                t = .Accelerometer
                
            case 1:
                t = .LinearAccelerometer
                
            case 2:
                t = .Gyroscope
                
            case 3:
                t = .Magnetometer
                
            case 4:
                t = .Barometer
                
            default:
                break
            }
            
            let cell = tableView.cellForRowAtIndexPath(indexPath)!
            
            if selectedSensors.contains(t) {
                selectedSensors.remove(t)
                cell.accessoryType = .None
            }
            else {
                selectedSensors.unionInPlace(t)
                cell.accessoryType = .Checkmark
            }
            
            updateSaveButton()
        }
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = kBackgroundColor
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
