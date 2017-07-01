//
//  JGSettingsTableViewController.swift
//  JGSettingsManager
//
//  Created by Jeff on 12/14/15.
//  Copyright © 2015 Jeff Greenberg. All rights reserved.
//

import UIKit

/// model for sections display
/// used by JGSettingManager - TableController to build settings display
public struct JGSection {
    fileprivate let header: String
    fileprivate let footer: String
    fileprivate let settingsCells: [UITableViewCell]
    fileprivate let heightForHeader: CGFloat
    fileprivate let heightForFooter: CGFloat
    
    // can't use default initializer with default assignments
    public init(
        header: String,
        footer: String,
        settingsCells: [UITableViewCell],
        heightForHeader: CGFloat = 40.0,
        heightForFooter: CGFloat = 40.0)
    {
        self.header = header
        self.footer = footer
        self.settingsCells = settingsCells
        self.heightForHeader = heightForHeader
        self.heightForFooter = heightForFooter
    }
}

public protocol JGSettingsSectionsData {
    func loadSectionsConfiguration() -> [JGSection]
}

/// main controller for JGSettingsManager
open class JGSettingsTableController: UITableViewController {
    
    open var tableSections = [JGSection]()
    
    // styling should be set to Grouped in storyboard (initialization)
    // if not emebeded in storyboard Nav or coded without storyboard
    // then un-comment this:
    //    convenience required init(coder aDecoder: NSCoder) {
    //        self.init(style: .Grouped)
    //    }
    
    override open func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.dataSource = self
        tableView.delegate = self
        
        tableView.allowsSelection = false
    }

    override open func numberOfSections(in tableView: UITableView) -> Int {
        return tableSections.count
    }

    override open func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return tableSections[section].settingsCells.count
    }
    
    override open func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return tableSections[section].header
    }
    
    override open func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        return tableSections[section].footer
    }
    
    override open func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if tableSections[section].heightForHeader == 0 { return 0.00001 } // compensate for 0.0 not being allowed to hide headers
        return tableSections[section].heightForHeader 
    }
    
    override open func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        if tableSections[section].heightForFooter == 0 { return 0.00001 }  // compensate for 0.0 not being allowed to hide footers
        return tableSections[section].heightForFooter
    }
    
    open override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if let cell = self.tableView(tableView, cellForRowAt: indexPath) as? JGSettingsTableCell {
            return cell.cellHeight
        }
        return 44
    }
    
    override open func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
         return tableSections[indexPath.section].settingsCells[indexPath.row]
    }
}
