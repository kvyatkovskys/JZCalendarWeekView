//
//  JZBaseEvent.swift
//  JZCalendarWeekView
//
//  Created by Jeff Zhang on 29/3/18.
//  Copyright © 2018 Jeff Zhang. All rights reserved.
//
import UIKit

open class JZBaseEvent: NSObject, NSCopying {

    /// Unique id for each event to identify an event, especially for cross-day events
    public var id: String
    public var isPlaceholder: Bool = false
    public var startDate: Date
    public var endDate: Date

    // If a event crosses two days, it should be devided into two events but with different intraStartDate and intraEndDate
    // eg. startDate = 2018.03.29 14:00 endDate = 2018.03.30 03:00, then two events should be generated: 1. 0329 14:00 - 23:59(IntraEnd) 2. 0330 00:00(IntraStart) - 03:00
    public var intraStartDate: Date
    public var intraEndDate: Date
    /// index of selected provider
    public var resourceIndex: Int?
    public var appointmentRequest: Any?
    public var appointment: Any?
    public var status: Any?
    
    public var isAppointmentRequestItemEvent: Bool {
        appointmentRequest != nil
    }
    
    public var isAppointmentEvent: Bool {
        appointment != nil
    }

    public init(id: String = "",
                startDate: Date,
                endDate: Date,
                resourceIndex: Int? = nil) {
        self.id = id
        self.startDate = startDate
        self.endDate = endDate
        self.intraStartDate = startDate
        self.intraEndDate = endDate
        self.resourceIndex = resourceIndex
    }

    // Must be overrided
    // Shadow copy is enough for JZWeekViewHelper to create multiple events for cross-day events
    open func copy(with zone: NSZone? = nil) -> Any {
        JZBaseEvent(id: id, startDate: startDate, endDate: endDate, resourceIndex: resourceIndex)
    }
}

public extension JZBaseEvent {
    
    var stubImage: UIImage? {
        UIImage(named: "background_request")
    }

    var stubColor: UIColor {
        if let img = stubImage {
            return UIColor(patternImage: img)
        } else {
            return UIColor(hexString: "#fdfec8")
        }
    }
    
}
