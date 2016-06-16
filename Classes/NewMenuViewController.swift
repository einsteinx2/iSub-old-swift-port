//
//  NewMenuViewController.swift
//  iSub
//
//  Created by Benjamin Baron on 2/1/16.
//  Copyright © 2016 Ben Baron. All rights reserved.
//

import libSub
import UIKit

private class MenuItem {
    let name: String
    let function: NewMenuViewController -> (MenuItem) -> Void
    var navController: UINavigationController?
    
    init(name: String, function: NewMenuViewController -> (MenuItem) -> Void) {
        self.name = name
        self.function = function
    }
}

class NewMenuViewController: UITableViewController {
    
    private let reuseIdentifier = "Menu Cell"
    private let menuItems = [MenuItem(name: "Folders", function: showFolders),
                             MenuItem(name: "Artists", function: showArtists),
                             MenuItem(name: "Settings", function: showSettings)];
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = UIColor.blackColor()
        
        self.tableView.registerClass(UITableViewCell.self, forCellReuseIdentifier: reuseIdentifier)
        self.tableView.contentInset = UIEdgeInsetsMake(20, 0, 0, 0)
        self.tableView.separatorStyle = .None
    }
    
    // Dispose of any existing controllers
    func resetMenuItems() {
        for menuItem in menuItems {
            menuItem.navController = nil
        }
        
        showDefaultViewController()
    }
    
    func showDefaultViewController() {
        let defaultMenuItem = menuItems[0]
        defaultMenuItem.function(self)(defaultMenuItem)
    }
    
    private func showFolders(menuItem: MenuItem) {
        if menuItem.navController == nil {
            let loader = ISMSRootFoldersLoader()
            let viewModel = ItemViewModel(loader: loader)
            viewModel.topLevelController = true
            let viewController = ItemViewController(viewModel: viewModel)
            let navController = UINavigationController(rootViewController: viewController)
            navController.navigationBar.barStyle = .Black
            menuItem.navController = navController
        }
        
        self.sidePanelController!.centerPanel = menuItem.navController
    }
    
    private func showArtists(menuItem: MenuItem) {
        if menuItem.navController == nil {
            let loader = ISMSRootArtistsLoader()
            let viewModel = ItemViewModel(loader: loader)
            viewModel.topLevelController = true
            let viewController = ItemViewController(viewModel: viewModel)
            let navController = UINavigationController(rootViewController: viewController)
            navController.navigationBar.barStyle = .Black
            menuItem.navController = navController
        }
        
        self.sidePanelController!.centerPanel = menuItem.navController
    }

    private func showSettings(menuItem: MenuItem) {
        if menuItem.navController == nil {
            let viewController = ServerListViewController()
            let navController = UINavigationController(rootViewController: viewController)
            navController.navigationBar.barStyle = .Black
            menuItem.navController = navController
        }
        
        self.sidePanelController!.centerPanel = menuItem.navController
    }
    
    func showSettings() {
        showSettings(menuItems.last!)
    }
    
    // MARK: - Table View Delegate -
    
    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return menuItems.count
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier(self.reuseIdentifier, forIndexPath: indexPath)
        cell.backgroundColor = UIColor.clearColor()
        cell.textLabel?.textColor = UIColor.whiteColor()
        
        let menuItem = self.menuItems[indexPath.row]
        cell.textLabel?.text = menuItem.name
        
        return cell
    }
    
    override func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        return 50
    }
    
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        let menuItem = self.menuItems[indexPath.row]
        menuItem.function(self)(menuItem)
    }
}
