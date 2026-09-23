#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
python3 tests/sw-rib-swm01/test_q1h_sttab_epsilon_area_representation.py | tee /tmp/sw-rib-swm01-q1h.txt
grep -Fq 'SW_RIB_SWM01_Q1H_CONFIRMATORY_CHARACTERIZATION=PASS' /tmp/sw-rib-swm01-q1h.txt
grep -Fq 'SW_RIB_SWM01_Q1H_OUTSIDE_TRANSITION_EXACT=PASS' /tmp/sw-rib-swm01-q1h.txt
grep -Fq 'SW_RIB_SWM01_Q1H_THEOREM_BOUND=PASS' /tmp/sw-rib-swm01-q1h.txt
grep -Fq 'SW_RIB_SWM01_Q1H_LINEAR_ERROR_CONTROL=PASS' /tmp/sw-rib-swm01-q1h.txt
echo 'SW_RIB_SWM01_Q1H_GATE=PASS'
