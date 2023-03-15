//
//  Operations.swift
//  Habits
//
//  Created by Diego Sierra on 25/02/23.
//

import Foundation


@available(iOS 16.0, *)
struct Operations {
    static func performApplicationUpdates() -> [Operation] {
        let refreshHomeViewController = RefreshHomeViewControllerInterface()
        return [refreshHomeViewController]
        
    }
}


@available(iOS 16.0, *)
class RefreshHomeViewControllerInterface: Operation {

    override func main() {
        
        HomeCollectionViewController.shared.backgroundAppUpdates()
    }
    
    
}
