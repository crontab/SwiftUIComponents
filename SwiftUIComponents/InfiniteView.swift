//
//  InfiniteView.swift
//
//  Created by Hovik Melikyan on 28.02.25.
//

import SwiftUI


enum InfiniteViewAction {
	case top(animated: Bool)
	case bottom(animated: Bool)
}


/// `InfiniteView`: a view that can extend its top and bottom contents without disrupting the interactive scrolling.
/// Useful for chat apps. Currently only vertical scrolling is supported.
///
/// You can add cotnent to the top of the scroll content and specify the overall height of the additional content using the
/// `headroom` parameter. The scroller will maintain its position even if the update happens during interactive scrolling.
///
/// The `onApproachingEdge` closure is called whenever the user approaches top or bottom edges of the content
/// while scrolling. This closure is `async`, meaning that you can perform e.g. a network call for additional data.
///
/// Check out the preview of this view at the bottom of the file for example usage.
///
/// See also: `InfiniteList`, a component based on `InfiniteView`.
struct InfiniteView<Content: View>: UIViewRepresentable {

	let headroom: Double
	@Binding var action: InfiniteViewAction?
	var edgeInsets: EdgeInsets = .zero
	let content: () -> Content
	let onApproachingEdge: (Edge) async -> Void // currently only `.top` and `.bottom`; triggered within half a screen from the edge


	func makeUIView(context: Context) -> HostedScrollView {
		return HostedScrollView(content: content, onApproachingEdge: onApproachingEdge)
	}


	func updateUIView(_ scrollView: HostedScrollView, context: Context) {
		scrollView.updateView(headroom: headroom, edgeInsets: edgeInsets, content: content)

		switch action {
			case .none:
				break

			case .top(let animated):
				Task {
					scrollView.scrollToTop(animated: animated)
					action = nil
				}

			case .bottom(let animated):
				Task {
					scrollView.scrollToBottom(animated: animated)
					action = nil
				}
		}
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


		fileprivate func updateView(headroom: Double, edgeInsets: EdgeInsets, content: () -> Content) {
			host.rootView = content()
			frame.size.width = 0 // this is required on the Mac for some reason
			host.view.sizeToFit()
			let newHeight = host.view.bounds.height
			let blankSpace = max(0, pageHeight - newHeight - edgeInsets.top - edgeInsets.bottom) // ensure small content is at the bottom
			host.view.frame.origin.y = -headroom
			var edgeInsets = edgeInsets.uiEdgeInsets
			edgeInsets.top += headroom + blankSpace
			contentInset = edgeInsets
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

		private func edgeTest(recurse: Int = 0) {
			guard !edgeLock else { return }
			guard recurse < 4 else { return }
			let vicinity = max(bounds.height / 2, 200)
			if isCloseToTop(within: vicinity) {
				edgeLock = true
				Task {
					await onApproachingEdge(.top)
					edgeLock = false
					edgeTest(recurse: recurse + 1)
				}
			}
			else if isCloseToBottom(within: vicinity) {
				edgeLock = true
				Task {
					await onApproachingEdge(.bottom)
					edgeLock = false
					edgeTest(recurse: recurse + 1)
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


extension EdgeInsets {
	static var zero: Self { .init(top: 0, leading: 0, bottom: 0, trailing: 0) }

	var uiEdgeInsets: UIEdgeInsets { .init(top: top, left: leading, bottom: bottom, right: trailing) }
}


// MARK: - Preview

private let page = 20
private let cellSize = 50.0

#Preview {

	struct Preview: View {
		@State private var range = 0..<page
		@State private var action: InfiniteViewAction? = .bottom(animated: false)
		@State private var headroom: Double = 0 // Double(page) * cellSize
		@State private var endOfData: Bool = false

		var body: some View {
			InfiniteView(headroom: headroom, action: $action) {
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
			.ignoresSafeArea()
		}
	}

	return Preview()
}
