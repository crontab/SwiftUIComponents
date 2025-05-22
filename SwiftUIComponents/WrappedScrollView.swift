//
//  WrappedScrollView.swift
//
//  Created by Hovik Melikyan on 22.05.25.
//

import SwiftUI


enum ScrollViewAction {
	case idle
	case offset(_ offset: Double, animated: Bool = false)
}


struct WrappedScrollView<Content: View>: UIViewRepresentable {

	typealias OnScrollAction = (Double) -> Void

	private let axis: Axis
	@Binding private var action: ScrollViewAction
	private let content: () -> Content
	private var onScrollAction: OnScrollAction?
	private var ignoreSafeArea: Bool = false


	init(_ axis: Axis = .vertical, action: Binding<ScrollViewAction> = .constant(.idle), @ViewBuilder content: @escaping () -> Content) {
		self.axis = axis
		self._action = action
		self.content = content
	}


	func onScroll(_ action: @escaping OnScrollAction) -> Self {
		var view = self
		view.onScrollAction = action
		return view
	}


	func contentIgnoresSafeArea() -> Self {
		var view = self
		view.ignoreSafeArea = true
		return view
	}


	func makeUIView(context: Context) -> HostedScrollView {
		let host = UIHostingController(rootView: content())
		host.view.backgroundColor = .clear

		let scrollView = HostedScrollView(host: host, ignoreSafeArea: ignoreSafeArea)
		scrollView.showsVerticalScrollIndicator = false
		scrollView.showsHorizontalScrollIndicator = false
		scrollView.delegate = context.coordinator

		host.view.translatesAutoresizingMaskIntoConstraints = false
		scrollView.addSubview(host.view)

		NSLayoutConstraint.activate([
			host.view.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
			host.view.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
			host.view.topAnchor.constraint(equalTo: scrollView.topAnchor),
			host.view.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
			host.view.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
		])

		return scrollView
	}


	func updateUIView(_ scrollView: HostedScrollView, context: Context) {
		scrollView.updateView(content: content)

		switch action {
			case .idle:
				break

			case .offset(let offset, let animated):
				Task { @MainActor in
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
					parent.onScrollAction?(offset)
				}
			}
		}
	}


	final class HostedScrollView: UIScrollView {
		private let host: UIHostingController<Content>
		private let ignoreSafeArea: Bool

		init(host: UIHostingController<Content>, ignoreSafeArea: Bool) {
			self.host = host
			self.ignoreSafeArea = ignoreSafeArea
			super.init(frame: .zero)
		}

		override var safeAreaInsets: UIEdgeInsets {
			ignoreSafeArea ? .zero : super.safeAreaInsets
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


// MARK: Lazy cell for WrappedScrollView

struct LazyCell<C: View>: View {
	private let hotFrame: CGRect
	private let content: () -> C

	@State private var isVisible: Bool = false


	init(content: @escaping () -> C) {
		let screen = UIScreen.main.bounds
		hotFrame = screen
			.insetBy(dx: -screen.width / 2, dy: -screen.height / 2)
		self.content = content
	}


	var body: some View {
		GeometryReader { proxy in // NB: this somehow also helps with rendering the cells only once and not with each scroll move, so don't touch it
			let frame = proxy.frame(in: .global)
			Group {
				if isVisible {
					content()
						.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
				}
				else {
					Color.clear
				}
			}
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


#Preview {
	WrappedScrollView(action: .constant(.offset(2000))) {
		VStack(spacing: 0) {
			ForEach(0...5, id: \.self) { i in
				LazyCell {
					VStack {
						Text("Page \(i)")
							.onAppear {
								print("Draw", i)
							}
					}
				}
				.frame(height: 600)
				.background(.quaternary)
				.border(.quaternary)
				.clipped()
			}
		}
	}
	.onScroll { offset in
//		print("Offset", offset)
	}
	.contentIgnoresSafeArea()
	.ignoresSafeArea()
}
