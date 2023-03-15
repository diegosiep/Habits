//
//  UserCollectionViewController.swift
//  Habits
//
//  Created by Diego Sierra on 14/01/23.
//

import UIKit

private let reuseIdentifier = "Cell"

@available(iOS 16.0, *)
class UserCollectionViewController: UICollectionViewController {
    
    enum Badge: String {
        case elementKind
        case reuseIdentifier
        
        var identifier: String {
            return rawValue
        }
        
    }
    
    typealias DataSourceType = UICollectionViewDiffableDataSource<ViewModel.SectionID, ViewModel.Item>
    
    //  Keep track of async tasks so they can be cancelled when appropriate
    var usersRequestTask: Task<Void, Never>? = nil
    deinit { usersRequestTask?.cancel() }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        dataSource = createDataSource()
        collectionView.dataSource = dataSource
        collectionView.collectionViewLayout = createLayout()
        collectionView.register(BadgeCollectionReusableView.self, forSupplementaryViewOfKind: Badge.elementKind.identifier, withReuseIdentifier: Badge.reuseIdentifier.identifier)
        update()
    
        
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.updateCollectionView()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.updateCollectionView()
    }
    
    
    enum ViewModel {
        typealias SectionID = Int
        
        struct Item: Hashable {
            let user: User
            let isFollowed: Bool
            func hash(into hasher: inout Hasher) {
                hasher.combine(user)
            }
            
            static func ==(_ lhs: Item, _ rhs: Item) -> Bool {
                return lhs.user == rhs.user
            }
        }
        
    }
    
    struct Model {
        var usersByID = [String: User]()
        
        var followedUsers: [User] {
            return Array(usersByID.filter{
                Settings.shared.followedUserIDs.contains($0.key)
            }.values)
        }
    }
    var dataSource: DataSourceType!
    var model = Model()
    
    
    func update() {
        usersRequestTask?.cancel()
        usersRequestTask = Task {
            if let users = try? await UserRequest().send() {
                self.model.usersByID = users
            } else {
                self.model.usersByID = [:]
            }
            self.updateCollectionView()
            usersRequestTask = nil
        }
    }
    
    func updateCollectionView() {
        let users = model.usersByID.values.sorted().reduce(into: [ViewModel.Item]()) { partial, user in
            partial.append(ViewModel.Item(user: user, isFollowed: model.followedUsers.contains(user)))}
        
        let itemsBySection = [0: users]
        let section: ViewModel.SectionID = 0
        
        dataSource.applySnapshotUsing(sectionIDs: [section], itemsBySection: itemsBySection)
        
    }
    
    
    func createDataSource() -> DataSourceType {
        let dataSource = DataSourceType(collectionView: collectionView) { collectionView, indexPath, item in
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "User", for: indexPath) as! UICollectionViewListCell
            
            var content = cell.defaultContentConfiguration()
            content.text = item.user.name
            content.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 11, leading: 8, bottom: 11, trailing: 8)
            content.textProperties.alignment = .center
            cell.contentConfiguration = content
            var backgroundConfiguration = UIBackgroundConfiguration.clear()
            backgroundConfiguration.backgroundColor = item.user.color?.uiColor ?? UIColor.systemGray6
            backgroundConfiguration.cornerRadius = 8
            cell.backgroundConfiguration = backgroundConfiguration
            
            return cell
        }
        
        dataSource.supplementaryViewProvider = { (collectionView, category, indexPath)  in
            guard let itemIdentifierIndexPath = self.dataSource.itemIdentifier(for: indexPath) else { return nil }
            
            let followedUsers = itemIdentifierIndexPath.isFollowed
            
            if let badge = collectionView.dequeueReusableSupplementaryView(ofKind: Badge.elementKind.identifier, withReuseIdentifier: Badge.reuseIdentifier.identifier, for: indexPath) as? BadgeCollectionReusableView {
                badge.isHidden = !followedUsers
                return badge
            } else {
                fatalError("Cannot create Supplementary Reusable View")
            }
        }
        
        return dataSource
    }
    
    func createLayout() -> UICollectionViewCompositionalLayout {
        
        let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(0.5), heightDimension: .fractionalHeight(1))
        
        let badgeAnchor = NSCollectionLayoutAnchor(edges: [.top, .trailing], fractionalOffset: CGPoint(x: 0.3, y: -0.3))
        let badgeSize = NSCollectionLayoutSize(widthDimension: .absolute(20), heightDimension: .absolute(20))
        let badge = NSCollectionLayoutSupplementaryItem(layoutSize: badgeSize, elementKind: Badge.elementKind.identifier, containerAnchor: badgeAnchor)
        
        let item = NSCollectionLayoutItem(layoutSize: itemSize, supplementaryItems: [badge])
        
        let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(90))
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, repeatingSubitem: item, count: 2)
        
        let section = NSCollectionLayoutSection(group: group)
        
        section.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 10, bottom: 10, trailing: 10)
        
        return UICollectionViewCompositionalLayout(section: section)
        
    }
    
    override func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        let config = UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { _ in
            guard let item = self.dataSource.itemIdentifier(for: indexPath) else { return nil }
            let followedToggle = UIAction(title: item.isFollowed ? "Unfollow" : "Follow") { (action) in
                Settings.shared.toggleFollowed(user: item.user)
                self.updateCollectionView()
                self.collectionView.reloadData()
            }
            if item.user == Settings.shared.currentUser {
                return UIMenu(title: "", image: nil, identifier: nil, options: [], children: [])
            } else {
                return UIMenu(title: "", image: nil, identifier: nil, options: [], children: [followedToggle])
            }
        }
        
        return config
    }
    
    
    @IBSegueAction func showUserDetail(_ coder: NSCoder, sender: Any?) -> UserDetailViewController? {
        guard let cell = sender as? UICollectionViewCell, let indexPath = collectionView.indexPath(for: cell), let item = dataSource.itemIdentifier(for: indexPath) else { return nil }
        return UserDetailViewController(coder: coder, user: item.user)
    }
    
    
}
