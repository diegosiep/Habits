//
//  LoggedHabit.swift
//  Habits
//
//  Created by Diego Sierra on 29/01/23.
//

import Foundation

struct LoggedHabit {
    let habitName: String
    let userID: String
    let timestamp: Date
    
    
}

extension LoggedHabit: Codable { }
