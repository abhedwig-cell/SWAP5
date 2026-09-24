#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
export PYTHONPATH="$ROOT/src/adapter${PYTHONPATH:+:$PYTHONPATH}"
python3 tests/triangle/test_sw_tri01_c_publication_order.py | tee /tmp/sw-tri01-c.txt
for marker in   SW_TRI01_C_CASE_PASS=C1_ALL_MATCH_PUBLISH_ONCE   SW_TRI01_C_CASE_PASS=C2_RIBASIM_MISMATCH_SAME_ORIGIN_RECOMPOSE   SW_TRI01_C_CASE_PASS=C3_GROUNDWATER_NOT_CONVERGED_NO_PUBLICATION   SW_TRI01_C_CASE_PASS=C4_STALE_JOINT_ORIGIN_FAIL_CLOSED   SW_TRI01_C_DUAL_EXTERNAL_PUBLICATION_ORDER=PASS; do
  grep -Fq "$marker" /tmp/sw-tri01-c.txt
done
echo 'SW-TRI01-C DUAL EXTERNAL ORDERING GATE PASS'
