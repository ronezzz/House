//
//  Color+.swift
//  House
//
//  Created by Adam Roney on 8/8/25.
//

import SwiftUI

extension Color {
    static var appBackground: Color {
        #if os(iOS) || os(tvOS) || os(watchOS)
        return Color(UIColor.systemBackground)
        #elseif os(macOS)
        return Color(nsColor: NSColor.windowBackgroundColor)
        #else
        return Color.gray.opacity(0.1)
        #endif
    }
    static var felt: Color { Color(red: 0.06, green: 0.38, blue: 0.26) }
    static var feltDark: Color { Color(red: 0.03, green: 0.25, blue: 0.18) }
    static var tableLine: Color { Color.white.opacity(0.22) }
}
