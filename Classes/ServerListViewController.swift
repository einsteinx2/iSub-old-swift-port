//
//  ServerListViewController.swift
//  iSub
//
//  Created by Benjamin Baron on 5/17/16.
//  Copyright © 2016 Ben Baron. All rights reserved.
//

import UIKit
import libSub

class ServerListViewController: DraggableTableViewController, ISMSLoaderDelegate, ServerEditDelegate {
    private let headerView = UIView()
    private let segmentedControl = UISegmentedControl(items: ["Servers", "Settings", "Help"])
    
    private var servers = Server.allServers()
    private var isEditing = false
    private var redirectUrl: String?
    private var settingsTabViewController: SettingsTabViewController?
    private var helpTabViewController: HelpTabViewController?
    
    deinit {
        NSNotificationCenter.removeObserverOnMainThread(self)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.tableView.allowsSelectionDuringEditing = true
        self.title = "Servers"
        
        if Server.allServers().count == 0 {
            addAction()
        }
        
        // Setup segmented control in the header view
        headerView.frame = CGRect(x: 0, y: 0, width: 320, height: 40)
        headerView.backgroundColor = UIColor(white: 0.3, alpha: 1.0)
        
        segmentedControl.autoresizingMask = .FlexibleWidth
        segmentedControl.addTarget(self, action: #selector(ServerListViewController.segmentAction), forControlEvents: .ValueChanged)
        segmentedControl.frame = CGRect(x: 5, y: 2, width: 310, height: 36)
        segmentedControl.tintColor = ISMSHeaderColor
        segmentedControl.selectedSegmentIndex = 0;
        headerView.addSubview(self.segmentedControl)
        
        self.tableView.tableHeaderView = self.headerView
        
        if !IS_IPAD() && self.tableView.tableHeaderView == nil {
            self.tableView.tableHeaderView = UIView()
        }
    }
    
    override func setupLeftBarButton() -> UIBarButtonItem {
        return UIBarButtonItem(title: "Menu", style: .Plain, target: self, action: #selector(ServerListViewController.showMenu))
    }
    
    func reloadTable() {
        servers = Server.allServers()
        self.tableView.reloadData()
    }
    
    func segmentAction() {
        settingsTabViewController?.parentController = nil
        settingsTabViewController = nil;
        helpTabViewController = nil;
        
        if self.segmentedControl.selectedSegmentIndex == 0 {
            self.title = "Servers"
            self.tableView.tableFooterView = nil
            self.tableView.scrollEnabled = true
            self.navigationItem.rightBarButtonItem = self.editButtonItem()
            
            if self.tableView.tableFooterView == nil {
                self.tableView.tableFooterView = UIView()
            }
            
            self.tableView.reloadData()
        } else if self.segmentedControl.selectedSegmentIndex == 1 {
            self.title = "Settings"
            self.tableView.scrollEnabled = true
            self.setEditing(false, animated: false)
            self.navigationItem.rightBarButtonItem = nil
            settingsTabViewController = SettingsTabViewController(nibName: "SettingsTabViewController", bundle: nil)
            settingsTabViewController!.parentController = self
            self.tableView.tableFooterView = settingsTabViewController!.view
            if self.tableView.tableFooterView == nil {
                self.tableView.tableFooterView = UIView()
            }
            self.tableView.reloadData()
        } else if self.segmentedControl.selectedSegmentIndex == 2 {
            self.title = "Help"
            self.tableView.scrollEnabled = false
            self.setEditing(false, animated: false)
            self.navigationItem.rightBarButtonItem = nil
            helpTabViewController = HelpTabViewController(nibName: "HelpTabViewController", bundle: nil)
            helpTabViewController!.view.frame = self.view.bounds
            helpTabViewController!.view.height -= 40.0
            self.tableView.tableFooterView = helpTabViewController!.view
            if self.tableView.tableFooterView == nil {
                self.tableView.tableFooterView = UIView()
            }
            self.tableView.reloadData()
        }
    }
    
    override func setEditing(editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
        if editing {
            isEditing = true
            self.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .Add, target: self, action: #selector(ServerListViewController.addAction))
        } else {
            isEditing = false
            self.navigationItem.leftBarButtonItem = setupLeftBarButton()
        }
    }
    
    func addAction() {
        self.showServerEditScreen(server: nil)
    }
    
    func saveAction() {
        self.navigationController?.popViewControllerAnimated(true)
    }
    
    func showServerEditScreen(server server: Server?) {
        let controller = SubsonicServerEditViewController(server: server)
        controller.delegate = self
        controller.modalPresentationStyle = .FormSheet
        self.presentViewController(controller, animated: true, completion: nil)
    }
    
    func serverEdited(server: Server) {
        reloadTable()
        self.navigationItem.leftBarButtonItem = setupLeftBarButton()
    }
    
    // MARK: - Table view methods -
    
    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if segmentedControl.selectedSegmentIndex == 0 {
            return servers.count
        } else {
            return 0
        }
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .Default, reuseIdentifier: "ServerListCell")
        
        let server = servers[indexPath.row]
        
        // Set up the cell...
        let serverNameLabel = UILabel()
        serverNameLabel.autoresizingMask = .FlexibleWidth
        serverNameLabel.backgroundColor = UIColor.clearColor()
        serverNameLabel.textAlignment = .Left; // default
        serverNameLabel.font = ISMSBoldFont(20)
        serverNameLabel.text = server.url
        cell.contentView.addSubview(serverNameLabel)
        
        let detailsLabel = UILabel()
        detailsLabel.autoresizingMask = .FlexibleWidth;
        detailsLabel.backgroundColor = UIColor.clearColor()
        detailsLabel.textAlignment = .Left; // default
        detailsLabel.font = ISMSRegularFont(15)
        detailsLabel.text = "username: \(server.username)"
        cell.contentView.addSubview(detailsLabel)
        
        var typeImage: UIImage?
        if server.type == .Subsonic {
            typeImage = UIImage(named: "server-subsonic")
        }
        
        let serverType = UIImageView(image: typeImage)
        serverType.autoresizingMask = .FlexibleLeftMargin;
        cell.contentView.addSubview(serverType)
        
        if SavedSettings.sharedInstance().currentServer.isEqual(server) {
            let currentServerMarker = UIImageView()
            currentServerMarker.image = UIImage(named: "current-server")
            cell.contentView.addSubview(currentServerMarker)
            
            currentServerMarker.frame = CGRect(x: 3, y: 12, width: 26, height: 26)
            serverNameLabel.frame = CGRect(x: 35, y: 0, width: 236, height: 25)
            detailsLabel.frame = CGRect(x: 35, y: 27, width: 236, height: 18)
        }
        else 
        {
            serverNameLabel.frame = CGRect(x: 5, y: 0, width: 266, height: 25)
            detailsLabel.frame = CGRect(x: 5, y: 27, width: 266, height: 18)
        }
        serverType.frame = CGRect(x: 271, y: 3, width: 44, height: 44)
        
        cell.backgroundView = UIView()
        
        return cell
    }
    
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        let server = servers[indexPath.row]
        
        // TODO: Figure out better way to get into edit mode, it's not intuitive
        if isEditing {
            showServerEditScreen(server: server)
        } else {
            redirectUrl = nil
            ViewObjectsSingleton.sharedInstance().showLoadingScreenOnMainWindowWithMessage("Checking Server")
            
            let statusLoader = StatusLoader(server: server)
            statusLoader.delegate = self;
            statusLoader.startLoad()
        }
    }
    
    override func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        return true
    }
    
    override func tableView(tableView: UITableView, canMoveRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        return true
    }
    
    override func tableView(tableView: UITableView, moveRowAtIndexPath sourceIndexPath: NSIndexPath, toIndexPath destinationIndexPath: NSIndexPath) {
        // TODO: Figure out how to implement this using the new data model. Or turn off move support.
        
        //	NSArray *server = [ settingsS.serverList objectAtIndexSafe:fromIndexPath.row];
        //	[settingsS.serverList removeObjectAtIndex:fromIndexPath.row];
        //	[settingsS.serverList insertObject:server atIndex:toIndexPath.row];
        //	[[NSUserDefaults standardUserDefaults] setObject:[NSKeyedArchiver archivedDataWithRootObject: settingsS.serverList] forKey:@"servers"];
        //	[[NSUserDefaults standardUserDefaults] synchronize];
        //
        //	[self.tableView reloadData];
    }
    
    override func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        if (editingStyle == .Delete)
        {
            // TODO: Automatically switch to the next server. Or if it's the last server, connect to the test server
            //		// Alert user to select new default server if they deleting the default
            //		if ([ settingsS.urlString isEqualToString:[(ISMSServer *)[ settingsS.serverList objectAtIndexSafe:indexPath.row] url]])
            //		{
            //			CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Notice" message:@"Make sure to select a new server" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
            //			alert.tag = 4;
            //			[alert show];
            //		}
            
            // Delete the row from the data source
            let server = servers[indexPath.row]
            server.deleteModel()
            
            tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .Automatic)
        }
    }
    
    func loadingRedirected(theLoader: ISMSLoader!, redirectUrl url: NSURL!) {
        var redirectUrlString = "\(url.scheme)://\(url.host)"
        if let port = url.port {
            redirectUrlString += port.stringValue
        }
        
        if let pathComponents = url.pathComponents {
            if pathComponents.count > 3 {
                for component in pathComponents {
                    if component == "api" || component == "rest" {
                        break;
                    } else if component != "/" {
                        redirectUrlString += "/\(component)"
                    }
                }
            }
        }
        
        redirectUrl = redirectUrlString
    }
    
    func loadingFailed(theLoader: ISMSLoader!, withError error: NSError!) {
        let alert: UIAlertView?
        if error.code == ISMSErrorCode_IncorrectCredentials {
            alert = UIAlertView(title: "Server Unavailable",
                                message: "Either your username or password is incorrect\n\n☆☆ Tap the gear in the top left and choose a server to return to online mode. ☆☆\n\nError code \(error.code):\n\(error.localizedDescription)",
                                delegate: nil,
                                cancelButtonTitle: "OK")
        } else {
            alert = UIAlertView(title: "Server Unavailable",
                                message: "Either the Subsonic URL is incorrect, the Subsonic server is down, or you may be connected to Wifi but do not have access to the outside Internet.\n\n☆☆ Tap the gear in the top left and choose a server to return to online mode. ☆☆\n\nError code \(error.code):\n\(error.description)",
                                delegate: nil,
                                cancelButtonTitle: "OK")
        }
        alert!.tag = 3
        alert!.show()
        
        ViewObjectsSingleton.sharedInstance().hideLoadingScreen()
    }
    
    func loadingFinished(theLoader: ISMSLoader!) {
        if let statusLoader = theLoader as? StatusLoader, server = statusLoader.server {
            SavedSettings.sharedInstance().currentServerId = server.serverId
            SavedSettings.sharedInstance().redirectUrlString = redirectUrl

            iSubAppDelegate.sharedInstance().switchServer(server, redirectUrl: redirectUrl)
            
            ViewObjectsSingleton.sharedInstance().hideLoadingScreen()
        }
    }
}