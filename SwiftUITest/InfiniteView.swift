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
	@State private var model = Model()


	var body: some View {
		InfiniteViewImpl(headroom: model.headroom) {
			VStack(spacing: 0) {
				ForEach(model.items) { item in
					cellContent(item)
						.frame(height: item.height)
				}
			}
			.frame(maxWidth: .infinity)
		} onApproachingEdge: { edge in
			if edge == .top {
				guard !model.endOfData else { return }
				let newItems = await onLoadMore()
				model.endOfData = newItems.isEmpty
				model.items.insert(contentsOf: newItems, at: 0)
				model.headroom += newItems.height
			}
		}
		.scrollTo($model.action)
		.task {
			// Initial batch
			model.items = await onLoadMore()
			model.endOfData = model.items.isEmpty
			model.action = .bottom(animated: false)
		}
	}

	@Observable fileprivate final class Model {
		var items: [Item] = []
		var headroom: Double = 0
		var endOfData: Bool = false
		var action: InfiniteViewScrollAction? = nil
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

#Preview {

	struct Item: InfiniteViewItem {
		let id: Int
		var height: Double { cellSize }
		static func from(range: Range<Int>) -> [Self] { range.map { Self(id: $0) } }
	}

	struct Preview: View {

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

	return Preview()
		.ignoresSafeArea()
}
