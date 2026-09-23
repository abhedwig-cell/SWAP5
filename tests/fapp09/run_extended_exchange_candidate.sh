#!/usr/bin/env bash
set -euo pipefail
ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"
python3 tests/fapp09/test_extended_exchange_candidate.py | tee /tmp/sw-rib-swm01-q4a.txt
grep -Fq 'SW_RIB_SWM01_Q4A_O0_O2_IDENTITY=PASS' /tmp/sw-rib-swm01-q4a.txt
grep -Fq 'SW_RIB_SWM01_Q4A_SOURCE_BOUND_VALUE_AND_TANGENT=PASS' /tmp/sw-rib-swm01-q4a.txt
grep -Fq 'SW_RIB_SWM01_Q4A_NEGATIVE_POWER_INTERFLOW_HELD=PASS' /tmp/sw-rib-swm01-q4a.txt
grep -Fq 'SW_RIB_SWM01_Q4A_EXTENDED_EXCHANGE_CANDIDATE=PASS' /tmp/sw-rib-swm01-q4a.txt
echo 'SW_RIB_SWM01_Q4A_GATE=PASS'
