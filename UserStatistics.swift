//
//  UserStatistics.swift
//  Habits
//
//  Created by Diego Sierra on 24/01/23.
//

import Foundation

struct UserStatistics {
    let user: User
    let habitCounts: [HabitCount]
    
}

extension UserStatistics: Codable { }
