//
//  InfiniteViewImpl.swift
//
//  Created by Hovik Melikyan on 28.02.25.
//

import SwiftUI


enum InfiniteViewImplAction: Equatable {
	case scrollToTop(animated: Bool)
	case scrollToBottom(animated: Bool)
	case didAddTopContent(height: Double) // 0 means calculate automatically
}


struct InfiniteViewImpl<Content: View>: UIViewRepresentable {

	typealias OnApproachingEdge = (Edge) async -> Void

	@Binding private var action: InfiniteViewImplAction?
	private var onApproachingEdge: OnApproachingEdge? = nil // currently only `top` and `bottom` and only during interactive action
	private let content: () -> Content


	init(action: Binding<InfiniteViewImplAction?> = .constant(nil), content: @escaping () -> Content) {
		self._action = action
		self.content = content
	}


	func onApproachingEdge(_ action: @escaping OnApproachingEdge) -> Self {
		var this = self
		this.onApproachingEdge = action
		return this
	}


	func makeUIView(context: Context) -> HostedScrollView {
		return HostedScrollView(content: content, onApproachingEdge: onApproachingEdge)
	}


	func updateUIView(_ scrollView: HostedScrollView, context: Context) {
		switch action {
			case .none:
				scrollView.updateView(content: content)

			case .scrollToTop(let animated):
				scrollView.updateView(content: content)
				Task {
					scrollView.scrollToTop(animated: animated)
				}

			case .scrollToBottom(let animated):
				scrollView.updateView(content: content)
				Task {
					scrollView.scrollToBottom(animated: animated)
				}

			case .didAddTopContent(let height):
				scrollView.updateView(topContent: height, content: content)
		}

		action = nil
	}


	final class HostedScrollView: UIScrollView, UIScrollViewDelegate {
		private let host: UIHostingController<Content>
		private let onApproachingEdge: OnApproachingEdge?
		private var edgeLock: Bool = false


		init(content: () -> Content, onApproachingEdge: OnApproachingEdge?) {
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


		fileprivate func updateView(topContent: Double? = nil, content: () -> Content) {
			let oldHeight = host.view.bounds.height
			host.rootView = content()
			frame.size.width = 0 // this is required on the Mac for some reason
			host.view.sizeToFit()
			let newHeight = host.view.bounds.height
			if let topContent { // expand up
				let d = topContent > 0 ? topContent : newHeight - contentSize.height
				host.view.frame.origin.y = -d
				contentInset.top = d
			}
			else { // expand down
				contentSize.height += newHeight - oldHeight
			}
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
			guard let onApproachingEdge else { return }
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

//		private var pageHeight: Double {
//			bounds.height - adjustedContentInset.top - adjustedContentInset.bottom
//		}
	}
}


// MARK: - Preview

struct InfiniteScrollerPreview: PreviewProvider {

	private struct Preview: View {
		@State private var range = 0..<20
		@State private var action: InfiniteViewImplAction? = .scrollToBottom(animated: false)

		var body: some View {
			InfiniteViewImpl(action: $action) {
				VStack(spacing: 0) {
					ForEach(range, id: \.self) { i in
						Text("Hello \(i + 1)")
							.frame(height: 50)
					}
				}
				.frame(maxWidth: .infinity)
				.background(Color(uiColor: .quaternarySystemFill))
			}
			.onApproachingEdge { edge in
				try? await Task.sleep(for: .seconds(1))
				switch edge {
					case .top:
						action = .didAddTopContent(height: 0)
						range = (range.lowerBound - 20)..<range.upperBound
					case .bottom:
						range = range.lowerBound..<(range.upperBound + 5)
					default:
						break
				}
			}
			.ignoresSafeArea()
		}
	}

	static var previews: some View {
		Preview()
	}
}
