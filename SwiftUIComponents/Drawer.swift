//
//  Drawer.swift
//
//  Created by Hovik Melikyan on 07.02.25.
//

import SwiftUI


// Rubber band formula: limit + 100 * log10(1 + (y - limit) / 100)


enum VPlacement {
	case top, bottom
}


extension View {

	func drawer(range: ClosedRange<CGFloat>, placement: VPlacement, maximized: Binding<Bool>) -> some View {
		modifier(Modifier(minHeight: range.lowerBound, maxHeight: range.upperBound, placement: placement, maximized: maximized))
	}

	func onHeightChange(_ action: @escaping (CGFloat) -> Void) -> some View {
		background {
			GeometryReader { proxy in
				Color.clear
					.onChange(of: proxy.size.height) { _, new in
						action(new)
					}
			}
		}
	}
}


func withDrawerAnimation<Result>(_ body: () throws -> Result) rethrows -> Result {
	try withAnimation(.easeInOut(duration: 0.2), body)
}


private struct Modifier: ViewModifier {

	let minHeight: CGFloat
	let maxHeight: CGFloat
	let placement: VPlacement
	@Binding var maximized: Bool

	@State private var offset: CGFloat = 0

	private var currentHeight: CGFloat { maximized ? maxHeight : minHeight }


	func body(content: Content) -> some View {
		content
			.overlay {
				dragIndicator()
			}
			.frame(height: max(minHeight / 2, currentHeight + offset))
			.gesture(
				DragGesture(coordinateSpace: .global)
					.onChanged(didDrag)
					.onEnded(dragDidEnd)
			)
	}


	private func didDrag(to value: DragGesture.Value) {
		offset = placement.direction * value.translation.height
		let current = currentHeight + offset
		if current > maxHeight {
			offset = rubberBandUp(y: current, limit: maxHeight) - currentHeight
		}
		else if current < minHeight {
			offset = rubberBandDown(y: current, limit: minHeight) - currentHeight
		}
	}


	private func dragDidEnd(at value: DragGesture.Value) {
		let dragEnd = currentHeight + offset
		let predicted = currentHeight + placement.direction * value.predictedEndTranslation.height

		// Change the position if the predicted landing location passes half of total
		let maximize = predicted >= (maxHeight + minHeight) / 2
		let target = maximize ? maxHeight : minHeight

		// If going back then velocity is set to standard, otherwise take the gesture value
		// Also set the minimum to 100 to avoid division by zero below
		let absVelocity = maximize == maximized ? 600 : max(100, abs(value.velocity.height))
		let absDelta = abs(target - dragEnd)

		// Calculate the animation duration based on velocity and distance but limit it to 0.2 ... 0.4
		let duration = min(0.3, max(0.2, absDelta / absVelocity))
		//		print("v =", absVelocity, " t =", duration)
		withAnimation(.bouncy(duration: duration)) {
			offset = 0
			maximized = maximize
		}
	}


	private func dragIndicator() -> some View {
		VStack {
			if placement == .top {
				Spacer()
			}
			Capsule()
				.fill(.quaternary.opacity(0.5))
				.frame(width: 36, height: 5)
				.padding(6)
				.contentShape(Rectangle())
				.onTapGesture {
					withDrawerAnimation {
						maximized = !maximized
					}
				}
			if placement == .bottom {
				Spacer()
			}
		}
	}
}


private extension VPlacement {
	var direction: CGFloat {
		switch self {
			case .top: 1
			case .bottom: -1
		}
	}
}


private func rubberBandUp(y: Double, limit: Double, elasticity: Double = 100) -> Double {
	return y > limit ? limit + elasticity * log10(1 + (y - limit) / elasticity) : y
}


private func rubberBandDown(y: Double, limit: Double, elasticity: Double = 100) -> Double {
	return y < limit ? limit - elasticity * log10(1 + (limit - y) / elasticity) : y
}
