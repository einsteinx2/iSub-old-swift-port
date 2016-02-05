//
//  NewMenuViewController.swift
//  iSub
//
//  Created by Benjamin Baron on 2/1/16.
//  Copyright © 2016 Ben Baron. All rights reserved.
//

import UIKit

private class MenuItem {
    let name: String
    let function: (MenuItem) -> Void
    var navController: UINavigationController?
    
    init(name: String, function: (MenuItem) -> Void) {
        self.name = name
        self.function = function
    }
}

private func showFolders(menuItem: MenuItem) {
    if menuItem.navController == nil {
        let loader = ISMSNewRootFoldersLoader()
        let viewModel = NewItemViewModel(loader: loader)
        let viewController = NewItemViewController(viewModel: viewModel)
        menuItem.navController = UINavigationController(rootViewController: viewController)
    }
    
    iSubAppDelegate.sharedInstance().sidePanelController.centerPanel = menuItem.navController
}

private func showArtists(menuItem: MenuItem) {
    if menuItem.navController == nil {
        let loader = ISMSRootArtistsLoader()
        let viewModel = NewItemViewModel(loader: loader)
        let viewController = NewItemViewController(viewModel: viewModel)
        menuItem.navController = UINavigationController(rootViewController: viewController)
    }
    
    iSubAppDelegate.sharedInstance().sidePanelController.centerPanel = menuItem.navController
}

class NewMenuViewController: UITableViewController {
    
    private let reuseIdentifier = "Menu Cell"
    private let menuItems = [MenuItem(name: "Folders", function: showFolders),
                             MenuItem(name: "Artists", function: showArtists)];
    
    func showDefaultViewController() {
        let defaultMenuItem = menuItems[0]
        defaultMenuItem.function(defaultMenuItem)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.tableView.registerClass(UITableViewCell.self, forCellReuseIdentifier: reuseIdentifier)
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
        
        return cell
    }
    
    override func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        return 50
    }
    
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        let menuItem = self.menuItems[indexPath.row]
        menuItem.function(menuItem)
    }
}
