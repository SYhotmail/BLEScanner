import BLEKitCore
import Charts
import SwiftUI

extension DiscoveredDevice: RSSIChartView.ViewModel {
    var displayName: String {
        name ?? identifier.uuidString
    }
}

/// Centered card showing a device's accumulated RSSI-over-time samples as a line chart, plus a
/// CSV export action — the "Chart" counterpart to `RawAdvertisementDataView`, opened from the
/// same row-level button row.
struct RSSIChartView: View {
    protocol ViewModel {
        var displayName: String { get }
    }
    
    let viewModel: RSSIChartView.ViewModel
    let samples: [RSSISample]
    let onDismiss: () -> Void

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
                .animation(.easeInOut(duration: 0.3), value: samples)
                .frame(height: 220)
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

        return (1...10).map { value in
            RSSISample(
                date: startDate.addingTimeInterval(TimeInterval(value)),
                rssi: -65 + Int.random(in: -8...8)
            )
        }
    }
}

extension RSSIChartViewFakeVM: RSSIChartView.ViewModel {}

#Preview {
    @Previewable let viewModel = RSSIChartViewFakeVM()
    
    RSSIChartView(viewModel: viewModel,
                  samples: viewModel.samples()) {
        
    }
}
