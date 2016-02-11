//
//  CharViewController.swift
//  iSub
//
//  Created by Benjamin Baron on 12/14/14.
//  Copyright (c) 2014 Ben Baron. All rights reserved.
//

import libSub
import Foundation
import UIKit
import Flurry_iOS_SDK

public class ChatViewController : CustomUITableViewController {
    
    let _viewObjects = ViewObjectsSingleton.sharedInstance()
    
    let _reuseIdentifier = "Chat Cell"
    
    var _dataModel : SUSChatDAO!
    var _textInput : CustomUITextView!
    var _chatMessageOverlay : UIView!
    var _dismissButton : UIButton!
    var _noChatMessagesScreen : UIImageView!
    var _receivedData  : NSMutableData!
    
    var _noChatMessagesScreenShowing : Bool = false
    var _reloading : Bool = false

    
    // MARK: - Rotation -
    
    override public func didRotateFromInterfaceOrientation(fromInterfaceOrientation: UIInterfaceOrientation) {
        if (!IS_IPAD() && _noChatMessagesScreenShowing) {
            let ty: CGFloat = UIInterfaceOrientationIsPortrait(fromInterfaceOrientation) ? 42.0 : -160.0;
            let translate = CGAffineTransformMakeTranslation(0.0, ty);
            _noChatMessagesScreen.transform = translate;
        }
    }
    
    // MARK: - Life Cycle -
    
    override public func viewDidLoad() {
        super.viewDidLoad()
        
        self.edgesForExtendedLayout = UIRectEdge.None
        self.automaticallyAdjustsScrollViewInsets = false
        
        self.title = "Chat"
        
        self._createDataModel()
    }

    func _createDataModel() {
        _dataModel = SUSChatDAO(delegate: self)
    }

    override public func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        self.loadData()
        
        Flurry.logEvent("ChatTab")
    }

    override public func viewWillDisappear(animated: Bool) {
        if (_noChatMessagesScreenShowing) {
            _noChatMessagesScreen.removeFromSuperview()
            _noChatMessagesScreenShowing = false
        }
    }
    
    // MARK: - CustomUITableViewController Overrides -
    
    override public func setupHeaderView() -> UIView! {
        let headerView = UIView(frame: CGRectMake(0, 0, 320, 82))
        headerView.autoresizingMask = UIViewAutoresizing.FlexibleWidth
        headerView.backgroundColor = ISMSHeaderColor
        
        _textInput = CustomUITextView(frame: CGRectMake(5, 5, 240, 72))
        _textInput.autoresizingMask = UIViewAutoresizing.FlexibleWidth
        _textInput.font = ISMSRegularFont(16)
        _textInput.delegate = self;
        headerView.addSubview(_textInput)
        
        let sendButton = UIButton(type: .Custom)
        sendButton.frame = CGRectMake(252, 11, 60, 60);
        sendButton.autoresizingMask = UIViewAutoresizing.FlexibleLeftMargin
        sendButton.addTarget(self, action: "a_sendButton:", forControlEvents: UIControlEvents.TouchUpInside)
        sendButton.setImage(UIImage(named: "comment-write"), forState: UIControlState.Normal)
        sendButton.setImage(UIImage(named: "comment-write-pressed"), forState: UIControlState.Highlighted)
        headerView.addSubview(sendButton)
        
        return headerView;
    }
    
    override public func customizeTableView(tableView: UITableView!) {
        tableView.separatorColor = UIColor.clearColor()
        tableView.registerClass(ChatUITableViewCell.self, forCellReuseIdentifier: _reuseIdentifier)
    }
    
    override public func shouldSetupRefreshControl() -> Bool {
        return true
    }
    
    override public func didPullToRefresh() {
        if (!_reloading) {
            _reloading = true
            _viewObjects.showLoadingScreenOnMainWindowWithMessage(nil)
            self.loadData()
        }
    }
    
    // MARK: - Loading -
    
    public func loadData() {
        _dataModel.startLoad()
        _viewObjects.showAlbumLoadingScreen(iSubAppDelegate.sharedInstance().window, sender: self)
    }
    
    public func cancelLoad() {
        _dataModel.cancelLoad()
        _viewObjects.hideLoadingScreen()
    }
    
    func _dataSourceDidFinishLoadingNewData() {
        _reloading = false;
        self.refreshControl?.endRefreshing()
    }
    
    // MARK: - Actions -
    
    func a_sendButton(sender: AnyObject) {
        if _textInput.text.characters.count != 0 {
            _textInput.resignFirstResponder()
            
            self.setupRightBarButton()
            
            _viewObjects.showLoadingScreenOnMainWindowWithMessage("Sending")
            _dataModel?.sendChatMessage(_textInput.text);
            
            _textInput.text = ""
            _textInput.resignFirstResponder()
        }
    }
    
    func a_doneSearching(sender: AnyObject) {
        _textInput.resignFirstResponder()
        
        self.navigationItem.rightBarButtonItem = self.setupRightBarButton()
    }
    
    // MARK:  - Private -
    
    func _showNoChatMessagesScreen() {
        if (!_noChatMessagesScreenShowing) {
            _noChatMessagesScreenShowing = true
            _noChatMessagesScreen = UIImageView()
            _noChatMessagesScreen.autoresizingMask = [UIViewAutoresizing.FlexibleLeftMargin, UIViewAutoresizing.FlexibleBottomMargin, UIViewAutoresizing.FlexibleRightMargin, UIViewAutoresizing.FlexibleTopMargin]
            _noChatMessagesScreen.frame = CGRectMake(40, 100, 240, 180)
            _noChatMessagesScreen.center = CGPointMake(self.view.bounds.size.width / 2, self.view.bounds.size.height / 2)
            _noChatMessagesScreen.image = UIImage(named: "loading-screen-image")
            _noChatMessagesScreen.alpha = 0.80
    
            let textLabel = UILabel()
            textLabel.backgroundColor = UIColor.clearColor()
            textLabel.textColor = UIColor.whiteColor()
            textLabel.font = ISMSBoldFont(30)
            textLabel.textAlignment = NSTextAlignment.Center
            textLabel.numberOfLines = 0
            textLabel.text = "No Chat Messages\non the\nServer"
            textLabel.frame = CGRectMake(15, 15, 210, 150)
            _noChatMessagesScreen.addSubview(textLabel)
    
            self.view.addSubview(_noChatMessagesScreen)
    
            if (!IS_IPAD()) {
                if (UIInterfaceOrientationIsLandscape(UIApplication.sharedApplication().statusBarOrientation)) {
                    let translate = CGAffineTransformMakeTranslation(0.0, 42.0)
                    let scale = CGAffineTransformMakeScale(0.75, 0.75)
                    _noChatMessagesScreen.transform = CGAffineTransformConcat(scale, translate)
                }
            }
        }
    }
    
    func _formatDate(date: NSDate) -> String {
        let formatter = NSDateFormatter()
        formatter.dateStyle = NSDateFormatterStyle.ShortStyle
        formatter.timeStyle = NSDateFormatterStyle.ShortStyle
        formatter.locale = NSLocale.currentLocale()
        
        let formattetDate = formatter.stringFromDate(date)
        return formattetDate
    }
}

// MARK: - Protocols -

// MARK: ISMSLoader Delegate

extension ChatViewController : ISMSLoaderDelegate {
    
    public func loadingFinished(theLoader: ISMSLoader!) {
        _viewObjects.hideLoadingScreen()
        
        self.tableView.reloadData()
        
        self._dataSourceDidFinishLoadingNewData()
    }
    
    public func loadingFailed(theLoader: ISMSLoader!, withError error: NSError!) {
        _viewObjects.hideLoadingScreen()
        
        self.tableView.reloadData()
        self._dataSourceDidFinishLoadingNewData()
        
        if error.code == ISMSErrorCode_CouldNotSendChatMessage {
            _textInput.text = error.userInfo["test"] as? String
        }
    }
}

// MARK: UITextView delegate

extension ChatViewController : UITextViewDelegate {
    
    public func textViewDidBeginEditing(textView: UITextView) {
        // Create overlay
        _chatMessageOverlay = UIView()
        _chatMessageOverlay.frame = IS_IPAD() ? CGRectMake(0, 82, 1024, 1024) : CGRectMake(0, 82, 480, 480)
    
        _chatMessageOverlay.autoresizingMask = [.FlexibleWidth, .FlexibleHeight];
        _chatMessageOverlay.backgroundColor = UIColor(white: 0, alpha: 0.80)
        _chatMessageOverlay.alpha = 0.0
        self.view.addSubview(_chatMessageOverlay)
    
        _dismissButton = UIButton(type: UIButtonType.Custom)
        _dismissButton.autoresizingMask = [.FlexibleWidth, .FlexibleHeight];
        _dismissButton.addTarget(self, action: "a_doneSearching:", forControlEvents: .TouchUpInside)
        _dismissButton.frame = self.view.bounds;
        _dismissButton.enabled = false
        _chatMessageOverlay.addSubview(_dismissButton)
    
        // Animate the segmented control on screen
        UIView.animateWithDuration(0.5, delay: 0, options: UIViewAnimationOptions.CurveLinear, animations: {
            self._chatMessageOverlay.alpha = 1
            self._dismissButton.enabled = true
        }, completion: nil)
    
        // Add the done button.
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .Done, target: self, action: "a_doneSearching:")
        }
    
    public func textViewDidEndEditing(textView: UITextView) {
        UIView.animateWithDuration(0.3, delay: 0, options: UIViewAnimationOptions.CurveLinear, animations: {
            self._chatMessageOverlay.alpha = 0
            self._dismissButton.enabled = false
        }, completion: nil)
    }
    
}

// MARK: Table View Delegate

extension ChatViewController {
    
    override public func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        // Automatically set the height based on the height of the message text
        var expectedLabelSize = CGSizeZero
        guard let chatMessage = _dataModel.chatMessages?[indexPath.row], let messageString = chatMessage.message else {
            return 0
        }
        
        expectedLabelSize = messageString.boundingRectWithSize(CGSizeMake(310, CGFloat.max), options: NSStringDrawingOptions.UsesLineFragmentOrigin, attributes: [NSFontAttributeName: ISMSRegularFont(20)], context: nil).size
        if expectedLabelSize.height < 40 {
            expectedLabelSize.height = 40
        }
        
        return (expectedLabelSize.height + 20)
    }

    override public func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }
    
    override public func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let chatMessages = _dataModel.chatMessages else {
            return 0
        }
        
        return chatMessages.count
    }

    override public func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier(_reuseIdentifier, forIndexPath: indexPath) as! ChatUITableViewCell
        cell.selectionStyle = UITableViewCellSelectionStyle.None
        cell.backgroundView = UIView()
        
        guard let chatMessage = _dataModel.chatMessages?[indexPath.row], timestamp = chatMessage.timestamp else {
            return cell;
        }
        
        cell.userNameLabel.text = "\(chatMessage.user) - \(self._formatDate(timestamp))"
        cell.messageLabel.text = chatMessage.message
        
        return cell
    }
}