#!/usr/bin/env bash
set -euo pipefail

# scripts/test.sh - Fast & targeted test runner for Parkking iOS
#
# Usage:
#   ./scripts/test.sh                      # Runs fast unit tests (skipping heavy 30MB dataset gates)
#   ./scripts/test.sh --fast               # Runs fast unit tests
#   ./scripts/test.sh --only <Suite/Test>  # Runs only the specified test or suite (1-2s iteration)
#   ./scripts/test.sh --all                # Runs entire test suite including PerformanceGateTests
#   ./scripts/test.sh --build-only         # Builds project for testing without executing

SCHEME="${SCHEME:-Parkking}"
DEVICE_NAME="${DEVICE_NAME:-iPhone 17}"
DESTINATION="${DESTINATION:-platform=iOS Simulator,name=${DEVICE_NAME}}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-build/DerivedData}"

MODE="fast"
TARGET_TEST=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --only|-o)
      MODE="only"
      TARGET_TEST="$2"
      shift 2
      ;;
    --only=*)
      MODE="only"
      TARGET_TEST="${1#*=}"
      shift 1
      ;;
    --fast|-f)
      MODE="fast"
      shift 1
      ;;
    --all|-a)
      MODE="all"
      shift 1
      ;;
    --build-only|-b)
      MODE="build"
      shift 1
      ;;
    --help|-h)
      echo "Usage: $0 [--fast | --only <Suite/Test> | --all | --build-only]"
      echo ""
      echo "Options:"
      echo "  --fast, -f             Run fast unit tests (skips slow dataset decode & perf gates)"
      echo "  --only, -o <Target>    Run only a specific test class or test function (e.g. ScheduleCorpusTests)"
      echo "  --all, -a              Run all tests including 30MB dataset decode and performance gates"
      echo "  --build-only, -b       Build for testing without running tests"
      exit 0
      ;;
    *)
      # If passed an argument without flag, assume it's a test name
      MODE="only"
      TARGET_TEST="$1"
      shift 1
      ;;
  esac
done

# Ensure simulator is booted and ready before running tests
ensure_sim_booted() {
  local booted
  booted=$(xcrun simctl list devices available | grep -E "^[[:space:]]*${DEVICE_NAME} \(" | grep -F "(Booted)" || true)
  if [[ -z "${booted}" ]]; then
    echo "⚡ Booting ${DEVICE_NAME} simulator..."
    xcrun simctl boot "${DEVICE_NAME}" >/dev/null 2>&1 || true
    xcrun simctl bootstatus "${DEVICE_NAME}" -b >/dev/null 2>&1 || true
  fi
}

FORMATTER=""
if [[ -t 1 ]] && command -v xcbeautify >/dev/null 2>&1; then
  FORMATTER="xcbeautify"
fi

run_xcodebuild() {
  if [[ -n "$FORMATTER" ]]; then
    set -o pipefail
    xcodebuild "$@" | "$FORMATTER"
  else
    xcodebuild "$@"
  fi
}

case "$MODE" in
  build)
    echo "🔨 Building ${SCHEME} for testing (${DESTINATION})..."
    run_xcodebuild build-for-testing \
      -scheme "${SCHEME}" \
      -destination "${DESTINATION}" \
      -derivedDataPath "${DERIVED_DATA_PATH}"
    ;;

  only)
    ensure_sim_booted
    # Prefix with ParkkingTests if not provided
    FULL_TARGET="$TARGET_TEST"
    if [[ "$FULL_TARGET" != ParkkingTests* ]]; then
      FULL_TARGET="ParkkingTests/${FULL_TARGET}"
    fi
    echo "🎯 Running targeted test: ${FULL_TARGET}..."
    run_xcodebuild test \
      -scheme "${SCHEME}" \
      -destination "${DESTINATION}" \
      -derivedDataPath "${DERIVED_DATA_PATH}" \
      -parallel-testing-enabled NO \
      -only-testing:"${FULL_TARGET}"
    ;;

  fast)
    ensure_sim_booted
    echo "🚀 Running fast test suite (skipping PerformanceGateTests & ParkingDataContractTests)..."
    run_xcodebuild test \
      -scheme "${SCHEME}" \
      -destination "${DESTINATION}" \
      -derivedDataPath "${DERIVED_DATA_PATH}" \
      -parallel-testing-enabled NO \
      -skip-testing:ParkkingTests/PerformanceGateTests \
      -skip-testing:ParkkingTests/ParkingDataContractTests
    ;;

  all)
    ensure_sim_booted
    echo "🧪 Running full test suite..."
    run_xcodebuild test \
      -scheme "${SCHEME}" \
      -destination "${DESTINATION}" \
      -derivedDataPath "${DERIVED_DATA_PATH}" \
      -parallel-testing-enabled NO
    ;;
esac

