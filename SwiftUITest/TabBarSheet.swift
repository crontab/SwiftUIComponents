//
//  TabBarSheet.swift
//  SwiftUITest
//
//  Created by Hovik Melikyan on 07.02.25.
//

import SwiftUI


// TODO: reiplement this as an ordinary view instead of a sheet, with interactive transition animation
// Rubber band formula: y = limit * (1 + log10(y / limit))
// My formula: 100 * log10(1 + (y - limit) / 100)


struct TabBarSheet: View {

	private let minimizedHeight = 64.0
	private let maximizedHeight = 600.0

	@State private var maximized: Bool = false
	@State private var offset: CGFloat = 0

	private var currentHeight: CGFloat { maximized ? maximizedHeight : minimizedHeight }
//	private var newHeight: CGFloat { maximized ? minimizedHeight : maximizedHeight }


	var body: some View {
		VStack {
			HStack {
				Text("Tab bar")
				Spacer()
			}
			Spacer()
		}
		.padding()
		.frame(height: max(minimizedHeight / 2, currentHeight + offset))
		.background {
			UnevenRoundedRectangle(topLeadingRadius: 12, topTrailingRadius: 12)
				.fill(.background.opacity(0.9))
				.shadow(color: .primary.opacity(0.3), radius: 0.5)
				.ignoresSafeArea()
		}
		.gesture(
			DragGesture(coordinateSpace: .global)
				.onChanged(didDrag)
				.onEnded(dragDidEnd)
		)
	}


	private func didDrag(to value: DragGesture.Value) {
		offset = -value.translation.height
		let current = currentHeight + offset
		if current > maximizedHeight {
			offset = rubberBandUp(y: current, limit: maximizedHeight, elasticity: 100) - currentHeight
		}
		else if current < minimizedHeight {
			offset = rubberBandDown(y: current, limit: minimizedHeight, elasticity: 10) - currentHeight
		}
	}


	private func dragDidEnd(at value: DragGesture.Value) {
		let dragEnd = currentHeight + offset
		let predicted = currentHeight - value.predictedEndTranslation.height

		// Change the position if the predicted landing location passes half of total
		let maximize = predicted >= (maximizedHeight + minimizedHeight) / 2
		let target = maximize ? maximizedHeight : minimizedHeight

		// If going back then velocity is set to standard, otherwise take the gesture value
		// Also set the minimum to 100 to avoid division by zero below
		let absVelocity = maximize == maximized ? 600 : max(100, abs(value.velocity.height))
		let absDelta = abs(target - dragEnd)

		// Calculate the animation duration based on velocity and distance but limit it to 0.2 ... 0.4
		let duration = min(0.4, max(0.2, absDelta / absVelocity))
//		print("v =", absVelocity, " t =", duration)
		withAnimation(.bouncy(duration: duration)) {
			offset = 0
			maximized = maximize
		}
	}
}


private func rubberBandUp(y: Double, limit: Double, elasticity: Double = 100) -> Double {
	return y > limit ? limit + elasticity * log10(1 + (y - limit) / elasticity) : y
}


private func rubberBandDown(y: Double, limit: Double, elasticity: Double = 100) -> Double {
	return y < limit ? limit - elasticity * log10(1 + (limit - y) / elasticity) : y
}


#Preview {
	struct Preview: View {

		var body: some View {
			Stripes()
				.ignoresSafeArea()
				.overlay(alignment: .bottom) {
					TabBarSheet()
				}
		}
	}

	return Preview()
}
