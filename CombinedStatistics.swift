//
//  CombinedStatistics.swift
//  Habits
//
//  Created by Diego Sierra on 31/01/23.
//

import Foundation

struct CombinedStatistics {
    let userStatistics: [UserStatistics]
    let habitStatistics: [HabitStatistics]
}


extension CombinedStatistics: Codable { }
