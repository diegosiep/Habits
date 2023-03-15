//
//  Settings.swift
//  Habits
//
//  Created by Diego Sierra on 15/01/23.
//

import Foundation
import UIKit

struct Settings {
    static var shared = Settings()
    
    private let defaults = UserDefaults.standard
    
    
    private func archiveJSON<T: Encodable>(value: T, key: String) {
        let data = try! JSONEncoder().encode(value)
        let string = String(data: data, encoding: .utf8)
        defaults.set(string, forKey: key)
    }
    
    private func unarchiveJSON<T: Decodable>(key: String) -> T? {
        guard let string = defaults.string(forKey: key),
              let data = string.data(using: .utf8) else {
            return nil
        }
        return try! JSONDecoder().decode(T.self, from: data)
    }
    
    
    var favoriteHabits: [Habit] {
        get {
            return unarchiveJSON(key: Setting.favoriteHabits) ?? []
        }
        
        set {
            archiveJSON(value: newValue, key: Setting.favoriteHabits)
        }
    }
    
    var followedUserIDs: [String] {
        get {
            return unarchiveJSON(key: Setting.followedUserIDs) ?? []
        }
        set {
            archiveJSON(value: newValue, key: Setting.followedUserIDs)
        }
    }
    
    enum Setting {
        static let favoriteHabits = "favoriteHabits"
        static let followedUserIDs = "followedUserIDs"
    }
    
    mutating func toggleFavorite(_ habit: Habit) {
        var favorites = favoriteHabits
        if favorites.contains(habit) {
            favorites = favorites.filter { $0 != habit}
        } else {
            favorites.append(habit)
        }
         self.favoriteHabits = favorites
    }
    
    mutating func toggleFollowed(user: User) {
        var followed = followedUserIDs
        if followed.contains(user.id) {
            followed = followed.filter { $0 != user.id }
        } else {
            followed.append(user.id)
        }
        followedUserIDs = followed
        
    }

    let currentUser = User(id: "activeUser", name: "Diego", color: Color(hue: 0.75707988194531695, saturation: 0.81293901213002762, brightness: 0.92267943863794188), bio: "I am a gay pianist")
    
// You can also create a static property. It needs to be static for it to be used in currentUser constant, otherwise, an initialisation error is thrown indicating that the property has not been initialised and that it was used before it was initialised.
//    static let currentUserColor = Color(hue: 0.75707988194531695, saturation: 0.81293901213002762, brightness: 0.92267943863794188)

}



