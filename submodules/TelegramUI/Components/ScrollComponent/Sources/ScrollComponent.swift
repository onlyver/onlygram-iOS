import Foundation
import UIKit
import ComponentFlow
import Display

public final class ScrollChildEnvironment: Equatable {
    public let insets: UIEdgeInsets
    
    public init(insets: UIEdgeInsets) {
        self.insets = insets
    }
    
    public static func ==(lhs: ScrollChildEnvironment, rhs: ScrollChildEnvironment) -> Bool {
        if lhs.insets != rhs.insets {
            return false
        }

        return true
    }
}

public final class ScrollComponent<ChildEnvironment: Equatable>: Component {
    public typealias EnvironmentType = ChildEnvironment
    
    public class ExternalState {
        public var contentHeight: CGFloat = 0.0
        
        public init() {
            
        }
    }
    
    let content: AnyComponent<(ChildEnvironment, ScrollChildEnvironment)>
    let externalState: ExternalState?
    let contentInsets: UIEdgeInsets
    let contentOffsetUpdated: (_ top: CGFloat, _ bottom: CGFloat) -> Void
    let contentOffsetWillCommit: (UnsafeMutablePointer<CGPoint>) -> Void
    let resetScroll: ActionSlot<CGPoint?>
    
    public init(
        content: AnyComponent<(ChildEnvironment, ScrollChildEnvironment)>,
        externalState: ExternalState? = nil,
        contentInsets: UIEdgeInsets,
        contentOffsetUpdated: @escaping (_ top: CGFloat, _ bottom: CGFloat) -> Void,
        contentOffsetWillCommit:  @escaping (UnsafeMutablePointer<CGPoint>) -> Void,
        resetScroll: ActionSlot<CGPoint?> = ActionSlot()
    ) {
        self.content = content
        self.externalState = externalState
        self.contentInsets = contentInsets
        self.contentOffsetUpdated = contentOffsetUpdated
        self.contentOffsetWillCommit = contentOffsetWillCommit
        self.resetScroll = resetScroll
    }
    
    public static func ==(lhs: ScrollComponent, rhs: ScrollComponent) -> Bool {
        if lhs.content != rhs.content {
            return false
        }
        if lhs.contentInsets != rhs.contentInsets {
            return false
        }
        return true
    }
    
    public final class View: UIScrollView, UIScrollViewDelegate {
        private var component: ScrollComponent<ChildEnvironment>?
        private let contentView: ComponentHostView<(ChildEnvironment, ScrollChildEnvironment)>
                
        override init(frame: CGRect) {
            self.contentView = ComponentHostView()
            
            super.init(frame: frame)
            
            if #available(iOSApplicationExtension 11.0, iOS 11.0, *) {
                self.contentInsetAdjustmentBehavior = .never
            }
            self.delegate = self
            self.showsVerticalScrollIndicator = false
            self.showsHorizontalScrollIndicator = false
            self.canCancelContentTouches = true
                        
            self.addSubview(self.contentView)
        }
        
        public override func touchesShouldCancel(in view: UIView) -> Bool {
            return true
        }
        
        private var ignoreDidScroll = false
        public func scrollViewDidScroll(_ scrollView: UIScrollView) {
            guard let component = self.component, !self.ignoreDidScroll else {
                return
            }
            let topOffset = scrollView.contentOffset.y
            let bottomOffset = max(0.0, scrollView.contentSize.height - scrollView.contentOffset.y - scrollView.frame.height)
            component.contentOffsetUpdated(topOffset, bottomOffset)
        }
        
        public func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
            guard let component = self.component, !self.ignoreDidScroll else {
                return
            }
            component.contentOffsetWillCommit(targetContentOffset)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
                
        func update(component: ScrollComponent<ChildEnvironment>, availableSize: CGSize, state: EmptyComponentState, environment: Environment<ChildEnvironment>, transition: ComponentTransition) -> CGSize {
            let contentSize = self.contentView.update(
                transition: transition,
                component: component.content,
                environment: {
                    environment[ChildEnvironment.self]
                    ScrollChildEnvironment(insets: component.contentInsets)
                },
                containerSize: CGSize(width: availableSize.width, height: .greatestFiniteMagnitude)
            )
            transition.setFrame(view: self.contentView, frame: CGRect(origin: .zero, size: contentSize), completion: nil)
            
            component.resetScroll.connect { [weak self] point in
                self?.setContentOffset(point ?? .zero, animated: point != nil)
            }
            
            if self.contentSize != contentSize {
                self.ignoreDidScroll = true
                self.contentSize = contentSize
                self.ignoreDidScroll = false
            }
            
            let verticalScrollIndicatorInsets = UIEdgeInsets(top: component.contentInsets.top, left: 0.0, bottom: component.contentInsets.bottom, right: 0.0)
            let horizontalScrollIndicatorInsets = UIEdgeInsets(top: 0.0, left: component.contentInsets.left, bottom: 0.0, right: component.contentInsets.right)
            
            if self.verticalScrollIndicatorInsets != verticalScrollIndicatorInsets {
                self.verticalScrollIndicatorInsets = verticalScrollIndicatorInsets
            }
            if self.horizontalScrollIndicatorInsets != horizontalScrollIndicatorInsets {
                self.horizontalScrollIndicatorInsets = horizontalScrollIndicatorInsets
            }
            component.externalState?.contentHeight = contentSize.height
            
            self.component = component
            
            return availableSize
        }
    }
    
    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<ChildEnvironment>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
