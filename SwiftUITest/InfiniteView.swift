//
//  InfiniteView.swift
//  SwiftUITest
//
//  Created by Hovik Melikyan on 02.03.25.
//

import SwiftUI


protocol InfiniteViewItem: Identifiable {
	var height: Double { get }
}


struct InfiniteView<Content: View, Data: RandomAccessCollection>: View where Data.Element: InfiniteViewItem {

	private let items: Data
	private let content: (Data.Element) -> Content


	init(_ items: Data, @ViewBuilder content: @escaping (Data.Element) -> Content) {
		self.items = items
		self.content = content
	}


	var body: some View {
		InfiniteViewImpl {
			VStack(spacing: 0) {
				ForEach(items) { item in
					content(item)
						.frame(height: item.height)
						.frame(maxWidth: .infinity)
				}
			}
		}
	}
}


struct InfiniteViewPreview: PreviewProvider {

	private struct Item: InfiniteViewItem {
		let id: Int
		var height: Double { 50 }
	}

	private struct Preview: View {

		var body: some View {
			let items = (0..<20).map { Item(id: $0) }
			InfiniteView(items) { item in
				Text("Hello \(item.id)")
			}
		}
	}

	static var previews: some View {
		Preview()
			.ignoresSafeArea()
	}
}
