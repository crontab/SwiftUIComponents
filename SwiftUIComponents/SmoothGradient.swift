//
//  SmoothGradient.swift
//
//  Created by Hovik Melikyan on 08.06.25.
//

import SwiftUI


struct SmoothLinearGradient: View {
	let from: Color
	let to: Color
	let startPoint: UnitPoint
	let endPoint: UnitPoint
	var curve: UnitCurve = .easeInOut
	var steps: Int = 10

	var body: some View {
		let steps = stride(from: 0.0, through: 1.0, by: 1.0 / Double(steps))
		let colors = steps.compactMap { step in
			from.mix(with: to, by: curve.value(at: step), in: .perceptual)
		}
		LinearGradient(gradient: .init(colors: colors), startPoint: .top, endPoint: .bottom)
	}
}


#Preview {
	HStack {
		LinearGradient(colors: [.white, .white.opacity(0)], startPoint: .top, endPoint: .bottom)
			.overlay {
				Text("Linear")
			}
		SmoothLinearGradient(from: .white, to: .white.opacity(0), startPoint: .top, endPoint: .bottom)
			.overlay {
				Text("Smooth")
			}
	}
	.background(.black)
	.foregroundStyle(.secondary)
}
