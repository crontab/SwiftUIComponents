//
//  InfiniteView.swift
//  SwiftUITest
//
//  Created by Hovik Melikyan on 02.03.25.
//

import SwiftUI


protocol InfiniteViewItem: Sendable, Identifiable {
	var height: Double { get }
}


struct InfiniteView<Content: View, Item: InfiniteViewItem>: View {

	@ViewBuilder let cellContent: (Item) -> Content
	let onLoadMore: () async -> [Item]
	@State private var items: [Item] = []
	@State private var headroom: Double = 0
	@State private var endOfData: Bool = false
	@State private var action: InfiniteViewScrollAction? = nil


	var body: some View {
		InfiniteViewImpl(headroom: headroom) {
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
				let newItems = await onLoadMore()
				endOfData = newItems.isEmpty
				items.insert(contentsOf: newItems, at: 0)
				headroom += newItems.height
			}
		}
		.scrollTo($action)
		.task {
			// Initial batch
			items = await onLoadMore()
			endOfData = items.isEmpty
			action = .bottom(animated: false)
		}
	}
}


private extension Array where Element: InfiniteViewItem {
	var height: Double {
		reduce(0) { $0 + $1.height }
	}
}


// MARK: - Preview

private let page = 20
private let cellSize = 50.0

struct InfiniteViewPreview: PreviewProvider {

	private struct Item: InfiniteViewItem {
		let id: Int
		var height: Double { cellSize }
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
					lower -= page
				}
				return Item.from(range: lower..<(lower + page))
			}
		}
	}

	static var previews: some View {
		Preview()
			.ignoresSafeArea()
	}
}
