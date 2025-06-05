//
//  InfiniteListTest.swift
//  SwiftUIComponents
//
//  Created by Hovik Melikyan on 05.06.25.
//

import SwiftUI


private let page = 30
private let cellSize = 100.0



struct InfiniteListTest: View {
	@State private var range = 0..<page
	@State private var action: InfiniteViewAction? = .bottom(animated: false)

	private struct Item: InfiniteListItem {
		let id: Int
		var height: Double { cellSize }
		static func from(range: Range<Int>) -> [Self] { range.map { Self(id: $0) } }
	}


	var body: some View {
		InfiniteList(items: Item.from(range: range), action: $action) { item in
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
					guard range.lowerBound >= -90 else { return true }
					try? await Task.sleep(for: .seconds(1))
					range = (range.lowerBound - page)..<(range.upperBound)
					return false
				default:
					return true
			}
		}
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

//		InfiniteView(action: $action) {
//			VStack(spacing: 0) {
//				ForEach(range, id: \.self) { i in
//					Text("Hello \(i + 1)")
//						.frame(height: 50)
//				}
//			}
//		} onApproachingEdge: { edge in
//			switch edge {
//				case .top:
//					action = .didAddTopContent(height: 0)
//					range = (range.lowerBound - 20)..<range.upperBound
//				case .bottom:
//					range = range.lowerBound..<(range.upperBound + 5)
//				default:
//					break
//			}
//		}
//		.ignoresSafeArea()
	}
}


#Preview {
	InfiniteListTest()
}
