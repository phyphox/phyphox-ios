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
    let cellIdentifier: String = "ConnectedBleDeviceCell"
    
    let flowLayout = UICollectionViewFlowLayout()
    
    init(frame: CGRect, data: [ConnectedDevicesDataModel]) {
        flowLayout.scrollDirection = .vertical
        flowLayout.minimumLineSpacing = 10
        flowLayout.minimumInteritemSpacing = 10
        flowLayout.itemSize = CGSize(width: frame.width, height: 40)
        flowLayout.collectionView?.backgroundColor = UIColor(named: "backgroundDark")
        super.init(frame: frame, collectionViewLayout: flowLayout)
        self.register(ConnectedBleDeviceCell.self, forCellWithReuseIdentifier: cellIdentifier)
        self.dataSource = self
        self.data = data
    }
    
    override func sizeThatFits(_ size: CGSize) -> CGSize {
        let cellHeights = CGFloat(data.count) * flowLayout.itemSize.height
        let spaceHeights = CGFloat(max(data.count - 1, 0)) * flowLayout.minimumLineSpacing
        return CGSize(width: frame.width, height: cellHeights + spaceHeights)
    }
    
    func updateData(_ data: [ConnectedDevicesDataModel]) -> Bool {
        let oldCount = self.data.count
        self.data = data
        self.reloadData()
        
        if (oldCount == data.count) {
            return false
        } else {
            self.setNeedsLayout()
            return true
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return data.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: cellIdentifier , for: indexPath) as? ConnectedBleDeviceCell else {
            return UICollectionViewCell()
        }
        
        cell.contentView.backgroundColor = UIColor(named: "backgroundDark")
        
        let dataModel: ConnectedDevicesDataModel = ConnectedDevicesDataModel(
            deviceIdentifier:data[indexPath.row].getDeviceIdentifier(),
            signalStrength:data[indexPath.row].getSignalStrength(),
            batteryLabel: data[indexPath.row].getBatteryLabel(),
            deviceName: data[indexPath.row].getDeviceName())
        
        cell.configure(model: dataModel)
        
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        // handle cell selection
    }
    
    override func layoutSubviews() {
        flowLayout.itemSize = CGSize(width: frame.width, height: 40)
        super.layoutSubviews()
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
            batteryImageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor,  constant: -8),
            batteryImageView.heightAnchor.constraint(equalTo: batteryImageView.widthAnchor)
        ])
        
        signalImageView.contentMode = .scaleAspectFit
        signalImageView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(signalImageView)
        NSLayoutConstraint.activate([
            signalImageView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            signalImageView.leadingAnchor.constraint(equalTo: batteryImageView.trailingAnchor, constant: 8),
            signalImageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            signalImageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor,  constant: -8),
            signalImageView.heightAnchor.constraint(equalTo: signalImageView.widthAnchor)
        ])
        
    }
    

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @available(iOS 13.0, *)
    func getSignal(rssi: Int) -> UIImage{
      
        if rssi > -35 {
            return UIImage(named: "cellular_level_4")!
        } else if rssi > -55 {
            return UIImage(named: "cellular_level_3")!
        } else if rssi > -70 {
            return UIImage(named: "cellular_level_2")!
        } else if rssi > -90 {
            return UIImage(named: "cellular_level_1")!
        } else {
            return UIImage(named: "cellular_level_0")!
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
            signalImageView.image = getImageAsDeviceMode(image: getSignal(rssi: model.getSignalStrength()))
            batteryImageView.image = getImageAsDeviceMode(image: getBatteryLevel(level: model.getBatteryLabel()))
        } else {
            // Fallback on earlier versions
        }
    }
    
}
