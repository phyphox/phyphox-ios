//
//  MenuTableViewController.swift
//  phyphox
//
//  Created by Sebastian Staacks on 29.05.19.
//  Copyright © 2019 RWTH Aachen. All rights reserved.
//

import Foundation

class MenuTableViewController: UITableViewController {
    
    struct MenuElement {
        let label: String
        let icon: UIImage
        let callback: () -> Void
    }
    
    let label: String
    let message: String?
    let elements: [MenuElement]
    
    var menuAlertController: UIAlertController?
    
    init(label: String, message: String?, elements: [MenuElement]) {
        self.label = label
        self.message = message
        self.elements = elements
        
        super.init(style: .plain)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "menu")
        view.addSubview(tableView)
        
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return elements.count
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: "menu")
        
        let element = elements[indexPath.row]
        
        cell.textLabel?.text = element.label
        cell.backgroundColor = .clear
        // Font size adjustment activates ONLY on the original iPhone SE.
        cell.textLabel?.adjustsFontSizeToFitWidth = true
        cell.separatorInset = .zero
        cell.accessoryView = UIImageView(image: element.icon)
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let element = elements[indexPath.row]
        menuAlertController?.dismiss(animated: true, completion: element.callback)
    }
    
    
    func prepareMenu() {
        menuAlertController = UIAlertController(title: label, message: message, preferredStyle: .actionSheet)
        
        guard let menuAlertController = menuAlertController else {
            return
        }
        
        tableView = FixedTableView()
        tableView.dataSource = self
        tableView.delegate = self
        tableView.backgroundColor = .clear
        tableView.isScrollEnabled = false
        
        // Add a separator on the top
        tableView.tableHeaderView = UIView(frame: CGRect(x: 0, y: 0, width: tableView.frame.width, height: 0.5))
        tableView.tableHeaderView?.backgroundColor = tableView.separatorColor
        
        tableView.isUserInteractionEnabled = true
        
        menuAlertController.setValue(self, forKey: "contentViewController")
        
        menuAlertController.addAction(UIAlertAction(title: localize("cancel"), style: .cancel, handler: nil))
    }
    
    func getMenu(sourceView: UIView) -> UIAlertController? {
        
        prepareMenu()
        
        guard let menuAlertController = menuAlertController else {
            return nil
        }
        
        if let popover = menuAlertController.popoverPresentationController {
            popover.sourceView = sourceView
            popover.sourceRect = sourceView.frame
        }
        
        return menuAlertController
    }
    
    func getMenu(sourceButton: UIBarButtonItem) -> UIAlertController? {
        
        prepareMenu()
        
        guard let menuAlertController = menuAlertController else {
            return nil
        }
        
        if let popover = menuAlertController.popoverPresentationController {
            popover.barButtonItem = sourceButton
        }
        
        return menuAlertController
    }
}
