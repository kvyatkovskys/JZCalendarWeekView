//
//  JZWeekViewFlowLayout.swift
//  JZCalendarWeekView
//
//  Created by Jeff Zhang on 28/3/18.
//  Inspired and followed by WRCalendarView (https://github.com/wayfinders/WRCalendarView)
//

import UIKit
import SnapKit

public protocol WeekViewFlowLayoutDelegate: AnyObject {
    /// Get the date for given section
    func collectionView(_ collectionView: UICollectionView, layout: JZWeekViewFlowLayout, dayForSection section: Int) -> Date
    /// Get the start time for given item indexPath
    func collectionView(_ collectionView: UICollectionView, layout: JZWeekViewFlowLayout, startTimeForItemAtIndexPath indexPath: IndexPath) -> Date
    /// Get the end time for given item indexPath
    func collectionView(_ collectionView: UICollectionView, layout: JZWeekViewFlowLayout, endTimeForItemAtIndexPath indexPath: IndexPath) -> Date
    /// TODO: Get the cell type for given item indexPath (Used for different cell types in the future)
    func collectionView(_ collectionView: UICollectionView, layout: JZWeekViewFlowLayout, cellTypeForItemAtIndexPath indexPath: IndexPath) -> String
    /// Get Resource Index for given item indexPath
    func collectionView(_ collectionView: UICollectionView, layout: JZWeekViewFlowLayout, resourceIndexForItemAtIndexPath indexPath: IndexPath) -> Int
    /// Get Resource Count
    func collectionView(_ collectionView: UICollectionView, resourceCountWithLayout: JZWeekViewFlowLayout) -> Int
    /// Get color for outside screen decoration
    func collectionView(_ collectionView: UICollectionView, colorForOutsideScreenDecorationViewAt indexPath: IndexPath) -> UIColor?
    /// Get color for outside screen decoration
    func collectionView(_ collectionView: UICollectionView, restrictedAreasFor section: Int, resourceIndex: Int) -> Set<RestrictedArea>?
    /// Get number of zones in section (number of providers as common)
    func collectionView(_ collectionView: UICollectionView, numberOfRestrictedLinesIn section: Int) -> Int
    
    func collectionView(_ collectionView: UICollectionView, layout: JZWeekViewFlowLayout, zIndexForItemAtIndexPath indexPath: IndexPath) -> Int
}

open class UICollectionViewLayoutAttributesResource: UICollectionViewLayoutAttributes {
    var resourceIndex: Int = 0
}

open class JZWeekViewFlowLayout: UICollectionViewFlowLayout {
    
    // UI params
    public var rowHeaderWidth: CGFloat!
    var columnHeaderHeight: CGFloat!
    var allDayHeaderHeight: CGFloat = 0
    public var sectionWidth: CGFloat!
    public var subsectionWidth: CGFloat!
    public var hourGridDivision: JZHourGridDivision!
    var minuteHeight: CGFloat { hourHeightForZoomLevel / 60 }
    var sectionHeight = UIScreen.main.bounds.height
    open var defaultRowHeaderWidth: CGFloat { 44 }
    open var defaultColumnHeaderHeight: CGFloat { 44 }
    open var defaultHourGridDivision: JZHourGridDivision { .minutes_15 }
    // You can change following constants
    open var defaultGridThickness: CGFloat {
#if targetEnvironment(macCatalyst)
        return 1
#else
        return 0.5
#endif
    }
    open var defaultRowHeaderDividerHeight: CGFloat { 25 }
    open var defaultCurrentTimeLineHeight: CGFloat { 10 }
    open var defaultAllDayOneLineHeight: CGFloat { 30 }
    /// Margin for the flowLayout in collectionView
    open var contentsMargin: UIEdgeInsets { UIEdgeInsets(top: 10, left: 0, bottom: 10, right: 0) }
    open var itemMargin: UIEdgeInsets { UIEdgeInsets(top: 1, left: 1, bottom: 1, right: 1) }
    /// weekview contentSize height
    open var maxSectionHeight: CGFloat {
        let height = hourHeightForZoomLevel * CGFloat(timelineType.duration) // statement too long for Swift 5 compiler
        return columnHeaderHeight + height + contentsMargin.top + contentsMargin.bottom + allDayHeaderHeight
    }
    
    let minOverlayZ = 1000  // Allows for 900 items in a section without z overlap issues
    let minCellZ = 100      // Allows for 100 items in a section's background
    let minBackgroundZ = 0
    
    // Attributes
    var cachedDayDateComponents = [Int: DateComponents]()
    var cachedCurrentTimeComponents = [Int: DateComponents]()
    var cachedStartTimeDateComponents = [IndexPath: DateComponents]()
    var cachedEndTimeDateComponents = [IndexPath: DateComponents]()
    var registeredDecorationClasses = [String: AnyClass]()
    var needsToPopulateAttributesForAllSections = true
    
    var currentZoom = ZoomConfiguration.ZoomLevel.default
    var timelineType = TimelineConfiguration.TimelineType.full
    var didRestrictScrollOffset: ((JZBaseWeekView.RestrictOffsetY?) -> Void)?
    
    var currentTimeComponents: DateComponents {
        if cachedCurrentTimeComponents[0] == nil {
            cachedCurrentTimeComponents[0] = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute],
                                                                             from: Date())
        }
        return cachedCurrentTimeComponents[0]!
    }
    
    var hourHeightForZoomLevel: CGFloat {
        let value = currentZoom.value.height * CGFloat(timelineType.duration)
        guard value > sectionHeight else {
            return sectionHeight / CGFloat(timelineType.duration)
        }
        
        return currentZoom.value.height
    }
    
    public var isPeekView: Bool = false
    
    private var numberOfDivisions: Int {
        let hourInMinutes = 60
        return hourInMinutes / hourGridDivision.rawValue
    }
    
    private var divisionHeight: CGFloat {
        hourHeightForZoomLevel / CGFloat(numberOfDivisions)
    }
    
    var timeRangeLowerOffset: CGFloat {
        CGFloat(timelineType.timeRange.lowerBound) * hourHeightForZoomLevel
    }
    
    typealias AttDic = [IndexPath: UICollectionViewLayoutAttributes]
    
    var allAttributes = [UICollectionViewLayoutAttributes]()
    var itemAttributes = AttDic()
    var columnHeaderAttributes = AttDic()
    var columnHeaderBackgroundAttributes = AttDic()
    var rowHeaderAttributes = AttDic()
    var rowHeaderBackgroundAttributes = AttDic()
    var verticalGridlineAttributes = AttDic()
    var horizontalGridlineAttributes = AttDic()
    var cornerHeaderAttributes = AttDic()
    var currentTimeLineAttributes = AttDic()
    private var outscreenCellsAttributes = AttDic()
    private var restrictedAreasAttributes = AttDic()
    private var rowHeaderDividerHorizontalAttributes = AttDic()
    
    var allDayHeaderAttributes = AttDic()
    var allDayHeaderBackgroundAttributes = AttDic()
    var allDayCornerAttributes = AttDic()
    
    weak var delegate: WeekViewFlowLayoutDelegate?
    private var minuteTimer: Timer?
    
    // Default UI parameters Initializer
    override init() {
        super.init()
        
        setupUIParams()
        initializeMinuteTick()
        setupOutsideScreenDecorations()
        setupRestrictedAreasDecorations()
        setupRowHeaderDivider()
    }
    
    // Custom UI parameters Initializer
    public init(hourHeight: CGFloat? = nil,
                rowHeaderWidth: CGFloat? = nil,
                columnHeaderHeight: CGFloat? = nil,
                hourGridDivision: JZHourGridDivision? = nil) {
        super.init()
        
        setupUIParams(hourHeight: hourHeight,
                      rowHeaderWidth: rowHeaderWidth,
                      columnHeaderHeight: columnHeaderHeight,
                      hourGridDivision: hourGridDivision)
        initializeMinuteTick()
        setupOutsideScreenDecorations()
        setupRestrictedAreasDecorations()
        setupRowHeaderDivider()
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        minuteTimer?.invalidate()
    }
    
    private func setupUIParams(hourHeight: CGFloat? = nil,
                               rowHeaderWidth: CGFloat? = nil,
                               columnHeaderHeight: CGFloat? = nil,
                               hourGridDivision: JZHourGridDivision? = nil) {
        self.rowHeaderWidth = rowHeaderWidth ?? defaultRowHeaderWidth
        self.columnHeaderHeight = columnHeaderHeight ?? defaultColumnHeaderHeight
        self.hourGridDivision = hourGridDivision ?? defaultHourGridDivision
    }
    
    private func initializeMinuteTick() {
        minuteTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.minuteTick()
        }
        if let timer = minuteTimer {
            RunLoop.current.add(timer, forMode: .common)
        }
    }
    
    @objc private func minuteTick() {
        cachedCurrentTimeComponents.removeAll()
        invalidateLayout()
    }
    
    // MARK: - UICollectionViewLayout
    override open func prepare(forCollectionViewUpdates updateItems: [UICollectionViewUpdateItem]) {
        invalidateLayoutCache()
        prepare()
        super.prepare(forCollectionViewUpdates: updateItems)
    }
    
    override open func finalizeCollectionViewUpdates() {
        for subview in (collectionView?.subviews ?? []) {
            for decorationViewClass in registeredDecorationClasses.values {
                if subview.isKind(of: decorationViewClass) {
                    subview.removeFromSuperview()
                }
            }
        }
        collectionView?.reloadData()
    }
    
    public func registerDecorationViews(_ viewClasses: [UICollectionReusableView.Type]) {
        viewClasses.forEach {
            self.register($0, forDecorationViewOfKind: $0.className)
        }
    }
    
    override open func register(_ viewClass: AnyClass?, forDecorationViewOfKind elementKind: String) {
        super.register(viewClass, forDecorationViewOfKind: elementKind)
        registeredDecorationClasses[elementKind] = viewClass
    }
    
    override open func prepare() {
        super.prepare()
        
        if needsToPopulateAttributesForAllSections {
            prepareHorizontalTileSectionLayoutForSections(NSIndexSet(indexesIn: NSRange(location: 0, length: collectionView!.numberOfSections)))
            needsToPopulateAttributesForAllSections = false
        }
        
        let needsToPopulateAllAttributes = (allAttributes.count == 0)
        
        if needsToPopulateAllAttributes {
            allAttributes.append(contentsOf: columnHeaderAttributes.values)
            allAttributes.append(contentsOf: columnHeaderBackgroundAttributes.values)
            allAttributes.append(contentsOf: rowHeaderAttributes.values)
            allAttributes.append(contentsOf: rowHeaderBackgroundAttributes.values)
            allAttributes.append(contentsOf: verticalGridlineAttributes.values)
            allAttributes.append(contentsOf: horizontalGridlineAttributes.values)
            allAttributes.append(contentsOf: cornerHeaderAttributes.values)
            allAttributes.append(contentsOf: currentTimeLineAttributes.values)
            allAttributes.append(contentsOf: itemAttributes.values)
            
            allAttributes.append(contentsOf: allDayCornerAttributes.values)
            allAttributes.append(contentsOf: allDayHeaderAttributes.values)
            allAttributes.append(contentsOf: allDayHeaderBackgroundAttributes.values)
            allAttributes.append(contentsOf: outscreenCellsAttributes.values)
            allAttributes.append(contentsOf: restrictedAreasAttributes.values)
            allAttributes.append(contentsOf: rowHeaderDividerHorizontalAttributes.values)
        }
    }
    
    open func prepareHorizontalTileSectionLayoutForSections(_ sectionIndexes: NSIndexSet) {
        guard let collectionView = collectionView,
              collectionView.numberOfSections != 0,
              sectionWidth > 0 else { return }
        
        var attributes =  UICollectionViewLayoutAttributes()
        
        let sectionHeight = (hourHeightForZoomLevel * CGFloat(timelineType.duration)).toDecimal1Value()
        let calendarGridMinY = columnHeaderHeight + contentsMargin.top + allDayHeaderHeight
        let calendarContentMinX = rowHeaderWidth + contentsMargin.left
        let calendarContentMinY = columnHeaderHeight + contentsMargin.top + allDayHeaderHeight
        
        // Current time line
        // TODO: Should improve this method, otherwise every column will display a timeline view
        sectionIndexes.forEach { (section) in
            let sectionMinX = calendarContentMinX + sectionWidth * CGFloat(section)
            let timeY = calendarContentMinY + (CGFloat(currentTimeComponents.hour!).toDecimal1Value() * hourHeightForZoomLevel + CGFloat(currentTimeComponents.minute!) * minuteHeight) - timeRangeLowerOffset
            let currentTimeHorizontalGridlineMinY = (timeY - (defaultGridThickness / 2.0).toDecimal1Value() - defaultCurrentTimeLineHeight/2)
            (attributes, currentTimeLineAttributes) = layoutAttributesForSupplementaryView(at: IndexPath(item: 0, section: section), ofKind: JZSupplementaryViewKinds.currentTimeline, withItemCache: currentTimeLineAttributes)
            attributes.frame = CGRect(x: sectionMinX, y: currentTimeHorizontalGridlineMinY, width: sectionWidth, height: defaultCurrentTimeLineHeight)
            attributes.zIndex = zIndexForElementKind(JZSupplementaryViewKinds.currentTimeline)
        }
        
        // Corner Header
        (attributes, cornerHeaderAttributes) = layoutAttributesForSupplementaryView(at: IndexPath(item: 0, section: 0), ofKind: JZSupplementaryViewKinds.cornerHeader, withItemCache: cornerHeaderAttributes)
        attributes.frame = CGRect(origin: collectionView.contentOffset, size: CGSize(width: rowHeaderWidth, height: columnHeaderHeight))
        attributes.zIndex = zIndexForElementKind(JZSupplementaryViewKinds.cornerHeader)
        
        // Row header
        let rowHeaderMinX = fmax(collectionView.contentOffset.x, 0)
        
        for rowHeaderIndex in timelineType.startRangeOffset {
            (attributes, rowHeaderAttributes) = layoutAttributesForSupplementaryView(at: IndexPath(item: rowHeaderIndex, section: 0), ofKind: JZSupplementaryViewKinds.rowHeader, withItemCache: rowHeaderAttributes)
            let rowHeaderMinY = calendarContentMinY + hourHeightForZoomLevel * CGFloat(rowHeaderIndex) - (hourHeightForZoomLevel / 2.0).toDecimal1Value()
            attributes.frame = CGRect(x: rowHeaderMinX, y: rowHeaderMinY, width: rowHeaderWidth, height: hourHeightForZoomLevel)
            attributes.zIndex = zIndexForElementKind(JZSupplementaryViewKinds.rowHeader)
        }
        
        // Row Header Background
        (attributes, rowHeaderBackgroundAttributes) = layoutAttributesForDecorationView(at: IndexPath(item: 0, section: 0), ofKind: JZDecorationViewKinds.rowHeaderBackground, withItemCache: rowHeaderBackgroundAttributes)
        attributes.frame = CGRect(x: rowHeaderMinX, y: collectionView.contentOffset.y, width: rowHeaderWidth, height: collectionView.frame.height)
        attributes.zIndex = zIndexForElementKind(JZDecorationViewKinds.rowHeaderBackground)
        
        // All-Day header
        let allDayHeaderMinY = fmax(collectionView.contentOffset.y + columnHeaderHeight, columnHeaderHeight)
        
        sectionIndexes.forEach { (section) in
            let sectionMinX = calendarContentMinX + sectionWidth * CGFloat(section)
            
            (attributes, allDayHeaderAttributes) = layoutAttributesForSupplementaryView(at: IndexPath(item: 0, section: section), ofKind: JZSupplementaryViewKinds.allDayHeader, withItemCache: allDayHeaderAttributes)
            attributes.frame = CGRect(x: sectionMinX, y: allDayHeaderMinY,
                                      width: sectionWidth, height: allDayHeaderHeight)
            attributes.zIndex = zIndexForElementKind(JZSupplementaryViewKinds.allDayHeader)
        }
        
        // All-Day header background
        (attributes, allDayHeaderBackgroundAttributes) = layoutAttributesForDecorationView(at: IndexPath(item: 0, section: 0), ofKind: JZDecorationViewKinds.allDayHeaderBackground, withItemCache: allDayHeaderBackgroundAttributes)
        attributes.frame = CGRect(origin: CGPoint(x: collectionView.contentOffset.x,
                                                  y: collectionView.contentOffset.y + columnHeaderHeight),
                                  size: CGSize(width: collectionView.frame.width,
                                               height: allDayHeaderHeight))
        attributes.zIndex = zIndexForElementKind(JZDecorationViewKinds.allDayHeaderBackground)
        
        (attributes, allDayCornerAttributes) = layoutAttributesForDecorationView(at: IndexPath(item: 0, section: 0),  ofKind: JZDecorationViewKinds.allDayCorner, withItemCache: allDayCornerAttributes)
        attributes.frame = CGRect(origin: CGPoint(x: collectionView.contentOffset.x,
                                                  y: collectionView.contentOffset.y + columnHeaderHeight),
                                  size: CGSize(width: rowHeaderWidth, height: allDayHeaderHeight))
        attributes.zIndex = zIndexForElementKind(JZDecorationViewKinds.allDayCorner)
        
        // column header background
        (attributes, columnHeaderBackgroundAttributes) = layoutAttributesForDecorationView(at: IndexPath(item: 0, section: 0), ofKind: JZDecorationViewKinds.columnHeaderBackground, withItemCache: columnHeaderBackgroundAttributes)
        let attributesHeight = columnHeaderHeight + (collectionView.contentOffset.y < 0 ? abs(collectionView.contentOffset.y) : 0)
        attributes.frame = CGRect(origin: collectionView.contentOffset, size: CGSize(width: collectionView.frame.width, height: attributesHeight))
        attributes.zIndex = zIndexForElementKind(JZDecorationViewKinds.columnHeaderBackground)
        
        // Column Header
        let columnHeaderMinY = fmax(collectionView.contentOffset.y, 0.0)
        
        sectionIndexes.forEach { (section) in
            let sectionMinX = calendarContentMinX + sectionWidth * CGFloat(section)
            (attributes, columnHeaderAttributes) = layoutAttributesForSupplementaryView(at: IndexPath(item: 0, section: section), ofKind: JZSupplementaryViewKinds.columnHeader, withItemCache: columnHeaderAttributes)
            attributes.frame = CGRect(x: sectionMinX, y: columnHeaderMinY, width: sectionWidth, height: columnHeaderHeight)
            attributes.zIndex = zIndexForElementKind(JZSupplementaryViewKinds.columnHeader)
            
            layoutVerticalGridLinesAttributes(section: section, sectionX: sectionMinX, calendarGridMinY: calendarGridMinY, sectionHeight: sectionHeight)
            layoutItemsAttributes(section: section, sectionX: sectionMinX, calendarStartY: calendarGridMinY)
        }
        
        if let resCount = delegate?.collectionView(collectionView, resourceCountWithLayout: self), resCount > 1 {
            for resIdx in 0...resCount {
                var attributes = UICollectionViewLayoutAttributes()
                let resourceOffset = nearbyint(subsectionWidth * CGFloat(resIdx)) + calendarContentMinX + sectionWidth * CGFloat(1)
                
                (attributes, verticalGridlineAttributes) = layoutAttributesForDecorationView(at: IndexPath(item: resIdx, section: 0), ofKind: JZDecorationViewKinds.verticalGridline, withItemCache: verticalGridlineAttributes)
                let minX = nearbyint(resourceOffset - defaultGridThickness / 2.0)
                let r = CGRect(x: minX, y: calendarGridMinY,
                               width: defaultGridThickness, height: sectionHeight)
                if !r.isNull {
                    attributes.frame = r
                }
                attributes.zIndex = zIndexForElementKind(JZDecorationViewKinds.verticalGridline)
            }
        }
        
        if !collectionView.isDragging {
            sectionIndexes.forEach { section in
                let linesCount = delegate?.collectionView(collectionView, numberOfRestrictedLinesIn: section) ?? 0
                for lineIdx in 0..<linesCount {
                    let subsectionOffsetMultiplier = UIDevice.current.userInterfaceIdiom == .phone ? 0 : CGFloat(lineIdx)
                    let resourceOffset = nearbyint(subsectionWidth * subsectionOffsetMultiplier) + calendarContentMinX + sectionWidth * CGFloat(section)
                    let minX = nearbyint(resourceOffset)
                    
                    if let areas = delegate?.collectionView(collectionView,
                                                            restrictedAreasFor: section, resourceIndex: lineIdx) {
                        addRestrictedAreasDecorations(resourceIdx: lineIdx,
                                                      section: section,
                                                      minX: minX,
                                                      maxX: minX + subsectionWidth,
                                                      areas: areas)
                    }
                }
            }
        }
        
        layoutHorizontalGridLinesAttributes(calendarStartX: calendarContentMinX, calendarStartY: calendarContentMinY)
    }
    
    // MARK: - Layout Attributes
    func layoutItemsAttributes(section: Int, sectionX: CGFloat, calendarStartY: CGFloat) {
        guard let collectionView = collectionView,
              let resCount = delegate?.collectionView(collectionView, resourceCountWithLayout: self) else { return }
        
        var attributes = UICollectionViewLayoutAttributesResource()
        var sectionItemAttributes = [UICollectionViewLayoutAttributesResource]()
        
        for item in 0..<collectionView.numberOfItems(inSection: section) {
            let itemIndexPath = IndexPath(item: item, section: section)
            
            let itemStartTime = startTimeForIndexPath(itemIndexPath)
            let itemEndTime = endTimeForIndexPath(itemIndexPath)
            let itemResourceIndex = resourceIndexForIndexPath(itemIndexPath)
            let zIndex = zIndexForIndexPath(itemIndexPath)
            let startHourY = CGFloat(itemStartTime.hour!) * hourHeightForZoomLevel
            let startMinuteY = CGFloat(itemStartTime.minute!) * minuteHeight
            var endHourY: CGFloat
            let endMinuteY = CGFloat(itemEndTime.minute!) * minuteHeight

            if itemEndTime.day! != itemStartTime.day! {
                endHourY = CGFloat(Calendar.current.maximumRange(of: .hour)!.count) * hourHeightForZoomLevel + CGFloat(itemEndTime.hour!) * hourHeightForZoomLevel
            } else {
                if itemEndTime.hour! > timelineType.timeRange.upperBound {
                    endHourY = CGFloat(timelineType.timeRange.upperBound) * hourHeightForZoomLevel
                } else {
                    endHourY = CGFloat(itemEndTime.hour!) * hourHeightForZoomLevel
                }
                endHourY -= timeRangeLowerOffset
            }
            
            let widthItem: CGFloat
            if resCount > 1 {
                widthItem = subsectionWidth
            } else {
                widthItem = sectionWidth
            }
            
            let resourceOffset = (subsectionWidth * CGFloat(itemResourceIndex)).toDecimal1Value()
            let itemMinX = (sectionX + itemMargin.left + resourceOffset).toDecimal1Value()
            let itemMinY = (startHourY + startMinuteY + calendarStartY + itemMargin.top).toDecimal1Value()
            let itemMaxX = (itemMinX + (widthItem - (itemMargin.left + itemMargin.right))).toDecimal1Value()
            let itemMaxY = (endHourY + endMinuteY + calendarStartY - itemMargin.bottom).toDecimal1Value()
            
//            if isPlaceholderEventForIndexPath(itemIndexPath) {
//                layoutPlaceholderAttributes(frame: CGRect(x: itemMinX, y: itemMinY,
//                                                          width: widthItem, height: divisionHeight),
//                                            indexPath: itemIndexPath)
//            } else
            if (itemMaxY - itemMinY) > 0 && itemMinY > 0 {
                (attributes, itemAttributes) = layoutAttributesForCell(at: itemIndexPath, withItemCache: itemAttributes)
                attributes.frame = CGRect(x: itemMinX, y: itemMinY,
                                          width: itemMaxX - itemMinX, height: itemMaxY - itemMinY)
                attributes.resourceIndex = itemResourceIndex
                
                if isCalendarBlockForIndexPath(itemIndexPath) {
                    attributes.zIndex = zIndexForElementKind(JZSupplementaryViewKinds.calendarBlockCell,
                                                             withOffset: zIndex)
                } else {
                    attributes.zIndex = zIndexForElementKind(JZSupplementaryViewKinds.eventCell)
                    let insetInsideCell: CGFloat = 20
                    let position: OutscreenDecorationViewPosition
                    if attributes.frame.minY > collectionView.contentOffset.y + collectionView.bounds.height - insetInsideCell {
                        position = .bottom
                    } else if attributes.frame.maxY < collectionView.contentOffset.y + columnHeaderHeight + insetInsideCell {
                        position = .top
                    } else {
                        position = .center
                    }
                    addOutsideScreenDecorationView(indexPath: itemIndexPath,
                                                   minX: itemMinX,
                                                   maxX: itemMaxX,
                                                   position: position)
                }
                sectionItemAttributes.append(attributes)
            }
        }
        
        if resCount == 1 {
            adjustItemsForOverlap(sectionItemAttributes,
                                  inSection: section,
                                  sectionMinX: sectionX,
                                  currentSectionZ: zIndexForElementKind(JZSupplementaryViewKinds.eventCell),
                                  sectionWidth: sectionWidth)
        } else if resCount > 1 {
            for resIdx in 0...resCount {
                let resourceOffset = nearbyint(subsectionWidth * CGFloat(resIdx))
                adjustItemsForOverlap(sectionItemAttributes,
                                      inSection: section,
                                      sectionMinX: sectionX + resourceOffset,
                                      currentSectionZ: zIndexForElementKind(JZSupplementaryViewKinds.eventCell),
                                      resourceIdx: resIdx,
                                      sectionWidth: subsectionWidth)
                
            }
        }
    }
    
    func layoutVerticalGridLinesAttributes(section: Int,
                                           sectionX: CGFloat,
                                           calendarGridMinY: CGFloat,
                                           sectionHeight: CGFloat) {
        var attributes = UICollectionViewLayoutAttributes()
        
        (attributes, verticalGridlineAttributes) = layoutAttributesForDecorationView(at: IndexPath(item: 0, section: section), ofKind: JZDecorationViewKinds.verticalGridline, withItemCache: verticalGridlineAttributes)
        attributes.frame = CGRect(x: (sectionX - defaultGridThickness / 2.0).toDecimal1Value(),
                                  y: calendarGridMinY,
                                  width: defaultGridThickness, height: sectionHeight)
        attributes.zIndex = zIndexForElementKind(JZDecorationViewKinds.verticalGridline)
    }
    
    func layoutHorizontalGridLinesAttributes(calendarStartX: CGFloat, calendarStartY: CGFloat) {
        var horizontalGridlineIndex = 0
        let calendarGridWidth = collectionViewContentSize.width - rowHeaderWidth - contentsMargin.left - contentsMargin.right
        var attributes = UICollectionViewLayoutAttributes()
        
        for hour in timelineType.startRangeOffset {
            (attributes, horizontalGridlineAttributes) = layoutAttributesForDecorationView(at: IndexPath(item: horizontalGridlineIndex, section: 0), ofKind: JZDecorationViewKinds.horizontalGridline, withItemCache: horizontalGridlineAttributes)
            let horizontalGridlineXOffset = calendarStartX
            let horizontalGridlineMinX = fmax(horizontalGridlineXOffset, collectionView!.contentOffset.x + horizontalGridlineXOffset)
            let horizontalGridlineMinY = (calendarStartY + (hourHeightForZoomLevel * CGFloat(hour))) - (defaultGridThickness / 2.0).toDecimal1Value()
            let horizontalGridlineWidth = fmin(calendarGridWidth, collectionView!.frame.width)
            
            attributes.frame = CGRect(x: horizontalGridlineMinX, y: horizontalGridlineMinY,
                                      width: horizontalGridlineWidth, height: defaultGridThickness)
            attributes.zIndex = zIndexForElementKind(JZDecorationViewKinds.horizontalGridline)
            horizontalGridlineIndex += 1
            
            if hourGridDivision.rawValue > 0 {
                horizontalGridlineIndex = drawHourDividersAtGridLineIndex(horizontalGridlineIndex,
                                                                          hour: hour,
                                                                          startX: horizontalGridlineMinX,
                                                                          startY: horizontalGridlineMinY,
                                                                          gridlineWidth: horizontalGridlineWidth)
            }
        }
    }
    
    func drawHourDividersAtGridLineIndex(_ gridlineIndex: Int, hour: Int, startX calendarStartX: CGFloat,
                                         startY calendarStartY: CGFloat, gridlineWidth: CGFloat) -> Int {
        var _gridlineIndex = gridlineIndex
        var attributes = UICollectionViewLayoutAttributes()
        
        for division in 1..<numberOfDivisions {
            let horizontalGridlineIndexPath = IndexPath(item: _gridlineIndex, section: 0)
            
            (attributes, horizontalGridlineAttributes) = layoutAttributesForDecorationView(at: horizontalGridlineIndexPath, ofKind: JZDecorationViewKinds.horizontalGridline, withItemCache: horizontalGridlineAttributes)
            let horizontalGridlineMinY = (calendarStartY + (divisionHeight * CGFloat(division)) - (defaultGridThickness / 2.0)).toDecimal1Value()
            attributes.frame = CGRect(x: calendarStartX, y: horizontalGridlineMinY, width: gridlineWidth, height: defaultGridThickness)
            attributes.alpha = 0.3
            attributes.zIndex = zIndexForElementKind(JZDecorationViewKinds.horizontalGridline)
            
            _gridlineIndex += 1
            
            layoutRowDividerHorizontalAttributes(startX: calendarStartX - rowHeaderWidth,
                                                 startY: horizontalGridlineMinY,
                                                 division: division,
                                                 indexPath: horizontalGridlineIndexPath)
            
        }
        return _gridlineIndex
    }
    
    override open var collectionViewContentSize: CGSize {
        CGSize(width: rowHeaderWidth + sectionWidth * CGFloat(collectionView!.numberOfSections),
               height: maxSectionHeight)
    }
    
    // MARK: - Layout
    override open func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        itemAttributes[indexPath]
    }
    
    override open func layoutAttributesForSupplementaryView(ofKind elementKind: String, at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        switch elementKind {
        case JZSupplementaryViewKinds.columnHeader:
            return columnHeaderAttributes[indexPath]
        case JZSupplementaryViewKinds.rowHeader:
            return rowHeaderAttributes[indexPath]
        case JZSupplementaryViewKinds.cornerHeader:
            return cornerHeaderAttributes[indexPath]
        case JZSupplementaryViewKinds.allDayHeader:
            return allDayHeaderAttributes[indexPath]
        case JZSupplementaryViewKinds.currentTimeline:
            return currentTimeLineAttributes[indexPath]
        default:
            return nil
        }
    }
    
    override open func layoutAttributesForDecorationView(ofKind elementKind: String, at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        switch elementKind {
        case JZDecorationViewKinds.verticalGridline:
            return verticalGridlineAttributes[indexPath]
        case JZDecorationViewKinds.horizontalGridline:
            return horizontalGridlineAttributes[indexPath]
        case JZDecorationViewKinds.rowHeaderBackground:
            return rowHeaderBackgroundAttributes[indexPath]
        case JZDecorationViewKinds.columnHeaderBackground:
            return columnHeaderBackgroundAttributes[indexPath]
        case JZDecorationViewKinds.allDayHeaderBackground:
            return allDayHeaderBackgroundAttributes[indexPath]
        case JZDecorationViewKinds.allDayCorner:
            return allDayCornerAttributes[indexPath]
        case JZDecorationViewKinds.outscreenCell:
            return outscreenCellsAttributes[indexPath]
        case JZDecorationViewKinds.restrictedArea:
            return restrictedAreasAttributes[indexPath]
        case JZDecorationViewKinds.rowHeaderDivider:
            return rowHeaderDividerHorizontalAttributes[indexPath]
        default:
            return nil
        }
    }
    
    // MARK: - Layout
    func layoutAttributesForCell(at indexPath: IndexPath, withItemCache itemCache: AttDic) -> (UICollectionViewLayoutAttributesResource, AttDic) {
        var layoutAttributes = itemCache[indexPath] as? UICollectionViewLayoutAttributesResource
        
        if layoutAttributes == nil {
            var _itemCache = itemCache
            layoutAttributes = UICollectionViewLayoutAttributesResource(forCellWith: indexPath)
            _itemCache[indexPath] = layoutAttributes
            return (layoutAttributes!, _itemCache)
        } else {
            return (layoutAttributes!, itemCache)
        }
    }
    
    func layoutAttributesForDecorationView(at indexPath: IndexPath,
                                           ofKind kind: String,
                                           withItemCache itemCache: AttDic,
                                           attributesKind: UICollectionViewLayoutAttributes.Type = UICollectionViewLayoutAttributes.self) -> (UICollectionViewLayoutAttributes, AttDic) {
        var layoutAttributes = itemCache[indexPath]
        
        if layoutAttributes == nil {
            var _itemCache = itemCache
            layoutAttributes = attributesKind.init(forDecorationViewOfKind: kind, with: indexPath)
            _itemCache[indexPath] = layoutAttributes
            return (layoutAttributes!, _itemCache)
        } else {
            return (layoutAttributes!, itemCache)
        }
    }
    
    func layoutAttributesForDecorationView(at indexPath: IndexPath,
                                           ofKind kind: String,
                                           withItemCache itemCache: AttDic) -> (UICollectionViewLayoutAttributes, AttDic) {
        var layoutAttributes = itemCache[indexPath]
        
        if layoutAttributes == nil {
            var _itemCache = itemCache
            layoutAttributes = UICollectionViewLayoutAttributes(forDecorationViewOfKind: kind, with: indexPath)
            _itemCache[indexPath] = layoutAttributes
            return (layoutAttributes!, _itemCache)
        } else {
            return (layoutAttributes!, itemCache)
        }
    }
    
    private func layoutAttributesForSupplementaryView(at indexPath: IndexPath,
                                                      ofKind kind: String,
                                                      withItemCache itemCache: AttDic) -> (UICollectionViewLayoutAttributes, AttDic) {
        var layoutAttributes = itemCache[indexPath]
        
        if layoutAttributes == nil {
            var _itemCache = itemCache
            layoutAttributes = UICollectionViewLayoutAttributes(forSupplementaryViewOfKind: kind, with: indexPath)
            _itemCache[indexPath] = layoutAttributes
            return (layoutAttributes!, _itemCache)
        } else {
            return (layoutAttributes!, itemCache)
        }
    }
    
    /**
     New method to adjust items layout for overlap
     
     Known existing issues:
     1. If some events have the same overlap count as others and at the same time, those events are not adjusted yet, then this method will calculate and divide them evenly in the section.
     However, there might be some cases, in very complicated situation, those same overlap count groups might exist already adjusted item overlapping with one of current group items, which
     means the order is wrong.
     2. Efficiency issue for getAvailableRanges and the rest of the code in this method
     */
    open func adjustItemsForOverlap(_ sectionItemAttributes: [UICollectionViewLayoutAttributesResource],
                                    inSection: Int,
                                    sectionMinX: CGFloat,
                                    currentSectionZ: Int,
                                    resourceIdx: Int = 0,
                                    sectionWidth: CGFloat) {
        let (maxOverlapIntervalCount, overlapGroups) = groupOverlapItems(items: sectionItemAttributes.filter { $0.resourceIndex == resourceIdx })
        guard maxOverlapIntervalCount > 1 else { return }
        
        let sortedOverlapGroups = overlapGroups.sorted { $0.count > $1.count }
        var adjustedItems: Set<UICollectionViewLayoutAttributes> = []
        var sectionZ = currentSectionZ
        
        // First draw the largest overlap items layout (only this case itemWidth is fixed and always at the right position)
        let largestOverlapCountGroup = sortedOverlapGroups[0]
        setItemsAdjustedAttributes(fullWidth: sectionWidth, items: largestOverlapCountGroup, currentMinX: sectionMinX, sectionZ: &sectionZ, adjustedItems: &adjustedItems)
        
        for index in 1..<sortedOverlapGroups.count {
            let group = sortedOverlapGroups[index]
            var unadjustedItems = [UICollectionViewLayoutAttributes]()
            // unavailable area and already sorted
            var adjustedRanges = [ClosedRange<CGFloat>]()
            group.forEach {
                if adjustedItems.contains($0) {
                    adjustedRanges.append($0.frame.minX...$0.frame.maxX)
                } else {
                    unadjustedItems.append($0)
                }
            }
            guard adjustedRanges.count > 0 else {
                // No need to recalulate the layout
                setItemsAdjustedAttributes(fullWidth: sectionWidth, items: group, currentMinX: sectionMinX, sectionZ: &sectionZ, adjustedItems: &adjustedItems)
                continue
            }
            guard unadjustedItems.count > 0 else { continue }
            
            let availableRanges = getAvailableRanges(sectionRange: sectionMinX...sectionMinX + sectionWidth, adjustedRanges: adjustedRanges)
            let minItemDivisionWidth = (sectionWidth / CGFloat(largestOverlapCountGroup.count)).toDecimal1Value()
            var i = 0, j = 0
            while i < unadjustedItems.count && j < availableRanges.count {
                let availableRange = availableRanges[j]
                let availableWidth = availableRange.upperBound - availableRange.lowerBound
                let availableMaxItemsCount = Int(round(availableWidth / minItemDivisionWidth))
                let leftUnadjustedItemsCount = unadjustedItems.count - i
                if leftUnadjustedItemsCount <= availableMaxItemsCount {
                    // All left unadjusted items can evenly divide the current available area
                    setItemsAdjustedAttributes(fullWidth: availableWidth, items: Array(unadjustedItems[i..<unadjustedItems.count]), currentMinX: availableRange.lowerBound, sectionZ: &sectionZ, adjustedItems: &adjustedItems)
                    break
                } else {
                    // This current available interval cannot afford all left unadjusted items
                    setItemsAdjustedAttributes(fullWidth: availableWidth, items: Array(unadjustedItems[i..<i+availableMaxItemsCount]), currentMinX: availableRange.lowerBound, sectionZ: &sectionZ, adjustedItems: &adjustedItems)
                    i += availableMaxItemsCount
                    j += 1
                }
            }
        }
    }
    
    /// Get current available ranges for unadjusted items with given current section range and already adjusted ranges
    ///
    /// - Parameters:
    ///   - sectionRange: current section minX and maxX range
    ///   - adjustedRanges: already adjusted ranges(cannot draw items on these ranges)
    /// - Returns: All available ranges after substract all adjusted ranges
    func getAvailableRanges(sectionRange: ClosedRange<CGFloat>, adjustedRanges: [ClosedRange<CGFloat>]) -> [ClosedRange<CGFloat>] {
        var availableRanges: [ClosedRange<CGFloat>] = [sectionRange]
        let sortedAdjustedRange = adjustedRanges.sorted { $0.lowerBound < $1.lowerBound }
        for adjustedRange in sortedAdjustedRange {
            let lastAvailableRange = availableRanges.last!
            if adjustedRange.lowerBound > lastAvailableRange.lowerBound + itemMargin.left + itemMargin.right {
                var currentAvailableRanges = [ClosedRange<CGFloat>]()
                // TODO: still exists 707.1999 and 708, needs to be fixed
                if adjustedRange.upperBound + itemMargin.right >= lastAvailableRange.upperBound {
                    // Adjusted range covers right part of the last available range
                    let leftAvailableRange = lastAvailableRange.lowerBound...adjustedRange.lowerBound
                    currentAvailableRanges.append(leftAvailableRange)
                } else {
                    // Adjusted range is in middle of the last available range
                    let leftAvailableRange = lastAvailableRange.lowerBound...adjustedRange.lowerBound
                    let rightAvailableRange = adjustedRange.upperBound...lastAvailableRange.upperBound
                    currentAvailableRanges = [leftAvailableRange, rightAvailableRange]
                }
                availableRanges.removeLast()
                availableRanges += currentAvailableRanges
            } else {
                if adjustedRange.upperBound > lastAvailableRange.lowerBound {
                    let availableRange = adjustedRange.upperBound...lastAvailableRange.upperBound
                    availableRanges.removeLast()
                    availableRanges.append(availableRange)
                } else {
                    // if false, means this adjustedRange is included in last adjustedRange, like (3, 7) & (5, 7) no need to do anything
                }
            }
        }
        return availableRanges
    }
    
    /// Set provided items correct adjusted layout attributes
    ///
    /// - Parameters:
    ///   - fullWidth: Full width for items can be divided
    ///   - items: All the items need to be adjusted
    ///   - currentMinX: Current minimum contentOffset(start position of the first item)
    ///   - sectionZ: section Z value (inout)
    ///   - adjustedItems: already adjused item (inout)
    private func setItemsAdjustedAttributes(fullWidth: CGFloat,
                                            items: [UICollectionViewLayoutAttributes],
                                            currentMinX: CGFloat,
                                            sectionZ: inout Int,
                                            adjustedItems: inout Set<UICollectionViewLayoutAttributes>) {
        let divisionWidth = (fullWidth / CGFloat(items.count)).toDecimal1Value()
        let itemWidth = divisionWidth - itemMargin.left - itemMargin.right
        for (index, itemAttribute) in items.enumerated() {
            itemAttribute.frame.origin.x = (currentMinX + itemMargin.left + CGFloat(index) * divisionWidth).toDecimal1Value()
            itemAttribute.frame.size = CGSize(width: itemWidth, height: itemAttribute.frame.height)
            itemAttribute.zIndex = sectionZ
            sectionZ += 1
            adjustedItems.insert(itemAttribute)
        }
    }
    
    /// Get maximum number of currently overlapping items, used to refer only
    ///
    /// Algorithm from http://www.zrzahid.com/maximum-number-of-overlapping-intervals/
    private func maxOverlapIntervalCount(startY: [CGFloat], endY: [CGFloat]) -> Int {
        var maxOverlap = 0, currentOverlap = 0
        let sortedStartY = startY.sorted(), sortedEndY = endY.sorted()
        
        var i = 0, j = 0
        while i < sortedStartY.count && j < sortedEndY.count {
            if sortedStartY[i] < sortedEndY[j] {
                currentOverlap += 1
                maxOverlap = max(maxOverlap, currentOverlap)
                i += 1
            } else {
                currentOverlap -= 1
                j += 1
            }
        }
        return maxOverlap
    }
    
    /// Group all the overlap items depending on the maximum overlap items
    ///
    /// Refer to the previous algorithm but integrated with groups
    /// - Parameter items: All the items(cells) in the UICollectionView
    /// - Returns: maxOverlapIntervalCount and all the maximum overlap groups
    func groupOverlapItems(items: [UICollectionViewLayoutAttributes]) -> (maxOverlapIntervalCount: Int, overlapGroups: [[UICollectionViewLayoutAttributes]]) {
        var maxOverlap = 0, currentOverlap = 0
        let sortedMinYItems = items.sorted { $0.frame.minY < $1.frame.minY }
        let sortedMaxYItems = items.sorted { $0.frame.maxY < $1.frame.maxY }
        let itemCount = items.count
        
        var i = 0, j = 0
        var overlapGroups = [[UICollectionViewLayoutAttributes]]()
        var currentOverlapGroup = [UICollectionViewLayoutAttributes]()
        var shouldAppendToOverlapGroups: Bool = false
        while i < itemCount && j < itemCount {
            if sortedMinYItems[i].frame.minY < sortedMaxYItems[j].frame.maxY {
                currentOverlap += 1
                maxOverlap = max(maxOverlap, currentOverlap)
                shouldAppendToOverlapGroups = true
                currentOverlapGroup.append(sortedMinYItems[i])
                i += 1
            } else {
                currentOverlap -= 1
                // should not append to group with continuous minus
                if shouldAppendToOverlapGroups {
                    if currentOverlapGroup.count > 1 { overlapGroups.append(currentOverlapGroup) }
                    shouldAppendToOverlapGroups = false
                }
                currentOverlapGroup.removeAll { $0 == sortedMaxYItems[j] }
                j += 1
            }
        }
        // Add last currentOverlapGroup
        if currentOverlapGroup.count > 1 { overlapGroups.append(currentOverlapGroup) }
        return (maxOverlap, overlapGroups)
    }
    
    func invalidateLayoutCache() {
        needsToPopulateAttributesForAllSections = true
        
        cachedDayDateComponents.removeAll()
        cachedStartTimeDateComponents.removeAll()
        cachedEndTimeDateComponents.removeAll()
        
        currentTimeLineAttributes.removeAll()
        verticalGridlineAttributes.removeAll()
        horizontalGridlineAttributes.removeAll()
        columnHeaderAttributes.removeAll()
        columnHeaderBackgroundAttributes.removeAll()
        rowHeaderAttributes.removeAll()
        rowHeaderBackgroundAttributes.removeAll()
        cornerHeaderAttributes.removeAll()
        itemAttributes.removeAll()
        allAttributes.removeAll()
        
        allDayHeaderAttributes.removeAll()
        allDayHeaderBackgroundAttributes.removeAll()
        allDayCornerAttributes.removeAll()
        outscreenCellsAttributes.removeAll()
        restrictedAreasAttributes.removeAll()
        rowHeaderDividerHorizontalAttributes.removeAll()
    }
    
    override open func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        let visibleSections = NSMutableIndexSet()
        NSIndexSet(indexesIn: NSRange(location: 0, length: collectionView!.numberOfSections))
            .enumerate(_:) { (section: Int, _: UnsafeMutablePointer<ObjCBool>) -> Void in
                let sectionRect = rectForSection(section)
                if rect.intersects(sectionRect) {
                    visibleSections.add(section)
                }
            }
        prepareHorizontalTileSectionLayoutForSections(visibleSections)
        
        return allAttributes.filter({ rect.intersects($0.frame) })
    }
    
    override open func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
        true
    }
    
    // MARK: - Section sizing
    open func rectForSection(_ section: Int) -> CGRect {
        CGRect(x: rowHeaderWidth + sectionWidth * CGFloat(section), y: 0,
               width: sectionWidth, height: collectionViewContentSize.height)
    }
    
    // MARK: - Delegate Wrapper
    
    /// Internal use only, use getDateForSection in JZBaseWeekView instead
    private func daysForSection(_ section: Int) -> DateComponents {
        if cachedDayDateComponents[section] != nil {
            return cachedDayDateComponents[section]!
        }
        
        let day = delegate?.collectionView(collectionView!, layout: self, dayForSection: section)
        guard day != nil else { fatalError() }
        let startOfDay = Calendar.current.startOfDay(for: day!)
        let dayDateComponents = Calendar.current.dateComponents([.year, .month, .day], from: startOfDay)
        cachedDayDateComponents[section] = dayDateComponents
        return dayDateComponents
    }

    private func startTimeForIndexPath(_ indexPath: IndexPath) -> DateComponents {
        if cachedStartTimeDateComponents[indexPath] != nil {
            return cachedStartTimeDateComponents[indexPath]!
        } else {
            if let date = delegate?.collectionView(collectionView!,
                                                   layout: self, startTimeForItemAtIndexPath: indexPath) {
                var startDate = Calendar.current.dateComponents([.day, .hour, .minute], from: date)
                startDate.hour = (startDate.hour ?? 0) - timelineType.timeRange.lowerBound
                cachedStartTimeDateComponents[indexPath] = startDate
                return cachedStartTimeDateComponents[indexPath]!
            } else {
                fatalError()
            }
        }
    }

    private func endTimeForIndexPath(_ indexPath: IndexPath) -> DateComponents {
        if cachedEndTimeDateComponents[indexPath] != nil {
            return cachedEndTimeDateComponents[indexPath]!
        } else {
            if let date = delegate?.collectionView(collectionView!,
                                                   layout: self, endTimeForItemAtIndexPath: indexPath) {
                var endTime = Calendar.current.dateComponents([.day, .hour, .minute], from: date)
                endTime.hour = (endTime.hour ?? 0)
                cachedEndTimeDateComponents[indexPath] = endTime
                return cachedEndTimeDateComponents[indexPath]!
            } else {
                fatalError()
            }
        }
    }
    
    private func isPlaceholderEventForIndexPath(_ indexPath: IndexPath) -> Bool {
        guard let view = collectionView,
              let type = delegate?.collectionView(view, layout: self, cellTypeForItemAtIndexPath: indexPath) else { return false }
        
        return type == JZSupplementaryViewKinds.placeholderCell
    }
    
    private func isCalendarBlockForIndexPath(_ indexPath: IndexPath) -> Bool {
        guard let view = collectionView,
              let type = delegate?.collectionView(view, layout: self, cellTypeForItemAtIndexPath: indexPath) else { return false }
        
        return type == JZSupplementaryViewKinds.calendarBlockCell
    }
    
    private func resourceIndexForIndexPath(_ indexPath: IndexPath) -> Int {
        delegate?.collectionView(collectionView!, layout: self, resourceIndexForItemAtIndexPath: indexPath) ?? 0
    }
    
    private func zIndexForIndexPath(_ indexPath: IndexPath) -> Int {
        delegate?.collectionView(collectionView!, layout: self, zIndexForItemAtIndexPath: indexPath) ?? 1
    }
    
    /// Vertically scroll the collectionView to specific time in a day, only **hour** will be calulated for the offset.
    /// If the hour you set is too large, it will only reach the bottom 24:00 as the maximum value.
    open func scrollCollectionViewTo(time: Date, position: ScrollPosition = .top, zoomLevel: ZoomConfiguration.ZoomLevel? = nil, animated: Bool = false) {
        let minLimit: CGFloat = 0
        let maxLimit: CGFloat = collectionView!.contentSize.height - collectionView!.bounds.height
        var hourY = CGFloat(Calendar.current.component(.hour, from: time)) * (zoomLevel?.value.height ?? hourHeightForZoomLevel)
        
        if timelineType != .full {
            hourY -= (zoomLevel?.value.height ?? hourHeightForZoomLevel) * CGFloat(timelineType.timeRange.lowerBound)
        }
        
        let y: CGFloat = {
            switch position {
            case .top:
                return hourY
            case .centerVertically:
                return hourY - collectionView!.bounds.height / 2
            }
        }()
        let limitedY = max(min(y, maxLimit), minLimit)
        
        self.collectionView!.setContentOffsetWithoutDelegate(CGPoint(x: self.collectionView!.contentOffset.x,
                                                                     y: limitedY),
                                                             animated: animated)
    }
    
    open func timeForRowHeader(at indexPath: IndexPath) -> Date {
        var components = daysForSection(indexPath.section)
        components.hour = indexPath.item + timelineType.timeRange.lowerBound
        return Calendar.current.date(from: components)!
    }
    
    open func dateForColumnHeader(at indexPath: IndexPath) -> Date {
        let day = delegate?.collectionView(collectionView!, layout: self, dayForSection: indexPath.section)
        return Calendar.current.startOfDay(for: day!)
    }
    
    // MARK: - z index
    open func zIndexForElementKind(_ kind: String, withOffset: Int = 10) -> Int {
        switch kind {
        case JZSupplementaryViewKinds.cornerHeader, JZDecorationViewKinds.allDayCorner:
            return minOverlayZ + 11
        case JZSupplementaryViewKinds.allDayHeader:
            return minOverlayZ + 10
        case JZDecorationViewKinds.allDayHeaderBackground:
            return minOverlayZ + 9
        case JZSupplementaryViewKinds.rowHeader, JZDecorationViewKinds.rowHeaderDivider:
            return minOverlayZ + 8
        case JZDecorationViewKinds.rowHeaderBackground:
            return minOverlayZ + 7
        case JZSupplementaryViewKinds.columnHeader:
            return minOverlayZ + 6
        case JZDecorationViewKinds.columnHeaderBackground:
            return minOverlayZ + 5
        case JZSupplementaryViewKinds.currentTimeline:
            return minOverlayZ + 12
        case JZDecorationViewKinds.horizontalGridline:
            return minBackgroundZ + 3
        case JZDecorationViewKinds.verticalGridline:
            return minBackgroundZ + 2
        case JZDecorationViewKinds.outscreenCell:
            return minCellZ + 41
        case JZDecorationViewKinds.restrictedArea:
            return minBackgroundZ + 1
        case JZSupplementaryViewKinds.placeholderCell:
            return minCellZ + 10
        case JZSupplementaryViewKinds.calendarBlockCell:
            return minCellZ + withOffset
        default:
            return minCellZ
        }
    }
}

// MARK: - Row header divider
extension JZWeekViewFlowLayout {
    
    private func setupRowHeaderDivider() {
        register(JZRowDividerHorizontalHeader.self, forDecorationViewOfKind: JZDecorationViewKinds.rowHeaderDivider)
    }
    
    private func layoutRowDividerHorizontalAttributes(startX: CGFloat,
                                                      startY: CGFloat,
                                                      division: Int,
                                                      indexPath: IndexPath) {
        var attributes = UICollectionViewLayoutAttributes()
        (attributes, rowHeaderDividerHorizontalAttributes) = layoutAttributesForDecorationView(at: indexPath, ofKind: JZDecorationViewKinds.rowHeaderDivider, withItemCache: rowHeaderDividerHorizontalAttributes, attributesKind: JZDividerLayoutAttributes.self)
        
        let text: String?
        switch hourGridDivision {
        case .minutes_30:
            text = ":\(hourGridDivision.rawValue)"
        case .minutes_15 where division % 2 == 0:
            text = ":\(hourGridDivision.rawValue * division)"
        case .minutes_5 where division % 3 == 0:
            text = ":\(hourGridDivision.rawValue * division)"
        default:
            text = nil
        }
        
        if let textAttributes = attributes as? JZDividerLayoutAttributes {
            textAttributes.text = text
        }
        
        let attributeY = startY - (defaultRowHeaderDividerHeight / 2)
        attributes.frame = CGRect(x: startX, y: attributeY, width: rowHeaderWidth - 4, height: defaultRowHeaderDividerHeight)
        attributes.alpha = 1
        attributes.zIndex = zIndexForElementKind(JZDecorationViewKinds.rowHeaderDivider)
    }
}

// MARK: - Outscreen decoration view
extension JZWeekViewFlowLayout {
    
    private enum OutscreenDecorationViewPosition {
        case top, bottom, center
    }
    
    private func setupOutsideScreenDecorations() {
        register(JZOutsideCellDecorationView.self, forDecorationViewOfKind: JZDecorationViewKinds.outscreenCell)
    }
    
    private func addOutsideScreenDecorationView(indexPath: IndexPath,
                                                minX: CGFloat,
                                                maxX: CGFloat,
                                                position: OutscreenDecorationViewPosition) {
        guard let collectionView = collectionView else { return }
        
        let attributes: UICollectionViewLayoutAttributes
        (attributes, outscreenCellsAttributes) = layoutAttributesForDecorationView(at: indexPath, ofKind: JZDecorationViewKinds.outscreenCell, withItemCache: outscreenCellsAttributes, attributesKind: JZStyleLayoutAttributes.self)
        if let attributes = attributes as? JZStyleLayoutAttributes {
            attributes.backgroundColor = delegate?.collectionView(collectionView, colorForOutsideScreenDecorationViewAt: indexPath)
        }
        attributes.zIndex = zIndexForElementKind(JZDecorationViewKinds.outscreenCell)
        
        let inset: CGFloat = 4
        let height: CGFloat = 5
        let minY: CGFloat
        
        switch position {
        case .center:
            attributes.alpha = 0
            return
        case .top:
            minY = collectionView.contentOffset.y + inset + columnHeaderHeight
            // For a right hierarchy we need to change zIndex
            attributes.zIndex += indexPath.item
        case .bottom:
            minY = collectionView.contentOffset.y + collectionView.bounds.height - inset - height
            attributes.zIndex -= indexPath.item
        }
        
        attributes.frame = CGRect(x: minX, y: minY, width: subsectionWidth, height: height)
        attributes.alpha = 1
    }
    
}

// MARK: - restricted areas
extension JZWeekViewFlowLayout {
    
    private func setupRestrictedAreasDecorations() {
        register(JZRestrictedAreaView.self, forDecorationViewOfKind: JZDecorationViewKinds.restrictedArea)
    }
    
    private func addRestrictedAreasDecorations(resourceIdx: Int,
                                               section: Int,
                                               minX: CGFloat,
                                               maxX: CGFloat,
                                               areas: Set<RestrictedArea>) {
        guard collectionView != nil else { return }
        
        let calendarGridMinY = columnHeaderHeight + contentsMargin.top + allDayHeaderHeight
        
        func yForSeconds(_ seconds: TimeInterval) -> CGFloat {
            CGFloat(seconds / 60) * minuteHeight
        }
        
        areas.enumerated().forEach { (index, area) in
            let indexPath = IndexPath(item: resourceIdx * 100 + index, section: section)
            let attributes: UICollectionViewLayoutAttributes
            (attributes, restrictedAreasAttributes) = layoutAttributesForDecorationView(at: indexPath, ofKind: JZDecorationViewKinds.restrictedArea, withItemCache: restrictedAreasAttributes, attributesKind: JZTemplatesLayoutAttributes.self)
            
            attributes.zIndex = zIndexForElementKind(JZDecorationViewKinds.restrictedArea)
            
            func calculateY() -> (minY: CGFloat, maxY: CGFloat) {
                var minY = yForSeconds(area.timeRange.lowerBound) + calendarGridMinY
                var maxY = yForSeconds(area.timeRange.upperBound) + calendarGridMinY
                
                switch timelineType {
                case .short, .range:
                    let value = timeRangeLowerOffset
                    minY -= value
                    maxY -= value
                default:
                    break
                }
                
                return (minY, maxX)
            }
            
            let result = calculateY()
            let minY = result.minY
            let maxY = result.maxY
            
            attributes.frame = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
            
            if let templateAttributes = attributes as? JZTemplatesLayoutAttributes {
                templateAttributes.text = area.title
                templateAttributes.backgroundColor = area.backgroundColor
                templateAttributes.isUnavailability = area.isUnavailability
                templateAttributes.isScheduleTemplate = area.isScheduleTemplate
            }
        }
    }
}
