//
//  ExperimentPickerViewController.swift
//  phyphox
//
//  Created by Sebastian Staacks on 06.01.19.
//  Copyright © 2019 RWTH Aachen. All rights reserved.
//

import UIKit

final class DynamicCollectionView: UICollectionView {
    override func layoutSubviews() {
        super.layoutSubviews()
        if !__CGSizeEqualToSize(bounds.size, self.intrinsicContentSize) {
            self.invalidateIntrinsicContentSize()
        }
    }
    
    override var intrinsicContentSize: CGSize {
        return collectionViewLayout.collectionViewContentSize
    }
}

final class PickerContainerView: CollectionContainerView {
    override func layoutSubviews() {
        super.layoutSubviews()
        if !__CGSizeEqualToSize(bounds.size, self.intrinsicContentSize) {
            self.invalidateIntrinsicContentSize()
        }
    }
    
    override class var collectionViewClass: UICollectionView.Type {
        return DynamicCollectionView.self
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        collectionView.backgroundColor = kBackgroundColor
    }
    
    override var intrinsicContentSize: CGSize {
        return collectionView.intrinsicContentSize
    }
}

final class ExperimentPickerViewController: CollectionViewController {
    var delegate: ExperimentReceiver?

    private var collections: [ExperimentCollection] = []
    
    func getAllExperiments() -> [Experiment] {
        var experiments: [Experiment] = []
        for collection in collections {
            for experiment in collection.experiments {
                experiments.append(experiment.experiment)
            }
        }
        return experiments
    }
    
    override class var viewClass: CollectionContainerView.Type {
        return PickerContainerView.self
    }
    
    override class var customCells: [String : UICollectionViewCell.Type]? {
        return ["ExperimentCell" : ExperimentCell.self]
    }
    
    override class var customHeaders: [String : UICollectionReusableView.Type]? {
        return ["Header" : ExperimentHeaderView.self]
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        self.navigationController?.navigationBar.barTintColor = kBackgroundColor
        self.navigationController?.navigationBar.isTranslucent = true
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    func populate(_ files: [URL]) {
        let experimentManager = ExperimentManager(files: files)
        collections = experimentManager.experimentCollections
        selfView.collectionView.reloadData()
    }
    
    //MARK: - UICollectionViewDataSource
    
    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        return collections.count
    }
    
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return collections[section].experiments.count
    }
    
    override func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let width = self.view.frame.size.width
        
        let h = ceil(UIFont.preferredFont(forTextStyle: UIFont.TextStyle.headline).lineHeight + UIFont.preferredFont(forTextStyle: UIFont.TextStyle.caption1).lineHeight + 12)
        
        return CGSize(width: width, height: h)
    }
    
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ExperimentCell", for: indexPath) as! ExperimentCell
        
        let collection = collections[indexPath.section]
        let experiment = collection.experiments[indexPath.row]
        
        cell.experiment = experiment.experiment
        
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {
        let width = self.view.frame.size.width
        return CGSize(width: width, height: 36.0)
    }
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        if kind == UICollectionView.elementKindSectionHeader {
            let view = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "Header", for: indexPath) as! ExperimentHeaderView
            
            let collection = collections[indexPath.section]
            
            view.title = collection.title
            var colorsInCollection = [UIColor : (Int, UIColor)]()
            for experiment in collection.experiments {
                if let count = colorsInCollection[experiment.experiment.color]?.0 {
                    colorsInCollection[experiment.experiment.color]!.0 = count + 1
                } else {
                    colorsInCollection[experiment.experiment.color] = (1, experiment.experiment.fontColor)
                }
            }
            var max = 0
            var catColor = kHighlightColor
            var catFontColor = UIColor.white
            for (color, (count, fontColor)) in colorsInCollection {
                if count > max {
                    max = count
                    catColor = color
                    catFontColor = fontColor
                }
            }
            view.color = catColor
            view.fontColor = catFontColor
            
            return view
        }
        
        fatalError("Invalid supplementary view: \(kind)")
    }
    
    //MARK: - UICollectionViewDelegate
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let experiment = collections[indexPath.section].experiments[indexPath.row]
        delegate?.experimentSelected(experiment.experiment)
    }
    
}
