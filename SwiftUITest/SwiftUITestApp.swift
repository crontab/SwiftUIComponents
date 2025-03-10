//
//  SwiftUITestApp.swift
//  SwiftUITest
//
//  Created by Hovik Melikyan on 29.03.24.
//

import SwiftUI


private let page = 20
private let cellSize = 50.0


@main
struct SwiftUITestApp: App {
	@State private var range = 0..<page
	@State private var action: InfiniteViewScrollAction? = .bottom(animated: false)

	private struct Item: InfiniteListItem {
		let id: Int
		var height: Double { cellSize }
		static func from(range: Range<Int>) -> [Self] { range.map { Self(id: $0) } }
	}


	var body: some Scene {
		WindowGroup {

			GeometryReader { proxy in
				InfiniteList(Item.from(range: range)) { item in
					LazyCell(item: item, parent: proxy) {
						Text("Hello \(item.id)")
					}
				} onLoadMore: { edge in
					switch edge {
						case .top:
							guard range.lowerBound >= -60 else { return true }
							try? await Task.sleep(for: .seconds(1))
							range = (range.lowerBound - page)..<(range.upperBound)
							return false
						default:
							return true
					}
				}
			}
			.ignoresSafeArea()

//			InfiniteView(action: $action) {
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
//
//			Stripes()
//				.ignoresSafeArea()
//				.overlay(alignment: .bottom) {
//					TabBarSheetTest()
//				}
		}
	}
}
