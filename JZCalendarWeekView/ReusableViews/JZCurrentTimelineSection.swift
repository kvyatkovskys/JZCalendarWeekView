//
//  JZCurrentTimelineSection.swift
//  JZCalendarWeekView
//
//  Created by Jeff Zhang on 28/3/18.
//  Copyright © 2018 Jeff Zhang. All rights reserved.
//

import UIKit

open class JZCurrentTimelineSection: UICollectionReusableView {
    
    public var halfBallView = UIView()
    public var lineView = UIView()
    public var showDate = false
    let halfBallSize: CGFloat = 10
    
    var reloadTimer : Timer?
    
    public override init(frame: CGRect) {
        super.init(frame: .zero)
        isOpaque = true
        layer.isDoubleSided = false
        setupUI()
    }
    
    deinit {
        self.reloadTimer?.invalidate()
    }
    
    let timeLabel: UILabel = {
        let lbl = UILabel()
        lbl.font = UIFont(name: "HelveticaNeue", size: 12)
        lbl.layer.cornerRadius = 3
        lbl.clipsToBounds = true
        lbl.textAlignment = .right
        lbl.textColor = JZWeekViewColors.today
        lbl.backgroundColor = .white
        return lbl
    }()
    
    @objc private func updateTime() {
        let formatter = DateFormatter()
        formatter.dateFormat = "hh:mm a"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        timeLabel.text = formatter.string(from: Date())
    }
    
    func updateUI() {
        reloadTimer?.invalidate()
        if showDate {
            reloadTimer = Timer.scheduledTimer(timeInterval: 1,
                                               target: self,
                                               selector: #selector(updateTime),
                                               userInfo: nil,
                                               repeats: true)
            updateTime()
            clipsToBounds = false
            timeLabel.isHidden = false
        } else {
            clipsToBounds = true
            timeLabel.isHidden = true
        }
    }
    
    open func setupUI() {
        addSubviews([halfBallView, lineView, timeLabel])
        
        halfBallView.snp.remakeConstraints {
            $0.size.equalTo(halfBallSize)
            $0.left.equalToSuperview()
        }
        
        timeLabel.snp.remakeConstraints { (maker) in
            maker.right.equalTo(halfBallView.snp.right)
            maker.top.bottom.equalToSuperview()
            maker.width.equalTo(60)
        }
        
        lineView.snp.remakeConstraints { (maker) in
            maker.left.right.equalToSuperview()
            maker.centerY.equalToSuperview()
            maker.height.equalTo(1).priority(.low)
        }
        updateUI()
        
        halfBallView.backgroundColor = JZWeekViewColors.today
        halfBallView.layer.cornerRadius = halfBallSize/2
        lineView.backgroundColor = JZWeekViewColors.today
        backgroundColor = .clear
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}
