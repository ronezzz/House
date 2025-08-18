//
//  ShoeView.swift
//  House
//
//  Created by Adam Roney on 8/10/25.
//

import SwiftUI

struct ShoeView: View {
	let decks: Int
	let remaining: Int
	let progress: Double
	init(decks: Int, remaining: Int, progress: Double) {
		self.decks = decks; self.remaining = remaining; self.progress = progress
	}
	
	var body: some View {
		HStack(spacing: 12) {
			ZStack(alignment: .bottomLeading) {
				ForEach(0..<decks, id: \.self) { i in
					let x = CGFloat(i) * -8
					RoundedRectangle(cornerRadius: 10, style: .continuous)
						.fill(Color.white)
						.frame(width: 36, height: 56)
						.overlay(
							RoundedRectangle(cornerRadius: 10, style: .continuous)
								.stroke(Color.black.opacity(0.10), lineWidth: 1)
						)
						.shadow(color: .black.opacity(0.12 + Double(i) * 0.01), radius: 6, x: 0, y: 3)
						.offset(x: x)
				}
			}
			.anchorPreference(key: ShoeFrameKey.self, value: .bounds) { $0 }
			.frame(width: 120, height: 64)
			// SOURCE: temporary card that morphs out of the shoe
			.overlay(alignment: .bottomLeading) {
				// Source is rendered by the flight overlay; keep the shoe clean here
				Color.clear.frame(width: 1, height: 1)
			}
			
			VStack(alignment: .leading, spacing: 4) {
				Text("Shoe")
					.font(.caption2).foregroundStyle(.white.opacity(0.85))
				ZStack(alignment: .leading) {
					Capsule().fill(.white.opacity(0.10)).frame(width: 110, height: 5)
					Capsule().fill(.white.opacity(0.45)).frame(width: 110 * progress, height: 5)
				}
				Text("\(remaining) cards")
					.font(.caption2).foregroundStyle(.white.opacity(0.70))
			}
		}
	}
}
