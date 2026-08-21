//
//  View+Ext.swift
//  BLEScanner
//
//  Created by Siarhei Yakushevich on 21/08/2026.
//
import SwiftUI

extension View {
    @inlinable nonisolated public func frame(size: CGSize?,
                                             alignment: Alignment = .center) -> some View {
        frame(width: size?.width, height: size?.height, alignment: alignment)
    }
}
