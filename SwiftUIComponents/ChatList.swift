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
	case reconfigure(id: ChatListItem.ID, animated: Bool = false)
}


enum EdgeStatus { case hasMore, eod }
enum VEdge { case bottom, top }


struct ChatList<Content: View, Item: ChatListItem>: UIViewRepresentable where Item.ID: Hashable & Sendable {

	let items: [Item]
	@Binding var action: ChatListAction?
	var edgeInsets: EdgeInsets = .zero
	@ViewBuilder let cellContent: (Item) -> Content

	private var onLoadMore: ((VEdge) async -> EdgeStatus)? = nil
	private var onVisibleItems: ((Set<Item.ID>) -> Void)? = nil
	private var header: AnyView? = nil
	private var headerHeight: CGFloat = 0
	private var footer: AnyView? = nil
	private var footerHeight: CGFloat = 0


	init(items: [Item], action: Binding<ChatListAction?>, edgeInsets: EdgeInsets = .zero, @ViewBuilder cellContent: @escaping (Item) -> Content) {
		self.items = items
		self._action = action
		self.edgeInsets = edgeInsets
		self.cellContent = cellContent
	}


	func onLoadMore(_ handler: @escaping (VEdge) async -> EdgeStatus) -> Self {
		var copy = self
		copy.onLoadMore = handler
		return copy
	}


	func onVisibleItems(_ handler: @escaping (Set<Item.ID>) -> Void) -> Self {
		var copy = self
		copy.onVisibleItems = handler
		return copy
	}


	func header<H: View>(height: CGFloat, @ViewBuilder _ content: () -> H) -> Self {
		var copy = self
		copy.header = AnyView(content())
		copy.headerHeight = height
		return copy
	}


	func footer<H: View>(height: CGFloat, @ViewBuilder _ content: () -> H) -> Self {
		var copy = self
		copy.footer = AnyView(content())
		copy.footerHeight = height
		return copy
	}


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

		let headerKind = UICollectionView.elementKindSectionHeader
		let headerRegistration = UICollectionView.SupplementaryRegistration<UICollectionViewCell>(elementKind: headerKind) { cell, _, _ in
			if let headerView = coordinator.header {
				cell.contentConfiguration = UIHostingConfiguration { headerView }
					.margins(.all, 0)
			}
		}

		let footerKind = UICollectionView.elementKindSectionFooter
		let footerRegistration = UICollectionView.SupplementaryRegistration<UICollectionViewCell>(elementKind: footerKind) { cell, _, _ in
			if let footerView = coordinator.footer {
				cell.contentConfiguration = UIHostingConfiguration { footerView }
					.margins(.all, 0)
			}
		}

		coordinator.dataSource = UICollectionViewDiffableDataSource<Int, Item.ID>(collectionView: collectionView) { collectionView, indexPath, itemID in
			collectionView.dequeueConfiguredReusableCell(using: registration, for: indexPath, item: itemID)
		}

		coordinator.dataSource.supplementaryViewProvider = { collectionView, kind, indexPath in
			switch kind {
				case headerKind: collectionView.dequeueConfiguredReusableSupplementary(using: headerRegistration, for: indexPath)
				case footerKind: collectionView.dequeueConfiguredReusableSupplementary(using: footerRegistration, for: indexPath)
				default: nil
			}
		}

		collectionView.delegate = coordinator
		return collectionView
	}


	func updateUIView(_ collectionView: UICollectionView, context: Context) {
		let coordinator = context.coordinator
		coordinator.cellContent = cellContent
		coordinator.onLoadMore = onLoadMore
		coordinator.onVisibleItems = onVisibleItems
		coordinator.header = header
		coordinator.headerHeight = headerHeight
		coordinator.footer = footer
		coordinator.footerHeight = footerHeight

		let newIDs = items.map(\.uiId)
		let oldIDs = coordinator.dataSource.snapshot().itemIdentifiers

		if newIDs != oldIDs {
			let oldOffset = collectionView.contentOffset.y

			updateItemMap(coordinator: coordinator)

			var snapshot = NSDiffableDataSourceSnapshot<Int, Item.ID>()
			snapshot.appendSections([0])
			snapshot.appendItems(newIDs, toSection: 0)
			coordinator.dataSource.apply(snapshot, animatingDifferences: false)

			if let firstOldID = oldIDs.first, let splitIndex = newIDs.firstIndex(of: firstOldID), splitIndex > 0 {
				let delta = items[..<splitIndex].reduce(0.0) { $0 + $1.uiHeight }
				collectionView.contentOffset.y = oldOffset + delta
			}

			coordinator.edgeTest()
		}

		collectionView.contentInset = edgeInsets.uiEdgeInsets

		if let action {
			handleAction(action, collectionView: collectionView, coordinator: coordinator)
			Task {
				self.action = nil
			}
		}

		Task {
			coordinator.visibilityTest()
		}
	}


	func makeCoordinator() -> Coordinator {
		Coordinator()
	}


	private func handleAction(_ action: ChatListAction, collectionView: UICollectionView, coordinator: Coordinator) {
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

			case .reconfigure(let id, let animated):
				var snapshot = coordinator.dataSource.snapshot()
				if snapshot.itemIdentifiers.contains(id) {
					updateItemMap(coordinator: coordinator)
					snapshot.reconfigureItems([id])
					coordinator.dataSource.apply(snapshot, animatingDifferences: animated)
					collectionView.collectionViewLayout.invalidateLayout()
				}
		}
	}


	private func updateItemMap(coordinator: Coordinator) {
		var itemMap: [Item.ID: Item] = [:]
		for item in items { itemMap[item.uiId] = item }
		coordinator.itemMap = itemMap
	}


	final class Coordinator: NSObject, UICollectionViewDelegateFlowLayout {
		var collectionView: UICollectionView!
		var dataSource: UICollectionViewDiffableDataSource<Int, Item.ID>!
		var itemMap: [Item.ID: Item] = [:]
		var cellContent: ((Item) -> Content)!

		var onLoadMore: ((VEdge) async -> EdgeStatus)?
		var onVisibleItems: ((Set<Item.ID>) -> Void)?

		var header: AnyView?
		var headerHeight: CGFloat = 0
		var footer: AnyView?
		var footerHeight: CGFloat = 0

		var edgeStatuses: [VEdge: EdgeStatus] = [:]
		private var edgeLock = false
		private var lastVisibleIDs = Set<Item.ID>()

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

		func collectionView(_ collectionView: UICollectionView, layout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {
			header != nil ? CGSize(width: collectionView.bounds.width, height: headerHeight) : .zero
		}

		func collectionView(_ collectionView: UICollectionView, layout: UICollectionViewLayout, referenceSizeForFooterInSection section: Int) -> CGSize {
			footer != nil ? CGSize(width: collectionView.bounds.width, height: footerHeight) : .zero
		}

		func edgeTest() {
			guard !edgeLock, let onLoadMore, let cv = collectionView else { return }
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

		func visibilityTest() {
			guard let onVisibleItems, let cv = collectionView else { return }
			let safeArea = cv.safeAreaInsets
			let top = cv.contentOffset.y + safeArea.top
			let bottom = cv.contentOffset.y + cv.bounds.height - safeArea.bottom
			var ids = Set<Item.ID>()
			for cell in cv.visibleCells {
				guard let ip = cv.indexPath(for: cell), let id = dataSource.itemIdentifier(for: ip) else { continue }
				let maxY = cell.frame.maxY
				if maxY >= top && maxY <= bottom {
					ids.insert(id)
				}
			}
			if ids.isEmpty && !cv.visibleCells.isEmpty {
				return
			}
			if ids != lastVisibleIDs {
				lastVisibleIDs = ids
				onVisibleItems(ids)
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
	var minimized: Bool = false
	var uiId: String { String(index) }
	var uiHeight: Double { minimized ? cellSize / 2 : index == 5 ? 1000 : cellSize }
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
		.frame(height: item.uiHeight)
		.background {
			Rectangle()
				.fill(.black.opacity(1 - Double(item.index + 100) / 100))
		}
		.overlay(alignment: .bottom) {
			Rectangle()
				.fill(.quaternary)
				.frame(height: 1)
		}
		.contentShape(Rectangle())
		.onTapGesture {
			guard let index = items.firstIndex(where: { $0.uiId == item.uiId }) else { return }
			items[index].minimized = !items[index].minimized
			action = .reconfigure(id: item.uiId, animated: true)
		}
	}
	.header(height: 50) {
		Text("Chat started")
			.foregroundStyle(.secondary)
	}
	.footer(height: 50) {
		Text("End of chat")
			.foregroundStyle(.secondary)
	}
	.onLoadMore { edge in
		switch edge {
			case .top:
				let first = items.first?.index ?? 0
				guard first > -20 else { return .eod }
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
	}
	.onVisibleItems { set in
		print("visible:", set.compactMap(Int.init).sorted())
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
