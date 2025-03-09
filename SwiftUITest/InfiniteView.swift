//
//  InfiniteView.swift
//
//  Created by Hovik Melikyan on 28.02.25.
//

import SwiftUI


enum InfiniteViewScrollAction {
	case top(animated: Bool)
	case bottom(animated: Bool)
}


struct InfiniteView<Content: View>: UIViewRepresentable {

	private let headroom: Double
	private let content: () -> Content
	private let onApproachingEdge: (Edge) async -> Void // currently only `.top` and `.bottom`; triggered within 200px from the edge
	@Binding private var scrollAction: InfiniteViewScrollAction?


	init(headroom: Double, content: @escaping () -> Content, onApproachingEdge: @escaping (Edge) async -> Void) {
		self.headroom = headroom
		self.content = content
		self.onApproachingEdge = onApproachingEdge
		self._scrollAction = .constant(nil)
	}


	func makeUIView(context: Context) -> HostedScrollView {
		return HostedScrollView(content: content, onApproachingEdge: onApproachingEdge)
	}


	func updateUIView(_ scrollView: HostedScrollView, context: Context) {
		scrollView.updateView(headroom: headroom, content: content)

		switch scrollAction {
			case .none:
				break

			case .top(let animated):
				Task {
					scrollView.scrollToTop(animated: animated)
					scrollAction = nil
				}

			case .bottom(let animated):
				Task {
					scrollView.scrollToBottom(animated: animated)
					scrollAction = nil
				}
		}
	}


	func scrollTo(_ action: Binding<InfiniteViewScrollAction?>) -> Self {
		var this = self
		this._scrollAction = action
		return this
	}


	final class HostedScrollView: UIScrollView, UIScrollViewDelegate {
		private let host: UIHostingController<Content>
		private let onApproachingEdge: (Edge) async -> Void
		private var edgeLock: Bool = false


		init(content: () -> Content, onApproachingEdge: @escaping (Edge) async -> Void) {
			self.host = UIHostingController(rootView: content())
			self.onApproachingEdge = onApproachingEdge
			super.init(frame: .zero)
			delegate = self
			addSubview(host.view)
			alwaysBounceVertical = true
			host.view.backgroundColor = .clear
			host.view.autoresizingMask = [.flexibleWidth]
			// updateView() will be called after this
		}


		required init?(coder: NSCoder) {
			preconditionFailure()
		}


		fileprivate func updateView(headroom: Double, content: () -> Content) {
			host.rootView = content()
			frame.size.width = 0 // this is required on the Mac for some reason
			host.view.sizeToFit()
			let newHeight = host.view.bounds.height
			let blankSpace = max(0, pageHeight - newHeight) // ensure small content is at the bottom
			host.view.frame.origin.y = -headroom
			contentInset.top = headroom + blankSpace
			contentSize.height = newHeight - headroom
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

		fileprivate func scrollToTop(animated: Bool) {
			setContentOffset(.init(x: contentOffset.x, y: -adjustedContentInset.top), animated: animated)
			if !animated {
				edgeTest() // otherwise it will be called in scrollViewDidEndScrollingAnimation()
			}
		}

		fileprivate func scrollToBottom(animated: Bool) {
			setContentOffset(.init(x: contentOffset.x, y: bottomContentOffsetY), animated: animated)
			if !animated {
				edgeTest()
			}
		}

		private func edgeTest() {
			guard !edgeLock else { return }
			let vicinity: Double = 200
			if isCloseToTop(within: vicinity) {
				edgeLock = true
				Task {
					await onApproachingEdge(.top)
					edgeLock = false
				}
			}
			else if isCloseToBottom(within: vicinity) {
				edgeLock = true
				Task {
					await onApproachingEdge(.bottom)
					edgeLock = false
				}
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

		private var pageHeight: Double {
			bounds.height - safeAreaInsets.top - safeAreaInsets.bottom
		}
	}
}


// MARK: - Preview

private let page = 20
private let cellSize = 50.0

#Preview {

	struct Preview: View {
		@State private var range = 0..<page
		@State private var action: InfiniteViewScrollAction? = .bottom(animated: false)
		@State private var headroom: Double = 0 // Double(page) * cellSize
		@State private var endOfData: Bool = false

		var body: some View {
			InfiniteView(headroom: headroom) {
				VStack(spacing: 0) {
					ForEach(range, id: \.self) { i in
						Text("Hello \(i + 1)")
							.frame(height: cellSize)
					}
				}
				.frame(maxWidth: .infinity)
				.background(Color(uiColor: .quaternarySystemFill))
			} onApproachingEdge: { edge in
				try? await Task.sleep(for: .seconds(1))
				switch edge {
					case .top:
						guard !endOfData else { return }
						endOfData = range.count > 60
						headroom += Double(page) * cellSize
						range = (range.lowerBound - page)..<range.upperBound
					case .bottom:
						range = range.lowerBound..<(range.upperBound + 5)
					default:
						break
				}
			}
			.scrollTo($action)
			.ignoresSafeArea()
		}
	}

	return Preview()
}
