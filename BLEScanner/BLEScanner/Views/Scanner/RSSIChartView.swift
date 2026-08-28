import BLEKitCore
import Charts
import SwiftUI

extension DiscoveredDevice: RSSIChartViewToDisplay {
    var displayName: String {
        name ?? identifier.uuidString
    }
}

protocol RSSIChartViewToDisplay {
    var displayName: String { get }
}

/// Centered card showing a device's accumulated RSSI-over-time samples as a line chart, plus a
/// CSV export action — the "Chart" counterpart to `RawAdvertisementDataView`, opened from the
/// same row-level button row.
struct RSSIChartView<T: RSSIChartViewToDisplay> : View {
    
    let viewModel: T
    let samples: [RSSISample]
    let onDismiss: () -> Void

    /// Committed horizontal zoom. `1` fits every sample; larger values zoom the time axis in.
    /// Combined with the live pinch delta (`pinchScale`) to derive the visible time window.
    @State private var zoomFactor: CGFloat = 1
    @GestureState private var pinchScale: CGFloat = 1

    /// Smallest time window the user can zoom into, so a fully-pinched chart still shows context.
    private let minVisibleDuration: TimeInterval = 2

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("RSSI Chart")
                        .font(.headline)
                    Text(viewModel.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel("Close")
                .accessibilityIdentifier("rssiChart.dismiss")
            }

            if samples.isEmpty {
                Text("No RSSI samples yet. Keep this device in range while scanning.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 160)
            } else {
                Chart(samples) { sample in
                    LineMark(
                        x: .value("Time", sample.date),
                        y: .value("RSSI", sample.rssi)
                    )
                    .foregroundStyle(.primary)
                    PointMark(
                        x: .value("Time", sample.date),
                        y: .value("RSSI", sample.rssi)
                    )
                    .foregroundStyle(.secondary)
                }
                .chartXAxisLabel("Time")
                .chartYAxisLabel("dBm", position: .top, alignment: .leading)
                .chartXScale(domain: xDomain)
                .chartYScale(domain: yDomain)
                .chartScrollableAxes(.horizontal)
                .chartXVisibleDomain(length: visibleDuration)
                .animation(.easeInOut(duration: 0.3), value: samples)
                .frame(height: 220)
                .contentShape(Rectangle())
                .gesture(zoomGesture)
                .overlay(alignment: .topTrailing) {
                    if isZoomed {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) { zoomFactor = 1 }
                        } label: {
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .font(.caption)
                                .padding(6)
                                .background(.thinMaterial, in: Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Reset zoom")
                        .accessibilityIdentifier("rssiChart.resetZoom")
                        .padding(4)
                    }
                }
                .accessibilityIdentifier("rssiChart.plot")
            }

            Divider()

            ShareLink(
                item: RSSIChartCSVDocument(csv: RSSISampleCSVExporter.csv(for: samples)),
                preview: SharePreview("RSSI Chart – \(viewModel.displayName)")
            ) {
                Label("Export CSV", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
            }
            .disabled(samples.isEmpty)
            .accessibilityIdentifier("rssiChart.export")
        }
        .padding()
        .frame(maxWidth: 340)
        .background(.background, in: RoundedRectangle(cornerRadius: 14))
        .shadow(radius: 20)
    }

    /// Full width of the plotted time range. The chart stays scrollable across this whole span
    /// while `visibleDuration` windows it.
    private var totalDuration: TimeInterval {
        let range = xDomain
        return Swift.max(range.upperBound.timeIntervalSince(range.lowerBound), minVisibleDuration)
    }

    /// Live zoom = committed zoom times the in-flight pinch delta, never below "fit all".
    private var effectiveZoom: CGFloat {
        Swift.max(1, zoomFactor * pinchScale)
    }

    /// Largest zoom that still leaves `minVisibleDuration` of context visible.
    private var maxZoom: CGFloat {
        Swift.max(1, CGFloat(totalDuration / minVisibleDuration))
    }

    private var isZoomed: Bool {
        effectiveZoom > 1.01
    }

    /// Visible time window: the full span divided by the clamped zoom. Shrinks as the user
    /// pinches in; `.chartScrollableAxes(.horizontal)` then lets them pan the remainder.
    private var visibleDuration: TimeInterval {
        totalDuration / Double(Swift.min(effectiveZoom, maxZoom))
    }

    /// Pinch-to-zoom on the time axis. The chart's own scroll view handles panning.
    private var zoomGesture: some Gesture {
        MagnifyGesture()
            .updating($pinchScale) { value, state, _ in
                state = value.magnification
            }
            .onEnded { value in
                zoomFactor = Swift.min(Swift.max(zoomFactor * value.magnification, 1), maxZoom)
            }
    }

    /// Zooms the time axis to the current samples' range (with a small edge margin) so the plot
    /// rescales as new samples arrive instead of keeping whatever domain the first batch implied.
    private var xDomain: ClosedRange<Date> {
        let dates = samples.map(\.date)
        guard let minDate = dates.min(), let maxDate = dates.max() else {
            let now = Date()
            return now...now
        }
        guard minDate < maxDate else {
            return minDate.addingTimeInterval(-1)...minDate.addingTimeInterval(1)
        }
        let margin = maxDate.timeIntervalSince(minDate) * 0.05
        return minDate.addingTimeInterval(-margin)...maxDate.addingTimeInterval(margin)
    }

    /// Zooms the dBm axis to the current samples' min/max (padded, clamped to the valid RSSI
    /// range) so the plot rescales as new samples arrive.
    private var yDomain: ClosedRange<Int> {
        let rssi = samples.map(\.rssi)
        let minValue = -100
        let maxValue = 0
        guard let minRSSI = rssi.min(), let maxRSSI = rssi.max() else {
            return minValue...maxValue
        }
        let padding = 5
        let lower = Swift.max(minValue, minRSSI - padding)
        let upper = Swift.min(maxValue, maxRSSI + padding)
        return lower < upper ? lower...upper : lower...(lower + 1)
    }
}


private struct RSSIChartViewFakeVM {
    let displayName = "Display Name"
    
    func samples() -> [RSSISample] {
        
        let startDate = Date.now

        return (1...40).map { value in
            RSSISample(
                date: startDate.addingTimeInterval(TimeInterval(value)),
                rssi: -65 + Int.random(in: -8...8)
            )
        }
    }
}

extension RSSIChartViewFakeVM: RSSIChartViewToDisplay {}

#Preview {
    @Previewable let viewModel = RSSIChartViewFakeVM()
    
    RSSIChartView(viewModel: viewModel,
                  samples: viewModel.samples()) {
        
    }
}
