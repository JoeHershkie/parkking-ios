# Milestone 1 performance notes

Measured on **iPhone 17 simulator (iOS 26.5)** with a Debug test host and a Release simulator build.

| Gate | Target | Observed (sim) |
| --- | --- | --- |
| Decode + spatial index of full snapshot | ≤ ~3s device / soft ≤ 8s sim | ~0.9s (`PerformanceGateTests`) |
| Indexed 80 m tap selection | ≤ ~50 ms | < 50 ms soft gate passed |
| Package dependencies | none | none |
| Renderer | SwiftUI `Map` + `MapPolyline` | **kept** (no MKMapView fallback) |

Physical-device Instruments pass was not completed in this environment because Xcode could not refresh the Apple ID / provisioning profile for `com.joeyhershkop.Parkking`. Simulator soft gates and interaction model (viewport subsetting, generation-checked refresh, indexed taps) are in place; re-run Instruments on a signed device before App Store cut.

Pinned snapshot:
- `final_parking_map.geojson`
- 15,870,101 bytes
- SHA-256 `d985b98cafe6a44060e0fdbd50b21adcea1ca17e6590120a1a120dd372216cc7`
- pipeline rev `0a68237adf8b81d06b97717aa0883e50e0cdec99`
- 21,424 line features + 9 skipped Points
