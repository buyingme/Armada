#!/usr/bin/env bash
# Compatibility wrapper for the canonical test runner.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/run_tests.sh" "$@"
