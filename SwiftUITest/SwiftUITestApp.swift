//
//  SwiftUITestApp.swift
//  SwiftUITest
//
//  Created by Hovik Melikyan on 29.03.24.
//

import SwiftUI


@main
struct SwiftUITestApp: App {
	@State private var range = 0..<20
	@State private var action: InfiniteScrollerAction? = .scrollToBottom(animated: false)

	var body: some Scene {
		WindowGroup {

			InfiniteScroller(action: $action) {
				VStack(spacing: 0) {
					ForEach(range, id: \.self) { i in
						Text("Hello \(i + 1)")
							.frame(height: 50)
					}
				}
			}
			.onApproachingEdge { edge in
				if edge == .top {
					range = (range.lowerBound - 20)..<range.upperBound
				}
			}
			.ignoresSafeArea()

//			Stripes()
//				.ignoresSafeArea()
//				.overlay(alignment: .bottom) {
//					TabBarSheetTest()
//				}
		}
	}
}
