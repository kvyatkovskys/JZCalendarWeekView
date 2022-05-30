//
//  JZCalendarModel.swift
//  JZCalendarWeekView
//
//  Created by Sergei Kviatkovskii on 5/30/22.
//  Copyright © 2022 Jeff Zhang. All rights reserved.
//

import UIKit

final public class ZoomConfiguration: NSObject, NSCoding {

    public enum ZoomLevel: Int {
        case min, `default`, max

        public var image: UIImage? {
            switch self {
            case .min, .default:
                return UIImage(named: "ic_zoom_max")?.withRenderingMode(.alwaysTemplate)
            case .max:
                return UIImage(named: "ic_zoom_min")?.withRenderingMode(.alwaysTemplate)
            }
        }

        public var value: (division: JZHourGridDivision, height: CGFloat) {
            switch self {
            case .min:
                return (.minutes_30, 75)
            case .default:
                return (.minutes_15, 150)
            case .max:
                return (.minutes_5, 300)
            }
        }

        public var durationPlaceholder: TimeInterval {
            switch self {
            case .min:
                return TimeInterval(30 * 60)
            case .default:
                return TimeInterval(15 * 60)
            case .max:
                return TimeInterval(5 * 60)
            }
        }

        // 🤔🤔🤔🤔🤔🤔🤔🤔🤔
        public var offset: Int {
            switch self {
            case .min:
                return 1800
            case .default:
                return 900
            case .max:
                return 300
            }
        }
    }

    public let userId: Int
    public let zoomLevel: ZoomLevel

    public init(userId: Int, zoomLevel: ZoomLevel) {
        self.userId = userId
        self.zoomLevel = zoomLevel
        super.init()
    }

    required public init(coder aDecoder: NSCoder) {
        userId = aDecoder.decodeInteger(forKey: "userId")
        let level = aDecoder.decodeInteger(forKey: "zoomLevel")
        zoomLevel = ZoomLevel(rawValue: level) ?? .default
    }

    public func encode(with aCoder: NSCoder) {
        aCoder.encode(userId, forKey: "userId")
        aCoder.encode(zoomLevel.rawValue, forKey: "zoomLevel")
    }
}

final public class TimelineConfiguration: NSObject, NSCoding {

    public enum TimelineType: Int {
        case short, full

        public var image: UIImage? {
            switch self {
            case .full:
                return UIImage(named: "ic_timeline_less")
            case .short:
                return UIImage(named: "ic_timeline_more")
            }
        }

        public var title: String {
            switch self {
            case .full:
                return "24"
            case .short:
                return "12"
            }
        }

        public var timeRange: ClosedRange<Int> {
            switch self {
            case .full:
                return 0...24
            case .short:
                return 0...12
            }
        }

        public var offset: Int {
            switch self {
            case .short:
                return 6
            case .full:
                return 0
            }
        }

        public var fullTitle: String {
            switch self {
            case .full:
                return "View 12 hours per day"
            case .short:
                return "View 24 hours per day"
            }
        }
    }

    public let userId: Int
    public let timelineType: TimelineType

    public init(userId: Int, timelineType: TimelineType) {
        self.userId = userId
        self.timelineType = timelineType
        super.init()
    }

    required public init(coder aDecoder: NSCoder) {
        userId = aDecoder.decodeInteger(forKey: "userId")
        let type = aDecoder.decodeInteger(forKey: "timelineType")
        timelineType = TimelineType(rawValue: type) ?? .full
    }

    public func encode(with aCoder: NSCoder) {
        aCoder.encode(userId, forKey: "userId")
        aCoder.encode(timelineType.rawValue, forKey: "timelineType")
    }
}

extension TimelineConfiguration {
    static func == (lhs: TimelineConfiguration, rhs: TimelineConfiguration) -> Bool {
        return lhs.userId == rhs.userId
    }
}

private enum AssociatedKeys {
    static var timer: UInt8 = 0
}

/// Any object can start and stop delayed action for key
protocol TimerThrottle: AnyObject {}

extension TimerThrottle {

    private var timers: [String: Timer] {
        get { return objc_getAssociatedObject(self, &AssociatedKeys.timer) as? [String: Timer] ?? [:] }
        set { objc_setAssociatedObject(self, &AssociatedKeys.timer, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    func stopTimer(_ key: String = "Timer") {
        timers[key]?.invalidate()
        timers[key] = nil
    }

    func startTimer(_ key: String = "Timer", interval: TimeInterval = 0.5, repeats: Bool = false, action: @escaping () -> Void) {
        stopTimer(key)

        timers[key] = Timer.scheduledTimer(withTimeInterval: interval, repeats: repeats, block: { _ in
            action()
        })
    }

}

public enum ScrollPosition: Int {
    case top, centerVertically
}

public struct RestrictedArea: Hashable, Equatable {
    public var timeRange: Range<TimeInterval>
    var title: String?
    var backgroundColor: UIColor?
    var isUnavailability: Bool?
    var isScheduleTemplate: Bool?
    var locationId: Int?
    
    public init(timeRange: Range<TimeInterval>,
                title: String? = nil,
                backgroundColor: UIColor? = nil,
                isUnavailability: Bool? = nil,
                isScheduleTemplate: Bool? = nil,
                locationId: Int? = nil) {
        self.timeRange = timeRange
        self.title = title
        self.backgroundColor = backgroundColor
        self.isUnavailability = isUnavailability
        self.isScheduleTemplate = isScheduleTemplate
        self.locationId = locationId
    }

    public func updated(timeRange: Range<TimeInterval>) -> RestrictedArea {
        var item = self
        item.timeRange = timeRange
        return item
    }
}
