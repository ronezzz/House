//
//  SeatSpot.swift
//  House
//
//  Created by Adam Roney on 8/10/25.
//

import SwiftUI

struct SeatSpot<Content: View, Footer: View>: View {
	var title: String
	var isActive: Bool
	@ViewBuilder var content: () -> Content
	@ViewBuilder var footer: () -> Footer
	
	var body: some View {
		VStack(spacing: 8) {
			HStack {
				Text(title)
					.font(.caption.weight(.semibold))
					.foregroundStyle(.white.opacity(0.75))
				Spacer()
			}
			.padding(.horizontal, 10)
			
			ZStack {
				RoundedRectangle(cornerRadius: 16, style: .continuous)
					.strokeBorder(Color.tableLine, lineWidth: isActive ? 2 : 1)
					.background(
						RoundedRectangle(cornerRadius: 16, style: .continuous)
							.fill(.white.opacity(isActive ? 0.06 : 0.04))
					)
				content().padding(10)
			}
			.frame(minHeight: 84)
			
			footer()
		}
		.padding(6)
	}
}
