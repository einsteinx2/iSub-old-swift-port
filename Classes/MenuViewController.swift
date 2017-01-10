//
//  MenuViewController.swift
//  iSub
//
//  Created by Benjamin Baron on 2/1/16.
//  Copyright © 2016 Ben Baron. All rights reserved.
//

import UIKit
import Async

private class MenuItem {
    let name: String
    let function: (MenuViewController) -> (MenuItem) -> Void
    var navController: UINavigationController?
    
    init(name: String, function: @escaping (MenuViewController) -> (MenuItem) -> Void) {
        self.name = name
        self.function = function
    }
}

class MenuViewController: UITableViewController {
    
    fileprivate let reuseIdentifier = "Menu Cell"
    fileprivate let menuItems = [MenuItem(name: "Folders", function: showFolders),
                                 MenuItem(name: "Artists", function: showArtists),
                                 MenuItem(name: "Albums", function: showAlbums),
                                 MenuItem(name: "Downloads", function: showDownloads),
                                 MenuItem(name: "Settings", function: showSettings)];
    
    fileprivate let centerController = CenterPanelContainerViewController()
        
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = UIColor.black
        
        self.tableView.register(UITableViewCell.self, forCellReuseIdentifier: reuseIdentifier)
        self.tableView.separatorStyle = .none
    }
    
    // Dispose of any existing controllers
    func resetMenuItems() {
        for menuItem in menuItems {
            menuItem.navController = nil
        }
        
        showDefaultViewController()
    }
    
    func showDefaultViewController() {
        self.sidePanelController.centerPanel = centerController
        
        let defaultMenuItem = menuItems[0]
        defaultMenuItem.function(self)(defaultMenuItem)
    }
    
    fileprivate func showFolders(_ menuItem: MenuItem) {
        if menuItem.navController == nil {
            let loader = RootFoldersLoader()
            let viewModel = ItemViewModel(loader: loader)
            viewModel.topLevelController = true
            viewModel.navigationTitle = "Folders"
            let viewController = ItemViewController(viewModel: viewModel)
            let navController = NavigationStack(rootViewController: viewController)
            navController.navigationBar.barStyle = .black
            navController.navigationBar.fixedHeightWhenStatusBarHidden = true
            navController.interactivePopGestureRecognizer?.delegate = viewController
            menuItem.navController = navController
        }
        
        centerController.contentController = menuItem.navController
    }
    
    fileprivate func showArtists(_ menuItem: MenuItem) {
        if menuItem.navController == nil {
            let loader = RootArtistsLoader()
            let viewModel = ItemViewModel(loader: loader)
            viewModel.topLevelController = true
            viewModel.navigationTitle = "Artists"
            let viewController = ItemViewController(viewModel: viewModel)
            let navController = NavigationStack(rootViewController: viewController)
            navController.navigationBar.barStyle = .black
            navController.navigationBar.fixedHeightWhenStatusBarHidden = true
            navController.interactivePopGestureRecognizer?.delegate = viewController
            menuItem.navController = navController
        }
        
        centerController.contentController = menuItem.navController
    }
    
    fileprivate func showAlbums(_ menuItem: MenuItem) {
        if menuItem.navController == nil {
            let loader = RootAlbumsLoader()
            let viewModel = ItemViewModel(loader: loader)
            viewModel.topLevelController = true
            viewModel.navigationTitle = "Albums"
            let viewController = ItemViewController(viewModel: viewModel)
            let navController = NavigationStack(rootViewController: viewController)
            navController.navigationBar.barStyle = .black
            navController.navigationBar.fixedHeightWhenStatusBarHidden = true
            navController.interactivePopGestureRecognizer?.delegate = viewController
            menuItem.navController = navController
        }
        
        centerController.contentController = menuItem.navController
    }
    
    fileprivate func showDownloads(_ menuItem: MenuItem) {
        if menuItem.navController == nil {
            let viewController = CacheViewController()
            let navController = NavigationStack(rootViewController: viewController)
            navController.navigationBar.barStyle = .black
            navController.navigationBar.fixedHeightWhenStatusBarHidden = true
            navController.interactivePopGestureRecognizer?.delegate = viewController
            menuItem.navController = navController
        }
        
        centerController.contentController = menuItem.navController
    }

    fileprivate func showSettings(_ menuItem: MenuItem) {
        if menuItem.navController == nil {
            let viewController = ServerListViewController()
            let navController = NavigationStack(rootViewController: viewController)
            navController.navigationBar.barStyle = .black
            navController.navigationBar.fixedHeightWhenStatusBarHidden = true
            navController.interactivePopGestureRecognizer?.delegate = viewController
            menuItem.navController = navController
        }
        
        centerController.contentController = menuItem.navController
    }
    
    func showSettings() {
        showSettings(menuItems.last!)
    }
    
    // MARK: - Table View Delegate -
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return menuItems.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: self.reuseIdentifier, for: indexPath)
        cell.backgroundColor = UIColor.clear
        cell.selectionStyle = .default
        let selectedBackgroundView = UIView()
        selectedBackgroundView.backgroundColor = UIColor.darkGray
        cell.selectedBackgroundView = selectedBackgroundView
        cell.textLabel?.textColor = UIColor.white
        
        let menuItem = self.menuItems[indexPath.row]
        cell.textLabel?.text = menuItem.name
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 64
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let menuItem = self.menuItems[indexPath.row]
        menuItem.function(self)(menuItem)
        Async.main(after: 0.2) {
            self.sidePanelController.showCenterPanel(animated: true)
        }
    }
}


// MARK: - Navigation Stack -

fileprivate func sharedGestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer, self: UIViewController) -> Bool {
    if self.navigationController?.viewControllers.count == 2 {
        return true
    }
    
    if let navigationController = self.navigationController as? NavigationStack {
        navigationController.showControllers()
    }
    
    return false
}

extension ItemViewController: UIGestureRecognizerDelegate {
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        return sharedGestureRecognizerShouldBegin(gestureRecognizer, self: self)
    }
}

extension CacheViewController: UIGestureRecognizerDelegate {
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        return sharedGestureRecognizerShouldBegin(gestureRecognizer, self: self)
    }
}

extension ServerListViewController: UIGestureRecognizerDelegate {
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        return sharedGestureRecognizerShouldBegin(gestureRecognizer, self: self)
    }
}
