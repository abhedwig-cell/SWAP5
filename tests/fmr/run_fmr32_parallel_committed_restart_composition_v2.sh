#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TMP="$ROOT/tests/fmr/.fmr32-composition-v2-$$.sh"
trap 'rm -f "$TMP"' EXIT
cp "$ROOT/tests/fmr/run_fmr32_parallel_committed_restart_composition.sh" "$TMP"
python3 - "$TMP" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); s=p.read_text()
old="    type(kernel_committed_state_t), allocatable :: continuous_states(:), origin_states(:), restart_states(:)\n"
new="    type(kernel_committed_state_t), allocatable :: continuous_states(:), continuous_mid_states(:), origin_states(:), restart_states(:)\n"
if s.count(old) != 1: raise SystemExit('FMR32 v2 patch: state declaration token mismatch')
s=s.replace(old,new,1)
old="    call require(all_committed(continuous_first) .and. max_abs_residual(continuous_first) <= hard_mass_gate, 'continuous first mass')\n"
new=old+"    continuous_mid_states = continuous_states\n"
if s.count(old) != 1: raise SystemExit('FMR32 v2 patch: midpoint insertion token mismatch')
s=s.replace(old,new,1)
old="    call require(states_identical(continuous_states,origin_states) .or. .true., 'host association guard')\n"
new="    call require(states_identical(continuous_mid_states,origin_states), 'origin committed midpoint state identity')\n"
if s.count(old) != 1: raise SystemExit('FMR32 v2 patch: trivial assertion token mismatch')
s=s.replace(old,new,1)
p.write_text(s)
PY
if grep -Fq ".or. .true." "$TMP"; then
  echo 'FMR32_V2_FAIL trivial always-true assertion remains' >&2
  exit 32
fi
echo 'FMR32_MIDPOINT_STATE_ORACLE=BOUND'
bash "$TMP"
