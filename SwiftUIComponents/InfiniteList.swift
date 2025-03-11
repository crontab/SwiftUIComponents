//
//  InfiniteList.swift
//
//  Created by Hovik Melikyan on 02.03.25.
//

import SwiftUI


protocol InfiniteListItem: Identifiable {
	var height: Double { get }
}


/// `InfiniteList`: a component based on `InfiniteView`; it maintains a potentially infinite scrollable list of
/// items with known height.
///
/// Each item should conform to `InfiniteListItem` and be `Identifiable` as well as should provide its height
/// on screen, considering the width of the item extends to the full width of the parent.
///
/// `cellContent` provides content for each item. The items are rendered in a "lazy" manner, i.e. only those that are
/// visible on the screen or are close to it are rendered. This helps with optimizing memory especially when items have
/// media such as images in them.
///
/// `onLoadMore` is a closure that's called whenever the scroller approaches its top or bottom edges; it gives you a
/// chance to load additional items asynchronously. This closure should return `true` if there's no more data left in
/// that direction.
///
/// The `scrollTo()` modifier can programmatically scroll to top or bottom, animated or not.
///
/// See the preview at the bottom of this file for example usage.
struct InfiniteList<Content: View, Item: InfiniteListItem>: View {

	private let items: [Item]
	@ViewBuilder private let cellContent: (Item) -> Content
	private let onLoadMore: (Edge) async -> Bool
	@State private var model = Model()
	@Binding var action: InfiniteViewAction?


	init(_ items: [Item], cellContent: @escaping (Item) -> Content, onLoadMore: @escaping (Edge) async -> Bool) {
		self.items = items
		self.cellContent = cellContent
		self.onLoadMore = onLoadMore
		self._action = .constant(nil)
	}


	func scrollTo(_ action: Binding<InfiniteViewAction?>) -> Self {
		var this = self
		this._action = action
		return this
	}


	var body: some View {
		GeometryReader { proxy in
			let headroom = model.calculateHeadroom(items: items)
			let frame = proxy.frame(in: .local)
			let hotFrame = frame
				.insetBy(dx: -frame.width / 2, dy: -frame.height / 2)
			InfiniteView(headroom: headroom) {
				VStack(spacing: 0) {
					ForEach(items) { item in
						GeometryReader { itemProxy in
							Group {
								let frame = itemProxy.frame(in: .scrollView)
								if hotFrame.intersects(frame) {
									cellContent(item)
								}
								else {
									Color.clear
								}
							}
							.frame(maxWidth: .infinity, maxHeight: .infinity)
						}
						.frame(height: item.height)
					}
				}
			} onApproachingEdge: { edge in
				guard !(model.endOfData[edge] ?? false) else { return }
				model.endOfData[edge] = await onLoadMore(edge)
			}
			.scrollTo($action)
		}
	}


	@Observable fileprivate final class Model {
		var endOfData: [Edge: Bool] = [:]
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
		@State private var action: InfiniteViewAction? = .bottom(animated: false)

		var body: some View {
			InfiniteList(Item.from(range: range)) { item in
				HStack {
					Text("Row \(item.id)")
				}
				.frame(maxWidth: .infinity, maxHeight: .infinity)
				.overlay(alignment: .bottom) {
					Rectangle()
						.fill(.quaternary)
						.frame(height: 1)
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
			.scrollTo($action)
			.ignoresSafeArea()

			.overlay(alignment: .bottomTrailing) {
				Button {
					action = .bottom(animated: true)
				} label: {
					Circle()
						.fill(.background)
						.shadow(color: Color(uiColor: .placeholderText), radius: 3, y: 1)
						.frame(width: 44)
						.padding(24)
						.overlay {
							Image(systemName: "chevron.down")
								.offset(y: 2)
						}
				}
			}
		}
	}

	return Preview()
}
