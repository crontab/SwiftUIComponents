//
//  ChatView.swift
//
//  Created by Hovik Melikyan on 20.03.26.
//

import SwiftUI


protocol ChatViewItem {
	typealias ID = String
	var height: Double { get }
	var uiId: ID { get }
}


private let EdgeVicinity = 500.0


struct ChatView<Content: View, Item: ChatViewItem>: View {
	let items: [Item]
	@ViewBuilder let cellContent: (Item) -> Content
	let onLoadMore: (VEdge) async -> EdgeStatus

	@State private var edgeStatuses: [VEdge: EdgeStatus] = [:]

	@State private var position: ScrollPosition = .init(idType: Item.ID.self, edge: .bottom)

	@State private var edgeLock: Bool = false
	@State private var isInitialLoad = true

	var body: some View {
		ScrollView {
			LazyVStack(spacing: 0) {
				ForEach(items, id: \.uiId) { item in
					cellContent(item)
				}
			}
			.scrollTargetLayout()
		}
		.scrollPosition($position)

		.onScrollGeometryChange(for: Double.self) { geo in
			geo.contentOffset.y + geo.contentInsets.top
		} action: { _, new in
			// Trigger when within the threshold of the top
			if new < 50 {
				onApproachingEdge(.top)
			}
		}
	}

	func onApproachingEdge(_ edge: VEdge) {
		guard !edgeLock, edgeStatuses[edge] != .eod else { return }

		let anchorID = items.first?.uiId // Capture BEFORE the update
		edgeLock = true

		Task {
			let status = await onLoadMore(edge)
			edgeStatuses[edge] = status

			if edge == .top, let anchorID {
				position = ScrollPosition(id: anchorID)
			}
			edgeLock = false
		}
	}
}


// MARK: - Preview

private let page = 10
private let cellSize = 100.0

private struct Item: ChatViewItem {
	let index: Int
	var height: Double { cellSize }
	var uiId: String { String(index) }
	static func from(range: Range<Int>) -> [Self] { range.map { Self(index: $0) } }
}

#Preview {

	//	@Previewable @State var range = 0..<page
	@Previewable @State var items = Item.from(range: 0..<page)

	ChatView(items: items) { item in
		HStack {
			Text("Row \(item.index)")
		}
		.frame(maxWidth: .infinity)
		.frame(height: item.height)
		.background {
			Rectangle()
				.fill(.white.opacity(Double(item.index + 100) / 100))
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
//				let last = items.last!
//				guard last.index < 20 else { return .eod }
//				try? await Task.sleep(for: .seconds(1))
//				items.append(contentsOf: Item.from(range: (last.index + 1)..<(last.index + page + 1)))
//				print(Date.now, "added more below")
//				return .hasMore
				return .eod
		}
	}
	.frame(maxWidth: .infinity, maxHeight: .infinity)
//	.ignoresSafeArea()
	.background(.primary)
}
