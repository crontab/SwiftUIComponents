//
//  SwiftUITestApp.swift
//  SwiftUITest
//
//  Created by Hovik Melikyan on 29.03.24.
//

import SwiftUI


@main
struct SwiftUITestApp: App {
//	@State private var range = 0..<30
//	@State private var action: InfiniteViewImplAction? = .scrollToBottom(animated: false)

	@State private var items: [Item] = (0..<20).map { Item(id: $0) }
	@State private var endOfData: Bool = false

	private struct Item: InfiniteViewItem {
		let id: Int
		var height: Double { 50 }
	}

	var body: some Scene {
		WindowGroup {

			InfiniteView(items: items) { item in
				Text("Hello \(item.id)")
			} onApproachingTop: {
				guard !endOfData else { return }
				endOfData = true
				items.insert(contentsOf: (-20..<0).map { Item(id: $0) }, at: 0)
			}

//			InfiniteViewImpl(action: $action) {
//				VStack(spacing: 0) {
//					ForEach(range, id: \.self) { i in
//						Text("Hello \(i + 1)")
//							.frame(height: 50)
//					}
//				}
//			}
//			.onApproachingEdge { edge in
//				switch edge {
//					case .top:
//						action = .didAddTopContent(height: 0)
//						range = (range.lowerBound - 20)..<range.upperBound
//					case .bottom:
//						range = range.lowerBound..<(range.upperBound + 5)
//					default:
//						break
//				}
//			}
//			.ignoresSafeArea()

//			Stripes()
//				.ignoresSafeArea()
//				.overlay(alignment: .bottom) {
//					TabBarSheetTest()
//				}
		}
	}
}
