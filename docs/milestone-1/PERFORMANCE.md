# Milestone 1 performance notes

Measured on **iPhone 17 simulator (iOS 26.5)** with a Debug test host and a Release simulator build.

| Gate | Target | Observed (sim) |
| --- | --- | --- |
| Decode + spatial index of full snapshot | ≤ ~3s device / soft ≤ 8s sim | ~0.9s (`PerformanceGateTests`) |
| Indexed 30 m tap selection | ≤ ~50 ms | < 50 ms soft gate passed |
| Package dependencies | none | none |
| Renderer | `MKMapView` + grouped `MKMultiPolyline` | **in use** (SwiftUI `MapPolyline` fallback removed) |
| SHA-256 on launch | Debug / tests only | skipped in Release (`ParkingDataStore.validatesHashByDefault`) |

Physical-device Instruments pass was not completed in this environment because Xcode could not refresh the Apple ID / provisioning profile for `com.joeyhershkop.Parkking`. Simulator soft gates and interaction model (viewport subsetting, generation-checked refresh, indexed taps, style-bucket overlays) are in place; re-run Instruments on a signed Release device before App Store cut.

Pinned snapshot:
- `final_parking_map.geojson`
- 30,495,169 bytes
- SHA-256 `a8fc75d6284509281d75ee622c7773518580b014f4ccdac2a56585d00bdc0cf1`
- pipeline rev `0a68237adf8b81d06b97717aa0883e50e0cdec99`
- 21,424 line features + 0 skipped Points
- Overlay volume is roughly 14,227 LineString + 7,197 MultiLineString (~42k line parts). Keep the 8s decode / 50ms tap gates unless they fail on the curb snapshot.
