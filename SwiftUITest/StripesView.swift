//
//  StripesView.swift
//
//  Created by Hovik Melikyan on 04.08.24.
//

import SwiftUI


// Based on https://github.com/eneko/Stripes

struct Stripes: View {
	@Environment(\.colorScheme) var colorScheme

	private let barWidth: CGFloat = 8
	private let barSpacing: CGFloat = 10

	var body: some View {
		GeometryReader { geometry in
			let longSide = max(geometry.size.width, geometry.size.height)
			let itemWidth = barWidth + barSpacing
			let items = Int(2 * longSide / itemWidth)
			HStack(spacing: barSpacing) {
				ForEach(0..<items, id: \.self) { index in
					Rectangle()
						.fill(.gray.opacity(colorScheme == .dark ? 0.15 : 0.05))
						.frame(width: barWidth, height: 2 * longSide)
				}
			}
			.frame(maxWidth: .infinity, maxHeight: .infinity)
			.rotationEffect(Angle(degrees: 45), anchor: .center)
			.offset(x: -longSide / 2, y: -longSide / 2)
		}
		.clipped()
	}
}


struct StripesView: View {

	var text: String?

	var body: some View {
		ZStack {
			Stripes()
				.ignoresSafeArea()

			if let text {
				Text(text.uppercased())
					.font(.caption)
					.foregroundColor(.secondary)
					.padding(EdgeInsets(top: 4, leading: 6, bottom: 3, trailing: 6))
			}
		}
	}
}


#Preview {
	StripesView(text: "Where am I?")
}
