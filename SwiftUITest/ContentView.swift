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
			PagingScrollView(.horizontal, action: $action, state: $state) {
				HStack(spacing: 0) {
					ForEach(0...9, id: \.self) { i in
						LazyPage(proxy: proxy) {
							Text("Page \(i)")
								.onAppear {
									print("Draw:", i)
								}
						}
						.background(.gray.opacity(0.1))
					}
				}
				.frame(height: proxy.size.height)
			}
		}
		.ignoresSafeArea()
	}
}


#Preview {
	ContentView()
}
