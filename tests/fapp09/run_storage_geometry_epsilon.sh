#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
python3 tests/fapp09/test_storage_geometry_epsilon.py | tee /tmp/fapp09-q1h.txt
grep -Fq 'SW_RIB_SWM01_Q1H_EPSILON=1.0e-06' /tmp/fapp09-q1h.txt
grep -Fq 'SW_RIB_SWM01_Q1H_OUTSIDE_TRANSITION_EXACT=PASS' /tmp/fapp09-q1h.txt
grep -Fq 'SW_RIB_SWM01_Q1H_THEOREM_BOUND=PASS' /tmp/fapp09-q1h.txt
grep -Fq 'SW_RIB_SWM01_Q1H_LINEAR_ERROR_CONTROL=PASS' /tmp/fapp09-q1h.txt
echo 'FAPP09_STORAGE_GEOMETRY_EPSILON_GATE=PASS'
