//
//  UICollectionView.swift
//  iSub Beta
//
//  Created by Andres Felipe Rodriguez Bolivar on 12/21/17.
//  Copyright © 2017 Ben Baron. All rights reserved.
//

import Foundation
import UIKit

public extension UICollectionView {
    
    func registerNibForCell<T: UICollectionViewCell>(with cellType: T.Type) {
        register(UINib(nibName: String(describing: cellType), bundle: nil), forCellWithReuseIdentifier: String(describing: cellType))
    }
    
    func reuse<T: UICollectionViewCell>(at index: IndexPath) -> T {
        let identifier = String(describing: T.self)
        guard let cell = dequeueReusableCell(withReuseIdentifier: identifier, for: index) as? T else {
            return T()
        }
        return cell
    }
    
}


