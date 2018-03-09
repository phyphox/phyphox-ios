//
//  CollectionViewController.swift
//  phyphox
//
//  Created by Jonas Gessner on 14.01.16.
//  Copyright © 2016 Jonas Gessner. All rights reserved.
//  By Order of RWTH Aachen.
//

import UIKit

class CollectionViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout  {
    
    final var selfView: CollectionContainerView {
        return view as! CollectionContainerView
    }
    
    private var lastViewSize: CGRect?
    
    //MARK: - Initializers
    
    @available(*, unavailable)
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        fatalError("Unavailable")
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("Unavailable")
    }
    
    init() {
        super.init(nibName: nil, bundle: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardFrameChanged(_:)), name: NSNotification.Name.UIKeyboardWillChangeFrame, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardFrameChanged(_:)), name:NSNotification.Name.UIKeyboardDidChangeFrame, object: nil)
    }
    
    override func loadView() {
        view = type(of: self).viewClass.init()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if let cells = type(of: self).customCells {
            for (key, cellClass) in cells {
                selfView.collectionView.register(cellClass, forCellWithReuseIdentifier: key)
            }
        }
        
        if let headers = type(of: self).customHeaders {
            for (key, headerClass) in headers {
                selfView.collectionView.register(headerClass, forSupplementaryViewOfKind: UICollectionElementKindSectionHeader, withReuseIdentifier: key)
            }
        }
        
        if let footers = type(of: self).customFooters {
            for (key, footerClass) in footers {
                selfView.collectionView.register(footerClass, forSupplementaryViewOfKind: UICollectionElementKindSectionFooter, withReuseIdentifier: key)
            }
        }
        
        selfView.collectionView.dataSource = self;
        selfView.collectionView.delegate = self;
        
    }
    
    private func attemptInvalidateLayout() {
        if lastViewSize == nil || !lastViewSize!.equalTo(view.frame) {
            selfView.collectionView.collectionViewLayout.invalidateLayout()
        }
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        attemptInvalidateLayout()
        lastViewSize = view.frame
    }
    
        //MARK: - Keyboard handler
    
    @objc private func keyboardFrameChanged(_ notification: Notification) {
        func UIViewAnimationOptionsFromUIViewAnimationCurve(_ curve: UIViewAnimationCurve) -> UIViewAnimationOptions  {
            let testOptions = UInt(UIViewAnimationCurve.linear.rawValue << 16);
            
            if (testOptions != UIViewAnimationOptions.curveLinear.rawValue) {
                NSLog("Unexpected implementation of UIViewAnimationOptionCurveLinear");
            }
            
            return UIViewAnimationOptions(rawValue: UInt(curve.rawValue << 16));
        }
        
        let duration = (notification.userInfo![UIKeyboardAnimationDurationUserInfoKey]! as AnyObject).doubleValue!
        
        let curve = UIViewAnimationCurve(rawValue: (notification.userInfo![UIKeyboardAnimationCurveUserInfoKey]! as AnyObject).intValue!)!
        
        var bottomInset: CGFloat = 0.0
        
        if !KeyboardTracker.keyboardFrame.isEmpty {
            bottomInset = view.frame.size.height-view.convert(KeyboardTracker.keyboardFrame, from: nil).origin.y
        }
        
        var contentInset = selfView.collectionView.contentInset
        var scrollInset = selfView.collectionView.scrollIndicatorInsets
        
        contentInset.bottom = bottomInset
        scrollInset.bottom = bottomInset
        
        UIView.animate(withDuration: duration, delay: 0.0, options: [UIViewAnimationOptions.beginFromCurrentState, UIViewAnimationOptionsFromUIViewAnimationCurve(curve)], animations: { () -> Void in
            self.selfView.collectionView.contentInset = contentInset
            self.selfView.collectionView.scrollIndicatorInsets = scrollInset
            }, completion: nil)
    }
    
    //MARK: - Override points
    
    class var viewClass: CollectionContainerView.Type {
        return CollectionContainerView.self
    }
    
    class var customCells: [String: UICollectionViewCell.Type]? {
        return nil
    }
    
    class var customHeaders: [String: UICollectionReusableView.Type]? {
        return nil
    }
    
    class var customFooters: [String: UICollectionReusableView.Type]? {
        return nil
    }
    
    //MARK: UICollectionViewDataSource
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        fatalError("Subclasses need to override this method")
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        fatalError("Subclasses need to override this method")
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        fatalError("Subclasses need to override this method")
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        fatalError("Subclasses need to override this method")
    }
    
    //MARK: UICollectionViewDelegateFlowLayout
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return 0.0
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 0.0
    }
    
    //MARK: -
    
    deinit {
        if isViewLoaded {
            selfView.collectionView.dataSource = nil;
            selfView.collectionView.delegate = nil;
        }
        NotificationCenter.default.removeObserver(self)
    }
}
