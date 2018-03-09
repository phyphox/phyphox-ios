//
//  ExperimentViewController.swift
//  phyphox
//
//  Created by Sebastian Kuhlen on 09.10.16.
//  Copyright © 2016 RWTH Aachen. All rights reserved.
//

import UIKit

private let moduleCellID = "ModuleCell"

final class ExperimentViewController: UICollectionViewController, UICollectionViewDelegateFlowLayout {
    private let modules: [ExperimentViewModuleView]
    var exclusiveView: UIView? = nil
    
    private let scrollView = UIScrollView()
    private let linearView = UIView()
    
    let insetTop: CGFloat = 10

    var active = false {
        didSet {
            for var module in modules {
                module.active = active
            }
        }
    }

    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }

    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return modules.count
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let s = modules[indexPath.row].sizeThatFits(view.frame.size)

        let safeAreaSize: CGRect

        if #available(iOS 11.0, *) {
            safeAreaSize = UIEdgeInsetsInsetRect(collectionView.frame, collectionView.safeAreaInsets)
        } else {
            safeAreaSize = collectionView.frame
        }

        return CGSize(width: safeAreaSize.width, height: s.height)
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        return UIEdgeInsets(top: 10.0, left: 0.0, bottom: 0.0, right: 0.0)
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: moduleCellID, for: indexPath) as? ExperimentViewModuleCollectionViewCell else {
            return UICollectionViewCell()
        }

        let module = modules[indexPath.row]

        cell.module = module

        // TODO: Better protocol
        module.setNeedsUpdate()

        return cell
    }

    override func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        guard let cell = cell as? ExperimentViewModuleCollectionViewCell else { return  }

        cell.module?.active = active
    }

    override func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        guard let cell = cell as? ExperimentViewModuleCollectionViewCell else { return  }

        cell.module?.active = false
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 5.0
    }
    
    init(modules: [ExperimentViewModuleView]) {
        self.modules = modules

        let layout = UICollectionViewFlowLayout()

        super.init(collectionViewLayout: layout)

        collectionView?.register(ExperimentViewModuleCollectionViewCell.self, forCellWithReuseIdentifier: moduleCellID)

        collectionView?.backgroundColor = kBackgroundColor
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
