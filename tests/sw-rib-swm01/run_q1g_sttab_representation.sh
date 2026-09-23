#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
python3 tests/sw-rib-swm01/test_q1g_sttab_ribasim_representation.py | tee /tmp/sw-rib-swm01-q1g.txt
grep -Fq 'SW_RIB_SWM01_Q1G_EXACT_DIRECT_STTAB_MAPPING=FALSIFIED' /tmp/sw-rib-swm01-q1g.txt
grep -Fq 'SW_RIB_SWM01_Q1G_CHARACTERIZATION=PASS' /tmp/sw-rib-swm01-q1g.txt
echo 'SW_RIB_SWM01_Q1G_GATE=PASS'
