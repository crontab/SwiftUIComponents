//
//  WrappedScrollView.swift
//
//  Created by Hovik Melikyan on 23.03.24.
//

import SwiftUI


enum ScrollViewAction {
	case idle
	case page(_ page: Int, animated: Bool)
}


struct ScrollViewState: Equatable {
	var view: UIScrollView?
	var page: Int = 0
}


struct WrappedScrollView<Content: View>: UIViewRepresentable {

	typealias RefreshAction = () async -> Void
	typealias OnScrollAction = (Double) -> Void

	@Binding private var action: ScrollViewAction
	@Binding private var state: ScrollViewState
	private let axis: Axis
	private let content: () -> Content
	private var refreshAction: RefreshAction?
	private var onScrollAction: OnScrollAction?


	init(_ axis: Axis, action: Binding<ScrollViewAction> = .constant(.idle), state: Binding<ScrollViewState> = .constant(.init()), @ViewBuilder content: @escaping () -> Content) {
		self._action = action
		self._state = state
		self.axis = axis
		self.content = content
	}


	func onRefresh(_ action: @escaping RefreshAction) -> Self {
		var view = self
		view.refreshAction = action
		return view
	}


	func onScroll(_ action: @escaping OnScrollAction) -> Self {
		var view = self
		view.onScrollAction = action
		return view
	}


	func makeUIView(context: Context) -> HostedScrollView {
		let host = UIHostingController(rootView: content())
		host.view.backgroundColor = .clear

		let scrollView = HostedScrollView(host: host, refreshAction: refreshAction)
		scrollView.isPagingEnabled = true
		scrollView.showsVerticalScrollIndicator = false
		scrollView.showsHorizontalScrollIndicator = false
		scrollView.delegate = context.coordinator

		scrollView.addSubview(host.view)

		Task {
			state.view = scrollView
		}

		return scrollView
	}


	func updateUIView(_ scrollView: HostedScrollView, context: Context) {
		scrollView.updateView(content: content)

		switch action {
			case .idle:
				break

			case .page(let page, let animated):
				DispatchQueue.main.async {
					let offset = Double(page) * (axis == .horizontal ? scrollView.bounds.width : scrollView.bounds.height)
					let size = axis == .horizontal ? scrollView.bounds.width : scrollView.bounds.height
					scrollView.setContentOffset(CGPoint(x: axis == .horizontal ? offset : 0, y: axis == .vertical ? offset : 0), animated: animated)
					if size > 0 {
						state.page = Int(round(offset / size))
					}
					Task {
						action = .idle
					}
				}
		}
	}


	func makeCoordinator() -> Coordinator {
		Coordinator(self)
	}


	final class Coordinator: NSObject, UIScrollViewDelegate {
		let parent: WrappedScrollView

		init(_ parent: WrappedScrollView) {
			self.parent = parent
		}

		func scrollViewDidScroll(_ scrollView: UIScrollView) {
			let size = parent.axis == .horizontal ? scrollView.bounds.width : scrollView.bounds.height
			if size > 0, scrollView.isTracking || scrollView.isDragging || scrollView.isDecelerating {
				// Triggered only if interactive
				Task {
					let offset = parent.axis == .horizontal ? scrollView.contentOffset.x : scrollView.contentOffset.y
					parent.state.page = Int(round(offset / size))
					parent.onScrollAction?(offset)
				}
			}
		}
	}


	final class HostedScrollView: UIScrollView {
		private let host: UIHostingController<Content>

		init(host: UIHostingController<Content>, refreshAction: RefreshAction?) {
			self.host = host
			super.init(frame: .zero)

			if let refreshAction {
				let refreshControl = UIRefreshControl()
				refreshControl.addAction(UIAction { [weak self]_ in
					guard let self else { return }
					Task {
						await refreshAction()
						refreshControl.endRefreshing()
						// Fix for the scroller not going all the way to the top if the parent view has ingoreSafeArea()
						self.setContentOffset(.init(x: 0, y: 0), animated: true)
					}
				}, for: .valueChanged)
				self.refreshControl = refreshControl
			}
		}

		required init?(coder: NSCoder) {
			preconditionFailure()
		}

		fileprivate func updateView(content: () -> Content) {
			host.rootView = content()
			host.view.sizeToFit()
			contentSize = host.view.bounds.size
		}
	}
}


// MARK: Lazy page for WrappedScrollView

struct LazyPage<C: View>: View {
	private let parentWidth, parentHeight: Double
	private let hotFrame: CGRect
	private let content: () -> C

	@State private var isVisible: Bool = false


	init(proxy: GeometryProxy, content: @escaping () -> C) {
		let frame = proxy.frame(in: .global)
		parentWidth = frame.width
		parentHeight = frame.height
		hotFrame = frame
			.insetBy(dx: -parentWidth / 2, dy: -parentHeight / 2)
		self.content = content
	}


	var body: some View {
		Group {
			if isVisible {
				content()
			}
			else {
				Color.clear
			}
		}

		// Ensure the cell always extends to the size of its parent
		.frame(width: parentWidth, height: parentHeight)

		// Empty overlay for tracking the real coordinates of this view
		.overlay {
			GeometryReader { proxy in
				let frame = proxy.frame(in: .global)
				Color.clear
					.onAppear {
						// This always loads the first two pages even if the initial page is set to non-zero a bit later
						isVisible = hotFrame.intersects(frame)
					}
					.onChange(of: frame) { oldValue, newValue in
						isVisible = hotFrame.intersects(newValue)
					}
			}
		}
	}
}


#Preview {
	GeometryReader { proxy in
		WrappedScrollView(.vertical, action: .constant(.page(0, animated: false))) {
			VStack(spacing: 0) {
				ForEach(0...5, id: \.self) { i in
					LazyPage(proxy: proxy) {
						Text("Page \(i)")
							.onAppear {
								print("Draw", i)
							}
					}
					.background(.gray.opacity(0.1))
				}
			}
		}
		.onRefresh {
			try? await Task.sleep(for: .seconds(2))
			print("Refresh")
		}
		.onScroll { offset in
			print("Offset", offset)
		}
	}
	.ignoresSafeArea()
}
