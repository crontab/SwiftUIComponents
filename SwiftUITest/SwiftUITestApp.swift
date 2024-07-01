//
//  SwiftUITestApp.swift
//  SwiftUITest
//
//  Created by Hovik Melikyan on 29.03.24.
//

import SwiftUI


@main
struct SwiftUITestApp: App {
	@State private var state: Bool = false

	var body: some Scene {
		WindowGroup {
//			ContentView()
			Group {
				if state {
					View1(state: $state, bgColor: .black.opacity(0.1))
				}
				else {
					View1(state: $state, bgColor: .yellow.opacity(0.1))
				}
			}
			.animation(.default, value: state)
		}
	}
}


// MARK: - Experiment

struct View1: View {
	@Binding var state: Bool
	let bgColor: Color

	var body: some View {
		NavigationStack {
			ZStack {
				VStack {
					Spacer()
					Button{
						state.toggle()
					} label: {
						Text("Flip")
							.foregroundColor(.primary)
							.frame(height: 64)
							.frame(maxWidth: .infinity)
							.background(.yellow)
					}
					.containerShape(Capsule())
				}
				.padding(24)
			}
			.background(bgColor)
		}
	}
}


#Preview {
	View1(state: .constant(true), bgColor: .black.opacity(0.1))
}
