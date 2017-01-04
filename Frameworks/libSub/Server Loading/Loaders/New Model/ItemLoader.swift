//
//  ItemLoader.swift
//  iSub
//
//  Created by Benjamin Baron on 1/4/17.
//  Copyright © 2017 Ben Baron. All rights reserved.
//

import Foundation

protocol ItemLoader {
    weak var delegate: ISMSLoaderDelegate? { get set }
    var callbackBlock: LoaderCallback? { get set }
    
    var associatedObject: Any? { get }
    
    var items: [ISMSItem] { get }
    
    var loaderState: ISMSLoaderState { get }
    
    func persistModels()
    func loadModelsFromCache() -> Bool
    
    func startLoad()
    func cancelLoad()
}
