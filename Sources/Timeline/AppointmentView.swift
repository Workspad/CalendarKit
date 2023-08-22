import UIKit

open class AppointmentView: UIView {
  public var descriptor: EventDescriptor?
  public var color = SystemColors.label

    private var isZeroDuration: Bool {
        return descriptor?.dateInterval.duration == Double(0.0)
    }
    
    private typealias Attributes = ([NSAttributedString.Key : NSObject])
    private let separator = NSAttributedString(string: "\n")
    private let lockImageSize: CGFloat = 14 
    private let pointSize: CGFloat = 10
    
    private lazy var subjectAttributes: Attributes = {
        let style = NSMutableParagraphStyle()
        style.lineBreakMode = .byTruncatingTail
        let attributes = [NSAttributedString.Key.foregroundColor: UIColor.label,
                          NSAttributedString.Key.font: UIFont.systemFont(ofSize: 13, weight: .medium),
                          NSAttributedString.Key.paragraphStyle: style]
        return attributes
    }()
    
    private lazy var locationAttributes: Attributes = {
        let style = NSMutableParagraphStyle()
        style.paragraphSpacingBefore = 5
        style.lineBreakMode = .byTruncatingTail
        let attributes = [NSAttributedString.Key.foregroundColor: UIColor.secondaryLabel,
                          NSAttributedString.Key.font: UIFont.systemFont(ofSize: 12, weight: .medium),
                          NSAttributedString.Key.paragraphStyle: style]
        return attributes
    }()
        
    private lazy var stackView: UIStackView = {
       let view = UIStackView()
        view.layoutMargins = UIEdgeInsets(top: 1, left: 1, bottom: 0, right: 0)
        view.isLayoutMarginsRelativeArrangement = true
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        view.axis = .vertical
        view.spacing = .zero
        return view
    }()
    
    private lazy var stactTextLabel: UILabel = {
       let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 13, weight: .medium)
        label.textColor = .label
        label.numberOfLines = 0
        return label
    }()
    
    private lazy var dummyView: UILabel = {
        return UILabel()
    }()
    
    private lazy var lockImageView: UIImageView = {
        let lockImage = UIImage(systemName: "lock.fill")
        let imageView = UIImageView(image: lockImage)
        imageView.tintColor = .label
        return imageView
    }()
   
    // MARK: - Props for zero duration view
    private lazy var containerView: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        return view
    }()
    
    private lazy var containerTextLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 13, weight: .medium)
        label.textColor = .label
        label.lineBreakMode = .byTruncatingTail
        return label  
    }()
    
    private lazy var pointView: UIView = {
       let view = UIView()
        return view
    }()
   
  /// Resize Handle views showing up when editing the event.
  /// The top handle has a tag of `0` and the bottom has a tag of `1`
  public private(set) lazy var eventResizeHandles = [EventResizeHandleView(), EventResizeHandleView()]

  override public init(frame: CGRect) {
    super.init(frame: frame)
    configure()
  }

  required public init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
    configure()
  }

  private func configure() {
    clipsToBounds = false
    color = tintColor
      stackView.addArrangedSubview(stactTextLabel)
      stackView.addArrangedSubview(dummyView)
      addSubview(stackView)
      addSubview(lockImageView)
      
      containerView.addSubview(pointView)
      containerView.addSubview(containerTextLabel)
      self.addSubview(containerView)
      
    for (idx, handle) in eventResizeHandles.enumerated() {
      handle.tag = idx
      addSubview(handle)
    }
  }

    public func updateWithDescriptor(event: EventDescriptor) {
        let attributedText = NSMutableAttributedString()
        
        let cancelledSubject = NSAttributedString(
            string: event.text,
            attributes: [.strikethroughStyle: NSUnderlineStyle.single.rawValue]
        )
         
        let attributedSubject = NSAttributedString(string: event.text, attributes: subjectAttributes)
        attributedText.append(event.isCancelledAppointment ? cancelledSubject : attributedSubject)
        
        if let location = event.location {
            let attributedLocation = NSAttributedString(string: location, attributes: locationAttributes)
            attributedText.append(separator)
            attributedText.append(attributedLocation)
        }
        
        stactTextLabel.attributedText = attributedText
        containerTextLabel.text = event.text
        descriptor = event
        
        setupViewStyle(with: CalendarResponse(rawValue: event.responseType),
                       isCancelledAppointment: event.isCancelledAppointment)
        
        pointView.backgroundColor = event.color
        
        eventResizeHandles.forEach{
            $0.borderColor = event.color
            $0.isHidden = event.editedEvent == nil
        }
        drawsShadow = event.editedEvent != nil
        
        clipsToBounds = true
        layer.cornerRadius = 2
        setNeedsDisplay()
        setNeedsLayout()
    }
    
  public func animateCreation() {
    transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
    func scaleAnimation() {
      transform = .identity
    }
    UIView.animate(withDuration: 0.2,
                   delay: 0,
                   usingSpringWithDamping: 0.2,
                   initialSpringVelocity: 10,
                   options: [],
                   animations: scaleAnimation,
                   completion: nil)
  }

  /**
   Custom implementation of the hitTest method is needed for the tap gesture recognizers
   located in the ResizeHandleView to work.
   Since the ResizeHandleView could be outside of the EventView's bounds, the touches to the ResizeHandleView
   are ignored.
   In the custom implementation the method is recursively invoked for all of the subviews,
   regardless of their position in relation to the Timeline's bounds.
   */
  public override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
    for resizeHandle in eventResizeHandles {
      if let subSubView = resizeHandle.hitTest(convert(point, to: resizeHandle), with: event) {
        return subSubView
      }
    }
    return super.hitTest(point, with: event)
  }

  override open func draw(_ rect: CGRect) {
    super.draw(rect)
    guard let context = UIGraphicsGetCurrentContext() else {
      return
    }
    context.interpolationQuality = .none
    context.saveGState()
    context.setStrokeColor(color.cgColor)
    context.setLineWidth(3)
    context.translateBy(x: 0, y: 0.5)
    let leftToRight = UIView.userInterfaceLayoutDirection(for: semanticContentAttribute) == .leftToRight
    let x: CGFloat = leftToRight ? 0 : frame.width - 1  // 1 is the line width
    let y: CGFloat = 0
    context.beginPath()
    context.move(to: CGPoint(x: x, y: y))
    context.addLine(to: CGPoint(x: x, y: (bounds).height))
    context.strokePath()
    context.restoreGState()
  }

  private var drawsShadow = false
    
    override open func layoutSubviews() {
        super.layoutSubviews()
        containerView.isHidden = true
        pointView.isHidden = true
        containerTextLabel.isHidden = true
        stackView.isHidden = false
        
        // Не показывать stackView для событий с длительностью 0. Вместо него использовать containerView 
        if isZeroDuration {
            stackView.isHidden = true
            containerView.isHidden = false
            pointView.isHidden = false
            containerTextLabel.isHidden = false
            
            containerView.frame = CGRect(x: bounds.minX,
                                         y: bounds.minY,
                                         width: bounds.width,
                                         height: bounds.height)
            
            pointView.frame = CGRect(x: containerView.frame.minX + 3,
                                     y: containerView.frame.height/2 - pointSize/2,
                                     width: pointSize,
                                     height: pointSize)
            
            pointView.layer.cornerRadius = pointSize/2
            
            containerTextLabel.frame = CGRect(x: pointView.frame.maxX + 5, 
                                     y: 0, 
                                     width: containerView.bounds.width - pointSize * 2, 
                                     height: containerView.frame.height)
            
        }
        
        
        stackView.frame = {
        if UIView.userInterfaceLayoutDirection(for: semanticContentAttribute) == .rightToLeft {
            return CGRect(x: bounds.minX, y: bounds.minY, width: bounds.width - lockImageSize - 5, height: bounds.height)
        } else {
            return CGRect(x: bounds.minX + 3, y: bounds.minY, width: bounds.width - lockImageSize - 5, height: bounds.height)
        }
    }()
      
    if frame.minY < 0 {
      var textFrame = stackView.frame;
      textFrame.origin.y = frame.minY * -1;
      textFrame.size.height += frame.minY;
        stackView.frame = textFrame;
    }
      
      lockImageView.frame = {
          if stackView.bounds.height <= lockImageSize {
              return CGRect(x: bounds.maxX - lockImageSize - 3,
                            y: bounds.maxY - lockImageSize,
                            width: lockImageSize,
                            height: lockImageSize)
          } else {
              return CGRect(x: bounds.maxX - lockImageSize - 3,
                            y: bounds.maxY - lockImageSize - 3,
                            width: lockImageSize,
                            height: lockImageSize)
          } 
      }() 
          
      guard let descriptor else { return }
      // Не показывать иконку замка для частных событий длительностью менее 15 мин (900 сек)
      lockImageView.isHidden = ((descriptor.dateInterval.duration) < TimeInterval(900.0)) || !(descriptor.isPrivate)
      
    let first = eventResizeHandles.first
    let last = eventResizeHandles.last
    let radius: CGFloat = 40
    let yPad: CGFloat =  -radius / 2
    let width = bounds.width
    let height = bounds.height
    let size = CGSize(width: radius, height: radius)
    first?.frame = CGRect(origin: CGPoint(x: width - radius - layoutMargins.right, y: yPad),
                          size: size)
    last?.frame = CGRect(origin: CGPoint(x: layoutMargins.left, y: height - yPad - radius),
                         size: size)
    
    if drawsShadow {
      applySketchShadow(alpha: 0.13,
                        blur: 10)
    }
  }

  private func applySketchShadow(
    color: UIColor = .black,
    alpha: Float = 0.5,
    x: CGFloat = 0,
    y: CGFloat = 2,
    blur: CGFloat = 4,
    spread: CGFloat = 0)
  {
    layer.shadowColor = color.cgColor
    layer.shadowOpacity = alpha
    layer.shadowOffset = CGSize(width: x, height: y)
    layer.shadowRadius = blur / 2.0
    if spread == 0 {
      layer.shadowPath = nil
    } else {
      let dx = -spread
      let rect = bounds.insetBy(dx: dx, dy: dx)
      layer.shadowPath = UIBezierPath(rect: rect).cgPath
    }
  }
    
    private func setupBackgroundColor(_ responseType: CalendarResponse?,
                                      _ isCancelledAppointment: Bool) -> UIColor {
        if !isCancelledAppointment {
            switch responseType {
            case .unknown:              return .appBlue
            case .organizer:            return .appBlue
            case .tentative:            return .appBlue.withAlphaComponent(0.50).patternStripes(color2: .appBlue.withAlphaComponent(0.25))
            case .accept:               return .appBlue
            case .decline:              return .appBlue
            case .noResponseReceived:   return .appBlue.withAlphaComponent(0.25)
            case .requestNotSent:       return .appBlue.withAlphaComponent(0.25)
            case .none:                 return .appBlue
            }
        } else {
            return .appGray
        }
    }
    
    private func setupViewStyle(with responseType: CalendarResponse?,isCancelledAppointment: Bool) {
        backgroundColor = setupBackgroundColor(responseType, isCancelledAppointment)
        color = isZeroDuration ? .clear : setupBackgroundColor(responseType, isCancelledAppointment)
        stactTextLabel.textColor = responseType == .requestNotSent ? .appRed : .label
        
        if responseType == .noResponseReceived ||
            responseType == .requestNotSent,
           !isCancelledAppointment {
            setupDashedBorder(view: self)
        }
    }
    
    private func setupDashedBorder(view: UIView) {
        let cornerRadius: CGFloat = 2
        let dashWidth: CGFloat = 2
        let dashColor: UIColor = .systemBlue.withAlphaComponent(0.75)
        let dashLength: CGFloat = 5
        let betweenDashesSpace: CGFloat = 5
        let dashBorder = CAShapeLayer()
        dashBorder.removeFromSuperlayer()
        
        view.layer.cornerRadius = cornerRadius
        view.layer.masksToBounds = true
        
        dashBorder.lineWidth = dashWidth
        dashBorder.strokeColor = dashColor.cgColor
        dashBorder.lineDashPattern = [dashLength, betweenDashesSpace] as [NSNumber]
        dashBorder.frame = view.bounds
        dashBorder.fillColor = nil
        dashBorder.path = UIBezierPath(roundedRect: view.bounds, cornerRadius: cornerRadius).cgPath
        
        view.layer.addSublayer(dashBorder)
    }
}

extension UIColor {
    
    /// make a diagonal striped pattern
    func patternStripes(color2: UIColor = .white, barThickness t: CGFloat = 3) -> UIColor {
        let dim: CGFloat = t * 2.0 * sqrt(2.0)
        
        let img = UIGraphicsImageRenderer(size: .init(width: dim, height: dim)).image { context in
            
            // rotate the context and shift up
            context.cgContext.scaleBy(x: 1, y: -1)
            context.cgContext.rotate(by: CGFloat.pi / 4.0)
            context.cgContext.translateBy(x: -t, y: -2.0 * t)
            
            let bars: [(UIColor,UIBezierPath)] = [
                (self,  UIBezierPath(rect: .init(x: -t, y: 0.0, width: dim * 2.0, height: t))),
                (color2,UIBezierPath(rect: .init(x: 0.0, y: t, width: dim * 2.0, height: t)))
            ]
            
            bars.forEach {  $0.0.setFill(); $0.1.fill() }
            
            // move down and paint again
            context.cgContext.translateBy(x: -t, y: -2.0 * t)
            bars.forEach {  $0.0.setFill(); $0.1.fill() }
        }
        
        return UIColor(patternImage: img)
    }
}

extension UIColor {
    static var appBlue = UIColor(red: 0/255, green: 128/255, blue: 255/255, alpha: 1)
    static var appRed = UIColor(red: 233/255, green: 52/255, blue: 35/255, alpha: 1)
    static var appGray: UIColor = {
        return UIColor { (UITraitCollection: UITraitCollection) -> UIColor in
            if UITraitCollection.userInterfaceStyle == .dark {
                /// Return the color for Dark Mode
                return .systemGray3
            } else {
                /// Return the color for Light Mode
                return .systemGray6
            }
        }
    }()
}
