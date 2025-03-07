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


struct InfiniteView<Content: View, Items: RandomAccessCollection>: View where Items.Element: InfiniteViewItem {

	let items: Items
	let cellContent: (Items.Element) -> Content
	let onApproachingTop: () async -> Void
	@State private var action: InfiniteViewImplAction? = nil


	var body: some View {
		InfiniteViewImpl(action: $action) {
			VStack(spacing: 0) {
				ForEach(items) { item in
					cellContent(item)
						.frame(height: item.height)
				}
			}
			.frame(maxWidth: .infinity)
		} onApproachingEdge: { edge in
			if edge == .top {
				let previousTopId = items.first?.id
				await onApproachingTop()
				if let previousTopId {
					didUpdateItems(previousTopId: previousTopId)
				}
			}
		}
		.onAppear {
			action = .scrollToBottom(animated: false)
		}
	}


	private func didUpdateItems(previousTopId: Items.Element.ID) {
		// Determine how much should be added to the content top
		var extraHeight: Double = 0
		let index = items.firstIndex { item in
			if item.id == previousTopId { return true }
			extraHeight += item.height
			return false
		}
		if index != nil, extraHeight > 0 {
			action = .didAddTopContent(height: extraHeight)
		}
	}
}


struct InfiniteViewPreview: PreviewProvider {

	private struct Item: InfiniteViewItem {
		let id: Int
		var height: Double { 50 }

		static func from(range: Range<Int>) -> [Self] { range.map { Self(id: $0) } }
	}

	private struct Preview: View {

		@State private var items: [Item] = Item.from(range: 0..<20)
		@State private var endOfData: Bool = false

		var body: some View {
			InfiniteView(items: items) { item in
				Text("Hello \(item.id)")
			} onApproachingTop: {
				guard !endOfData else { return }
				endOfData = true
				items.insert(contentsOf: Item.from(range: -20..<0), at: 0)
			}
		}
	}

	static var previews: some View {
		Preview()
			.ignoresSafeArea()
	}
}
