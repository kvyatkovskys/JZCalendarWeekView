//
//  JZRowHeader.swift
//  JZCalendarWeekView
//
//  Created by Jeff Zhang on 28/3/18.
//  Copyright © 2018 Jeff Zhang. All rights reserved.
//

import UIKit

/// Header for each row (every hour) in collectionView (Supplementary View)
open class JZRowHeader: UICollectionReusableView {

    public var didTap: ((Date?) -> Void)?
    public var lblTime = UILabel()
    public var dateFormatter = DateFormatter()
    
    private var date: Date?

    public override init(frame: CGRect) {
        super.init(frame: .zero)
        setupLayout()
        setupBasic()
        isOpaque = true
        layer.isDoubleSided = false
        let tap = UITapGestureRecognizer(target: self, action: #selector(tapRowHeader))
        addGestureRecognizer(tap)
    }
    
    @objc private func tapRowHeader() {
        didTap?(date)
    }

    private func setupLayout() {
        addSubview(lblTime)
        // This one is used to support iPhone X Landscape state because of notch status bar
        // If you want to customise the RowHeader, please keep the similar contraints with this one (vertically center and a value to trailing anchor)
        // If you want to change rowHeaderWidth and font size, you can change the trailing value to make it horizontally center in normal state, but keep the trailing anchor
        lblTime.setAnchorCenterVerticallyTo(view: self, trailingAnchor: (self.trailingAnchor, -5))
    }

    open func setupBasic() {
        // Hide all content when colum header height equals 0
        self.clipsToBounds = true
        dateFormatter.dateFormat = "hh a"
        lblTime.textColor = JZWeekViewColors.rowHeaderTime
        lblTime.font = UIFont.systemFont(ofSize: 12)
    }

    public func updateView(date: Date) {
        self.date = date
        let s = dateFormatter.string(from: date)
        if (s == "12 PM") {
            lblTime.text = "Noon"
        } else {
            lblTime.text = s.replacingOccurrences(of: "^0+", with: "", options: .regularExpression)
        }
    }

    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

}
