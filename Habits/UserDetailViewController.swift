//
//  UserDetailViewController.swift
//  Habits
//
//  Created by Diego Sierra on 14/01/23.
//

import UIKit

@available(iOS 15.2, *)
class UserDetailViewController: UIViewController {
    
    
    @IBOutlet var switchLayoutButton: UIBarButtonItem!
    
    var imageRequestTask: Task<Void, Never>? = nil
    var userStatisticsRequestTask: Task<Void, Never>? = nil
    var habitLeadStatisticsRequestTask: Task<Void, Never>? = nil
    deinit {
        imageRequestTask?.cancel()
        userStatisticsRequestTask?.cancel()
        habitLeadStatisticsRequestTask?.cancel()
    }
    
    @IBOutlet var followUnfollowButton: UIBarButtonItem!
    
    @IBAction func switchLayouts(sender: UIBarButtonItem) {
        switch activeLayout {
        case .rankedByCounts:
            activeLayout = .sectioned
        case .sectioned:
            activeLayout = .rankedByCounts
        }
    }
    
    typealias DataSourceType = UICollectionViewDiffableDataSource<ViewModel.Section, ViewModel.Item>
    
    var layout: [Layout: UICollectionViewCompositionalLayout] = [:]
    
    var activeLayout: Layout = .sectioned {
        didSet {
            if let layout = layout[activeLayout] {
                self.collectionView.reloadData()
                collectionView.setCollectionViewLayout(layout, animated: true) { (_) in
                    switch self.activeLayout {
                    case .sectioned:
                        self.switchLayoutButton.image = UIImage(systemName: "list.number")
                    case .rankedByCounts:
                        self.switchLayoutButton.image = UIImage(systemName: "list.bullet.below.rectangle")
                    }
                    
                }
                
            }
        }
    }
    
    
    
    enum ViewModel {
        enum Section: Hashable, Comparable {
            case leading
            case category(_ category: Category)
            case numbered
            
            static func < (lhs: UserDetailViewController.ViewModel.Section, rhs: UserDetailViewController.ViewModel.Section) -> Bool {
                switch (lhs, rhs) {
                case (.leading, .category), (.leading, .leading):
                    return true
                case (.category, .leading):
                    return false
                case (category(let category1), category(let category2)):
                    return category1.name < category2.name
                default:
                    return true
                }
            }
            
            var sectionColor: UIColor {
                switch self {
                case .category(let category):
                    return category.color.uiColor
                case .leading:
                    return .systemGray4
                case .numbered:
                    return .systemYellow
                }
            }
        }
        
        typealias Item = HabitCount
    }
    
    enum SectionHeader: String {
        case kind = "SectionHeader"
        case reuse = "HeaderView"
        
        var identifier: String {
            return rawValue
        }
    }
    
    enum Layout {
        case sectioned
        case rankedByCounts
    }
    
    struct Model {
        var userStatistics: UserStatistics?
        var leadingStats: UserStatistics?
        
    }
    
    var dataSource: DataSourceType!
    var model = Model()
    
    @IBOutlet var profileImageView: UIImageView!
    @IBOutlet var userNameLabel: UILabel!
    @IBOutlet var bioLabel: UILabel!
    @IBOutlet var collectionView: UICollectionView!
    
    var user: User!
    
    init?(coder: NSCoder, user: User) {
        self.user = user
        super.init(coder: coder)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        layout[.sectioned] = createCategorisedLayout()
        layout[.rankedByCounts] = createSortedByCountLayout()
        if let layout = layout[activeLayout] {
            collectionView.collectionViewLayout = layout
        }
        userNameLabel.text = user.name
        bioLabel.text = user.bio
        collectionView.register(NamedSectionHeaderView.self, forSupplementaryViewOfKind: SectionHeader.kind.identifier, withReuseIdentifier: SectionHeader.reuse.identifier)
        dataSource = createDataSource()
        collectionView.dataSource = dataSource
        update()
        imageRequest()
        view.backgroundColor = user.color?.uiColor ?? .white
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.backgroundColor = .quaternarySystemFill
        tabBarController?.tabBar.scrollEdgeAppearance = tabBarAppearance
        let navBarAppearance = UINavigationBarAppearance()
        navBarAppearance.backgroundColor = .quaternarySystemFill
        navigationItem.scrollEdgeAppearance = navBarAppearance
        followUnfollowButtonStatus()
        
    }
    
    func update() {
        userStatisticsRequestTask?.cancel()
        userStatisticsRequestTask = Task {
            if let userStats = try? await UserStatisticsRequest(userIDs: [user.id]).send(), userStats.count > 0 {
                self.model.userStatistics = userStats[0]
            } else {
                self.model.userStatistics = nil
            }
            
            self.updateCollectionView()
            userStatisticsRequestTask?.cancel()
        }
        habitLeadStatisticsRequestTask?.cancel()
        habitLeadStatisticsRequestTask = Task {
            if let userStats = try? await HabitLeadStatisticsRequest(userID: user.id).send() {
                self.model.leadingStats = userStats
            } else {
                self.model.leadingStats = nil
            }
            self.updateCollectionView()
            habitLeadStatisticsRequestTask = nil
        }
        
    }
    
    func updateCollectionView() {
        switch activeLayout {
            
        case .sectioned:
            guard let userStatistics = model.userStatistics, let leadingStats = model.leadingStats else { return }
            
            var itemsBySection = userStatistics.habitCounts.reduce(into: [ViewModel.Section: [ViewModel.Item]]()) { partial, count in
                let section: ViewModel.Section
                
                if leadingStats.habitCounts.contains(count) {
                    section = .leading
                } else {
                    section = .category(count.habit.category)
                }
                
                partial[section, default: []].append(count)
            }
            
            itemsBySection = itemsBySection.mapValues { $0.sorted()}
            
            let sectionIDs = itemsBySection.keys.sorted()
            
            dataSource.applySnapshotUsing(sectionIDs: sectionIDs, itemsBySection: itemsBySection)
            
        case .rankedByCounts:
            guard let userStatistics = model.userStatistics else { return }
            
            var itemsByCounts = userStatistics.habitCounts.reduce(into: [ViewModel.Section: [ViewModel.Item]]()) { partial, count in
                let section: ViewModel.Section
                section = .numbered
                partial[section, default: []].append(count)
            }
            
            itemsByCounts = itemsByCounts.mapValues { habitCounts in
                habitCounts.sorted()
            }
            let sectionIDs = itemsByCounts.keys.sorted()
            
            dataSource.applySnapshotUsing(sectionIDs: sectionIDs, itemsBySection: itemsByCounts)
        }
        
        
    }
    
    
    
    func createDataSource() -> DataSourceType {
        let dataSource = DataSourceType(collectionView: collectionView) { collectionView, indexPath, habitStat in
            
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "HabitCount", for: indexPath) as! UserDetailCollectionViewCell
            
            cell.habitNameLabel.text = habitStat.habit.name
            cell.habitCountLabel.text = "\(habitStat.count)"
            
            return cell
            
        }
        
        dataSource.supplementaryViewProvider = { (collectionView, category, indexPath) in
            let header = collectionView.dequeueReusableSupplementaryView(ofKind: SectionHeader.kind.identifier, withReuseIdentifier: SectionHeader.reuse.identifier, for: indexPath) as! NamedSectionHeaderView
            let section = dataSource.snapshot().sectionIdentifiers[indexPath.section]
            header.backgroundColor = section.sectionColor
            switch section {
            case .leading:
                header.nameLabel.text = "Leading"
            case .category(let category):
                header.nameLabel.text = category.name
            case .numbered:
                header.nameLabel.text = "From highest to lowest habit count logs"
            }
            return header
        }
        
        return dataSource
        
    }
    
    func createCategorisedLayout() -> UICollectionViewCompositionalLayout {
        let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .fractionalHeight(1))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        item.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 12)
        
        
        let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(44))
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
        
        let headerSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(36))
        let sectionHeader = NSCollectionLayoutBoundarySupplementaryItem(layoutSize: headerSize, elementKind: SectionHeader.kind.identifier, alignment: .top)
        sectionHeader.pinToVisibleBounds = true
        
        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = NSDirectionalEdgeInsets(top: 20, leading: 0, bottom: 20, trailing: 0)
        
        section.boundarySupplementaryItems = [sectionHeader]
        
        return UICollectionViewCompositionalLayout(section: section)
        
    }
    
    func createSortedByCountLayout() -> UICollectionViewCompositionalLayout {
        let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .fractionalHeight(1))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        item.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 12)
        
        let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(44))
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
        
        let headerSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(36))
        let sectionHeader = NSCollectionLayoutBoundarySupplementaryItem(layoutSize: headerSize, elementKind: SectionHeader.kind.identifier, alignment: .top)
        sectionHeader.pinToVisibleBounds = true
        
        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = NSDirectionalEdgeInsets(top: 20, leading: 0, bottom: 20, trailing: 0)
        section.boundarySupplementaryItems = [sectionHeader]
        
        
        return UICollectionViewCompositionalLayout(section: section)
        
    }
    
    func imageRequest() {
        imageRequestTask = Task {
            if let image = try? await ImageRequest(imageID: user.id).send() {
                self.profileImageView.image = image
            }
            imageRequestTask = nil
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
    
    func followUnfollowButtonStatus() {
        if Settings.shared.followedUserIDs.contains(self.user.id) {
            followUnfollowButton.title = "Unfollow"
        } else if self.user.id == Settings.shared.currentUser.id {
            followUnfollowButton.title = ""
            followUnfollowButton.isEnabled = false
        } else {
            followUnfollowButton.title = "Follow"
        }
    }
    
    @IBAction func toggleFollowUnfollow(_ sender: Any) {
        Settings.shared.toggleFollowed(user: self.user)
        followUnfollowButtonStatus()
        
    }
    
    @IBSegueAction func showHabitDetailViewController(_ coder: NSCoder, sender: UserDetailCollectionViewCell) -> HabitDetailViewController? {
        
        guard let habitIdentity = habitIdentity(with: sender.habitNameLabel.text!) else { return nil}
        return HabitDetailViewController(coder: coder, habit: habitIdentity)
    }
    
    func habitIdentity(with name: String) -> Habit? {
        let selectedHabitIdentity = model.userStatistics?.habitCounts.first(where: { $0.habit.name == name })
        return selectedHabitIdentity?.habit
    }
   
    
}
