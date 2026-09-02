# Agent Workflow Guidelines for Parkking iOS

## Testing & Build Optimization Rules

To ensure fast iteration times during agentic loops, always follow these testing practices:

### 1. The Inner Loop (Fast Feedback)
- **NEVER** run the full test suite (`xcodebuild test` or `./scripts/test.sh --all`) when developing or debugging a feature.
- **ALWAYS** run only the specific test suite or test case related to the files you modified.
- Commands to use:
  ```bash
  # Targeted test (runs in ~1-2 seconds)
  ./scripts/test.sh --only <SuiteName>
  # or
  make test-only SUITE=<SuiteName>

  # Examples:
  ./scripts/test.sh --only ScheduleCorpusTests
  ./scripts/test.sh --only CurbVerdictTests
  ./scripts/test.sh --only ParkingMapViewModelTests
  ```

### 2. Fast Test Suite (Pre-completion Verification)
- When verifying your changes before reporting back, use the fast test suite:
  ```bash
  ./scripts/test.sh --fast
  # or
  make test-fast
  ```
- This runs all unit tests while skipping heavy performance and dataset decoding tests (`PerformanceGateTests`, `ParkingDataContractTests`), which load and hash the 30.5MB GeoJSON file.

### 3. Full Test Suite & Performance Gates
- Only run `./scripts/test.sh --all` or `make test-all` if:
  1. The user explicitly requests full validation.
  2. You specifically modified dataset loading, GeoJSON parsing, or performance gate logic (`ParkingDataStore.swift`, `ParkingGeoJSONDecoder.swift`, `ParkingSpatialIndex.swift`).

### 4. Build-only Checks
- To simply verify compilation without running tests:
  ```bash
  make build
  # or
  ./scripts/test.sh --build-only
  ```

---

## Test Harness Architecture & Speed Optimizations
- **Test Host Short-Circuit:** In `ParkkingApp.swift`, `isTesting` detects test runner execution and renders `Color.clear`, preventing eager initialization of `ParkingMapScreen`, `ParkingMapViewModel`, and `CLLocationManager` synchronous XPC locks.
- **Single Simulator Execution:** All test plans and `./scripts/test.sh` run with `-parallel-testing-enabled NO` / `parallelizable: false` so tests run directly on the booted `iPhone 17` without spinning up ephemeral cloned simulators in `~/Library/Developer/XCTestDevices/`.
- **Boot Synchronization:** `./scripts/test.sh` checks simulator readiness using `xcrun simctl bootstatus "iPhone 17" -b` before invoking `xcodebuild`.

## Test Target Directory Reference
- Schedule logic: `ParkkingTests/Schedule/` (`ScheduleCorpusTests`, `CurbVerdictTests`, `ParkingTimeQueryTests`, `OntarioPublicHolidaysTests`)
- Geometry & Spatial indexing: `ParkkingTests/Geometry/` (`CurbSelectionTests`, `ParkingSpatialIndexTests`, `SideNormalizationTests`)
- Map & UI ViewModels: `ParkkingTests/ParkingMap/` (`ParkingMapViewModelTests`, `ParkingOverlayStylingTests`)
- Location client flows: `ParkkingTests/Location/` (`LocationClientFlowTests`, `MapKitSearchClientTests`, `RecentsStoreTests`)
- Verdict display: `ParkkingTests/Verdict/` (`BylawCopyControllerTests`, `VerdictSheetTests`)

