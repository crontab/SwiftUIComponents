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

	@State private var lower: Int = 0

	private struct Item: InfiniteViewItem {
		let id: Int
		var height: Double { 50 }

		static func from(range: Range<Int>) -> [Self] { range.map { Self(id: $0) } }
	}


	var body: some Scene {
		WindowGroup {

			InfiniteView { (item: Item) in
				Text("Hello \(item.id)")
			} onLoadMore: {
				guard lower > -20 else { return [] }
				defer {
					lower -= 20
				}
				return Item.from(range: lower..<(lower + 20))
			}
			.ignoresSafeArea()

//			InfiniteViewImpl(action: $action) {
//				VStack(spacing: 0) {
//					ForEach(range, id: \.self) { i in
//						Text("Hello \(i + 1)")
//							.frame(height: 50)
//					}
//				}
//			} onApproachingEdge: { edge in
//				switch edge {
//					case .top:
//						action = .didAddTopContent(height: 0)
//						range = (range.lowerBound - 20)..<range.upperBound
////					case .bottom:
////						range = range.lowerBound..<(range.upperBound + 5)
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
