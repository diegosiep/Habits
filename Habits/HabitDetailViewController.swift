//
//  HabitDetailViewController.swift
//  Habits
//
//  Created by Diego Sierra on 14/01/23.
//

import UIKit


class HabitDetailViewController: UIViewController {
    typealias DataSourceType = UICollectionViewDiffableDataSource<ViewModel.Section, ViewModel.Item>
    
    //  Keep track of async tasks so they can be cancelled when appropriate
    var habitStatisticsRequestTask: Task<Void, Never>? = nil
    deinit { habitStatisticsRequestTask?.cancel() }
    
    enum ViewModel {
        enum Section: Hashable {
            case leaders(count: Int)
            case remaining
        }
        
        enum Item: Comparable, Hashable {
            static func < (lhs: HabitDetailViewController.ViewModel.Item, rhs: HabitDetailViewController.ViewModel.Item) -> Bool {
                switch(lhs, rhs) {
                case (single(let lCount), single(let rCount)):
                    return lCount.count < rCount.count
               
                }
            }
            case single(_ stat: UserCounts)
         
        }
    }
    
    struct Model {
        var habitStatistics: HabitStatistics?
        var userCounts: [UserCounts] {
            habitStatistics?.userCounts ?? []
        }
    }
    
    var dataSourceType: DataSourceType!
    var model = Model()
    
    @IBOutlet var habitNameLabel: UILabel!
    @IBOutlet var categoryLabel: UILabel!
    @IBOutlet var infoLabel: UILabel!
    @IBOutlet var collectionView: UICollectionView!
    
    
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        habitNameLabel.text = habit.name
        categoryLabel.text = habit.category.name
        infoLabel.text = habit.info
        dataSourceType = createDataSource()
        collectionView.dataSource = dataSourceType
        collectionView.collectionViewLayout = createLayout()
        
        update()
        
    }
    
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
    
    var habit: Habit!
    
    init?(coder: NSCoder, habit: Habit) {
        super.init(coder: coder)
        self.habit = habit
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func update() {
        habitStatisticsRequestTask?.cancel()
        habitStatisticsRequestTask = Task {
            if let statistics = try? await HabitsStatisticsRequest(habitNames: [habit.name]).send(), statistics.count > 0 {
                self.model.habitStatistics = statistics[0]
            } else {
                self.model.habitStatistics = nil
            }
            self.updateCollectionView()
            
            habitStatisticsRequestTask = nil
            
        }
    }

    func updateCollectionView() {
    
        let items = (self.model.habitStatistics?.userCounts.map { ViewModel.Item.single($0)
        } ?? []).sorted(by: >)
        
        dataSourceType.applySnapshotUsing(sectionIDs: [.remaining], itemsBySection: [.remaining: items])
        
    }
    
    func createDataSource() -> DataSourceType {
        return DataSourceType(collectionView: collectionView) { (collectionView, indexPath, grouping) -> UICollectionViewCell? in
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "UserCount", for: indexPath) as! UICollectionViewListCell
            
            var content = UIListContentConfiguration.subtitleCell()
            content.prefersSideBySideTextAndSecondaryText = true
            switch grouping {
            case .single(let userStat):
                content.text = userStat.user.name
                content.secondaryText = "\(userStat.count)"
                content.secondaryTextProperties.font = .preferredFont(forTextStyle: .body)
              
                
            }
            cell.contentConfiguration = content
            
            return cell
        }
    }
    
    func createLayout() -> UICollectionViewCompositionalLayout {
        let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .fractionalHeight(1))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        item.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 12)
        
        let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(44))
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
        
        let section = NSCollectionLayoutSection(group: group)
        
        section.contentInsets = NSDirectionalEdgeInsets(top: 20, leading: 0, bottom: 20, trailing: 0)
        
        return UICollectionViewCompositionalLayout(section: section)
    }
    
    var updateTimer: Timer?
    
    

    
    
}
