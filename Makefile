.PHONY: test test-fast test-all test-only build boot-sim help

# Default target runs fast unit tests
test: test-fast

# Fast iteration tests (skips slow performance gates and dataset load)
test-fast:
	@./scripts/test.sh --fast

# Run only a specific test suite or test case (e.g. make test-only SUITE=ScheduleCorpusTests)
test-only:
	@if [ -z "$(SUITE)" ]; then \
		echo "Usage: make test-only SUITE=<SuiteName or ParkkingTests/SuiteName/testName>"; \
		exit 1; \
	fi
	@./scripts/test.sh --only "$(SUITE)"

# Run full test suite including performance gates
test-all:
	@./scripts/test.sh --all

# Build project for testing
build:
	@./scripts/test.sh --build-only

# Pre-boot simulator in background
boot-sim:
	@xcrun simctl boot "iPhone 17" 2>/dev/null || true

help:
	@echo "Parkking iOS Development Commands:"
	@echo "  make test-fast             Run fast unit tests (default)"
	@echo "  make test-only SUITE=...   Run specific test class or function (fastest)"
	@echo "  make test-all              Run full test suite (for CI / pre-push)"
	@echo "  make build                 Build project for testing"
	@echo "  make boot-sim              Pre-boot iPhone 17 simulator"
