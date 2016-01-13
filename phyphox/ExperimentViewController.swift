//
//  ExperimentViewController.swift
//  phyphox
//
//  Created by Jonas Gessner on 08.01.16.
//  Copyright © 2016 RWTH Aachen. All rights reserved.
//

import UIKit

final class ExperimentViewController: UIViewController {
    let experiment: Experiment
    
    init(experiment: Experiment) {
        self.experiment = experiment
        
        super.init(nibName: nil, bundle: nil)
    }
    
    override func loadView() {
        view = ExperimentView(viewDescriptors: experiment.viewDescriptors)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }
    
}
