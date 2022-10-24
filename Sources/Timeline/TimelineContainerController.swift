import UIKit

public final class TimelineContainerController: UIViewController {
  /// Content Offset to be set once the view size has been calculated
    public var pendingContentOffset: CGPoint?
  
  public private(set) lazy var timeline = TimelineView()
  public private(set) lazy var container: TimelineContainer = {
    let view = TimelineContainer(timeline)
    view.addSubview(timeline)
    return view
  }()
  
  public override func loadView() {
    view = container
//      container.delegate = self
  }
  
//    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
//        self.parent?.children.forEach({ vc in
//            if let vc = vc as? TimelineContainerController, vc !== self {
//                vc.container.setContentOffset(scrollView.contentOffset, animated: false)
//            }
//        })
//    }
    
  public override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    container.contentSize = timeline.frame.size
      if let newOffset = self.pendingContentOffset {
      // Apply new offset only once the size has been determined
      if view.bounds != .zero {
        container.setContentOffset(newOffset, animated: false)
        container.setNeedsLayout()
        pendingContentOffset = nil
      }
    }
  }
}
