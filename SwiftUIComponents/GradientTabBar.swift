//
//  GradientTabBar.swift
//
//  Created by Hovik Melikyan on 19.07.25.
//

import SwiftUI


struct GradientTabBar<Content: View>: View {
	@Binding var selection: Int
	let icons: [ImageResource]
	@ViewBuilder var content: () -> Content

	var body: some View {
		ZStack(alignment: .bottom) {
			content()
				.safeAreaPadding(.bottom, 70)

			GeometryReader { proxy in
				HStack(spacing: 0) {
					ForEach(Array(icons.enumerated()), id: \.offset) { index, icon in
						Image(icon)
							.renderingMode(selection == index ? .original : .template)
							.foregroundStyle(.secondary)
							.frame(maxWidth: .infinity, maxHeight: .infinity)
							.contentShape(.rect)
							.onTapGesture {
								selection = index
							}
					}
				}
				.offset(y: proxy.safeAreaInsets.bottom / 8)
				.background {
					Rectangle()
						.fill(.ultraThinMaterial)
						.mask {
							LinearGradient(stops: [
								.init(color: .clear, location: 0),
								.init(color: .black, location: 0.3),
								.init(color: .black, location: 1),
							], startPoint: .top, endPoint: .bottom)
						}
						.padding(.top, -proxy.safeAreaInsets.bottom)
						.ignoresSafeArea()
				}
			}
			.frame(height: 44)
		}
	}
}


#Preview {

	struct TabPage: View {
		let title: String

		var body: some View {
			ScrollView {
				LazyVStack(spacing: 12) {
					ForEach(0..<20) { item in
						Text("\(title) item \(item)")
							.frame(maxWidth: .infinity, alignment: .leading)
							.padding()
							.background(.quaternary, in: .rect(cornerRadius: 12))
					}
				}
				.padding()
			}
		}
	}

	@Previewable @State var selection = 0

	let titles = ["Home", "Discover", "Coach", "Library"]
	let icons: [ImageResource] = [.tabHome, .tabDiscover, .tabCoach, .tabLibrary]

	return GradientTabBar(selection: $selection, icons: icons) {
		ZStack {
			ForEach(titles.indices, id: \.self) { index in
				TabPage(title: titles[index])
					.opacity(selection == index ? 1 : 0)
			}
		}
	}
}
