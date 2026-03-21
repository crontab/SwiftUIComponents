//
//  ChatList.swift
//
//  Created by Hovik Melikyan on 21.03.26.
//

import SwiftUI


protocol ChatListItem {
	typealias ID = String
	var uiId: ID { get }
	var uiHeight: Double { get }
}


enum ChatListAction {
	case top(animated: Bool)
	case bottom(animated: Bool)
	case scrollTo(id: ChatListItem.ID, animated: Bool)
	case resetEdges
}


enum EdgeStatus { case hasMore, eod }
enum VEdge { case bottom, top }


struct ChatList<Content: View, Item: ChatListItem>: UIViewRepresentable where Item.ID: Hashable & Sendable {

	let items: [Item]
	@Binding var action: ChatListAction?
	var edgeInsets: EdgeInsets = .zero
	@ViewBuilder let cellContent: (Item) -> Content
	let onLoadMore: (VEdge) async -> EdgeStatus
	var onItemSeen: ((Item) -> Void)? = nil


	func makeUIView(context: Context) -> UICollectionView {
		let layout = UICollectionViewFlowLayout()
		layout.minimumLineSpacing = 0
		layout.minimumInteritemSpacing = 0
		let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
		collectionView.backgroundColor = .clear
		collectionView.alwaysBounceVertical = true

		let coordinator = context.coordinator
		coordinator.collectionView = collectionView

		let registration = UICollectionView.CellRegistration<UICollectionViewCell, Item.ID> { cell, indexPath, itemID in
			if let item = coordinator.itemMap[itemID] {
				cell.contentConfiguration = UIHostingConfiguration {
					coordinator.cellContent(item)
				}
				.margins(.all, 0)
			}
		}

		coordinator.dataSource = UICollectionViewDiffableDataSource<Int, Item.ID>(collectionView: collectionView) { collectionView, indexPath, itemID in
			collectionView.dequeueConfiguredReusableCell(using: registration, for: indexPath, item: itemID)
		}

		collectionView.delegate = coordinator
		return collectionView
	}


	func updateUIView(_ collectionView: UICollectionView, context: Context) {
		let coordinator = context.coordinator
		coordinator.cellContent = cellContent
		coordinator.onLoadMore = onLoadMore
		coordinator.onItemSeen = onItemSeen

		let newIDs = items.map(\.uiId)
		let oldIDs = coordinator.dataSource.snapshot().itemIdentifiers

		if newIDs != oldIDs {
			let oldOffset = collectionView.contentOffset.y
			coordinator.seenIDs.formIntersection(newIDs)

			var itemMap: [Item.ID: Item] = [:]
			for item in items { itemMap[item.uiId] = item }
			coordinator.itemMap = itemMap

			var snapshot = NSDiffableDataSourceSnapshot<Int, Item.ID>()
			snapshot.appendSections([0])
			snapshot.appendItems(newIDs, toSection: 0)
			coordinator.dataSource.apply(snapshot, animatingDifferences: false)

			if let firstOldID = oldIDs.first, let splitIndex = newIDs.firstIndex(of: firstOldID), splitIndex > 0 {
				let delta = items[..<splitIndex].reduce(0.0) { $0 + $1.uiHeight }
				collectionView.contentOffset.y = oldOffset + delta
			}

			coordinator.edgeTest()
			coordinator.visibilityTest()
		}

		collectionView.contentInset = edgeInsets.uiEdgeInsets

		if let action {
			Task {
				switch action {

					case .top(let animated):
						let count = coordinator.dataSource.snapshot().numberOfItems
						if count > 0 {
							collectionView.scrollToItem(at: IndexPath(item: 0, section: 0), at: .top, animated: animated)
						}

					case .bottom(let animated):
						let count = coordinator.dataSource.snapshot().numberOfItems
						if count > 0 {
							collectionView.scrollToItem(at: IndexPath(item: count - 1, section: 0), at: .bottom, animated: animated)
						}

					case .scrollTo(let id, let animated):
						if let indexPath = coordinator.dataSource.indexPath(for: id) {
							collectionView.scrollToItem(at: indexPath, at: .top, animated: animated)
						}

					case .resetEdges:
						coordinator.edgeStatuses = [:]
						coordinator.edgeTest()
				}
				self.action = nil
			}
		}
	}


	func makeCoordinator() -> Coordinator {
		Coordinator()
	}


	final class Coordinator: NSObject, UICollectionViewDelegateFlowLayout {
		var collectionView: UICollectionView!
		var dataSource: UICollectionViewDiffableDataSource<Int, Item.ID>!
		var itemMap: [Item.ID: Item] = [:]
		var cellContent: ((Item) -> Content)!
		var onLoadMore: ((VEdge) async -> EdgeStatus)!
		var onItemSeen: ((Item) -> Void)?
		var edgeStatuses: [VEdge: EdgeStatus] = [:]
		var seenIDs: Set<Item.ID> = []
		private var edgeLock = false

		func scrollViewDidScroll(_ scrollView: UIScrollView) {
			guard scrollView.isTracking || scrollView.isDecelerating || scrollView.isDragging else { return }
			edgeTest()
			visibilityTest()
		}

		func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
			edgeTest()
			visibilityTest()
		}

		func collectionView(_ collectionView: UICollectionView, layout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
			let id = dataSource.itemIdentifier(for: indexPath)
			let h = id.flatMap { itemMap[$0]?.uiHeight } ?? 0
			return CGSize(width: collectionView.bounds.width, height: h)
		}

		func visibilityTest() {
			guard let onItemSeen, let cv = collectionView else { return }
			let viewportTop = cv.contentOffset.y + cv.adjustedContentInset.top
			let viewportBottom = cv.contentOffset.y + cv.bounds.height - cv.adjustedContentInset.bottom
			for indexPath in cv.indexPathsForVisibleItems {
				guard let id = dataSource.itemIdentifier(for: indexPath), !seenIDs.contains(id), let item = itemMap[id], let attrs = cv.layoutAttributesForItem(at: indexPath), attrs.frame.maxY >= viewportTop, attrs.frame.maxY <= viewportBottom else { continue }
				seenIDs.insert(id)
				onItemSeen(item)
			}
		}

		func edgeTest() {
			guard !edgeLock, let cv = collectionView else { return }
			let vicinity = max(cv.bounds.height / 2, 200)
			let topDist = cv.contentOffset.y + cv.adjustedContentInset.top
			let bottomDist = cv.contentSize.height - cv.contentOffset.y - cv.bounds.height + cv.adjustedContentInset.bottom

			if topDist <= vicinity, edgeStatuses[.top] != .eod {
				edgeLock = true
				Task {
					edgeStatuses[.top] = await onLoadMore(.top)
					edgeLock = false
				}
			}
			else if bottomDist <= vicinity, edgeStatuses[.bottom] != .eod {
				edgeLock = true
				Task {
					edgeStatuses[.bottom] = await onLoadMore(.bottom)
					edgeLock = false
				}
			}
		}
	}
}


extension EdgeInsets {
	static let zero = EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)

	var uiEdgeInsets: UIEdgeInsets { UIEdgeInsets(top: top, left: leading, bottom: bottom, right: trailing) }
}


// MARK: - Preview

private let page = 10
private let cellSize = 100.0

private struct Item: ChatListItem {
	let index: Int
	var uiId: String { String(index) }
	var uiHeight: Double { cellSize }
	static func from(range: Range<Int>) -> [Self] { range.map { Self(index: $0) } }
}

#Preview {
	@Previewable @State var items: [Item] = []
	@Previewable @State var action: ChatListAction? = .bottom(animated: false)

	ChatList(items: items, action: $action, edgeInsets: EdgeInsets(top: 100, leading: 0, bottom: 100, trailing: 0)) { item in
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
				let last = items.last?.index ?? -1
				guard last < 100 else { return .eod }
				try? await Task.sleep(for: .seconds(1))
				items.append(contentsOf: Item.from(range: (last + 1)..<(last + 1 + page)))
				print(Date.now, "added more below")
				return .hasMore
		}
	} onItemSeen: { item in
		print("seen", item.uiId)
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
