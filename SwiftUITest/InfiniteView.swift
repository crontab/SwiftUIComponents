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


struct InfiniteView<Content: View, Item: InfiniteViewItem>: View {

	private let items: [Item]
	@ViewBuilder private let cellContent: (Item) -> Content
	private let onLoadMore: () async -> Bool
	@State private var model = Model()


	init(_ items: [Item], cellContent: @escaping (Item) -> Content, onLoadMore: @escaping () async -> Bool) {
		self.items = items
		self.cellContent = cellContent
		self.onLoadMore = onLoadMore
	}


	var body: some View {
		let headroom = model.calculateHeadroom(items: items)
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
				guard !model.endOfData else { return }
				model.endOfData = await onLoadMore()
			}
		}
		.scrollTo($model.action)
		.onAppear {
			model.action = .bottom(animated: false)
		}
	}


	@Observable fileprivate final class Model {
		var endOfData: Bool = false
		var action: InfiniteViewScrollAction? = nil
		private var previousTopId: Item.ID?
		private var headroom: Double = 0

		func calculateHeadroom(items: [Item]) -> Double {
			if previousTopId != items.first?.id {
				if let id = previousTopId {
					var extraHeight: Double = 0
					let index = items.firstIndex { item in
						if item.id == id { return true }
						extraHeight += item.height
						return false
					}
					if index != nil, extraHeight > 0 {
						self.headroom += extraHeight
					}
				}
				previousTopId = items.first?.id // careful with triggering an update
			}
			return headroom
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

#Preview {

	struct Item: InfiniteViewItem {
		let id: Int
		var height: Double { cellSize }
		static func from(range: Range<Int>) -> [Self] { range.map { Self(id: $0) } }
	}

	struct Preview: View {

		@State private var range = 0..<page

		var body: some View {
			InfiniteView(Item.from(range: range)) { item in
				Text("Hello \(item.id)")
			} onLoadMore: {
				guard range.lowerBound >= -60 else { return true }
				try? await Task.sleep(for: .seconds(1))
				range = (range.lowerBound - page)..<(range.upperBound)
				return false
			}
		}
	}

	return Preview()
		.ignoresSafeArea()
}
