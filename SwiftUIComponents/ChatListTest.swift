//
//  ChatListTest.swift
//  SwiftUIComponents
//
//  Created by Hovik Melikyan on 05.06.25.
//

import SwiftUI


private let page = 10
private let cellSize = 100.0


struct ChatListTest: View {

	private struct Item: ChatListItem {
		let index: Int
		var uiID: String { String(index) }
		var uiHeight: CGFloat { cellSize }
		static func from(range: Range<Int>) -> [Self] { range.map { Self(index: $0) } }
	}


	@State private var items: [Item] = []
	@State private var action: ChatListAction? = .bottom(animated: false)


	var body: some View {
		ChatList(items: items, action: $action) { item in
			HStack {
				Text("Row \(item.index)")
			}
			.frame(maxWidth: .infinity)
			.frame(height: cellSize)
			.background {
				Rectangle()
					.fill(.black.opacity(1 - Double(item.index + 100) / 100))
			}
			.overlay(alignment: .bottom) {
				Rectangle()
					.fill(.quaternary)
					.frame(height: 1)
			}
		} onLoadMore: { edge in
			switch edge {
				case .top:
					let first = items.first?.index ?? 0
					guard first > -100 else { return .eod }
					try? await Task.sleep(for: .seconds(1))
					items.insert(contentsOf: Item.from(range: (first - page)..<first), at: 0)
					print(Date.now, "added more above")
					return .hasMore
				case .bottom:
					let last = items.last?.index ?? 0
					guard last < 100 else { return .eod }
					try? await Task.sleep(for: .seconds(1))
					items.append(contentsOf: Item.from(range: (last + 1)..<(last + 1 + page)))
					print(Date.now, "added more below")
					return .hasMore
			}
		}
		.frame(maxWidth: .infinity, maxHeight: .infinity)
		.ignoresSafeArea()

		.toolbar {
			ToolbarItem(placement: .bottomBar) {
				Button {
					action = .bottom(animated: true)
				} label: {
					Image(systemName: "chevron.down")
				}
			}

			ToolbarItem(placement: .bottomBar) {
				Button {
					action = .scrollTo(id: "0", animated: true)
				} label: {
					Image(systemName: "minus")
				}
			}

			ToolbarItem(placement: .bottomBar) {
				Button {
					action = .top(animated: true)
				} label: {
					Image(systemName: "chevron.up")
				}
			}
		}

		.onAppear {
			items = Item.from(range: 0..<page)
		}
	}
}


#Preview {
	ChatListTest()
}
