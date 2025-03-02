//
//  InfiniteView.swift
//  SwiftUITest
//
//  Created by Hovik Melikyan on 02.03.25.
//

import SwiftUI


// Unfinished experiment

struct InfiniteView<Content: View, Data: RandomAccessCollection>: View where Data.Element: Identifiable {

	private let items: Data
	private let content: (Data.Element) -> Content


	init(_ items: Data, @ViewBuilder content: @escaping (Data.Element) -> Content) {
		self.items = items
		self.content = content
	}


	var body: some View {
		ScrollView {
			ForEach(items, content: content)
				.padding(.bottom, -100)
				.offset(y: -100)
		}
		.contentMargins(100, for: .scrollContent)
	}
}


#Preview {

	struct Item: Identifiable {
		let id: Int
	}

	struct Preview: View {

		var body: some View {
			let items = (0..<20).map { Item(id: $0) }
			InfiniteView(items) { item in
				Text("Hello \(item.id)")
					.frame(height: 50)
					.frame(maxWidth: .infinity)
			}
		}
	}

	return Preview()
}
