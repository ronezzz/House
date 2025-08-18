//
//  CardFrameKey.swift
//  House
//
//  Created by Adam Roney on 8/10/25.
//

import SwiftUI

// Preference keys for card and shoe frame anchors
struct CardFrameKey: PreferenceKey {
	static var defaultValue: [UUID: Anchor<CGRect>] = [:]
	static func reduce(value: inout [UUID: Anchor<CGRect>], nextValue: () -> [UUID: Anchor<CGRect>]) {
		value.merge(nextValue(), uniquingKeysWith: { $1 })
	}
}

struct ShoeFrameKey: PreferenceKey {
	static var defaultValue: Anchor<CGRect>? = nil
	static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
		if value == nil { value = nextValue() }
	}
}
