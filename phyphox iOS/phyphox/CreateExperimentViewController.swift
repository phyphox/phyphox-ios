//
//  CreateExperimentViewController.swift
//  phyphox
//
//  Created by Jonas Gessner on 03.04.16.
//  Copyright © 2016 RWTH Aachen. All rights reserved.
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
    var selectedSensors = MapSensorType.None
    
    init() {
        super.init(style: .Grouped)
        
        tableView.registerClass(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        tableView.registerClass(TextFieldTableViewCell.self, forCellReuseIdentifier: "TextCell")
        
        tableView.keyboardDismissMode = .OnDrag
        
        title = "Create Experiment"
        
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
        let title = (tableView.cellForRowAtIndexPath(NSIndexPath(forRow: 0, inSection: 0)) as! TextFieldTableViewCell).textField.text!
        let size = Int((tableView.cellForRowAtIndexPath(NSIndexPath(forRow: 0, inSection: 1)) as! TextFieldTableViewCell).textField.text!)!
        let rate = Double((tableView.cellForRowAtIndexPath(NSIndexPath(forRow: 0, inSection: 2)) as! TextFieldTableViewCell).textField.text!.stringByReplacingOccurrencesOfString(",", withString: "."))!
        
        let selected = selectedSensors
        
        let hud = JGProgressHUD(style: .Dark)
        hud.showInView(self.presentingViewController!.view)
        
        self.navigationController!.dismissViewControllerAnimated(true, completion: nil)
        
        //The main collection view controller messes up if it is reloaded while the custom transition is running (??)
        after(0.8) {
            do {
                try SimpleExperimentSerializer.writeSimpleExperiment(title: title, bufferSize: size, rate: rate, sensors: selected)
                hud.dismiss()
            }
            catch let error as NSError {
                
                hud.indicatorView = JGProgressHUDErrorIndicatorView()
                
                hud.textLabel.text = "Failed to create Experiment: \(error.localizedDescription)"

                hud.dismissAfterDelay(3.0)
            }
        }
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
            return "Sensors"
        default:
            return nil
        }
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        if indexPath.section == 3 {
            let cell = tableView.dequeueReusableCellWithIdentifier("Cell", forIndexPath: indexPath)
            
            switch indexPath.row {
            case 0:
                cell.textLabel!.text = "Accelerometer"
                cell.accessoryType = selectedSensors.contains(.Accelerometer) ? .Checkmark : .None
            case 1:
                cell.textLabel!.text = "Linear Accelerometer"
                cell.accessoryType = selectedSensors.contains(.LinearAccelerometer) ? .Checkmark : .None
            case 2:
                cell.textLabel!.text = "Gyroscope"
                cell.accessoryType = selectedSensors.contains(.Gyroscope) ? .Checkmark : .None
            case 3:
                cell.textLabel!.text = "Magnetometer"
                cell.accessoryType = selectedSensors.contains(.Magnetometer) ? .Checkmark : .None
            case 4:
                cell.textLabel!.text = "Barometer"
                cell.accessoryType = selectedSensors.contains(.Barometer) ? .Checkmark : .None
            default:
                break
            }
            
            return cell
        }
        else {
            let cell = tableView.dequeueReusableCellWithIdentifier("TextCell", forIndexPath: indexPath) as! TextFieldTableViewCell
            
            if indexPath.section == 0 {
                cell.textField.placeholder = "Title"
                cell.textField.keyboardType = .Default
            }
            else if indexPath.section == 1 {
                cell.textField.placeholder = "Buffer Size"
                cell.textField.keyboardType = .DecimalPad
            }
            else if indexPath.section == 2 {
                cell.textField.placeholder = "Sensor Refresh Rate (Hz)"
                cell.textField.keyboardType = .DecimalPad
            }
            
            cell.editingEndedCallback = { [unowned self] in
                self.updateSaveButton()
            }
            
            cell.editingChangedCallback = { [unowned self] in
                self.updateSaveButton()
            }
            
            return cell
        }
    }
    
    func updateSaveButton() {
        let titleCellCheck = (tableView.cellForRowAtIndexPath(NSIndexPath(forRow: 0, inSection: 0)) as! TextFieldTableViewCell).textField.text?.characters.count > 0
        let sizeCellCheck = (tableView.cellForRowAtIndexPath(NSIndexPath(forRow: 0, inSection: 1)) as! TextFieldTableViewCell).textField.text?.characters.count > 0
        let rateCellCheck = (tableView.cellForRowAtIndexPath(NSIndexPath(forRow: 0, inSection: 2)) as! TextFieldTableViewCell).textField.text?.characters.count > 0
        
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
