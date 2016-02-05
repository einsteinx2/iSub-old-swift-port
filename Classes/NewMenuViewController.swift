//
//  NewMenuViewController.swift
//  iSub
//
//  Created by Benjamin Baron on 2/1/16.
//  Copyright © 2016 Ben Baron. All rights reserved.
//

import UIKit

private struct MenuItem {
    let name: String
    let function: (MenuItem) -> Void
    var navController: UINavigationController?
}

private func showFolders(menuItem: MenuItem) {
    if menuItem.navController == nil {
        let loader = ISMSNewRootFoldersLoader()
        let viewModel = NewItemViewModel(loader: loader)
        let viewController = NewItemViewController(viewModel: viewModel)
        let navController = UINavigationController(rootViewController: viewController)
        iSubAppDelegate.sharedInstance().sidePanelController.centerPanel = navController
    }
}

private func showArtists(menuItem: MenuItem) {
    
}

class NewMenuViewController: UITableViewController {
    
    private let reuseIdentifier = "Menu Cell"
    private let menuItems = [MenuItem(name: "Folders", function: showFolders, navController: nil),
                             MenuItem(name: "Artists", function: showArtists, navController: nil)];

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
