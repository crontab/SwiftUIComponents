//
//  TabBarSheet.swift
//
//  Created by Hovik Melikyan on 07.02.25.
//

import SwiftUI


struct TabBarSheetTest: View {

	private let minHeight = 64.0
	private let maxHeight = 600.0

	@State private var maximized: Bool = false
	@State private var currentHeight: CGFloat = 0

	private var progress: CGFloat { (currentHeight - minHeight) / (maxHeight - minHeight) }


	var body: some View {
		ZStack {
			// Maximized
			VStack {
				Circle()
				Spacer()
			}
			.padding(.bottom, -maxHeight)
			.opacity(progress)

			// Minimized
			VStack {
				HStack {
					Button {
						withAnimation(.bouncy(duration: 0.2)) {
							maximized.toggle()
						}
					} label: {
						Text("Tab bar")
					}
				}
				Spacer()
			}
//			.opacity(1 - progress)
		}
		.frame(maxWidth: .infinity, maxHeight: .infinity)
		.padding()
		.background {
			UnevenRoundedRectangle(topLeadingRadius: 12, topTrailingRadius: 12)
				.fill(.background.opacity(0.9))
				.shadow(color: .primary.opacity(0.3), radius: 0.5)
				.ignoresSafeArea()
		}
		.drawer(range: minHeight...maxHeight, placement: .bottom, maximized: $maximized)
		.onHeightChange { newHeight in
			currentHeight = newHeight
			print(newHeight)
		}
	}
}


#Preview {
	struct Preview: View {

		var body: some View {
			Stripes()
				.ignoresSafeArea()
				.overlay(alignment: .bottom) {
					TabBarSheetTest()
				}
		}
	}

	return Preview()
}
