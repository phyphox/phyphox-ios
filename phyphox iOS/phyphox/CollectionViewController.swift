//
//  CollectionViewController.swift
//  phyphox
//
//  Created by Jonas Gessner on 14.01.16.
//  Copyright © 2016 Jonas Gessner. All rights reserved.
//  By Order of RWTH Aachen.
//

import UIKit

public var keyboardFrame = CGRect.zero

class CollectionViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout  {
    
    final var selfView: CollectionContainerView? {
        return view as? CollectionContainerView
    }
    
    private var lastViewSize: CGRect?
    
    //MARK: - Initializers
    
    @available(*, unavailable)
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: NSBundle?) {
        fatalError("Unavailable")
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("Unavailable")
    }
    
    init() {
        super.init(nibName: nil, bundle: nil)
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(keyboardFrameChanged(_:)), name: UIKeyboardWillChangeFrameNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(keyboardFrameChanged(_:)), name:UIKeyboardDidChangeFrameNotification, object: nil)
    }
    
    override func loadView() {
        view = self.dynamicType.viewClass.init()
    }
    
    override func viewDidLoad() {
        if let cells = self.dynamicType.customCells {
            for (key, cellClass) in cells {
                selfView!.collectionView.registerClass(cellClass, forCellWithReuseIdentifier: key)
            }
        }
        
        if let headers = self.dynamicType.customHeaders {
            for (key, headerClass) in headers {
                selfView!.collectionView.registerClass(headerClass, forSupplementaryViewOfKind: UICollectionElementKindSectionHeader, withReuseIdentifier: key)
            }
        }
        
        if let footers = self.dynamicType.customFooters {
            for (key, footerClass) in footers {
                selfView!.collectionView.registerClass(footerClass, forSupplementaryViewOfKind: UICollectionElementKindSectionFooter, withReuseIdentifier: key)
            }
        }
        
        selfView!.collectionView.dataSource = self;
        selfView!.collectionView.delegate = self;
        
    }
    
    private func attemptInvalidateLayout() {
        if lastViewSize == nil || !CGRectEqualToRect(lastViewSize!, view.frame) {
            selfView?.collectionView.collectionViewLayout.invalidateLayout()
        }
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        attemptInvalidateLayout()
        lastViewSize = view.frame
    }
    
        //MARK: - Keyboard handler
    
    dynamic private func keyboardFrameChanged(notification: NSNotification) {
        func UIViewAnimationOptionsFromUIViewAnimationCurve(curve: UIViewAnimationCurve) -> UIViewAnimationOptions  {
            let testOptions = UInt(UIViewAnimationCurve.Linear.rawValue << 16);
            
            if (testOptions != UIViewAnimationOptions.CurveLinear.rawValue) {
                NSLog("Unexpected implementation of UIViewAnimationOptionCurveLinear");
            }
            
            return UIViewAnimationOptions(rawValue: UInt(curve.rawValue << 16));
        }
        
        let duration = notification.userInfo![UIKeyboardAnimationDurationUserInfoKey]!.doubleValue!
        
        let curve = UIViewAnimationCurve(rawValue: notification.userInfo![UIKeyboardAnimationCurveUserInfoKey]!.integerValue!)!
        
        var bottomInset: CGFloat = 0.0
        
        if !CGRectIsEmpty(keyboardFrame) {
            bottomInset = view.frame.size.height-view.convertRect(keyboardFrame, fromView: nil).origin.y
        }
        
        var contentInset = selfView!.collectionView.contentInset
        var scrollInset = selfView!.collectionView.scrollIndicatorInsets
        
        contentInset.bottom = bottomInset
        scrollInset.bottom = bottomInset
        
        UIView.animateWithDuration(duration, delay: 0.0, options: [UIViewAnimationOptions.BeginFromCurrentState, UIViewAnimationOptionsFromUIViewAnimationCurve(curve)], animations: { () -> Void in
            self.selfView!.collectionView.contentInset = contentInset
            self.selfView!.collectionView.scrollIndicatorInsets = scrollInset
            }, completion: nil)
    }
    
    override class func initialize() {
        super.initialize()
        
        NSNotificationCenter.defaultCenter().addObserver(self.self, selector: #selector(keyboardFrameWillChange(_:)), name: UIKeyboardWillChangeFrameNotification, object: nil)
        
        NSNotificationCenter.defaultCenter().addObserver(self.self, selector: #selector(keyboardFrameDidChange(_:)), name:UIKeyboardDidChangeFrameNotification, object: nil)
    }
    
    dynamic private class func keyboardFrameWillChange(notification: NSNotification) {
        keyboardFrame = notification.userInfo![UIKeyboardFrameEndUserInfoKey]!.CGRectValue;
        if (CGRectIsEmpty(keyboardFrame)) {
            keyboardFrame = notification.userInfo![UIKeyboardFrameBeginUserInfoKey]!.CGRectValue;
        }
    }
    
    dynamic private class func keyboardFrameDidChange(notification: NSNotification) {
        keyboardFrame = notification.userInfo![UIKeyboardFrameEndUserInfoKey]!.CGRectValue;
    }
    
    //MARK: - Override points
    
    internal class var viewClass: CollectionContainerView.Type {
        return CollectionContainerView.self
    }
    
    internal class var customCells: [String: UICollectionViewCell.Type]? {
        return nil
    }
    
    internal class var customHeaders: [String: UICollectionReusableView.Type]? {
        return nil
    }
    
    internal class var customFooters: [String: UICollectionReusableView.Type]? {
        return nil
    }
    
    //MARK: UICollectionViewDataSource
    
    func numberOfSectionsInCollectionView(collectionView: UICollectionView) -> Int {
        fatalError("Subclasses need to override this method")
    }
    
    func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        fatalError("Subclasses need to override this method")
    }
    
    func collectionView(collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAtIndexPath indexPath: NSIndexPath) -> CGSize {
        fatalError("Subclasses need to override this method")
    }
    
    func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        fatalError("Subclasses need to override this method")
    }
    
    //MARK: UICollectionViewDelegateFlowLayout
    
    func collectionView(collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAtIndex section: Int) -> CGFloat {
        return 0.0
    }
    
    func collectionView(collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAtIndex section: Int) -> CGFloat {
        return 0.0
    }
    
    //MARK: -
    
    deinit {
        selfView?.collectionView.dataSource = nil;
        selfView?.collectionView.delegate = nil;
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
}
