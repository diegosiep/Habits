//
//  BadgeCollectionReusableView.swift
//  Habits
//
//  Created by Diego Sierra on 13/02/23.
//

import UIKit

class BadgeCollectionReusableView: UICollectionReusableView {
    var badgeIcon: UILabel = {
        let label = UILabel()
        
        return label
    }()
    
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
        
    }
    
    override var frame: CGRect {
        didSet {
            configureBorder()
        }
    }
    
    private func setupView() {
        addSubview(badgeIcon)
        backgroundColor = .systemGreen
        badgeIcon.translatesAutoresizingMaskIntoConstraints = true
        
    }
    
    private func configureBorder() {
        let radius = bounds.width / 2.0
        layer.cornerRadius = radius
        
    }
}

