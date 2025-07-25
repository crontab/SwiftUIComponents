//
//  FoundationEx.swift
//  SwiftUIComponents
//
//  Created by Hovik Melikyan on 20.07.25.
//

import Foundation


extension Comparable {
	@inlinable
	func clamped(to limits: ClosedRange<Self>) -> Self { min(max(self, limits.lowerBound), limits.upperBound) }
}
