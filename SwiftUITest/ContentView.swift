//
//  ContentView.swift
//  SwiftUITest
//
//  Created by Hovik Melikyan on 18.06.24.
//

import SwiftUI


struct ContentView: View {
	@State private var action: ScrollViewAction = .page(0, animated: false)
	@State private var state: ScrollViewState = .init()

	var body: some View {
		GeometryReader { proxy in
			PagingScrollView(.vertical, action: .constant(.page(0, animated: false))) {
				VStack(spacing: 0) {
					ForEach(0...5, id: \.self) { i in
						LazyPage(proxy: proxy) {
							Text("Page \(i)")
								.onAppear {
									print("Draw", i)
								}
						}
						.background(.gray.opacity(0.1))
					}
				}
			}
			.refreshAction {
				try? await Task.sleep(for: .seconds(2))
				print("Refresh")
			}
		}
		.ignoresSafeArea()
	}
}


#Preview {
	ContentView()
}
