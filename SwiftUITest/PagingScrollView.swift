//
//  PagingScrollView.swift
//  PepQuotes
//
//  Created by Hovik Melikyan on 23.03.24.
//

import SwiftUI


// Scroll view with paging that exposes its underlying UIKit view. Can be used for e.g. installing gesture recognizers that are impossible in pure SwiftUI.


enum ScrollViewAction {
	case idle
	case page(_ page: Int, animated: Bool)
}


struct ScrollViewState: Equatable {
	var view: UIScrollView?
	var page: Int = 0
}


struct PagingScrollView<Content: View>: UIViewRepresentable {

	@Binding private var action: ScrollViewAction
	@Binding private var state: ScrollViewState
	private let axis: Axis
	private let content: () -> Content
	private var removeSafeArea: Bool = false


	init(_ axis: Axis, action: Binding<ScrollViewAction> = .constant(.idle), state: Binding<ScrollViewState> = .constant(.init()), @ViewBuilder content: @escaping () -> Content) {
		self._action = action
		self._state = state
		self.axis = axis
		self.content = content
	}


	func removesSafeArea() -> some View {
		var view = self
		view.removeSafeArea = true
		return view.ignoresSafeArea()
	}


	func makeUIView(context: Context) -> HostedScrollView {
		let host = UIHostingController(rootView: content())
		host.view.backgroundColor = .clear

		let scrollView = HostedScrollView(host: host, ignoreSafeArea: removeSafeArea)
		scrollView.isPagingEnabled = true
		scrollView.showsVerticalScrollIndicator = false
		scrollView.showsHorizontalScrollIndicator = false
		scrollView.contentInsetAdjustmentBehavior = removeSafeArea ? .never : .automatic
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
					scrollView.setContentOffset(CGPoint(x: axis == .horizontal ? offset : 0, y: axis == .vertical ? offset : 0), animated: animated)
					Task {
						action = .idle
					}
				}
		}
	}


	func makeCoordinator() -> Coordinator {
		Coordinator(self)
	}


	class Coordinator: NSObject, UIScrollViewDelegate {
		let parent: PagingScrollView

		init(_ parent: PagingScrollView) {
			self.parent = parent
		}

		func scrollViewDidScroll(_ scrollView: UIScrollView) {
			let size = parent.axis == .horizontal ? scrollView.bounds.width : scrollView.bounds.height
			if size > 0 {
				Task {
					let offset = parent.axis == .horizontal ? scrollView.contentOffset.x : scrollView.contentOffset.y
					parent.state.page = Int(round(offset / size))
				}
			}
		}
	}


	class HostedScrollView: UIScrollView {
		private let host: UIHostingController<Content>
		private let ignoreSafeArea: Bool

		init(host: UIHostingController<Content>, ignoreSafeArea: Bool) {
			self.host = host
			self.ignoreSafeArea = ignoreSafeArea
			super.init(frame: .zero)
		}

		required init?(coder: NSCoder) {
			fatalError("init(coder:) has not been implemented")
		}

		override var safeAreaInsets: UIEdgeInsets { ignoreSafeArea ? .zero : super.safeAreaInsets }

		fileprivate func updateView(content: () -> Content) {
			host.rootView = content()
			host.view.sizeToFit()
			contentSize = host.view.bounds.size
		}
	}
}


#Preview {
	GeometryReader { proxy in
		PagingScrollView(.vertical, action: .constant(.page(2, animated: false))) {
			VStack(spacing: 0) {
				ForEach([1, 2, 3, 4, 5], id: \.self) { i in
					Text("Page \(i)")
						.frame(width: proxy.size.width, height: proxy.size.height)
						.background(.gray.opacity(0.15))
				}
			}
		}
		.removesSafeArea()
		.background(.gray.opacity(0.15))
	}
	.ignoresSafeArea()
}
