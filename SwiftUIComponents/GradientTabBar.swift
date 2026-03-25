//
//  GradientTabBar.swift
//
//  Created by Hovik Melikyan on 19.07.25.
//

import SwiftUI


struct WrappedVC: UIViewControllerRepresentable {
	let viewController: UIViewController

	func makeUIViewController(context: Context) -> UIViewController { viewController }
	func updateUIViewController(_ vc: UIViewController, context: Context) {}
}


struct GradientTabBar<Content: View>: View {
	@Binding var selection: Int
	let tabIcons: [String]
	@ViewBuilder var content: () -> Content

	var body: some View {
		ZStack(alignment: .bottom) {
			content()
				.safeAreaPadding(.bottom, 70)

			GeometryReader { proxy in
				HStack(spacing: 0) {
					ForEach(Array(tabIcons.enumerated()), id: \.offset) { index, icon in
						Button {
							selection = index
						} label: {
							Image(systemName: icon)
								.font(.title2)
								.frame(maxWidth: .infinity, maxHeight: .infinity)
								.contentShape(.rect)
						}
						.foregroundStyle(index == selection ? .primary : .secondary)
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


struct GradientTabBarTest: View {
	@State private var selection = 0

	private static let titles = ["Home", "Search", "Notifications", "Profile"]

	private static let icons = ["house.fill", "magnifyingglass", "bell.fill", "person.fill"]

	var body: some View {
		GradientTabBar(selection: $selection, tabIcons: Self.icons) {
			ZStack {
				ForEach(Self.icons.indices, id: \.self) { index in
					TabPage(title: Self.titles[index])
						.opacity(selection == index ? 1 : 0)
				}
			}
		}
	}
}


private struct TabPage: View {
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


#Preview {
	GradientTabBarTest()
}
