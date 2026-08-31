# Parkking iOS Agent Directives

Refer to [AGENTS.md](file:///Users/joey/Developer/projects/parkking/parkking-ios/AGENTS.md) for full guidelines.

## Quick Testing Rules for Agents
- **Iterative Testing:** Use `./scripts/test.sh --only <SuiteName>` or `make test-only SUITE=<SuiteName>` to test only relevant code.
- **Verification:** Run `./scripts/test.sh --fast` or `make test-fast` (skips slow 30MB dataset gates).
- **Full Suite:** Only run `./scripts/test.sh --all` when explicitly requested.
