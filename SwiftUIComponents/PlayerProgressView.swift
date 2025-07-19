//
//  PlayerProgressView.swift
//
//  Created by Hovik Melikyan on 19.07.25.
//

import SwiftUI


let PlayerProgressHeight = sliderWidth + 18

private let sliderWidth = 6.0
private let inflatedSliderWidth = 12.0


struct PlayerProgressView: UIViewRepresentable {

	let total: TimeInterval
	let value: TimeInterval
	var animateTo: TimeInterval?


	func makeUIView(context: Context) -> HostedPlayerProgressView {
		HostedPlayerProgressView(context: context)
	}


	func updateUIView(_ view: HostedPlayerProgressView, context: Context) {
		view.update(total: total, value: value, animateTo: animateTo, context: context)
	}


	final class HostedPlayerProgressView: UIView {

		init(context: Context) {
			self.context = context
			super.init(frame: .zero)
			barLayer.addSublayer(progressLayer)
		}

		private var total: TimeInterval = 0
		private var value: TimeInterval = 0
		private var animateTo: TimeInterval? = nil
		private var context: Context
		override class var layerClass: AnyClass { CAShapeLayer.self }
		private var barLayer: CAShapeLayer { layer as! CAShapeLayer }
		private let progressLayer = CAShapeLayer()


		override func layoutSubviews() {
			super.layoutSubviews()
			updatePath()
		}


		fileprivate func update(total: TimeInterval, value: TimeInterval, animateTo: TimeInterval?, context: Context) {
			self.total = total
			self.value = value
			self.animateTo = animateTo
			self.context = context
			updatePath()
		}


		private func updatePath() {
			guard total > 0, bounds.width > 0 else { return }

			barLayer.strokeColor = Color.inactive.opacity(0.5).resolve(in: context.environment).cgColor
			barLayer.lineWidth = sliderWidth
			barLayer.lineCap = .round
			barLayer.path = buildPath(width: bounds.width)

			progressLayer.strokeColor = Color.accentColor.resolve(in: context.environment).cgColor
			progressLayer.lineWidth = sliderWidth
			progressLayer.lineCap = .round
			progressLayer.path = buildPath(width: bounds.width)
			progressLayer.strokeEnd = value / total

			if let animateTo, animateTo != value {
				animate(from: value / total, to: animateTo / total, duration: abs(animateTo - value))
			}
			else {
				progressLayer.removeAllAnimations()
			}
		}


		private func animate(from: Double, to: Double, duration: TimeInterval) {
			progressLayer.removeAllAnimations()
			progressLayer.strokeEnd = to
			CATransaction.begin()
			let animation = CABasicAnimation(keyPath: "strokeEnd")
			animation.fromValue = from
			animation.toValue = to
			animation.duration = duration
			progressLayer.add(animation, forKey: "progress")
			CATransaction.commit()
		}


		private func buildPath(width: Double) -> CGPath {
			let middle = bounds.height / 2
			let path = UIBezierPath()
			path.move(to: CGPoint(x: sliderWidth / 2, y: middle))
			path.addLine(to: CGPoint(x: width - sliderWidth / 2, y: middle))
			return path.cgPath
		}


		required init?(coder: NSCoder) {
			preconditionFailure()
		}
	}
}


#Preview {
	@Previewable @State var value = 0.0
	@Previewable @State var animateTo = Optional(30.0)
	VStack {
		PlayerProgressView(total: 30, value: value, animateTo: animateTo)
			.frame(height: PlayerProgressHeight)
			.border(.red)
		PlayerProgressView(total: 30, value: 10, animateTo: nil)
		Spacer()
	}
	.padding()
	.task {
//		try? await Task.sleep(for: .seconds(2))
//		value = 0
//		animateTo = 5
//		try? await Task.sleep(for: .seconds(2))
//		value = 15
//		animateTo = nil
//		try? await Task.sleep(for: .seconds(2))
//		value = 5
//		animateTo = 7
	}
}
