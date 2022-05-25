//
//  JZRestrictedAreaView.swift
//  Symplast
//
//  Created by Aleksei Konshin on 14.02.2020.
//
import UIKit

/// Gray colored area view
open class JZRestrictedAreaView: UICollectionReusableView, TimerThrottle {
    
    private let symplastLightGrayColor = UIColor(hexString: "#C8C8C8")

    private let textLabel: UILabel = {
        let view = UILabel()
        view.textColor = .white
        view.numberOfLines = 0
        view.lineBreakMode = .byWordWrapping
        view.font = .systemFont(ofSize: 15, weight: .medium)
        view.layer.cornerRadius = 4
        view.layer.masksToBounds = true
        view.textAlignment = .center
        view.isUserInteractionEnabled = true
        return view
    }()

    private lazy var tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))

    private let insets: CGFloat = 20

    private var transparentTimer: Timer?

    // MARK: - lifecycle
    override init(frame: CGRect) {
        super.init(frame: frame)
        layer.isDoubleSided = false
        setup()
    }

    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    open override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
         !textLabel.isHidden && textLabel.isUserInteractionEnabled && textLabel.frame.contains(point)
    }

    // MARK: - functions
    private func setup() {
        backgroundColor = symplastLightGrayColor.withAlphaComponent(0.3)
        isUserInteractionEnabled = true
        layer.borderColor = UIColor(hexString: "#FF6A6A").cgColor
        textLabel.addGestureRecognizer(tap)

        addSubview(textLabel)
        clipsToBounds = true
        
        textLabel.snp.remakeConstraints {
            $0.leading.trailing.equalToSuperview().inset(20)
            $0.centerY.equalToSuperview()
            $0.height.greaterThanOrEqualTo(30)
        }
    }

    private func setTransparent(_ transparent: Bool) {
        textLabel.isUserInteractionEnabled = !transparent
        UIView.animate(withDuration: 0.2) {
            self.alpha = transparent ? 0 : 1
        }
    }

    open override func prepareForReuse() {
        super.prepareForReuse()

        setTransparent(false)
        stopTimer("label_cell_event")
    }

    @objc private func handleTap() {
        guard !textLabel.isHidden else { return }

        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        setTransparent(true)
        startTimer("label_cell_event", interval: 3) { [weak self] in
            self?.setTransparent(false)
        }
    }

    open override func apply(_ layoutAttributes: UICollectionViewLayoutAttributes) {
        super.apply(layoutAttributes)
        
        guard let attributes = layoutAttributes as? JZTemplatesLayoutAttributes else {
            backgroundColor = symplastLightGrayColor.withAlphaComponent(0.2)
            textLabel.isHidden = true
            layer.borderWidth = 0
            isUserInteractionEnabled = false
            return
        }

        if attributes.text?.isEmpty == false {
            textLabel.text = attributes.text
            textLabel.isHidden = false
            layer.borderWidth = 2
            isUserInteractionEnabled = true
        } else {
            textLabel.isHidden = true
            layer.borderWidth = 0
            isUserInteractionEnabled = false
        }

        if let color = attributes.backgroundColor {
            textLabel.backgroundColor = color.withAlphaComponent(0.9)
            
            if attributes.isUnavailability ?? false {
                backgroundColor = symplastLightGrayColor.withAlphaComponent(0.2)
                layer.borderColor = color.cgColor
            } else if attributes.isScheduleTemplate ?? false {
                backgroundColor = color.withAlphaComponent(0.2)
                layer.borderColor = UIColor.clear.cgColor
            } else {
                backgroundColor = symplastLightGrayColor.withAlphaComponent(0.2)
                layer.borderColor = UIColor.clear.cgColor
            }
        } else {
            backgroundColor = symplastLightGrayColor.withAlphaComponent(0.2)
            textLabel.backgroundColor = UIColor.clear
            layer.borderColor = UIColor.clear.cgColor
        }
    }

}
