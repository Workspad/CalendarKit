import UIKit

public protocol TimelineViewDelegate: AnyObject {
  func timelineView(_ timelineView: TimelineView, didTapAt date: Date)
  func timelineView(_ timelineView: TimelineView, didLongPressAt date: Date)
  func timelineView(_ timelineView: TimelineView, didTap event: AppointmentView)
  func timelineView(_ timelineView: TimelineView, didLongPress event: AppointmentView)
}

public final class TimelineView: UIView {
  public weak var delegate: TimelineViewDelegate?

  public var date = Date() {
    didSet {
      setNeedsLayout()
    }
  }

  private var currentTime: Date {
    Date()
  }

  private var eventViews = [AppointmentView]()
  public private(set) var regularLayoutAttributes = [EventLayoutAttributes]()
  public private(set) var allDayLayoutAttributes = [EventLayoutAttributes]()
  
  public var layoutAttributes: [EventLayoutAttributes] {
    get {
      allDayLayoutAttributes + regularLayoutAttributes
    }
    set {
      
      // update layout attributes by separating allday from non all day events
      allDayLayoutAttributes.removeAll()
      regularLayoutAttributes.removeAll()
      for anEventLayoutAttribute in newValue {
        let eventDescriptor = anEventLayoutAttribute.descriptor
        if eventDescriptor.isAllDay {
          allDayLayoutAttributes.append(anEventLayoutAttribute)
        } else {
          regularLayoutAttributes.append(anEventLayoutAttribute)
        }
      }
      
      recalculateEventLayout()
      prepareEventViews()
      allDayView.events = allDayLayoutAttributes.map { $0.descriptor }
      allDayView.isHidden = allDayLayoutAttributes.count == 0
      allDayView.scrollToBottom()
      
      setNeedsLayout()
    }
  }
  private var pool = ReusePool<AppointmentView>()

  public var firstEventYPosition: CGFloat? {
    let first = regularLayoutAttributes.sorted{$0.frame.origin.y < $1.frame.origin.y}.first
    guard let firstEvent = first else {return nil}
    let firstEventPosition = firstEvent.frame.origin.y
    let beginningOfDayPosition = dateToY(date)
    return max(firstEventPosition, beginningOfDayPosition)
  }
    
    public var currentTimeYPosition: CGFloat? {
        if isToday {
            let yPosition = nowLine.frame.origin.y
            return yPosition
        } else {
            return nil
        }
    }

  private lazy var nowLine: CurrentTimeIndicator = CurrentTimeIndicator()
  
  private var allDayViewTopConstraint: NSLayoutConstraint?
  private lazy var allDayView: AllDayView = {
    let allDayView = AllDayView(frame: CGRect.zero)
    
    allDayView.translatesAutoresizingMaskIntoConstraints = false
    addSubview(allDayView)

    allDayViewTopConstraint = allDayView.topAnchor.constraint(equalTo: topAnchor, constant: 0)
    allDayViewTopConstraint?.isActive = true

    allDayView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 0).isActive = true
    allDayView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: 0).isActive = true

    return allDayView
  }()
  
  var allDayViewHeight: CGFloat {
    allDayView.bounds.height
  }

  var style = TimelineStyle()
  private var horizontalEventInset: CGFloat = 3

  public var fullHeight: CGFloat {
    style.verticalInset * 2 + style.verticalDiff * 24
  }

  public var calendarWidth: CGFloat {
    bounds.width - style.leadingInset
  }
    
  public private(set) var is24hClock = true {
    didSet {
      setNeedsDisplay()
    }
  }

  public var calendar: Calendar = Calendar.autoupdatingCurrent {
    didSet {
      eventEditingSnappingBehavior.calendar = calendar
      nowLine.calendar = calendar
      regenerateTimeStrings()
      setNeedsLayout()
    }
  }

  public var eventEditingSnappingBehavior: EventEditingSnappingBehavior = SnapTo15MinuteIntervals() {
    didSet {
      eventEditingSnappingBehavior.calendar = calendar
    }
  }

  private var times: [String] {
    is24hClock ? _24hTimes : _12hTimes
  }

  private lazy var _12hTimes: [String] = TimeStringsFactory(calendar).make12hStrings()
  private lazy var _24hTimes: [String] = TimeStringsFactory(calendar).make24hStrings()
  
  private func regenerateTimeStrings() {
    let factory = TimeStringsFactory(calendar)
    _12hTimes = factory.make12hStrings()
    _24hTimes = factory.make24hStrings()
  }
  
  public lazy private(set) var longPressGestureRecognizer = UILongPressGestureRecognizer(target: self,
                                                                                         action: #selector(longPress(_:)))
  
  public lazy private(set) var tapGestureRecognizer = UITapGestureRecognizer(target: self,
                                                                             action: #selector(tap(_:)))

  private var isToday: Bool {
    calendar.isDateInToday(date)
  }
  
  // MARK: - Initialization
  
  public init() {
    super.init(frame: .zero)
    frame.size.height = fullHeight
    configure()
  }

  override public init(frame: CGRect) {
    super.init(frame: frame)
    configure()
  }

  required public init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
    configure()
  }

  private func configure() {
    contentScaleFactor = 1
    layer.contentsScale = 1
    contentMode = .redraw
    backgroundColor = SystemColors.systemBackground
    addSubview(nowLine)
    
    // Add long press gesture recognizer
    addGestureRecognizer(longPressGestureRecognizer)
    addGestureRecognizer(tapGestureRecognizer)
  }
  
  // MARK: - Event Handling
  
  @objc private func longPress(_ gestureRecognizer: UILongPressGestureRecognizer) {
    if (gestureRecognizer.state == .began) {
      // Get timeslot of gesture location
      let pressedLocation = gestureRecognizer.location(in: self)
      if let eventView = findEventView(at: pressedLocation) {
        delegate?.timelineView(self, didLongPress: eventView)
      } else {
        delegate?.timelineView(self, didLongPressAt: yToDate(pressedLocation.y))
      }
    }
  }
  
  @objc private func tap(_ sender: UITapGestureRecognizer) {
    let pressedLocation = sender.location(in: self)
    if let eventView = findEventView(at: pressedLocation) {
      delegate?.timelineView(self, didTap: eventView)
    } else {
      delegate?.timelineView(self, didTapAt: yToDate(pressedLocation.y))
    }
  }
  
  private func findEventView(at point: CGPoint) -> AppointmentView? {
    for eventView in allDayView.eventViews {
      let frame = eventView.convert(eventView.bounds, to: self)
      if frame.contains(point) {
        return eventView
      }
    }

    for eventView in eventViews {
      let frame = eventView.frame
      if frame.contains(point) {
        return eventView
      }
    }
    return nil
  }
  
  
  /**
   Custom implementation of the hitTest method is needed for the tap gesture recognizers
   located in the AllDayView to work.
   Since the AllDayView could be outside of the Timeline's bounds, the touches to the EventViews
   are ignored.
   In the custom implementation the method is recursively invoked for all of the subviews,
   regardless of their position in relation to the Timeline's bounds.
   */
  public override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
    for subview in allDayView.subviews {
      if let subSubView = subview.hitTest(convert(point, to: subview), with: event) {
        return subSubView
      }
    }
    return super.hitTest(point, with: event)
  }
  
  // MARK: - Style

  public func updateStyle(_ newStyle: TimelineStyle) {
    style = newStyle
    allDayView.updateStyle(style.allDayStyle)
    nowLine.updateStyle(style.timeIndicator)
    
    switch style.dateStyle {
      case .twelveHour:
        is24hClock = false
      case .twentyFourHour:
        is24hClock = true
      default:
        is24hClock = calendar.locale?.uses24hClock() ?? Locale.autoupdatingCurrent.uses24hClock()
    }
    
    backgroundColor = SystemColors.systemBackground
    setNeedsDisplay()
  }
  
  // MARK: - Background Pattern

  public var accentedDate: Date?

  override public func draw(_ rect: CGRect) {
    super.draw(rect)

    var hourToRemoveIndex = -1

    var accentedHour = -1
    var accentedMinute = -1

    if let accentedDate = accentedDate {
      accentedHour = eventEditingSnappingBehavior.accentedHour(for: accentedDate)
      accentedMinute = eventEditingSnappingBehavior.accentedMinute(for: accentedDate)
    }

    if isToday {
      let minute = component(component: .minute, from: currentTime)
      let hour = component(component: .hour, from: currentTime)
      if minute > 39 {
        hourToRemoveIndex = hour + 1
      } else if minute < 21 {
        hourToRemoveIndex = hour
      }
    }

    let mutableParagraphStyle = NSParagraphStyle.default.mutableCopy() as! NSMutableParagraphStyle
    mutableParagraphStyle.lineBreakMode = .byWordWrapping
    mutableParagraphStyle.alignment = .right
    let paragraphStyle = mutableParagraphStyle.copy() as! NSParagraphStyle

    let attributes = [NSAttributedString.Key.paragraphStyle: paragraphStyle,
                      NSAttributedString.Key.foregroundColor: self.style.timeColor,
                      NSAttributedString.Key.font: style.font] as [NSAttributedString.Key : Any]

    let scale = UIScreen.main.scale
    let hourLineHeight = 1 / UIScreen.main.scale

    let center: CGFloat
    if Int(scale) % 2 == 0 {
        center = 1 / (scale * 2)
    } else {
        center = 0
    }
    
    let offset = 0.5 - center
    
    for (hour, time) in times.enumerated() {
        let rightToLeft = UIView.userInterfaceLayoutDirection(for: semanticContentAttribute) == .rightToLeft
        
        let hourFloat = CGFloat(hour)
        let context = UIGraphicsGetCurrentContext()
        context!.interpolationQuality = .none
        context?.saveGState()
        context?.setStrokeColor(style.separatorColor.cgColor)
        context?.setLineWidth(hourLineHeight)
        let xStart: CGFloat = {
            if rightToLeft {
                return bounds.width - 53
            } else {
                return 53
            }
        }()
        let xEnd: CGFloat = {
            if rightToLeft {
                return 0
            } else {
                return bounds.width
            }
        }()
        let y = style.verticalInset + hourFloat * style.verticalDiff + offset
        context?.beginPath()
        context?.move(to: CGPoint(x: xStart, y: y))
        context?.addLine(to: CGPoint(x: xEnd, y: y))
        context?.strokePath()
        context?.restoreGState()
    
        if hour == hourToRemoveIndex { continue }
    
        let fontSize = style.font.pointSize
        let timeRect: CGRect = {
            var x: CGFloat
            if rightToLeft {
                x = bounds.width - 53
            } else {
                x = 2
            }
            
            return CGRect(x: x,
                          y: hourFloat * style.verticalDiff + style.verticalInset - 7,
                          width: style.leadingInset - 8,
                          height: fontSize + 2)
        }()
    
        let timeString = NSString(string: time)
        timeString.draw(in: timeRect, withAttributes: attributes)
    
        if accentedMinute == 0 {
            continue
        }
    
        if hour == accentedHour {
            
            var x: CGFloat
            if UIView.userInterfaceLayoutDirection(for: semanticContentAttribute) == .rightToLeft {
                x = bounds.width - (style.leadingInset + 7)
            } else {
                x = 2
            }
            
            let timeRect = CGRect(x: x, y: hourFloat * style.verticalDiff + style.verticalInset - 7     + style.verticalDiff * (CGFloat(accentedMinute) / 60),
                                width: style.leadingInset - 8, height: fontSize + 2)
            
            let timeString = NSString(string: ":\(accentedMinute)")
            
            timeString.draw(in: timeRect, withAttributes: attributes)
        }
    }
  }
  
  // MARK: - Layout

  override public func layoutSubviews() {
    super.layoutSubviews()
    recalculateEventLayout()
    layoutEvents()
    layoutNowLine()
    layoutAllDayEvents()
  }

  private func layoutNowLine() {
    if !isToday {
      nowLine.alpha = 0
    } else {
		bringSubviewToFront(nowLine)
      nowLine.alpha = 1
      let size = CGSize(width: bounds.size.width, height: 20)
      let rect = CGRect(origin: CGPoint.zero, size: size)
      nowLine.date = currentTime
      nowLine.frame = rect
      nowLine.center.y = dateToY(currentTime)
    }
  }

  private func layoutEvents() {
    if eventViews.isEmpty { return }
    
    for (idx, attributes) in regularLayoutAttributes.enumerated() {
      let descriptor = attributes.descriptor
      let eventView = eventViews[idx]
      eventView.frame = attributes.frame
        
      var x: CGFloat
      if UIView.userInterfaceLayoutDirection(for: semanticContentAttribute) == .rightToLeft {
        x = bounds.width - attributes.frame.minX - attributes.frame.width
      } else {
        x = attributes.frame.minX
      }
        
      eventView.frame = CGRect(x: x,
                               y: attributes.frame.minY,
                               width: attributes.frame.width - style.eventGap,
                               height: attributes.frame.height - style.eventGap)
      eventView.updateWithDescriptor(event: descriptor)
    }
  }
  
  private func layoutAllDayEvents() {
    //add day view needs to be in front of the nowLine
    bringSubviewToFront(allDayView)
  }
  
  /**
   This will keep the allDayView as a staionary view in its superview
   
   - parameter yValue: since the superview is a scrollView, `yValue` is the
   `contentOffset.y` of the scroll view
   */
  public func offsetAllDayView(by yValue: CGFloat) {
    if let topConstraint = self.allDayViewTopConstraint {
      topConstraint.constant = yValue
      layoutIfNeeded()
    }
  }
    
    private func recalculateEventLayout() {
        // Берем все события
        let dayEvents = self.regularLayoutAttributes
        
        // Создаем массив событий с пересечениями
        var overlappedEvents: [EventLayoutAttributes] = []

        dayEvents.forEach { dayEvent in
            // Если у события есть пересечения, добавляем его в массив, чтобы позже рассчитать фреймы
            if doesEventOverlap(event: dayEvent, existingEvents: dayEvents) {
                overlappedEvents.append(dayEvent)
            } else {
                // Если пересечений нет, то сразу рассчитываем фрейм события
                dayEvent.frame = frameForSeparatedEvent(dayEvent)
            }
        }
        
        // Считаем количество колонок — оно равно максимальному количеству пересечений в одно время
        let groupCount = getMaxIntersectionsCountFromEvents(overlappedEvents)
        
        // Распределяем пересекающиеся события в колонки и считаем их фреймы
        distributeEventsToGroups(overlappedEvents, into: groupCount)
    }

  private func prepareEventViews() {
    pool.enqueue(views: eventViews)
    eventViews.removeAll()
    for _ in regularLayoutAttributes {
      let newView = pool.dequeue()
      if newView.superview == nil {
        addSubview(newView)
      }
      eventViews.append(newView)
    }
  }

  public func prepareForReuse() {
    pool.enqueue(views: eventViews)
    eventViews.removeAll()
    setNeedsDisplay()
  }

  // MARK: - Helpers

  public func dateToY(_ date: Date) -> CGFloat {
    let provisionedDate = date.dateOnly(calendar: calendar)
    let timelineDate = self.date.dateOnly(calendar: calendar)
    var dayOffset: CGFloat = 0
    if provisionedDate > timelineDate {
      // Event ending the next day
      dayOffset += 1
    } else if provisionedDate < timelineDate {
      // Event starting the previous day
      dayOffset -= 1
    }
    let fullTimelineHeight = 24 * style.verticalDiff
    let hour = component(component: .hour, from: date)
    let minute = component(component: .minute, from: date)
    let hourY = CGFloat(hour) * style.verticalDiff + style.verticalInset
    let minuteY = CGFloat(minute) * style.verticalDiff / 60
    return hourY + minuteY + fullTimelineHeight * dayOffset
  }

  public func yToDate(_ y: CGFloat) -> Date {
    let timeValue = y - style.verticalInset
    var hour = Int(timeValue / style.verticalDiff)
    let fullHourPoints = CGFloat(hour) * style.verticalDiff
    let minuteDiff = timeValue - fullHourPoints
    let minute = Int(minuteDiff / style.verticalDiff * 60)
    var dayOffset = 0
    if hour > 23 {
      dayOffset += 1
      hour -= 24
    } else if hour < 0 {
      dayOffset -= 1
      hour += 24
    }
    let offsetDate = calendar.date(byAdding: DateComponents(day: dayOffset),
                                   to: date)!
    let newDate = calendar.date(bySettingHour: hour,
                                minute: minute.clamped(to: 0...59),
                                second: 0,
                                of: offsetDate)
    return newDate!
  }

  private func component(component: Calendar.Component, from date: Date) -> Int {
    return calendar.component(component, from: date)
  }
  
  private func getDateInterval(date: Date) -> DateInterval {
    let earliestEventMintues = component(component: .minute, from: date)
    let splitMinuteInterval = style.splitMinuteInterval
    let minute = component(component: .minute, from: date)
    let minuteRange = (minute / splitMinuteInterval) * splitMinuteInterval
    let beginningRange = calendar.date(byAdding: .minute, value: -(earliestEventMintues - minuteRange), to: date)!
    let endRange = calendar.date(byAdding: .minute, value: splitMinuteInterval, to: beginningRange)!
    return DateInterval(start: beginningRange, end: endRange)
  }
   
    // MARK: - Calendar Grid Helpers
    
    // Функция для распределения пересекающихся событий в вертикальные колонки и подсчёта фреймов
    private func distributeEventsToGroups(_ events: [EventLayoutAttributes], into numberOfGroups: Int) -> [[EventLayoutAttributes]] {
        let events = events.sorted { $0.descriptor.dateInterval.start > $1.descriptor.dateInterval.start }
        let width = calendarWidth / CGFloat(numberOfGroups)
        
        // Создаем несколько пустых массивов — это колонки для событий
        var groups = Array(repeating: [EventLayoutAttributes](), count: numberOfGroups)
        
        // Берем каждое событие и заполняем массивы
        for event in events.sorted(by: { $0.descriptor.dateInterval.start < $1.descriptor.dateInterval.end }) {
            var added = false
            
            // Проходимся во всем массивам и смотрим, нет ли пересечений у текущего события с другими в нём до первого подходящего
            for index in 0..<groups.count {
                if !groups[index].contains(where: { $0.descriptor.dateInterval.intersects(event.descriptor.dateInterval) }) {
                    // При успехе добавляем в массив, считаем размер и фрейм вью
                    event.frame = frameForOverlappedEvent(event, index: index, width: width)
                    groups[index].append(event)
                    added = true
                    break
                } else if !doesEventOverlap(event: event, existingEvents: groups[index]) {
                    // Дополнительно после проверяем кейс событий стык в стык (конец одного = начало другого)
                    event.frame = frameForOverlappedEvent(event, index: index, width: width)
                    groups[index].append(event)
                    added = true
                    break
                }
            }
            if !added {
                // Если событие по времени пересекается со всеми событиями всех групп, оно не добавляется
                continue
            }
        }
        
        return groups
    }
    
    // Функция для вычисления максимального количества пересечений
    private func getMaxIntersectionsCountFromEvents(_ events: [EventLayoutAttributes]) -> Int {
        var intervals = [DateInterval]()
        events.forEach { event in
            intervals.append(event.descriptor.dateInterval)
        }
        
        // Создаем массив всех начал и концов интервалов с метками
        let points = intervals.flatMap { interval -> [(Date, Bool)] in
            return [(interval.start, false), (interval.end, true)]
        }
        
        // Сортируем точки по дате, при равенстве сначала конец интервала
        let sortedPoints = points.sorted {
            $0.0 == $1.0 ? $0.1 && !$1.1 : $0.0 < $1.0
        }
        
        var maxIntersections = 0
        var currentIntersections = 0
        
        // Проходим по отсортированным точкам и считаем пересечения
        for point in sortedPoints {
            if point.1 {
                currentIntersections -= 1
            } else {
                currentIntersections += 1
                maxIntersections = max(maxIntersections, currentIntersections)
            }
        }
        
        return maxIntersections
    }
    
    // Функция для проверки пересечений у события
    private func doesEventOverlap(event: EventLayoutAttributes, existingEvents: [EventLayoutAttributes]) -> Bool {
        for existingEvent in existingEvents {
            let dublicate = (event.descriptor.text == existingEvent.descriptor.text) && (event.descriptor.dateInterval == existingEvent.descriptor.dateInterval)
            if event.descriptor.dateInterval.start < existingEvent.descriptor.dateInterval.end && event.descriptor.dateInterval.end > existingEvent.descriptor.dateInterval.start && !dublicate {
                return true
            }
        }
        return false
    }
    
    // Расчет фрейма для отдельного события
    private func frameForSeparatedEvent(_ event: EventLayoutAttributes) -> CGRect {
        let startY = dateToY(event.descriptor.dateInterval.start)
        let endY = dateToY(event.descriptor.dateInterval.end)
        var height = endY - startY
        
        // если событие менее 15 минут - отображать высоту view как для 15 минут
        if height < style.verticalDiff / 4 {
            height = style.verticalDiff / 4
        }
        
        let width = calendarWidth
        let startX = style.leadingInset
        let frame = CGRect(x: startX, y: startY, width: width, height: height)
        return frame
    }
    
    // Расчет фрейма для пересекающегося события
    private func frameForOverlappedEvent(_ event: EventLayoutAttributes, index: Int, width: CGFloat) -> CGRect {
        let startY = dateToY(event.descriptor.dateInterval.start)
        let endY = dateToY(event.descriptor.dateInterval.end)
        var height = endY - startY
        
        // если событие менее 15 минут - отображать высоту view как для 15 минут
        if height < style.verticalDiff / 4 {
            height = style.verticalDiff / 4
        }
    
        let floatIndex = CGFloat(index)
        let startX = style.leadingInset + floatIndex * width
        let frame = CGRect(x: startX, y: startY, width: width, height: height)
        return frame
    }
}
