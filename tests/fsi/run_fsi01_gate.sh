#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

python3 "$ROOT/tools/fsi/fsi01_source_boundary_gate.py"

# Reuse the canonical source-bound worker-context gate. It compiles and runs
# the OpenMP 8-worker test at both O0 and O2 and reruns the transaction substrate.
bash "$ROOT/tests/fci/run_fci03_gate.sh"

echo "F-SI01_GATE PASS"
