//
//  InfiniteScroller.swift
//
//  Created by Hovik Melikyan on 28.02.25.
//

import SwiftUI


enum InfiniteScrollerAction {
	case scrollToBottom(animated: Bool)
}


struct InfiniteScroller<Content: View>: UIViewRepresentable {

	typealias OnApproachingEdge = (Edge) -> Void

	init(action: Binding<InfiniteScrollerAction?> = .constant(nil), content: @escaping () -> Content) {
		self._action = action
		self.content = content
	}


	func onApproachingEdge(_ action: @escaping OnApproachingEdge) -> Self {
		var this = self
		this.onApproachingEdge = action
		return this
	}


	// Private part

	@Binding private var action: InfiniteScrollerAction?
	private var onApproachingEdge: OnApproachingEdge? = nil // currently only `top` and `bottom` and only during interactive action
	private let content: () -> Content


	func makeUIView(context: Context) -> HostedScrollView {
		return HostedScrollView(content: content, onApproachingEdge: onApproachingEdge)
	}


	func updateUIView(_ scrollView: HostedScrollView, context: Context) {
		scrollView.updateView(content: content)

		switch action {
			case .none:
				break

			case .scrollToBottom(let animated):
				Task { @MainActor in
					scrollView.scrollToBottom(animated: animated)
					self.action = nil
				}
		}
	}


	final class HostedScrollView: UIScrollView, UIScrollViewDelegate {
		private let host: UIHostingController<Content>
		private let onApproachingEdge: OnApproachingEdge?


		init(content: () -> Content, onApproachingEdge: OnApproachingEdge?) {
			self.host = UIHostingController(rootView: content())
			self.onApproachingEdge = onApproachingEdge
			super.init(frame: .zero)
			delegate = self
			addSubview(host.view)
			alwaysBounceVertical = true
			host.view.backgroundColor = .quaternarySystemFill // .clear
			host.view.autoresizingMask = [.flexibleWidth]
			// updateView() will be called after this
		}


		required init?(coder: NSCoder) {
			preconditionFailure()
		}


		fileprivate func updateView(content: () -> Content) {
			let headroom: Double = 1_000_000
//			let prevHeight = host.view.bounds.height
			host.rootView = content()
			frame.size.width = 0 // somehow this fixes the auto-width problem

			// Auto-size and auto-place content
			host.view.sizeToFit()
			let newHeight = host.view.bounds.height
			host.view.frame.origin.y = headroom - newHeight
			contentSize.height = headroom
			contentInset.top = -headroom + newHeight
		}


		// Delegate

		func scrollViewDidScroll(_ scrollView: UIScrollView) {
			guard isTracking || isDecelerating || isDragging else { return }
			edgeTest()
		}


		func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
			edgeTest()
		}


		// Positioning utilities

		fileprivate func scrollToBottom(animated: Bool) {
			setContentOffset(CGPoint(x: contentOffset.x, y: bottomContentOffsetY), animated: animated)
			if !animated {
				edgeTest() // otherwise it will be called in scrollViewDidEndScrollingAnimation()
			}
		}

		private func edgeTest() {
			guard let onApproachingEdge else { return }
			let vicinity: Double = 200
			if isCloseToTop(within: vicinity) {
				onApproachingEdge(.top)
			}
			else if isCloseToBottom(within: vicinity) {
				onApproachingEdge(.bottom)
			}
		}

		private func isCloseToTop(within offset: Double) -> Bool {
			contentOffset.y + adjustedContentInset.top <= offset
		}

		private func isCloseToBottom(within offset: Double) -> Bool {
			bottomContentOffsetY - contentOffset.y <= offset
		}

		private var bottomContentOffsetY: Double {
			max(contentSize.height - bounds.height + adjustedContentInset.bottom, -adjustedContentInset.top)
		}
	}
}


#Preview {
	@Previewable @State var range = 0..<20
	@Previewable @State var action: InfiniteScrollerAction? = .scrollToBottom(animated: false)

	InfiniteScroller(action: $action) {
		VStack(spacing: 0) {
			ForEach(range, id: \.self) { i in
				Text("Hello \(i + 1)")
					.frame(height: 50)
			}
		}
	}
	.onApproachingEdge { edge in
		if edge == .top {
			range = (range.lowerBound - 20)..<20
			print(Date.now.timeIntervalSinceReferenceDate, edge)
		}
	}
	.ignoresSafeArea()
}
