#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-multi04-p3p4-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "FPE_MULTI04_P3P4_FAIL $*" >&2; exit 1; }

for workers in 1 4; do
  fixture="$BUILD/fixture_w${workers}.f90"
  runner="$BUILD/run_w${workers}.sh"
  cp tests/fpe/mod_fpe_temporal08_production_live_fixture.f90 "$fixture"
  if [[ "$workers" != 1 ]]; then
    python3 - "$fixture" "$workers" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); workers=int(sys.argv[2]); s=p.read_text()
needle="    value%initial_time=0.0_real64\n"
if needle not in s: raise SystemExit("worker config seam missing")
s=s.replace(needle,needle+f"    value%groundwater_parallel_workers={workers}\n",1)
p.write_text(s)
PY
  fi

  cp tests/fpe/run_fpe_temporal08_p3_live_production.sh "$runner"
  python3 - "$runner" "$fixture" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); fixture=Path(sys.argv[2]).resolve(); s=p.read_text()
s=s.replace('ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"','ROOT="$(pwd)"',1)
s=s.replace('tests/fpe/mod_fpe_temporal08_production_live_fixture.f90',str(fixture),1)
# Keep git-diff validation, if any, pointed at repository files only.
p.write_text(s)
PY
  bash "$runner" > "$BUILD/w${workers}.txt"
  grep -Fq 'FPE_TEMPORAL08_LIVE_PRODUCTION_BOOTSTRAP=PASS' "$BUILD/w${workers}.txt" || fail "live bootstrap w=$workers"
  grep -Fq 'FPE_TEMPORAL08_EXACTLY_ONCE_PUBLICATION=PASS' "$BUILD/w${workers}.txt" || fail "exactly once w=$workers"
  grep -Fq 'FGC49D_LIVE_MODFLOW6_6_8_0=PASS' "$BUILD/w${workers}.txt" || fail "MODFLOW w=$workers"
  grep -Fq 'FGC49D_LIVE_MODFLOW_SWAP_LEDGER_PUBLICATION=PASS' "$BUILD/w${workers}.txt" || fail "ledger publication w=$workers"
  grep -E '^(FGC49D_LIVE_ITERATIONS|FGC49D_LIVE_MAX_CELL_RESIDUAL_M_PER_S)=' "$BUILD/w${workers}.txt" > "$BUILD/w${workers}.numeric"
done

diff -u "$BUILD/w1.numeric" "$BUILD/w4.numeric"
cat "$BUILD/w4.numeric"
echo 'FPE_MULTI04_P3_WORKER4_EXACTLY_ONCE_PUBLICATION=PASS'
echo 'FPE_MULTI04_P3_WORKER4_LEDGER_COMMIT=PASS'
echo 'FPE_MULTI04_P4_LIVE_MODFLOW6_WORKER4=PASS'
echo 'FPE_MULTI04_P4_WORKER1_WORKER4_COUPLING_IDENTITY=PASS'
