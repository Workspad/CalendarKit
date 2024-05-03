import Foundation
import UIKit

public protocol EventDescriptor: AnyObject {
  var dateInterval: DateInterval {get set}
  var isAllDay: Bool {get}
  var isPrivate: Bool {get}
  var text: String {get}
  var location: String? {get}
  var attributedText: NSAttributedString? {get}
  var lineBreakMode: NSLineBreakMode? {get}
  var font : UIFont {get}
  var color: UIColor {get}
  var textColor: UIColor {get}
  var backgroundColor: UIColor {get}
  var editedEvent: EventDescriptor? {get set}
  var responseType: Int { get }
  var isCancelledAppointment: Bool { get }
  var isBaseCalendar: Bool { get }
  var organizerStatus: Int { get }
  var hasFullAccess: Bool { get }
  var calendarColor: UIColor { get }
  func makeEditable() -> Self
  func commitEditing()
}

public enum CalendarResponse: Int {
    case unknown
    case organizer
    case tentative
    case accept
    case decline
    case noResponseReceived
    case requestNotSent
}

public enum OrganizerStatus: Int {
    case free
    case tentative
    case busy
    case OOF
    case noData
}
