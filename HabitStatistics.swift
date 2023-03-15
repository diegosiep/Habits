//
//  HabitStatistics.swift
//  Habits
//
//  Created by Diego Sierra on 20/01/23.
//

import Foundation


struct HabitStatistics {
    let habit: Habit
    let userCounts: [UserCounts]
    
}



extension HabitStatistics: Codable { }
