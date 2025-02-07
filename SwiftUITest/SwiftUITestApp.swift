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
			Stripes()
				.ignoresSafeArea()
				.overlay(alignment: .bottom) {
					TabBarSheet()
				}
		}
	}
}
