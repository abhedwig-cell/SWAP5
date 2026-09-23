#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
export PYTHONPATH="$ROOT/tests/sw-rib-swm01${PYTHONPATH:+:$PYTHONPATH}"
python3 tests/sw-rib-swm01/test_q2a_policy.py | tee /tmp/sw-rib-swm01-q2a.txt
grep -Fq 'SW_RIB_SWM01_Q2A_ACCEPTED_STATE_POLICY=PASS' /tmp/sw-rib-swm01-q2a.txt
grep -Fq 'SW_RIB_SWM01_Q2A_ROLLBACK=PASS' /tmp/sw-rib-swm01-q2a.txt
grep -Fq 'SW_RIB_SWM01_Q2A_STALE_COMMIT_FAIL_CLOSED=PASS' /tmp/sw-rib-swm01-q2a.txt
test "$(grep -c '^SW_RIB_SWM01_Q2A_CASE_PASS=' /tmp/sw-rib-swm01-q2a.txt)" -eq 8
echo 'SW_RIB_SWM01_Q2A_GATE=PASS'
