//
//  CacheViewController.swift
//  iSub
//
//  Created by Benjamin Baron on 1/7/17.
//  Copyright © 2017 Ben Baron. All rights reserved.
//

import Foundation

class CacheViewController: DraggableTableViewController {
    fileprivate let foldersRowIndex   = 0
    fileprivate let artistsRowIndex   = 1
    fileprivate let albumsRowIndex    = 2
    fileprivate let songsRowIndex     = 3
    
    override var preferredStatusBarStyle : UIStatusBarStyle {
        return .lightContent
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.edgesForExtendedLayout = UIRectEdge()
        self.automaticallyAdjustsScrollViewInsets = false
        
        self.tableView.tableFooterView = UIView(frame:CGRect(x: 0, y: 0, width: 320, height: 64))
    }

    override func setupLeftBarButton() -> UIBarButtonItem {
        return UIBarButtonItem(title: "Menu", style: .plain, target: self, action: #selector(showMenu))
    }
    
    // MARK: - Table View Delegate -
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 4
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell()
        cell.accessoryType = UITableViewCellAccessoryType.disclosureIndicator
        
        switch indexPath.row {
        case foldersRowIndex: cell.textLabel?.text = "Folders"
        case artistsRowIndex: cell.textLabel?.text = "Artists"
        case albumsRowIndex: cell.textLabel?.text = "Albums"
        case songsRowIndex: cell.textLabel?.text = "Songs"
        default: break
        }

        return cell
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return ISMSNormalize(ISMSSubfolderCellHeight)
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if ViewObjectsSingleton.si().isCellEnabled {
            switch indexPath.row {
            case foldersRowIndex:
                let loader = CachedRootFoldersLoader()
                pushItemController(loader: loader)
            case artistsRowIndex:
                let loader = CachedRootArtistsLoader()
                pushItemController(loader: loader)
            case albumsRowIndex:
                let loader = CachedRootAlbumsLoader()
                pushItemController(loader: loader)
            case songsRowIndex:
                let loader = CachedRootSongsLoader()
                pushItemController(loader: loader)
            default:
                break
            }
        }
        else
        {
            self.tableView.deselectRow(at: indexPath, animated: false)
        }
    }
    
    fileprivate func pushItemController(loader: ItemLoader) {
        let viewModel = ItemViewModel(loader: loader)
        let viewController = ItemViewController(viewModel: viewModel)
        self.pushCustom(viewController)
    }
}
