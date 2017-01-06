//
//  ServerListViewController.swift
//  iSub
//
//  Created by Benjamin Baron on 5/17/16.
//  Copyright © 2016 Ben Baron. All rights reserved.
//

import UIKit

class ServerListViewController: DraggableTableViewController, ISMSLoaderDelegate, ServerEditDelegate {
    fileprivate let headerView = UIView()
    fileprivate let segmentedControl = UISegmentedControl(items: ["Servers", "Settings", "Help"])
    
    fileprivate var servers = Server.allServers()
    fileprivate var isEditingServerList = false
    fileprivate var redirectUrl: String?
    fileprivate var settingsTabViewController: SettingsTabViewController?
    fileprivate var helpTabViewController: HelpTabViewController?
    
    deinit {
        NotificationCenter.removeObserver(onMainThread: self)
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
        
        segmentedControl.autoresizingMask = .flexibleWidth
        segmentedControl.addTarget(self, action: #selector(ServerListViewController.segmentAction), for: .valueChanged)
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
        return UIBarButtonItem(title: "Menu", style: .plain, target: self, action: #selector(ServerListViewController.showMenu))
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
            self.tableView.isScrollEnabled = true
            self.navigationItem.rightBarButtonItem = self.editButtonItem
            
            if self.tableView.tableFooterView == nil {
                self.tableView.tableFooterView = UIView()
            }
            
            self.tableView.reloadData()
        } else if self.segmentedControl.selectedSegmentIndex == 1 {
            self.title = "Settings"
            self.tableView.isScrollEnabled = true
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
            self.tableView.isScrollEnabled = false
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
    
    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
        if editing {
            isEditingServerList = true
            self.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(ServerListViewController.addAction))
        } else {
            isEditingServerList = false
            self.navigationItem.leftBarButtonItem = setupLeftBarButton()
        }
    }
    
    func addAction() {
        self.showServerEditScreen(server: nil)
    }
    
    func saveAction() {
        _ = self.navigationController?.popViewController(animated: true)
    }
    
    func showServerEditScreen(server: Server?) {
        let controller = SubsonicServerEditViewController(server: server)
        controller.delegate = self
        controller.modalPresentationStyle = .formSheet
        self.present(controller, animated: true, completion: nil)
    }
    
    func serverEdited(_ server: Server) {
        reloadTable()
        self.navigationItem.leftBarButtonItem = setupLeftBarButton()
    }
    
    // MARK: - Table view methods -
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if segmentedControl.selectedSegmentIndex == 0 {
            return servers.count
        } else {
            return 0
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: "ServerListCell")
        
        let server = servers[indexPath.row]
        
        // Set up the cell...
        let serverNameLabel = UILabel()
        serverNameLabel.autoresizingMask = .flexibleWidth
        serverNameLabel.backgroundColor = UIColor.clear
        serverNameLabel.textAlignment = .left; // default
        serverNameLabel.font = ISMSBoldFont(20)
        serverNameLabel.text = server.url
        cell.contentView.addSubview(serverNameLabel)
        
        let detailsLabel = UILabel()
        detailsLabel.autoresizingMask = .flexibleWidth;
        detailsLabel.backgroundColor = UIColor.clear
        detailsLabel.textAlignment = .left; // default
        detailsLabel.font = ISMSRegularFont(15)
        detailsLabel.text = "username: \(server.username)"
        cell.contentView.addSubview(detailsLabel)
        
        var typeImage: UIImage?
        if server.type == .subsonic {
            typeImage = UIImage(named: "server-subsonic")
        }
        
        let serverType = UIImageView(image: typeImage)
        serverType.autoresizingMask = .flexibleLeftMargin;
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
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let server = servers[indexPath.row]
        
        // TODO: Figure out better way to get into edit mode, it's not intuitive
        if isEditingServerList {
            showServerEditScreen(server: server)
        } else {
            redirectUrl = nil
            ViewObjectsSingleton.sharedInstance().showLoadingScreenOnMainWindow(withMessage: "Checking Server")
            
            let statusLoader = StatusLoader(server: server)
            statusLoader.delegate = self;
            statusLoader.startLoad()
        }
    }
    
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    override func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        // TODO: Figure out how to implement this using the new data model. Or turn off move support.
        
        //	NSArray *server = [ settingsS.serverList objectAtIndexSafe:fromIndexPath.row];
        //	[settingsS.serverList removeObjectAtIndex:fromIndexPath.row];
        //	[settingsS.serverList insertObject:server atIndex:toIndexPath.row];
        //	[[NSUserDefaults standardUserDefaults] setObject:[NSKeyedArchiver archivedDataWithRootObject: settingsS.serverList] forKey:@"servers"];
        //	[[NSUserDefaults standardUserDefaults] synchronize];
        //
        //	[self.tableView reloadData];
    }
    
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if (editingStyle == .delete)
        {
            // TODO: Automatically switch to the next server. Or if it's the last server, connect to the test server
            //		// Alert user to select new default server if they deleting the default
            //		if ([ settingsS.urlString isEqualToString:[(Server *)[ settingsS.serverList objectAtIndexSafe:indexPath.row] url]])
            //		{
            //			UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Notice" message:@"Make sure to select a new server" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
            //			alert.tag = 4;
            //			[alert show];
            //		}
            
            // Delete the row from the data source
            let server = servers[indexPath.row]
            _ = server.deleteModel()
            
            tableView.deleteRows(at: [indexPath], with: .automatic)
        }
    }
    
    func loadingRedirected(_ theLoader: ISMSLoader, redirectUrl url: URL) {
        var redirectUrlString = "\(url.scheme)://\(url.host)"
        if let port = url.port {
            redirectUrlString += "\(port)"
        }
        
        if url.pathComponents.count > 3 {
            for component in url.pathComponents {
                if component == "api" || component == "rest" {
                    break;
                } else if component != "/" {
                    redirectUrlString += "/\(component)"
                }
            }
        }
        
        redirectUrl = redirectUrlString
    }
    
    public func loadingFailed(_ theLoader: ISMSLoader, withError error: Error) {
        let message: String
        if (error as NSError).code == ISMSErrorCode_IncorrectCredentials {
            message = "Either your username or password is incorrect\n\n☆☆ Tap the gear in the top left and choose a server to return to online mode. ☆☆\n\nError code \((error as NSError).code):\n\(error.localizedDescription)"
        } else {
            message = "Either the Subsonic URL is incorrect, the Subsonic server is down, or you may be connected to Wifi but do not have access to the outside Internet.\n\n☆☆ Tap the gear in the top left and choose a server to return to online mode. ☆☆\n\nError code \((error as NSError).code):\n\((error as NSError).description)"
        }
        
        let alert = UIAlertController(title: "Server Unavailable", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        self.present(alert, animated: true, completion: nil)
        
        ViewObjectsSingleton.sharedInstance().hideLoadingScreen()
    }
    
    func loadingFinished(_ theLoader: ISMSLoader) {
        if let statusLoader = theLoader as? StatusLoader, let server = statusLoader.server {
            SavedSettings.sharedInstance().currentServerId = server.serverId
            SavedSettings.sharedInstance().redirectUrlString = redirectUrl
            
            iSubAppDelegate.sharedInstance().switchServer(to: server, redirectUrl: redirectUrl)
            
            ViewObjectsSingleton.sharedInstance().hideLoadingScreen()
        }
    }
}
