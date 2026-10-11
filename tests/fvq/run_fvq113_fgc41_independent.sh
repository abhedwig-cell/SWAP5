#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
python3 tests/fvq/test_fvq113_fgc41_independent.py
