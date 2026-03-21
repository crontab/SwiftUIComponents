//
//  ChatView.swift
//
//  Created by Hovik Melikyan on 20.03.26.
//

import SwiftUI


protocol ChatViewItem {
	typealias ID = String
	var uiId: ID { get }
	var uiHeight: Double { get }
}


enum ChatViewAction {
	case top(animated: Bool)
	case bottom(animated: Bool)
	case scrollTo(id: ChatViewItem.ID, animated: Bool)
	case resetEdges
}


struct ChatView<Content: View, Item: ChatViewItem>: View {

	let items: [Item]
	@Binding var action: ChatViewAction?
	var edgeInsets: EdgeInsets = .zero
	@ViewBuilder let cellContent: (Item) -> Content
	let onLoadMore: (VEdge) async -> EdgeStatus

	@State private var model = Model()


	var body: some View {
		GeometryReader { proxy in
			let headroom = model.calculateHeadroom(items: items)
			let frame = proxy.frame(in: .local)
			let hotFrame = frame.insetBy(dx: -frame.width / 2, dy: -frame.height / 2)
			Representable(headroom: headroom, action: $action, edgeInsets: edgeInsets, items: items, model: model) {
				VStack(spacing: 0) {
					ForEach(items, id: \.uiId) { item in
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
						.frame(height: item.uiHeight)
					}
				}
			} onApproachingEdge: { edge in
				if (model.endOfData[edge] ?? .hasMore) == .hasMore {
					model.endOfData[edge] = await onLoadMore(edge)
				}
			}
		}
	}


	@Observable
	fileprivate final class Model {
		var endOfData: [VEdge: EdgeStatus] = [:]
		private var previousTopId: ChatViewItem.ID?
		private var headroom: Double = 0

		func calculateHeadroom(items: [Item]) -> Double {
			if previousTopId != items.first?.uiId {
				if let id = previousTopId {
					var extraHeight: Double = 0
					let index = items.firstIndex { item in
						if item.uiId == id { return true }
						extraHeight += item.uiHeight
						return false
					}
					if index != nil, extraHeight > 0 {
						self.headroom += extraHeight
					}
				}
				previousTopId = items.first?.uiId
			}
			return headroom
		}
	}


	private struct Representable<C: View>: UIViewRepresentable {
		let headroom: Double
		@Binding var action: ChatViewAction?
		let edgeInsets: EdgeInsets
		let items: [Item]
		let model: Model
		let content: () -> C
		let onApproachingEdge: (VEdge) async -> Void


		func makeUIView(context: Context) -> HostedScrollView {
			HostedScrollView(content: content, onApproachingEdge: onApproachingEdge)
		}


		func updateUIView(_ scrollView: HostedScrollView, context: Context) {
			scrollView.updateView(headroom: headroom, edgeInsets: edgeInsets, content: content)

			switch action {
				case .none:
					break

				case .top(let animated):
					scrollView.scrollToTop(animated: animated)
					Task { action = nil }

				case .bottom(let animated):
					scrollView.scrollToBottom(animated: animated)
					Task { action = nil }

				case .scrollTo(let id, let animated):
					if let offset = topOffset(of: id) {
						scrollView.scrollToOffset(offset, headroom: headroom, animated: animated)
					}
					Task { action = nil }

				case .resetEdges:
					model.endOfData = [:]
					scrollView.edgeTest()
					Task { action = nil }
			}
		}


		private func topOffset(of id: ChatViewItem.ID) -> Double? {
			var top = 0.0
			for item in items {
				if item.uiId == id { return top }
				top += item.uiHeight
			}
			return nil
		}


		final class HostedScrollView: UIScrollView, UIScrollViewDelegate {
			private let host: UIHostingController<C>
			private let onApproachingEdge: (VEdge) async -> Void
			private var edgeLock = false


			init(content: () -> C, onApproachingEdge: @escaping (VEdge) async -> Void) {
				self.host = UIHostingController(rootView: content())
				self.onApproachingEdge = onApproachingEdge
				super.init(frame: .zero)
				delegate = self
				addSubview(host.view)
				alwaysBounceVertical = true
				showsVerticalScrollIndicator = false
				host.view.backgroundColor = .clear
			}


			required init?(coder: NSCoder) {
				preconditionFailure()
			}


			fileprivate func updateView(headroom: Double, edgeInsets: EdgeInsets, content: () -> C) {
				host.rootView = content()
				host.view.sizeToFit()
				host.view.frame.size.width = bounds.width
				let newHeight = host.view.bounds.height
				let blankSpace = max(0, pageHeight - newHeight - edgeInsets.top - edgeInsets.bottom)
				host.view.frame.origin.y = -headroom
				var edgeInsets = edgeInsets.uiEdgeInsets
				edgeInsets.top += headroom + blankSpace
				contentInset = edgeInsets
				contentSize.height = newHeight - headroom
			}


			func scrollViewDidScroll(_ scrollView: UIScrollView) {
				guard isTracking || isDecelerating || isDragging else { return }
				edgeTest()
			}

			func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
				edgeTest()
			}


			fileprivate func scrollToTop(animated: Bool) {
				setContentOffset(.init(x: contentOffset.x, y: -adjustedContentInset.top), animated: animated)
				if !animated { edgeTest() }
			}

			fileprivate func scrollToBottom(animated: Bool) {
				setContentOffset(.init(x: contentOffset.x, y: bottomContentOffsetY), animated: animated)
				if !animated { edgeTest() }
			}

			fileprivate func scrollToOffset(_ offset: Double, headroom: Double, animated: Bool) {
				let wh = bounds.height - safeAreaInsets.top - safeAreaInsets.bottom
				let ch = contentSize.height + headroom
				let clamped = max(0, min(offset, ch - wh))
				setContentOffset(.init(x: 0, y: clamped - headroom - safeAreaInsets.top), animated: animated)
				if !animated { edgeTest() }
			}

			fileprivate func edgeTest() {
				guard !edgeLock else { return }
				let vicinity = max(bounds.height / 2, 200)
				if isCloseToTop(within: vicinity) {
					edgeLock = true
					Task {
						await onApproachingEdge(.top)
						edgeLock = false
					}
				}
				else if isCloseToBottom(within: vicinity) {
					edgeLock = true
					Task {
						await onApproachingEdge(.bottom)
						edgeLock = false
					}
				}
			}

			private func isCloseToTop(within offset: Double) -> Bool {
				contentOffset.y + adjustedContentInset.top <= offset
			}

			private func isCloseToBottom(within offset: Double) -> Bool {
				bottomContentOffsetY - contentOffset.y <= offset
			}

			private var bottomContentOffsetY: Double {
				max(contentSize.height - bounds.height + adjustedContentInset.bottom, -adjustedContentInset.top)
			}

			private var pageHeight: Double {
				bounds.height - safeAreaInsets.top - safeAreaInsets.bottom
			}
		}
	}
}


// MARK: - Preview

private let page = 10
private let cellSize = 100.0

private struct Item: ChatViewItem {
	let index: Int
	var uiId: String { String(index) }
	var uiHeight: Double { cellSize }
	static func from(range: Range<Int>) -> [Self] { range.map { Self(index: $0) } }
}

#Preview {
	@Previewable @State var items: [Item] = []
	@Previewable @State var action: ChatViewAction? = .bottom(animated: false)

	ChatView(items: items, action: $action, edgeInsets: EdgeInsets(top: 100, leading: 0, bottom: 100, trailing: 0)) { item in
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
