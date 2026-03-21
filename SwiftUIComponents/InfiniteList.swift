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
/// chance to load additional items asynchronously. This closure should return `true` if it has more data.
///
/// See the preview at the bottom of this file for example usage.
struct InfiniteList<Content: View, Item: InfiniteListItem>: View {

	let items: [Item]
	@Binding var action: InfiniteViewAction?
	var edgeInsets: EdgeInsets = .zero
	@ViewBuilder let cellContent: (Item, _ frameInParent: CGRect) -> Content
	let onLoadMore: (VEdge) async -> Bool

	@State private var model = Model()


	var body: some View {
		GeometryReader { proxy in
			let headroom = model.calculateHeadroom(items: items)
			let frame = proxy.frame(in: .local)
			let hotFrame = frame
				.insetBy(dx: -frame.width / 2, dy: -frame.height / 2)
			InfiniteView(headroom: headroom, action: $action, edgeInsets: edgeInsets) {
				VStack(spacing: 0) {
					ForEach(items) { item in
						GeometryReader { itemProxy in
							Group {
								let frame = itemProxy.frame(in: .scrollView)
								if hotFrame.intersects(frame) {
									cellContent(item, frame)
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
				if (model.endOfData[edge] ?? .hasMore) == .hasMore {
					model.endOfData[edge] = await onLoadMore(edge) ? .hasMore : .eod
				}
			}
		}
	}


	@Observable fileprivate final class Model {
		enum EdgeStatus { case hasMore, eod }

		var endOfData: [VEdge: EdgeStatus] = [:]
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


extension InfiniteViewAction {

	static func item<Item: InfiniteListItem>(at: Int, in items: [Item], viewHeight: Double, align: VEdge = .top, animated: Bool = true) -> Self? {
		let item = items[at]
		guard let top = topOf(id: item.id, in: items) else {
			return nil
		}
		switch align {
			case .top:
				return .offset(top, animated: animated)
			case .bottom:
				return .offset(top - viewHeight + item.height, animated: animated)
		}
	}

	private static func topOf<Item: InfiniteListItem>(id: Item.ID, in items: [Item]) -> Double? {
		var top = 0.0
		for item in items {
			if item.id == id {
				return top
			}
			top += item.height
		}
		return nil
	}
}


// MARK: - Preview

private let page = 5
private let cellSize = 100.0

#Preview {

	struct Item: InfiniteListItem {
		let id: Int
		var height: Double { cellSize }
		static func from(range: Range<Int>) -> [Self] { range.map { Self(id: $0) } }
	}

	struct Preview: View {

		@State private var items = Item.from(range: 0..<page)
		@State private var action: InfiniteViewAction? = .bottom(animated: false)

		var body: some View {
			GeometryReader { proxy in
				InfiniteList(items: items, action: $action, edgeInsets: EdgeInsets(top: 200, leading: 0, bottom: 300, trailing: 0)) { item, _ in
					HStack {
						Text("Row \(item.id)")
					}
					.frame(maxWidth: .infinity, maxHeight: .infinity)
					.contentShape(Rectangle())
					.onTapGesture {
						guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
						action = .item(at: index, in: items, viewHeight: proxy.size.height, align: .top)
					}
					.overlay(alignment: .bottom) {
						Rectangle()
							.fill(.quaternary)
							.frame(height: 1)
					}
				} onLoadMore: { edge in
					switch edge {
						case .top:
							let first = items.first!
							guard first.id > -20 else { return false }
							try? await Task.sleep(for: .seconds(1))
							items.insert(contentsOf: Item.from(range: (first.id - page)..<first.id), at: 0)
							return true
						default:
							return false
					}
				}
				.ignoresSafeArea()
				.background(.quaternary.opacity(0.5))
			}

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
