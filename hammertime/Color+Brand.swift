//
//  Color+Brand.swift
//  hammertime
//

import SwiftUI

extension Color {
    /// Brand yellow from Figma (#E8FF1C)
    static let brandYellow = Color(red: 232.0/255.0, green: 255.0/255.0, blue: 28.0/255.0)
}

extension LinearGradient {
    /// Primary gradient using brand yellow
    static var brandYellowPrimary: LinearGradient {
        LinearGradient(colors: [Color.brandYellow.opacity(0.95), Color.brandYellow], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

// Allow usage like `.fill(.brandYellowPrimary)` anywhere a ShapeStyle is expected
extension ShapeStyle where Self == LinearGradient {
    static var brandYellowPrimary: LinearGradient { LinearGradient.brandYellowPrimary }
}

// MARK: - Brand Button Style
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 20, weight: .medium))
            .foregroundStyle(Color.black)
            .padding(.vertical, 10)
            .padding(.horizontal, 16)
            .background(
                Capsule()
                    .fill(Color.brandYellow)
                    .overlay(
                        Capsule().stroke(Color.black.opacity(0.05), lineWidth: 1)
                    )
            )
            .shadow(color: Color.black.opacity(0.01), radius: 9, x: 0, y: 21)
            .shadow(color: Color.black.opacity(0.02), radius: 7, x: 0, y: 12)
            .shadow(color: Color.black.opacity(0.03), radius: 5, x: 0, y: 5)
            .shadow(color: Color.black.opacity(0.04), radius: 3, x: 0, y: 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.easeInOut(duration: 0.08), value: configuration.isPressed)
    }
}


