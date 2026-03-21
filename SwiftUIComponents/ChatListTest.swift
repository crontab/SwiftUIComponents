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
		static func from(range: Range<Int>) -> [Self] { range.map { Self(index: $0) } }
	}


	@State private var items: [Item] = Item.from(range: 0..<page)
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
					let first = items.first!
					guard first.index > -100 else { return .eod }
					try? await Task.sleep(for: .seconds(1))
					items.insert(contentsOf: Item.from(range: (first.index - page)..<first.index), at: 0)
					print(Date.now, "added more above")
					return .hasMore
				case .bottom:
					return .eod
			}
		}
		.frame(maxWidth: .infinity, maxHeight: .infinity)
		.ignoresSafeArea()

		.overlay(alignment: .bottomTrailing) {
			Button {
				action = .bottom(animated: true)
			} label: {
				Circle()
					.fill(.background)
					.shadow(color: .secondary.opacity(0.2), radius: 3, y: 2)
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


#Preview {
	ChatListTest()
}
