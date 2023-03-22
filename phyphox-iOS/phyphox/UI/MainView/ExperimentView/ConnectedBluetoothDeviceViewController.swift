//
//  ConnectedBluetoothDeviceViewController.swift
//  phyphox
//
//  Created by Gaurav Tripathee on 10.03.23.
//  Copyright © 2023 RWTH Aachen. All rights reserved.
//

import Foundation

class ConnectedBluetoothDevicesViewController: UICollectionView, UICollectionViewDataSource {
    
    private var data: [ConnectedDevicesDataModel] = [ConnectedDevicesDataModel]()
    
    init(frame: CGRect, collectionViewLayout layout: UICollectionViewLayout, data: [ConnectedDevicesDataModel]) {
        super.init(frame: frame, collectionViewLayout: layout)
        self.register(ConnectedBleDeviceCell.self, forCellWithReuseIdentifier: "ConnectedBleDeviceCell")
        self.dataSource = self
        self.data = data
        layout.collectionView?.backgroundColor = UIColor(named: "backgroundDark")
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return data.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {

        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ConnectedBleDeviceCell", for: indexPath) as? ConnectedBleDeviceCell else {
            return UICollectionViewCell()
        }
        
        cell.contentView.backgroundColor = UIColor(named: "backgroundDark")
        
        let dataModel: ConnectedDevicesDataModel = ConnectedDevicesDataModel(signalStrength: data[indexPath.row].getSignalStrength(), batteryLabel: data[indexPath.row].getBatteryLabel(), deviceName: data[indexPath.row].getDeviceName())
        
        cell.configure(model: dataModel)
        
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        // handle cell selection
    }
    
}

class ConnectedBleDeviceCell: UICollectionViewCell {
    
    let batteryImageView = UIImageView()
    let signalImageView = UIImageView()
    let deviceLabel = UILabel()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        
        deviceLabel.font = UIFont.systemFont(ofSize: 14)
        deviceLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(deviceLabel)
        NSLayoutConstraint.activate([
            deviceLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            deviceLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            deviceLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
        ])
        
        batteryImageView.contentMode = .scaleAspectFit
        
        batteryImageView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(batteryImageView)
        NSLayoutConstraint.activate([
            batteryImageView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            batteryImageView.leadingAnchor.constraint(equalTo: deviceLabel.trailingAnchor, constant: 8),
            
            batteryImageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor,  constant: -8)
        ])
        
        signalImageView.contentMode = .scaleAspectFit
        signalImageView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(signalImageView)
        NSLayoutConstraint.activate([
            signalImageView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            signalImageView.leadingAnchor.constraint(equalTo: batteryImageView.trailingAnchor, constant: 8),
            signalImageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            signalImageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor,  constant: -8)
        ])
        
    }
    

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @available(iOS 13.0, *)
    func getSignal(rssi: Int) -> UIImage{
      
        if rssi > -35 {
            return (UIImage(named: "cellular_level_4")?.withTintColor(.black, renderingMode: .alwaysOriginal))!
        } else if rssi > -55 {
            return (UIImage(named: "cellular_level_3")?.withTintColor(.black, renderingMode: .alwaysOriginal))!
        } else if rssi > -70 {
            return (UIImage(named: "cellular_level_2")?.withTintColor(.black, renderingMode: .alwaysOriginal))!
        } else if rssi > -90 {
            return (UIImage(named: "cellular_level_1")?.withTintColor(.black, renderingMode: .alwaysOriginal))!
        } else {
            return (UIImage(named: "cellular_level_0")?.withTintColor(.black, renderingMode: .alwaysOriginal))!
        }
        
        
    }
    
    @available(iOS 13.0, *)
    func getBatteryLevel(level: Int) -> UIImage{
        let config = UIImage.SymbolConfiguration(
            pointSize: 25, weight: .medium, scale: .default)
        
       if level == -1 {
           return UIImage()
           
        } else if level < 5 {
            return UIImage(systemName: "battery.0", withConfiguration: config)!
        }
        else if level < 25 {
            return UIImage(systemName: "battery.25", withConfiguration: config)!
        } else if level < 50 {
            return  UIImage(systemName: "battery.50", withConfiguration: config)!
        } else if level < 75 {
            return UIImage(systemName: "battery.75", withConfiguration: config)!
        } else if level < 100 {
            return  UIImage(systemName: "battery.100", withConfiguration: config)!
        } else{
            return UIImage(systemName: "battery.100", withConfiguration: config)!
        }
        
    }
    
    
    @available(iOS 13.0, *)
    func getImageAsDeviceMode(image: UIImage) -> UIImage{
        if(SettingBundleHelper.getAppMode() == Utility.LIGHT_MODE){
            return image.withTintColor(.black, renderingMode: .alwaysOriginal)
        } else if(SettingBundleHelper.getAppMode() == Utility.DARK_MODE){
            return image.withTintColor(UIColor(white: 1.0, alpha: 1.0), renderingMode: .alwaysOriginal)
        } else {
            if(UIScreen.main.traitCollection.userInterfaceStyle == .light){
                return image.withTintColor(.black, renderingMode: .alwaysOriginal)
            } else {
                return image.withTintColor(UIColor(white: 1.0, alpha: 1.0), renderingMode: .alwaysOriginal)
            }
        }
    }
    
    func configure(model: ConnectedDevicesDataModel){
        deviceLabel.text = model.getDeviceName()
        if #available(iOS 13.0, *) {
            signalImageView.image = getSignal(rssi: model.getSignalStrength())
            let getBatteryLevelImage = getBatteryLevel(level: model.getBatteryLabel())
            batteryImageView.image = getBatteryLevelImage.withTintColor(.black, renderingMode: .alwaysOriginal)
        } else {
            // Fallback on earlier versions
        }
    }
    
}
