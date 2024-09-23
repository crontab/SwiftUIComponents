//
//  UnimplementedView.swift
//
//  Created by Hovik Melikyan on 04.08.24.
//

import SwiftUI


// Stripes are based on https://github.com/eneko/Stripes

struct StripesConfig {
	var background: Color = .gray.opacity(0.05)
	var foreground: Color = .gray.opacity(0.08)
	var degrees: Double = 45
	var barWidth: CGFloat = 8
	var barSpacing: CGFloat = 10

	static let `default` = StripesConfig()
}


struct Stripes: View {
	let config: StripesConfig

	init(_ config: StripesConfig) {
		self.config = config
	}

	var body: some View {
		GeometryReader { geometry in
			let longSide = max(geometry.size.width, geometry.size.height)
			let itemWidth = config.barWidth + config.barSpacing
			let items = Int(2 * longSide / itemWidth)
			HStack(spacing: config.barSpacing) {
				ForEach(0..<items, id: \.self) { index in
					config.foreground
						.frame(width: config.barWidth, height: 2 * longSide)
				}
			}
			.frame(maxWidth: .infinity, maxHeight: .infinity)
			.rotationEffect(Angle(degrees: config.degrees), anchor: .center)
			.offset(x: -longSide / 2, y: -longSide / 2)
			.background(config.background)
		}
		.clipped()
	}
}


struct UnimplementedView: View {

	var showLabel: Bool = true

	var body: some View {
		ZStack {
			Stripes(.default)
				.ignoresSafeArea()

			if showLabel {
				Text("Not implemented".uppercased())
					.font(.caption)
					.foregroundColor(.gray)
					.padding(EdgeInsets(top: 4, leading: 6, bottom: 3, trailing: 6))
					.background(.white)
			}
		}
	}
}


#Preview {
	UnimplementedView()
}
