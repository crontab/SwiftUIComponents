//
//  TabBarSheet.swift
//
//  Created by Hovik Melikyan on 07.02.25.
//

import SwiftUI


struct TabBarSheetTest: View {

	@State private var maximized: Bool = false
	@State private var currentHeight: CGFloat = 0


	var body: some View {
		VStack {
			HStack {
				Button {
					withAnimation(.bouncy(duration: 0.2)) {
						maximized.toggle()
					}
				} label: {
					Text("Tab bar")
				}
				Spacer()
			}
			Spacer()
		}
		.padding()
		.background {
			UnevenRoundedRectangle(topLeadingRadius: 12, topTrailingRadius: 12)
				.fill(.background.opacity(0.9))
				.shadow(color: .primary.opacity(0.3), radius: 0.5)
				.ignoresSafeArea()
		}
		.tabBarSheet(minHeight: 64, maxHeight: 500, maximized: $maximized)
		.onHeightChange(value: $currentHeight)
		.onChange(of: currentHeight) { _, new in
			print(new)
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
