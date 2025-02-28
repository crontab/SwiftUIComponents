//
//  InfiniteScroller.swift
//  SwiftUITest
//
//  Created by Hovik Melikyan on 28.02.25.
//

import SwiftUI


struct InfiniteScroller<Content: View>: UIViewRepresentable {

	let content: () -> Content


	func makeUIView(context: Context) -> HostedScrollView {
		return HostedScrollView(content: content)
	}


	func updateUIView(_ scrollView: HostedScrollView, context: Context) {
		scrollView.updateView(content: content)
	}


	final class HostedScrollView: UIScrollView {
		private let host: UIHostingController<Content>

		init(content: () -> Content) {
			host = UIHostingController(rootView: content())
			super.init(frame: .zero)
			addSubview(host.view)

			alwaysBounceVertical = true

			host.view.backgroundColor = .quaternarySystemFill
			host.view.autoresizingMask = [.flexibleWidth]
		}

		required init?(coder: NSCoder) {
			preconditionFailure()
		}

		fileprivate func updateView(content: () -> Content) {
			host.rootView = content()
			host.view.sizeToFit()
			frame.size.width = 0
			contentSize = host.view.bounds.size
		}
	}
}


#Preview {
	@Previewable @State var total: Int = 2

	InfiniteScroller {
		VStack(spacing: 0) {
			ForEach(0..<total, id: \.self) { i in
				Text("Hello \(i + 1)")
					.frame(height: 50)
			}
			Button("Add") {
				total += 2
			}
			.frame(height: 50)
		}
	}
	.ignoresSafeArea()
}
