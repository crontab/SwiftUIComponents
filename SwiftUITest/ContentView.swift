//
//  ContentView.swift
//  SwiftUITest
//
//  Created by Hovik Melikyan on 18.06.24.
//

import SwiftUI

struct ContentView: View {
	@State private var action: ScrollViewAction = .page(2, animated: false)
	@State private var state: ScrollViewState = .init()

	var body: some View {
		GeometryReader { proxy in
			PagingScrollView(.vertical, action: $action, state: $state) {
				VStack(spacing: 0) {
					ForEach([1, 2, 3, 4, 5], id: \.self) { i in
						Text("Page \(i)")
							.frame(width: proxy.size.width, height: proxy.size.height)
							.background(.gray.opacity(0.15))
					}
				}
			}
			.removesSafeArea()
			.background(.gray.opacity(0.15))
		}
		.ignoresSafeArea()
		.onChange(of: state) { newValue in
			print(newValue.page)
		}
	}
}

#Preview {
	ContentView()
}
