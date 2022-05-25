//
//  JZOutsideCellDecorationView.swift
//  Symplast
//
//  Created by Aleksei Konshin on 04.02.2020.
//

import UIKit

open class JZOutsideCellDecorationView: UICollectionReusableView {

    override init(frame: CGRect) {
        super.init(frame: frame)

        setup()
    }

    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup() {
        isOpaque = true
        layer.isDoubleSided = false
        clipsToBounds = true
        layer.cornerRadius = 4
        layer.borderColor = UIColor(hexString: "#FAB353").cgColor
    }

    open override func apply(_ layoutAttributes: UICollectionViewLayoutAttributes) {
        super.apply(layoutAttributes)

        if let style = layoutAttributes as? JZStyleLayoutAttributes, let color = style.backgroundColor {
            var white: CGFloat = 0
            color.getWhite(&white, alpha: nil)
            if white > 0.97 {
                layer.borderWidth = 2
            } else {
                layer.borderWidth = 0
            }
            backgroundColor = color
        } else {
            backgroundColor = UIColor(hexString: "#FAB353")
        }
    }

}
