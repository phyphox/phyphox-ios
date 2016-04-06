//
//  CollectionViewController.swift
//  phyphox
//
//  Created by Jonas Gessner on 14.01.16.
//  Copyright © 2016 RWTH Aachen. All rights reserved.
//

import UIKit

public var keyboardFrame = CGRect.zero

class CollectionViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout  {
    let titleView: PTNavigationBarTitleView
    
    final var selfView: CollectionContainerView {
        return view as! CollectionContainerView
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
        titleView = PTNavigationBarTitleView()
        super.init(nibName: nil, bundle: nil)
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(keyboardFrameChanged(_:)), name: UIKeyboardWillChangeFrameNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(keyboardFrameChanged(_:)), name:UIKeyboardDidChangeFrameNotification, object: nil)
    }
    
    //MARK: -
    
    override var title: String? {
        set {
            titleView.title = newValue
            super.title = ""
        }
        get {
            return super.title
        }
    }
    
    override func loadView() {
        view = self.dynamicType.viewClass.init()
    }
    
    override func viewDidLoad() {
        if let cells = self.dynamicType.customCells {
            for (key, cellClass) in cells {
                selfView.collectionView.registerClass(cellClass, forCellWithReuseIdentifier: key)
            }
        }
        
        if let headers = self.dynamicType.customHeaders {
            for (key, headerClass) in headers {
                selfView.collectionView.registerClass(headerClass, forSupplementaryViewOfKind: UICollectionElementKindSectionHeader, withReuseIdentifier: key)
            }
        }
        
        if let footers = self.dynamicType.customFooters {
            for (key, footerClass) in footers {
                selfView.collectionView.registerClass(footerClass, forSupplementaryViewOfKind: UICollectionElementKindSectionFooter, withReuseIdentifier: key)
            }
        }
        
        selfView.collectionView.dataSource = self;
        selfView.collectionView.delegate = self;
        
        navigationItem.titleView = titleView
    }
    
    private func attemptInvalidateLayout() {
        if lastViewSize == nil || !CGRectEqualToRect(lastViewSize!, view.frame) {
            selfView.collectionView.collectionViewLayout.invalidateLayout()
        }
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        attemptInvalidateLayout()
        lastViewSize = view.frame
    }
    
    override func viewWillTransitionToSize(size: CGSize, withTransitionCoordinator coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransitionToSize(size, withTransitionCoordinator: coordinator)
        coordinator.animateAlongsideTransition({[unowned self] (_) -> Void in
            self.layoutMenuIfVisible()
            }, completion: nil)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        layoutMenuIfVisible()
    }
    
    private func layoutMenuIfVisible() {
        if self.menu != nil {
            let height = self.navigationController!.navigationBar.frame.size.height+(UIApplication.sharedApplication().statusBarHidden ? 0.0 : 20.0)
            
            var c = self.view.bounds
            
            c.origin.y += height;
            c.size.height -= height;
            
            self.menuColorHost!.frame = c;
            self.menu!.sizeToFit()
            
            var r = self.menu!.frame
            r.size.width = self.view.bounds.size.width;
            r.origin.y = height;
            self.menu!.frame = r;
        }
    }
    
    private var menu: PTDropDownMenu?
    private var menuColorHost: UIControl?
    
    func presentDropDownMenu(menu m: PTDropDownMenu) {
        assert(menu == nil, "Menu already visible")
        
        menu = m
        
        UIApplication.sharedApplication().beginIgnoringInteractionEvents()
        
        menuColorHost = UIControl()
        menuColorHost!.backgroundColor = UIColor.blackColor()
        menuColorHost!.alpha = 0.0
        menuColorHost!.addTarget(self, action: #selector(dismissDropDownMenuIfVisible), forControlEvents: .TouchUpInside)
        
        let height = self.navigationController!.navigationBar.frame.size.height+(UIApplication.sharedApplication().statusBarHidden ? 0.0 : 20.0)
        
        var c = view.bounds
        c.origin.y += height;
        c.size.height -= height;
        menuColorHost!.frame = c;
        
        view.addSubview(menuColorHost!)
        view.addSubview(m)
        
        m.sizeToFit()
        
        var r = m.frame
        r.size.width = self.view.bounds.size.width;
        r.origin.y = height-m.frame.size.height;
        m.frame = r;
        
        r.origin.y = height
        
        titleView.promptButtonExtended = true
        
        UIApplication.sharedApplication().endIgnoringInteractionEvents()
        
        UIView.animateWithDuration(0.5, delay: 0.0, usingSpringWithDamping: 0.9, initialSpringVelocity: 0.0, options: .CurveEaseInOut, animations: { () -> Void in
            m.frame = r
            }, completion: nil)
        
        UIView.animateWithDuration(0.5, delay: 0.0, options: .CurveEaseInOut, animations: { () -> Void in
            self.menuColorHost!.alpha = 0.6
            }, completion: nil)
    }

    func dismissDropDownMenuIfVisible() {
        if menu == nil {
            return
        }
        
        UIApplication.sharedApplication().beginIgnoringInteractionEvents()
        
        var r = menu!.frame
        
        let height = self.navigationController!.navigationBar.frame.size.height+(UIApplication.sharedApplication().statusBarHidden ? 0.0 : 20.0)
        
        r.origin.y = height-r.size.height
        
        titleView.promptButtonExtended = false
        
        UIView.animateWithDuration(0.3, animations: { () -> Void in
            self.menu!.frame = r
            self.menuColorHost!.alpha = 0.0
            }) { (_) -> Void in
                self.menu!.removeFromSuperview()
                self.menu = nil
                
                self.menuColorHost!.removeFromSuperview()
                self.menuColorHost = nil
                
                UIApplication.sharedApplication().endIgnoringInteractionEvents()
        }
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
        
        var contentInset = selfView.collectionView.contentInset
        var scrollInset = selfView.collectionView.scrollIndicatorInsets
        
        contentInset.bottom = bottomInset
        scrollInset.bottom = bottomInset
        
        UIView.animateWithDuration(duration, delay: 0.0, options: [UIViewAnimationOptions.BeginFromCurrentState, UIViewAnimationOptionsFromUIViewAnimationCurve(curve)], animations: { () -> Void in
            self.selfView.collectionView.contentInset = contentInset
            self.selfView.collectionView.scrollIndicatorInsets = scrollInset
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
        selfView.collectionView.dataSource = nil;
        selfView.collectionView.delegate = nil;
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
}
