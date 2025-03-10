//
//  InfiniteList.swift
//  SwiftUITest
//
//  Created by Hovik Melikyan on 02.03.25.
//

import SwiftUI


protocol InfiniteListItem: Identifiable {
	var height: Double { get }
}


struct InfiniteList<Content: View, Item: InfiniteListItem>: View {

	private let items: [Item]
	@ViewBuilder private let cellContent: (Item) -> Content
	private let onLoadMore: (Edge) async -> Bool
	@State private var model = Model()


	init(_ items: [Item], cellContent: @escaping (Item) -> Content, onLoadMore: @escaping (Edge) async -> Bool) {
		self.items = items
		self.cellContent = cellContent
		self.onLoadMore = onLoadMore
	}


	var body: some View {
		let headroom = model.calculateHeadroom(items: items)
		InfiniteView(headroom: headroom) {
			VStack(spacing: 0) {
				ForEach(items) { item in
					cellContent(item)
						.frame(height: item.height)
				}
			}
			.frame(maxWidth: .infinity)
		} onApproachingEdge: { edge in
			guard !(model.endOfData[edge] ?? false) else { return }
			model.endOfData[edge] = await onLoadMore(edge)
		}
		.scrollTo($model.action)
		.onAppear {
			model.action = .bottom(animated: false)
		}
	}


	@Observable fileprivate final class Model {
		var endOfData: [Edge: Bool] = [:]
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


struct LazyCell<Content: View, Item: InfiniteListItem>: View {

	private let item: Item
	private let content: () -> Content
	private let hotFrame: CGRect
	@State private var isVisible: Bool = false

	init(item: Item, parent: GeometryProxy, content: @escaping () -> Content) {
		self.item = item
		self.content = content
		let frame = parent.frame(in: .scrollView)
		self.hotFrame = frame
			.insetBy(dx: -frame.width / 2, dy: -frame.height / 2)
	}

	var body: some View {
		Group {
			if isVisible {
				content()
			}
			else {
				Color.clear
			}
		}
		.frame(height: item.height)
		.frame(maxWidth: .infinity)
		.overlay {
			// Empty overlay for tracking the real coordinates of this view
			GeometryReader { proxy in
				let frame = proxy.frame(in: .scrollView)
				Color.clear
					.onChange(of: frame) { _, frame in
						isVisible = hotFrame.intersects(frame)
					}
			}
		}
	}
}


private extension Array where Element: InfiniteListItem {
	var height: Double {
		reduce(0) { $0 + $1.height }
	}
}


// MARK: - Preview

private let page = 20
private let cellSize = 100.0

#Preview {

	struct Item: InfiniteListItem {
		let id: Int
		var height: Double { cellSize }
		static func from(range: Range<Int>) -> [Self] { range.map { Self(id: $0) } }
	}

	struct Preview: View {

		@State private var range = 0..<page

		var body: some View {
			GeometryReader { proxy in
				InfiniteList(Item.from(range: range)) { item in
					LazyCell(item: item, parent: proxy) {
						Text("Hello \(item.id)")
					}
				} onLoadMore: { edge in
					switch edge {
						case .top:
							guard range.lowerBound >= -60 else { return true }
							try? await Task.sleep(for: .seconds(1))
							range = (range.lowerBound - page)..<(range.upperBound)
							return false
						default:
							return true
					}
				}
			}
		}
	}

	return Preview()
		.ignoresSafeArea()
}
