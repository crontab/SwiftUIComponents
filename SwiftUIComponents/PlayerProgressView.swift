//
//  PlayerProgressView.swift
//
//  Created by Hovik Melikyan on 19.07.25.
//

import SwiftUI


private let SliderWidth = 6.0
private let InflatedSliderWidth = 12.0


struct PlayerProgressView: UIViewRepresentable {

	let total: TimeInterval
	let playhead: TimeInterval
	let playing: Bool
	let onDrag: (TimeInterval) -> Void


	func makeUIView(context: Context) -> HostedView {
		HostedView(context: context)
	}


	func updateUIView(_ view: HostedView, context: Context) {
		view.update(total: total, playhead: playhead, playing: playing, onDrag: onDrag, context: context)
	}


	final class HostedView: UIView {

		private var total: TimeInterval = 0
		private var playing: Bool = false
		private var context: Context
		private var onDrag: ((TimeInterval) -> Void)?

		private let barLayer = CAShapeLayer()
		private let progressLayer = CAShapeLayer()

		private var dragStartX: Double? // start of the drag gesture
		private var isDragging: Bool { dragStartX != nil }
		private var sliderWidth: Double { isDragging ? InflatedSliderWidth : SliderWidth }


		init(context: Context) {
			self.context = context
			super.init(frame: .zero)
			layer.addSublayer(barLayer)
			layer.addSublayer(progressLayer)
			addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(didDrag)))
		}


		override func layoutSubviews() {
			super.layoutSubviews()
			setupLayer(barLayer, color: .inactive.opacity(0.5))
			setupLayer(progressLayer, color: .accentColor)
			updatePath()
		}


		fileprivate func update(total: TimeInterval, playhead: TimeInterval, playing: Bool, onDrag: @escaping (TimeInterval) -> Void, context: Context) {
			self.total = total
			progressLayer.strokeEnd = playhead / total
			self.playing = playing
			self.onDrag = onDrag
			self.context = context
			updatePath()
		}


		@objc private func didDrag(_ sender: UIPanGestureRecognizer) {
			switch sender.state {
				case .began:
					let progress = progressLayer.presentation()?.strokeEnd ?? progressLayer.strokeEnd
					dragStartX = bounds.width * progress
					progressLayer.strokeEnd = progress
					progressLayer.removeAllAnimations()
					updatePath()

				case .changed:
					if let dragStartX {
						let x = sender.translation(in: self).x + dragStartX
						let progress = (x / bounds.width).clamped(to: 0...1)
						progressLayer.strokeEnd = progress
						progressLayer.removeAllAnimations()
						onDrag?(progress * total)
					}

				case .ended, .cancelled:
					dragStartX = nil
					updatePath()

				default:
					break
			}
		}


		private func updatePath() {
			guard total > 0, bounds.width > 0 else { return }

			barLayer.lineWidth = sliderWidth
			progressLayer.lineWidth = sliderWidth

			if playing {
				animateStrokeEnd()
			}
			else if !isDragging {
				progressLayer.removeAllAnimations()
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
			layer.path = buildPath(width: bounds.width)
		}


		required init?(coder: NSCoder) {
			preconditionFailure()
		}
	}
}


#Preview {
	@Previewable @State var playhead = 10.0
	@Previewable @State var playing = true
	VStack {
		PlayerProgressView(total: 30, playhead: playhead, playing: playing) { newValue in
		}
		.frame(height: 32)
	}
	.padding()
	.task {
//		try? await Task.sleep(for: .seconds(3))
//		playhead = 5
//		playing = true
		try? await Task.sleep(for: .seconds(3))
		playhead = 15
		playing = false
//		try? await Task.sleep(for: .seconds(2))
//		playhead = 27
//		playing = true
	}
}
