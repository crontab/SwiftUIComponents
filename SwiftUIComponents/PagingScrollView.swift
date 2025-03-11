//
//  PagingScrollView.swift
//
//  Created by Hovik Melikyan on 23.03.24.
//

import SwiftUI


// This is a SwiftUI wrapper around UIScrollView that provides paging functionality (scroll and snap to a page the size
// of the view itself) for iOS versions prior to 17. Tested on iOS 16 with Swift 5.10.
//
// Use the binding `action` argument to move the scroller to a specified position. The binding `state` argument is for
// the scroller's feedback: it returns the underlying UIScrollView object in case you need to additionally configure
// it, and also the current page number which is updated as the user drags the scroller.
//
// The `refreshAction()` modifier acts like SwiftUI's `refreshable()`.
//
// `LazyPage()` provides a lazy rendering mechanism for PagingScrollView. You can wrap the contents of each page into
// this view, presumably within a `ForEach()` loop. The reason this component exists is that `LazyXView()` standard
// components don't work as intended under our PagingScrollView, since they expect the parent view to be SwiftUI's
// native `ScrollView` instead.
//
// (And sorry for the tabs, I like them though I know those who use spaces earn more money on average 😜)


enum ScrollViewAction {
	case idle
	case page(_ page: Int, animated: Bool)
}


struct ScrollViewState: Equatable {
	var view: UIScrollView?
	var page: Int = 0
}


struct PagingScrollView<Content: View>: UIViewRepresentable {

	typealias RefreshAction = () async -> Void

	@Binding private var action: ScrollViewAction
	@Binding private var state: ScrollViewState
	private let axis: Axis
	private let content: () -> Content
	private var refreshAction: RefreshAction?


	init(_ axis: Axis, action: Binding<ScrollViewAction> = .constant(.idle), state: Binding<ScrollViewState> = .constant(.init()), @ViewBuilder content: @escaping () -> Content) {
		self._action = action
		self._state = state
		self.axis = axis
		self.content = content
	}


	func refreshAction(_ action: @escaping RefreshAction) -> Self {
		var view = self
		view.refreshAction = action
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
		let parent: PagingScrollView

		init(_ parent: PagingScrollView) {
			self.parent = parent
		}

		func scrollViewDidScroll(_ scrollView: UIScrollView) {
			let size = parent.axis == .horizontal ? scrollView.bounds.width : scrollView.bounds.height
			if size > 0, scrollView.isTracking || scrollView.isDragging || scrollView.isDecelerating {
				// Triggered only if interactive
				Task {
					let offset = parent.axis == .horizontal ? scrollView.contentOffset.x : scrollView.contentOffset.y
					parent.state.page = Int(round(offset / size))
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
			fatalError("init(coder:) has not been implemented")
		}

		fileprivate func updateView(content: () -> Content) {
			host.rootView = content()
			host.view.sizeToFit()
			contentSize = host.view.bounds.size
		}
	}
}


// MARK: Lazy page for PagingScrollView

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
					.onChange(of: frame) { old, new in
						isVisible = hotFrame.intersects(new)
					}
			}
		}
	}
}


#Preview {
	GeometryReader { proxy in
		PagingScrollView(.vertical, action: .constant(.page(0, animated: false))) {
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
		.refreshAction {
			try? await Task.sleep(for: .seconds(2))
			print("Refresh")
		}
	}
	.ignoresSafeArea()
}
