//
//  Count.swift
//  Habits
//
//  Created by Diego Sierra on 20/01/23.
//

import Foundation


struct UserCounts {
    let user: User
    let count: Int
}

extension UserCounts: Codable { }
extension UserCounts: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(user)
    }
    
    static func ==(_ lhs: UserCounts, _ rhs: UserCounts) -> Bool {
        return lhs.user == rhs.user
    }
}
