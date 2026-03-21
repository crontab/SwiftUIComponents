//
//  ChatList.swift
//
//  Created by Hovik Melikyan on 21.03.26.
//

import SwiftUI


protocol ChatListItem {
	typealias ID = String
	var uiID: ID { get }
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
	let cellContent: (Item) -> Content
	let onLoadMore: (VEdge) async -> EdgeStatus


	func makeUIView(context: Context) -> UICollectionView {
		let config = UICollectionLayoutListConfiguration(appearance: .plain)
		let layout = UICollectionViewCompositionalLayout.list(using: config)
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

		let newIDs = items.map(\.uiID)
		let oldIDs = coordinator.dataSource.snapshot().itemIdentifiers

		guard newIDs != oldIDs else { return }

		let topChanged = oldIDs.first != nil && newIDs.first != nil && oldIDs.first != newIDs.first

		let oldContentHeight = collectionView.contentSize.height
		let oldOffset = collectionView.contentOffset.y

		var itemMap: [Item.ID: Item] = [:]
		for item in items { itemMap[item.uiID] = item }
		coordinator.itemMap = itemMap

		var snapshot = NSDiffableDataSourceSnapshot<Int, Item.ID>()
		snapshot.appendSections([0])
		snapshot.appendItems(newIDs, toSection: 0)
		coordinator.dataSource.apply(snapshot, animatingDifferences: false)

		if topChanged {
			collectionView.layoutIfNeeded()
			let delta = collectionView.contentSize.height - oldContentHeight
			if delta != 0 {
				collectionView.contentOffset.y = oldOffset + delta
			}
		}

		collectionView.contentInset = edgeInsets.uiEdgeInsets

		collectionView.layoutIfNeeded()
		coordinator.edgeTest()

		if let action {
			Task {
				switch action {

					case .top(let animated):
						collectionView.setContentOffset(.init(x: 0, y: -collectionView.adjustedContentInset.top), animated: animated)

					case .bottom(let animated):
						let y = max(collectionView.contentSize.height - collectionView.bounds.height + collectionView.adjustedContentInset.bottom, -collectionView.adjustedContentInset.top)
						collectionView.setContentOffset(.init(x: 0, y: y), animated: animated)

					case .scrollTo(let id, let animated):
						if let indexPath = coordinator.dataSource.indexPath(for: id) {
							collectionView.scrollToItem(at: indexPath, at: .centeredVertically, animated: animated)
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


	final class Coordinator: NSObject, UICollectionViewDelegate {
		var collectionView: UICollectionView!
		var dataSource: UICollectionViewDiffableDataSource<Int, Item.ID>!
		var itemMap: [Item.ID: Item] = [:]
		var cellContent: ((Item) -> Content)!
		var onLoadMore: ((VEdge) async -> EdgeStatus)!
		var edgeStatuses: [VEdge: EdgeStatus] = [:]
		private var edgeLock = false

		func scrollViewDidScroll(_ scrollView: UIScrollView) {
			guard scrollView.isTracking || scrollView.isDecelerating || scrollView.isDragging else { return }
			edgeTest()
		}

		func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
			edgeTest()
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
	var uiID: String { String(index) }
	static func from(range: Range<Int>) -> [Self] { range.map { Self(index: $0) } }
}

#Preview {
	@Previewable @State var items = Item.from(range: 0..<page)
	@Previewable @State var action: ChatListAction? = nil

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
}
