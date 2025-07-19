//
//  PlayerProgressView.swift
//
//  Created by Hovik Melikyan on 19.07.25.
//

import SwiftUI


private let SliderWidth = 6.0
private let InflatedSliderWidth = 12.0
private let PlayerProgressHeight = SliderWidth + 18


struct PlayerProgressView: View {

	let total: TimeInterval
	let playhead: TimeInterval
	let playing: Bool
	let onDrag: (TimeInterval) -> Void

	@State private var dragStartX: Double? // start of the drag gesture
	private var isDragging: Bool { dragStartX != nil }

	var body: some View {
		GeometryReader { proxy in
//			let totalX = proxy.size.width - SliderWidth

			WrappedPlayerProgressView(total: total, playhead: playhead, playing: playing && !isDragging, inflated: isDragging)
				.frame(height: PlayerProgressHeight)
//				.highPriorityGesture(
//					DragGesture(minimumDistance: 0)
//						.onChanged { v in
//							if dragStartX == nil {
//								dragStartX = valueToX(playhead, totalX: totalX)
//							}
//							onDrag(xToValue(v.translation.width + dragStartX!, totalX: totalX))
//						}
//						.onEnded { v in
//							dragStartX = nil
//						},
//					including: .gesture
//				)
		}
	}

	private func valueToX(_ value: TimeInterval, totalX: Double) -> Double {
		(value / total).clamped(to: 0...1) * totalX + SliderWidth
	}

	private func xToValue(_ x: Double, totalX: Double) -> TimeInterval {
		((x - SliderWidth) / totalX).clamped(to: 0...1) * total
	}
}


private struct WrappedPlayerProgressView: UIViewRepresentable {

	let total: TimeInterval
	let playhead: TimeInterval
	let playing: Bool
	let inflated: Bool


	func makeUIView(context: Context) -> HostedPlayerProgressView {
		HostedPlayerProgressView(context: context)
	}


	func updateUIView(_ view: HostedPlayerProgressView, context: Context) {
		view.update(total: total, playhead: playhead, playing: playing, inflated: inflated, context: context)
	}


	final class HostedPlayerProgressView: UIView {

		private var total: TimeInterval = 0
		private var playing: Bool = false
		private var inflated: Bool = false
		private var context: Context

		override class var layerClass: AnyClass { CAShapeLayer.self }
		private var barLayer: CAShapeLayer { layer as! CAShapeLayer }
		private let progressLayer = CAShapeLayer()

		private var sliderWidth: Double { inflated ? InflatedSliderWidth : SliderWidth }


		init(context: Context) {
			self.context = context
			super.init(frame: .zero)
			barLayer.addSublayer(progressLayer)
		}


		override func layoutSubviews() {
			super.layoutSubviews()
			setupLayer(barLayer, color: .inactive.opacity(0.5))
			setupLayer(progressLayer, color: .accentColor)
			updatePath()
		}


		fileprivate func update(total: TimeInterval, playhead: TimeInterval, playing: Bool, inflated: Bool, context: Context) {
			self.total = total
			progressLayer.strokeEnd = playhead / total
			self.playing = playing
			self.inflated = inflated
			self.context = context
			updatePath()
		}


		private func updatePath() {
			guard total > 0, bounds.width > 0 else { return }

			barLayer.lineWidth = sliderWidth
			progressLayer.lineWidth = sliderWidth

			if playing {
				animateStrokeEnd()
			}
			else {
				progressLayer.removeAnimation(forKey: "strokeEnd")
			}
		}


		private func animateStrokeEnd() {
			let animation = CABasicAnimation(keyPath: "strokeEnd")
			animation.fromValue = progressLayer.strokeEnd
			animation.toValue = 1
			animation.duration = total * (1 - progressLayer.strokeEnd)
			progressLayer.strokeEnd = 1
			CATransaction.begin()
			progressLayer.add(animation, forKey: "strokeEnd")
			CATransaction.commit()
		}


		private func buildPath(width: Double) -> CGPath {
			let middle = bounds.height / 2
			let path = UIBezierPath()
			path.move(to: CGPoint(x: sliderWidth / 2, y: middle))
			path.addLine(to: CGPoint(x: width - sliderWidth / 2, y: middle))
			return path.cgPath
		}


		private func setupLayer(_ layer: CAShapeLayer, color: Color) {
			layer.strokeColor = color.resolve(in: context.environment).cgColor
			layer.lineCap = .round
			layer.lineWidth = sliderWidth
			layer.path = buildPath(width: bounds.width)
		}


		required init?(coder: NSCoder) {
			preconditionFailure()
		}
	}
}


extension Comparable {
	@inlinable
	func clamped(to limits: ClosedRange<Self>) -> Self { min(max(self, limits.lowerBound), limits.upperBound) }
}


#Preview {
	@Previewable @State var playhead = 10.0
	@Previewable @State var playing = false
	VStack {
		PlayerProgressView(total: 30, playhead: playhead, playing: playing) { newValue in
			playhead = newValue
		}
		Spacer()
	}
	.padding()
	.task {
//		try? await Task.sleep(for: .seconds(3))
//		playhead = 5
//		playing = true
//		try? await Task.sleep(for: .seconds(3))
//		playhead = 15
//		playing = false
//		try? await Task.sleep(for: .seconds(2))
//		playhead = 5
//		playing = true
	}
}
