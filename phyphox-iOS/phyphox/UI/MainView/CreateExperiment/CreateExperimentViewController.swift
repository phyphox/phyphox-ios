//
//  CreateExperimentViewController.swift
//  phyphox
//
//  Created by Jonas Gessner on 03.04.16.
//  Copyright © 2016 Jonas Gessner. All rights reserved.
//

import UIKit

struct MapSensorType: OptionSet {
    let rawValue: Int
    
    static let None = MapSensorType([])
    
    static let Accelerometer = MapSensorType(rawValue: 1 << 0) //1
    static let LinearAccelerometer = MapSensorType(rawValue: 1 << 1) //2
    static let Gyroscope = MapSensorType(rawValue: 1 << 2) //4
    static let Magnetometer = MapSensorType(rawValue: 1 << 3) //8
    static let Barometer = MapSensorType(rawValue: 1 << 4) //16
    static let Proximity = MapSensorType(rawValue: 1 << 5) //32
    static let GPS = MapSensorType(rawValue: 1 << 6) //64
}

class CreateExperimentViewController: UITableViewController {
    private var selectedSensors = MapSensorType.None
    private var experimentTitle: String?
    private var rateString: String?
    
    func actualInit() {
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        tableView.register(TextFieldTableViewCell.self, forCellReuseIdentifier: "TextCell")
        
        tableView.keyboardDismissMode = .onDrag
        
        title = localize("newExperimentSimple")
        
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .save, target: self, action: #selector(save))
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancel))
        
        self.navigationItem.rightBarButtonItem!.isEnabled = false
    }
    
    init() {
        super.init(style: .grouped)
        actualInit()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        actualInit()
    }
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        actualInit()
    }
    
    @objc func cancel() {
        self.navigationController!.dismiss(animated: true, completion: nil)
    }
    
    @objc func save() {
        guard let title = experimentTitle, let rate = Double(rateString!.replacingOccurrences(of: ",", with: ".")) else {
            let hud = JGProgressHUD(style: .dark)
            hud.interactionType = .blockTouchesOnHUDView
            hud.indicatorView = JGProgressHUDErrorIndicatorView()
            
            hud.textLabel.text = "Invalid input"
            
            hud.show(in: self.navigationController!.view)
            hud.dismiss(afterDelay: 3.0)
            
            return
        }
        
        let selected = selectedSensors
        
        let hud = JGProgressHUD(style: .dark)
        hud.interactionType = .blockTouchesOnHUDView
        hud.show(in: self.presentingViewController!.view)
        
        do {
            try _ = SimpleExperimentSerializer.writeSimpleExperiment(title: title, bufferSize: 0, rate: rate, sensors: selected)
            hud.dismiss()
        }
        catch let error as NSError {
            
            hud.indicatorView = JGProgressHUDErrorIndicatorView()
            
            hud.textLabel.text = "Failed to create Experiment: \(error.localizedDescription)"
            
            hud.dismiss(afterDelay: 3.0)
        }
        
        self.navigationController!.dismiss(animated: true, completion: nil)
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 3
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section < 2 {
            return 1
        }
        else {
            return 7
        }
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
//        case 0:
//            return "Title"
//        case 1:
//            return "Buffer Size"
//        case 2:
//            return "Sensor Refresh Rate"
        case 2:
            return localize("newExperimentInputSensors")
        default:
            return nil
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 2 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
            
            switch indexPath.row {
            case 0:
                cell.textLabel!.text = localize("sensorAccelerometer")
                cell.accessoryType = selectedSensors.contains(.Accelerometer) ? .checkmark : .none
            case 1:
                cell.textLabel!.text = localize("sensorLinearAcceleration")
                cell.accessoryType = selectedSensors.contains(.LinearAccelerometer) ? .checkmark : .none
            case 2:
                cell.textLabel!.text = localize("location")
                cell.accessoryType = selectedSensors.contains(.GPS) ? .checkmark : .none
            case 3:
                cell.textLabel!.text = localize("sensorGyroscope")
                cell.accessoryType = selectedSensors.contains(.Gyroscope) ? .checkmark : .none
            case 4:
                cell.textLabel!.text = localize("sensorMagneticField")
                cell.accessoryType = selectedSensors.contains(.Magnetometer) ? .checkmark : .none
            case 5:
                cell.textLabel!.text = localize("sensorPressure")
                cell.accessoryType = selectedSensors.contains(.Barometer) ? .checkmark : .none
            case 6:
                cell.textLabel!.text = localize("sensorProximity")
                cell.accessoryType = selectedSensors.contains(.Proximity) ? .checkmark : .none
            default:
                break
            }
            
            return cell
        }
        else {
            let cell = tableView.dequeueReusableCell(withIdentifier: "TextCell", for: indexPath) as! TextFieldTableViewCell
            
            if indexPath.section == 0 {
                cell.textField.placeholder = localize("newExperimentInputTitle")
                cell.textField.keyboardType = .default
                cell.textField.text = experimentTitle
            }
            else if indexPath.section == 1 {
                cell.textField.placeholder = localize("newExperimentInputRate")
                cell.textField.keyboardType = .decimalPad
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
                    self.rateString = cell.textField.text
                }
                
                self.updateSaveButton()
            }
            
            return cell
        }
    }
    
    func updateSaveButton() {
        let titleCellCheck = experimentTitle?.count ?? 0 > 0
        let rateCellCheck = rateString?.count ?? 0 > 0
        
        self.navigationItem.rightBarButtonItem!.isEnabled = titleCellCheck && rateCellCheck && selectedSensors != .None
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        if indexPath.section == 2 {
            var t: MapSensorType! = nil
            
            switch indexPath.row {
            case 0:
                t = .Accelerometer
                
            case 1:
                t = .LinearAccelerometer
                
            case 2:
                t = .GPS
                
            case 3:
                t = .Gyroscope
                
            case 4:
                t = .Magnetometer
                
            case 5:
                t = .Barometer
                
            case 6:
                t = .Proximity
                
            default:
                break
            }
            
            let cell = tableView.cellForRow(at: indexPath)!
            
            if selectedSensors.contains(t) {
                selectedSensors.remove(t)
                cell.accessoryType = .none
            }
            else {
                selectedSensors.formUnion(t)
                cell.accessoryType = .checkmark
            }
            
            updateSaveButton()
        }
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
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
