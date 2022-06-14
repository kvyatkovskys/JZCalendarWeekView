//
//  JZPlaceholderEvent.swift
//  Symplast
//
//  Created by Sergei Kviatkovskii on 07.09.2021.
//
import UIKit

open class JZPlaceholderEvent: UICollectionViewCell {

    public var didTap: (() -> Void)?

    public override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor(hexString: "#C7C7CC")
        isOpaque = true
        layer.isDoubleSided = false

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(tapOnPlaceholder))
        addGestureRecognizer(tapGesture)
    }

    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func tapOnPlaceholder() {
        didTap?()
    }

}
