//
//  JZCurrentTimelinePage.swift
//  JZCalendarWeekView
//
//  Created by Jeff Zhang on 25/8/18.
//  Copyright © 2018 Jeff Zhang. All rights reserved.
//

import UIKit

open class JZCurrentTimelinePage: UICollectionReusableView {

    public var ballView = UIView()
    public var lineView = UIView()
    let ballSize: CGFloat = 6

    public override init(frame: CGRect) {
        super.init(frame: .zero)
        isOpaque = true
        layer.isDoubleSided = false
        setupUI()
    }

    open func setupUI() {
        addSubviews([ballView, lineView])
        ballView.snp.remakeConstraints {
            $0.left.equalToSuperview().offset(2)
            $0.size.equalTo(ballSize)
        }
        lineView.snp.remakeConstraints {
            $0.left.right.equalToSuperview()
            $0.height.equalTo(1)
        }
        
        ballView.backgroundColor = JZWeekViewColors.appleCalendarRed
        ballView.layer.cornerRadius = ballSize/2
        ballView.isHidden = true
        lineView.backgroundColor = JZWeekViewColors.appleCalendarRed
    }

    open func updateView(needShowBallView: Bool) {
        ballView.isHidden = !needShowBallView
    }

    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

}
