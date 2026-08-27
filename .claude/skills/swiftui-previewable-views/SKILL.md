---
name: swiftui-previewable-views
description: Write or review a SwiftUI view in BLEScanner so it has a working #Preview backed by a minimal, view-local protocol rather than a whole concrete model/dependency. Use when adding a new view under BLEScanner/BLEScanner/Views/, or when a view's initializer takes a full concrete type (a TCA model like DiscoveredDevice, a client, a large struct) that would be expensive to construct for a preview.
---

# SwiftUI Previewable Views

## Why this matters

`#Preview` is a primary tool for iterating on views in this project — it must keep working, and
it must stay *cheap* to construct. A view that stores a whole concrete production type (a TCA
model, a hardware client, a large struct with many unrelated fields) forces every preview of that
view to stand up that type's full dependency graph just to render one screen. Over time this
either kills the preview (someone deletes it) or makes previews slow/fragile.

The fix used in this codebase: the view declares a **minimal protocol** exposing only the
properties it actually reads, defined right next to the view. Production types conform via a
plain `extension`. Previews get a tiny fake struct that hardcodes literal values — no fixtures,
no dependency injection, no TCA store.

## Reference example

`BLEScanner/BLEScanner/Views/Scanner/RSSIChartView.swift`:

```swift
extension DiscoveredDevice: RSSIChartView.ViewModel {
    var displayName: String {
        name ?? identifier.uuidString
    }
}

struct RSSIChartView: View {
    protocol ViewModel {
        var displayName: String { get }
    }

    let viewModel: RSSIChartView.ViewModel
    let samples: [RSSISample]
    let onDismiss: () -> Void
    // ...
}

struct RSSIChartViewFakeVM: RSSIChartView.ViewModel {
    let displayName = "Display Name"
}

#Preview {
    RSSIChartView(viewModel: RSSIChartViewFakeVM(), samples: RSSIChartViewFakeVM.samples()) {}
}
```

The view only ever needed `displayName` out of `DiscoveredDevice`'s many fields — the protocol
says so explicitly, and the preview's fake conformer is a one-line struct instead of a fully
populated `DiscoveredDevice`.

Contrast with `RawAdvertisementDataView.swift`, which stores `let device: DiscoveredDevice`
directly and has no `#Preview` at all — a candidate for this same treatment if it's touched next.

## When writing or reviewing a view

1. **Nest the protocol in the view** (`protocol ViewModel { ... }` inside the `View` struct, as
   above), so its shape is scoped to that one view and obviously not a shared abstraction.
2. **Only include what the view's `body` actually reads.** Don't mirror the whole source model —
   if the view shows a name and an RSSI value, the protocol has exactly those two properties.
3. **Conform production types via `extension`** at the top of the same file (e.g.
   `extension DiscoveredDevice: RSSIChartView.ViewModel`), not by changing the source model
   itself.
4. **Add a `#if DEBUG` fake conformer + `#Preview`** using literal/hardcoded values — no
   `@Dependency`, no `TestStore`, no fixtures from `BLEKitTestSupport`. If sample data (e.g. an
   array) is needed, generate it inline in the fake type, not from production code paths.
5. Keep collaborators that aren't read directly (closures like `onDismiss`, arrays like
   `samples: [RSSISample]`) as plain stored properties — the protocol is only for the
   "one concrete model with more than the view needs" case, not every parameter.
6. When reviewing an existing view that takes a full concrete type and has no `#Preview`, suggest
   this refactor rather than leaving it — but don't do it opportunistically to unrelated views
   outside the current change.
