import SwiftUI

extension Color {
    static func rssiColor(for rssi: Int) -> Color {
        switch rssi {
        case (-50)...: .green
        case -70 ..< -50: .yellow
        case -85 ..< -70: .orange
        default: .red
        }
    }
}
