//
//  WrappedZoomTransition.swift
//
//  Created by Hovik Melikyan on 05.06.25.
//

import SwiftUI


struct DetailView: View {
	let url: URL

	var body: some View {
		GeometryReader { proxy in
			ScrollView {
				VStack {
					let width = proxy.size.width * 0.9
					let height = width * 4 / 3
					AsyncImage(url: url) { image in
						image
							.resizable()
							.aspectRatio(contentMode: .fill)
					} placeholder: {
						Color.clear
					}
					.frame(width: width, height: height)
					.clipShape(RoundedRectangle(cornerRadius: 12))
				}
			}
			.frame(maxWidth: .infinity)
		}
	}
}


#Preview {
	let url = "https://cdn.marvel.com/u/prod/marvel/i/mg/3/40/62b9e061035c9/clean.jpg"
	DetailView(url: URL(string: url)!)
}
