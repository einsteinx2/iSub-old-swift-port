//
//  SettingsViewController.swift
//  iSub Beta
//
//  Created by Benjamin Baron on 7/1/17.
//  Copyright © 2017 Ben Baron. All rights reserved.
//

import Foundation

class SettingsViewController: JGSettingsTableController, JGSettingsSectionsData, JGSettingsTableCellDelegate {
    override func viewDidLoad() {
        super.viewDidLoad()
        self.tableSections = loadSectionsConfiguration()
        
        self.tableView.tableFooterView = UIView(frame: CGRect(x: 0, y: 0, width: 0, height: 100))
    }
    
    fileprivate var totalSpaceInMB: Float { return Float(CacheManager.si.totalSpace / 1024 / 1024) }
    fileprivate var totalSpaceInGB: Float { return totalSpaceInMB / 1024 }
    
    func loadSectionsConfiguration() -> [JGSection] {
        let sections = [
            JGSection (
                header: "General",
                footer: "",
                settingsCells: [
                    JGSwitchTableCell(data: SavedSettings.JGUserDefaults.disableScreenSleep, delegate: self, labelString: "Disable screen sleep"),
                    JGSwitchTableCell(data: SavedSettings.JGUserDefaults.disableUsageCell, delegate: self, labelString: "Display usage over cellular")
                    ],
                heightForFooter: 10.0
            ),
            JGSection (
                header: "Player",
                footer: "",
                settingsCells: [
                    JGSegmentedControlTableCell(data: SavedSettings.JGUserDefaults.quickSkipLength,
                                                delegate: self,
                                                title: "Quick skip length",
                                                segments: ["5s", "10s", "15s", "30s", "1m", "2m", "5m", "10m", "20m"])
                ],
                heightForFooter: 10.0
            ),
            JGSection (
                header: "Audio Streaming",
                footer: "",
                settingsCells: [
                    JGSegmentedControlTableCell(data: SavedSettings.JGUserDefaults.maxAudioBitrateCell,
                                                delegate: self,
                                                title: "Max cell streaming kbps",
                                                subTitle: "Lower this setting to reduce bandwidth usage. Note: If your account has a lower max bit rate set in Subsonic, that bit rate is honored.",
                                                segments: ["64", "96", "128", "160", "192", "256", "320", "None"]),
                    JGSegmentedControlTableCell(data: SavedSettings.JGUserDefaults.maxAudioBitrateWifi,
                                                delegate: self,
                                                title: "Max wifi streaming kbps",
                                                segments: ["64", "96", "128", "160", "192", "256", "320", "None"])
                ],
                heightForFooter: 10.0
            ),
            JGSection (
                header: "Video Streaming",
                footer: "",
                settingsCells: [
                    JGSegmentedControlTableCell(data: SavedSettings.JGUserDefaults.maxVideoBitrateCell,
                                                delegate: self,
                                                title: "Max cell streaming kbps",
                                                subTitle: "Lower this setting to reduce bandwidth usage. Note: Unlike audio streaming, video streaming uses adaptive bitrate technology to automatically choose the best quality based on your connection. Only lower this if your computer is too slow to transcode high quality video or if you need to restrict your data usage.",
                                                segments: ["64", "256", "512", "1024", "2048", "4096"]),
                    JGSegmentedControlTableCell(data: SavedSettings.JGUserDefaults.maxVideoBitrateWifi,
                                                delegate: self,
                                                title: "Max wifi streaming kbps",
                                                segments: ["64", "256", "512", "1024", "2048", "4096"])
                ],
                heightForFooter: 10.0
            ),
            JGSection (
                header: "Song Caching",
                footer: "",
                settingsCells: [
                    JGSwitchTableCell(data: SavedSettings.JGUserDefaults.downloadUsingCell, delegate: self, labelString: "Enable downloads over cellular"),
                    JGSwitchTableCell(data: SavedSettings.JGUserDefaults.autoSongCaching, delegate: self, labelString: "Automatically cache songs"),
                    JGSwitchTableCell(data: SavedSettings.JGUserDefaults.preloadNextSong, delegate: self, labelString: "Pre-load next song"),
                    JGSwitchTableCell(data: SavedSettings.JGUserDefaults.backupDownloads, delegate: self, labelString: "Backup downloads and cached songs"),
                    JGSliderTableCell(data: SavedSettings.JGUserDefaults.minFreeSpace,
                                      delegate: self,
                                      title: "Minimum free space before purging",
                                      minimumValue: 0,
                                      maximumValue: totalSpaceInMB,
                                      units: "MB",
                                      decimalPlaces: 0),
                    JGSliderTableCell(data: SavedSettings.JGUserDefaults.maxCacheSize,
                                      delegate: self,
                                      title: "Minimum cache size before purging",
                                      minimumValue: 0,
                                      maximumValue: totalSpaceInGB,
                                      units: "GB")
                ],
                heightForFooter: 10.0
            )
        ]
        
        return sections
    }
    
    func settingsTableCellTitleFont(_ cell: JGSettingsTableCell) -> UIFont {
        return UIFont.systemFont(ofSize: 17)
    }
    
    func settingsTableCellSubTitleFont(_ cell: JGSettingsTableCell) -> UIFont {
        return UIFont.systemFont(ofSize: 13)
    }
    
    func settingsTableCellLabelFont(_ cell: JGSettingsTableCell) -> UIFont {
        return UIFont.systemFont(ofSize: 17)
    }
    
    func settingsTableCellControlFont(_ cell: JGSettingsTableCell) -> UIFont {
        if cell is JGSegmentedControlTableCell {
            return UIFont.systemFont(ofSize: 12)
        }
        return UIFont.systemFont(ofSize: 17)
    }
}
