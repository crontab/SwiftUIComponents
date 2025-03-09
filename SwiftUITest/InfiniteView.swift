//
//  InfiniteView.swift
//  SwiftUITest
//
//  Created by Hovik Melikyan on 02.03.25.
//

import SwiftUI

/*
protocol InfiniteViewItem: Sendable, Identifiable {
	var height: Double { get }
}


struct InfiniteView<Content: View, Item: InfiniteViewItem>: View {

	@ViewBuilder let cellContent: (Item) -> Content
	let onLoadMore: () async -> [Item]
	@State private var items: [Item] = []
	@State private var endOfData: Bool = false
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
				guard !endOfData else { return }
				let previousTopId = items.first?.id
				let newItems = await onLoadMore()
				endOfData = newItems.isEmpty
				items.insert(contentsOf: newItems, at: 0)
				if let previousTopId {
					didUpdateItems(previousTopId: previousTopId)
				}
			}
		}
		.task {
			items = await onLoadMore()
			endOfData = items.isEmpty
			action = .scrollToBottom(animated: false)
		}
	}


	private func didUpdateItems(previousTopId: Item.ID) {
		// Determine how much should be added to the content top
		var extraHeight: Double = 0
		let index = items.firstIndex { item in
			if item.id == previousTopId { return true }
			extraHeight += item.height
			return false
		}
		if index != nil, extraHeight > 0 {
			action = .didAddTopContent(height: extraHeight)
			print("action:", action ?? "-")
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

		@State private var lower: Int = 0

		var body: some View {
			InfiniteView { (item: Item) in
				Text("Hello \(item.id)")
			} onLoadMore: {
				guard lower >= -60 else { return [] }
				try? await Task.sleep(for: .seconds(1))
				defer {
					lower -= 20
				}
				return Item.from(range: lower..<(lower + 20))
			}
		}
	}

	static var previews: some View {
		Preview()
			.ignoresSafeArea()
	}
}
*/
