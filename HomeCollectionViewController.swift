//
//  HomeCollectionViewController.swift
//  Habits
//
//  Created by Diego Sierra on 14/01/23.
//

import UIKit
import UserNotifications

enum SupplementaryItemType {
    case collectionSupplementaryView
    case layoutDecorationView
}

protocol SupplementaryItem {
    associatedtype ViewClass: UICollectionReusableView
    
    var itemType: SupplementaryItemType { get }
    
    var reuseIdentifier: String { get }
    var viewKind: String { get }
    var viewClass: ViewClass.Type { get }
}

extension SupplementaryItem {
    func register(on collectionView: UICollectionView) {
        switch itemType {
        case .collectionSupplementaryView:
            collectionView.register(viewClass.self, forSupplementaryViewOfKind: viewKind, withReuseIdentifier: reuseIdentifier)
        case .layoutDecorationView:
            collectionView.collectionViewLayout.register(viewClass.self, forDecorationViewOfKind: viewKind)
        }
    }
}

enum SupplementaryView: String, CaseIterable, SupplementaryItem {
    case leaderboardSectionHeader
    case leaderboardBackground
    case followedUsersSectionHeader
    
    var reuseIdentifier: String {
        return rawValue
    }
    var viewKind: String {
        return rawValue
    }
    
    var itemType: SupplementaryItemType {
        switch self {
        case .leaderboardBackground:
            return .layoutDecorationView
        default:
            return .collectionSupplementaryView
        }
    }
    
    var viewClass: UICollectionReusableView.Type {
        switch self {
        case .leaderboardBackground:
            return SectionBackgroundView.self
        default:
            return NamedSectionHeaderView.self
        }
    }
    
}

class SectionBackgroundView: UICollectionReusableView {
    override func didMoveToSuperview() {
        backgroundColor = .systemGray6
    }
}

@available(iOS 16.0, *)
class HomeCollectionViewController: UICollectionViewController {
    typealias DataSourceType = UICollectionViewDiffableDataSource<ViewModel.Section, ViewModel.Item>
    
    static let shared = HomeCollectionViewController()
    
    func printSomething() {
        print("Printed something")
    }
    
    var userRequestTask: Task<Void, Never>? = nil
    var habitRequestTask: Task<Void, Never>? = nil
    var combinedStatisticsRequest: Task<Void, Never>? = nil
    deinit {
        userRequestTask?.cancel()
        habitRequestTask?.cancel()
        combinedStatisticsRequest?.cancel()
    }
    
    enum ViewModel {
        enum Section: Hashable {
            case leaderboard
            case followedUsers
        }
        
        enum Item: Hashable {
            case leaderboardHabit(name: String, leadingUserRanking: String?, secondaryUserRanking: String?)
            case followedUser(_ user: User, message: String)
            
            func hash(into hasher: inout Hasher) {
                switch self {
                case .leaderboardHabit(name: let name, _, _):
                    hasher.combine(name)
                case .followedUser(let user, _):
                    hasher.combine(user)
                }
            }
            
            static func ==(_ lhs: Item, _ rhs: Item) -> Bool {
                switch (lhs, rhs) {
                case (.leaderboardHabit(name: let lName, _, _), .leaderboardHabit(name: let rName, _, _)):
                    return lName == rName
                case (.followedUser(let lUser, _), .followedUser(let rUser, _)):
                    return lUser == rUser
                default:
                    return false
                }
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        dataSource = createDataSource()
        collectionView.dataSource = dataSource
        collectionView.collectionViewLayout = createLayout()
        
        for supplementaryView in SupplementaryView.allCases {
            supplementaryView.register(on: collectionView)
        }
        
        userRequestTask = Task {
            if let users = try? await UserRequest().send() {
                self.model.usersByID = users
            }
            self.updateCollectionView()
            
            userRequestTask = nil
        }
        
        habitRequestTask = Task {
            if let habits = try? await HabitRequest().send() {
                self.model.habitsByName = habits
            }
            self.updateCollectionView()
            habitRequestTask = nil
        }
        
    }
    
    
    struct Model {
        var usersByID = [String: User]()
        var habitsByName = [String: Habit]()
        var habitStatistics = [HabitStatistics]()
        var userStatistics = [UserStatistics]()
        
        var currentUser: User {
            return Settings.shared.currentUser
        }
        
        var user: [User] {
            return Array(usersByID.values)
        }
        
        var habits: [Habit] {
            return Array(habitsByName.values)
        }
        
        var followedUsers: [User] {
            return Array(usersByID.filter { Settings.shared.followedUserIDs.contains($0.key)}.values)
        }
        
        var favoriteHabits: [Habit] {
            return Settings.shared.favoriteHabits
        }
        
        var nonFavoriteHabits: [Habit] {
            return habits.filter { !favoriteHabits.contains($0)}
        }
        
        
    }
    
    var model = Model()
    var dataSource: DataSourceType!
    
    
  
    func updateCollectionView() {
        
        var sectionIDs = [ViewModel.Section]()
        let leaderBoardItems = model.habitStatistics.filter { statistic in
            return model.favoriteHabits.contains { $0.name == statistic.habit.name }
        }
            .sorted(by: { $0.habit.name < $1.habit.name})
            .reduce(into: [ViewModel.Item]()) { partial, statistic in
                //                Rank the user counts from highest to lowest.
                let rankedUserCounts = statistic.userCounts.sorted { $0.count > $1.count }
                //                Find the index of the current user's count, keeping in mind that it won't exist if the user hasn't logged that habit yet.
                let myCountIndex = rankedUserCounts.firstIndex { $0.user.id == self.model.currentUser.id
                }
                
                var leadingRanking: String?
                var secondaryRanking: String?
                
                //                Examine the number of user counts for the statistic:
                switch rankedUserCounts.count {
                    //                If 0, set the leader label to “Nobody Yet!” and leave the secondary label nil.
                case 0:
                    leadingRanking = "Nobody Yet!"
                    secondaryRanking = nil
                    //                If 1, set the leader label to the only user and count.
                case 1:
                    let onlyCount = rankedUserCounts.first!
                    leadingRanking = userRankingSorting(from: onlyCount)
                    //                Otherwise, do the following:
                default:
                    //                Set the leader label to the user count at index 0.
                    let leaderCount = rankedUserCounts.first!
                    leadingRanking = userRankingSorting(from: leaderCount)
                    //                Check whether the index of the current user's count exists and is not 0.
                    if let currentUserIndex = myCountIndex, currentUserIndex != 0 {
                        //                If true, the user's count and ranking should be displayed in the secondary label.
                        let currentUserCount = rankedUserCounts.first(where: { $0.user.id == self.model.currentUser.id })
                        secondaryRanking = userRankingSorting(from: currentUserCount!)
                        //                If false, the second-place user count should be displayed.
                    } else {
                        let secondPlaceUser = rankedUserCounts[1]
                        secondaryRanking = userRankingSorting(from: secondPlaceUser)
                    }
                }
                func userRankingSorting(from userCount: UserCounts) -> String {
                    var name = userCount.user.name
                    var ranking = ""
                    if userCount.user.name == self.model.currentUser.name {
                        name = "You"
                        ranking = "\(ordinalString(from: myCountIndex!))"
                    }
                    return "\(name) \(userCount.count)" + ranking
                }
                let leaderboardItem = ViewModel.Item.leaderboardHabit(name: statistic.habit.name, leadingUserRanking: leadingRanking, secondaryUserRanking: secondaryRanking)
                partial.append(leaderboardItem)
            }
        sectionIDs.append(.leaderboard)
        var itemsBySection = [ViewModel.Section.leaderboard: leaderBoardItems]
        
        var followedUserItems = [ViewModel.Item]()
        func loggedHabits(for user: User) -> Set<String> {
            var names = [String]()
            if let stats = model.userStatistics.first(where: { $0.user == user }) {
                names = stats.habitCounts.map { $0.habit.name }
            }
            
            return Set(names)
        }
        
        //        Get the current user's logged habits and extract the favorites
        let currentUserLoggedHabits = loggedHabits(for: model.currentUser)
        let favoriteLoggedHabits = Set(model.favoriteHabits.map { $0.name }).intersection(currentUserLoggedHabits)
        //        Loop through all the followed users
        for followedUser in model.followedUsers.sorted(by: { $0.name < $1.name }) {
            let message: String
            let followedUsersLoggedHabits = loggedHabits(for: followedUser)
            
            let commonLoggedHabits = currentUserLoggedHabits.intersection(followedUsersLoggedHabits)
            // If the users have a habit in common:
            if commonLoggedHabits.count > 0 {
                // Pick the habit to focus on
                let habitName: String
                
                let commonFavoriteLoggedHabits = favoriteLoggedHabits.intersection(commonLoggedHabits)
                
                if commonFavoriteLoggedHabits.count > 0 {
                    habitName = commonFavoriteLoggedHabits.sorted().first!
                } else {
                    habitName = commonLoggedHabits.sorted().first!
                }
                // Get the full statistics (all the user counts) for that habit
                let habitStats = model.habitStatistics.first { $0.habit.name == habitName}!
                // Get the ranking for each user
                let rankedUserCounts = habitStats.userCounts.sorted { $0.count > $1.count }
                let currentUserRanking = rankedUserCounts.firstIndex { $0.user == model.currentUser }!
                let followedUserRanking = rankedUserCounts.firstIndex { $0.user == followedUser }!
                
                // Construct the message depending on who's leading
                if currentUserRanking < followedUserRanking {
                    message = "Currently #\(ordinalString(from: followedUserRanking)), behind you (#\(ordinalString(from: currentUserRanking))) in \(habitName). Send them a friendly reminder!"
                } else if currentUserRanking > followedUserRanking {
                    message = "Currently #\(ordinalString(from: followedUserRanking)), ahead of you (#\(ordinalString(from: currentUserRanking))) in \(habitName). You might catch up with a little extra effort"
                } else {
                    message = "You're tied at \(ordinalString(from: followedUserRanking)) in \(habitName)! Now's your chance to pull ahead."
                }
                //        Otherwise, if the followed user has logged at least one habit:
            } else if followedUsersLoggedHabits.count > 0 {
                // Get an arbitrary name
                let habitName = followedUsersLoggedHabits.sorted().first!
                // Get the full statistics (all the user counts) for thtat habit
                let habitStats = model.habitStatistics.first { $0.habit.name == habitName }!
                // Get the user's ranking for that habit
                let rankedUserCounts = habitStats.userCounts.sorted { $0.count > $1.count }
                let followedUserRanking = rankedUserCounts.firstIndex { $0.user == followedUser }!
                // Construct the message
                message = "Currently #\(ordinalString(from: followedUserRanking)), in \(habitName). Maybe you should give this habit a look."
                //        Otherwise, this user hasn't done anything
            } else {
                message = "This user doesn't seem to have one much yet. Check in to see if they need help getting started."
            }
            followedUserItems.append(.followedUser(followedUser, message: message))
        }
        sectionIDs.append(.followedUsers)
        itemsBySection[.followedUsers] = followedUserItems
        
        dataSource.applySnapshotUsing(sectionIDs: sectionIDs, itemsBySection: itemsBySection)
    }
    
    static let formatter: NumberFormatter = {
        var f = NumberFormatter()
        f.numberStyle = .ordinal
        return f
    }()
    
    func ordinalString(from number: Int) -> String {
        return Self.formatter.string(from: NSNumber(integerLiteral: number + 1))!
    }
    
    func update() {
        combinedStatisticsRequest?.cancel()
        
        combinedStatisticsRequest = Task {
            if let combinedStatistics = try? await CombinedStatisticsRequest().send() {
                self.model.userStatistics = combinedStatistics.userStatistics
                self.model.habitStatistics = combinedStatistics.habitStatistics
            } else {
                self.model.userStatistics = []
                self.model.habitStatistics = []
            }
            self.updateCollectionView()
            
            combinedStatisticsRequest = nil
        }
    }
    
    func backgroundAppUpdates() {
        combinedStatisticsRequest?.cancel()
        
        combinedStatisticsRequest = Task {
            if let combinedStatistics = try? await CombinedStatisticsRequest().send() {
                self.model.userStatistics = combinedStatistics.userStatistics
                self.model.habitStatistics = combinedStatistics.habitStatistics
                print(combinedStatistics.userStatistics)
                print(combinedStatistics.habitStatistics)
                
            } else {
                self.model.userStatistics = []
                self.model.habitStatistics = []
            }
            
            combinedStatisticsRequest = nil
        }
    }
    
    var updateTimer: Timer?
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        update()
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true, block: { _ in
            self.update()
        })
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        updateTimer?.invalidate()
        updateTimer = nil
    }
    
    func createDataSource() -> DataSourceType {
        let dataSource = DataSourceType(collectionView: collectionView) { (collectionView, indexPath, itemIdentifier) in
            switch itemIdentifier {
            case .leaderboardHabit(let name, let leadingUserRanking, let secondaryUserRanking):
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "LeaderboardHabit", for: indexPath) as! LeaderboardHabitCollectionViewCell
                cell.habitNameLabel.text = name
                cell.leaderLabel.text = leadingUserRanking
                cell.secondaryLabel.text = secondaryUserRanking
                cell.contentView.backgroundColor = favoriteHabitColor.withAlphaComponent(0.75)
                cell.contentView.layer.cornerRadius = 8
                cell.layer.shadowRadius = 3
                cell.layer.shadowColor = UIColor.systemGray3.cgColor
                cell.layer.shadowOffset = CGSize(width: 0, height: 0)
                cell.layer.shadowOpacity = 1
                cell.layer.masksToBounds = false
                
                return cell
            case .followedUser(let user, let message):
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "FollowedUser", for: indexPath) as! FollowedUserCollectionViewCell
                cell.primaryTextLabel.text = user.name
                cell.secondaryTextLabel.text = message
                if indexPath.item == collectionView.numberOfItems(inSection: indexPath.section) - 1 {
                    cell.separatorLineView.isHidden = true
                } else {
                    cell.separatorLineView.isHidden = false
                }
                return cell
            }
        }
        
        dataSource.supplementaryViewProvider = {
            (collectionView, kind, indexPath) in
            guard let elementKind = SupplementaryView(rawValue: kind) else { return nil }
            
            let view = collectionView.dequeueReusableSupplementaryView(ofKind: elementKind.viewKind, withReuseIdentifier: elementKind.reuseIdentifier, for: indexPath)
            
            switch elementKind {
            case .leaderboardSectionHeader:
                let header = view as! NamedSectionHeaderView
                header.nameLabel.text = "Leaderboard"
                header.nameLabel.font = UIFont.preferredFont(forTextStyle: .largeTitle)
                header.alignLabelToTop()
                return header
            case .followedUsersSectionHeader:
                let header = view as! NamedSectionHeaderView
                header.nameLabel.text = "Following"
                header.nameLabel.font = UIFont.preferredFont(forTextStyle: .title2)
                header.alignLabelToYCenter()
                return header
            default:
                return nil
            }
            
        }
        
        return dataSource
    }
    
    func createLayout() -> UICollectionViewCompositionalLayout {
        let layout = UICollectionViewCompositionalLayout { (sectionIndex, environment) -> NSCollectionLayoutSection? in
            switch self.dataSource.snapshot().sectionIdentifiers[sectionIndex] {
            case .leaderboard:
                let leaderBoardItemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .fractionalHeight(0.3))
                let leaderBoarditem = NSCollectionLayoutItem(layoutSize: leaderBoardItemSize)
                
                let verticalTrioSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(0.75), heightDimension: .fractionalWidth(0.75))
                let leaderboardVerticalTrio = NSCollectionLayoutGroup.vertical(layoutSize: verticalTrioSize, repeatingSubitem: leaderBoarditem, count: 3)
                leaderboardVerticalTrio.interItemSpacing = .fixed(20)
                
                let leaderboardSection = NSCollectionLayoutSection(group: leaderboardVerticalTrio)
                
                let headerSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(80))
                let header = NSCollectionLayoutBoundarySupplementaryItem(layoutSize: headerSize, elementKind: SupplementaryView.leaderboardSectionHeader.viewKind, alignment: .top)
                
                let background = NSCollectionLayoutDecorationItem.background(elementKind: SupplementaryView.leaderboardBackground.viewKind)
                
                leaderboardSection.boundarySupplementaryItems = [header]
                leaderboardSection.decorationItems = [background]
                leaderboardSection.supplementariesFollowContentInsets = false
                leaderboardSection.interGroupSpacing = 20
                leaderboardSection.orthogonalScrollingBehavior = .continuous
                leaderboardSection.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 20, bottom: 20, trailing: 20)
                
                return leaderboardSection
                
            case .followedUsers:
                let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(100))
                let followedUserItem = NSCollectionLayoutItem(layoutSize: itemSize)
                
                let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(100))
                let followedUserGroup = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, repeatingSubitem: followedUserItem, count: 1)
                
                let followedUserSection = NSCollectionLayoutSection(group: followedUserGroup)
                
                let headerSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(60))
                let header = NSCollectionLayoutBoundarySupplementaryItem(layoutSize: headerSize, elementKind: SupplementaryView.followedUsersSectionHeader.viewKind, alignment: .top)
                followedUserSection.boundarySupplementaryItems = [header]
                
                return followedUserSection
                
            }
        }
        return layout
    }
    
    @IBSegueAction func showHabitDetailViewController(_ coder: NSCoder, sender: LeaderboardHabitCollectionViewCell?) -> HabitDetailViewController? {
        guard let cell = sender else { return nil }
        guard let habitIdentity = habitIdentity(with: cell.habitNameLabel.text!) else { return nil }
        
        return HabitDetailViewController(coder: coder, habit: habitIdentity)
    }
    
    func habitIdentity(with name: String) -> Habit? {
        let selectedHabitIdentity = model.favoriteHabits.first(where: {$0.name == name})
        return selectedHabitIdentity!
    }
    
    @IBSegueAction func showPersonDetailViewController(_ coder: NSCoder, sender: FollowedUserCollectionViewCell?) -> UserDetailViewController? {
        guard let cell = sender else { return nil }
        guard let personIdentity = personIdentity(with: cell.primaryTextLabel.text!) else { return nil }
        
        return UserDetailViewController(coder: coder, user: personIdentity)
    }
    
    func personIdentity(with name: String) -> User? {
        let selectedUserIdentity = model.followedUsers.first(where: { $0.name == name})
        return selectedUserIdentity!
    }
    
    
}




