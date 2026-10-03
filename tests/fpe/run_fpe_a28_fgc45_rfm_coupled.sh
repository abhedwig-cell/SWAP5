#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-fgc45-n1-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD/modflow-bin" "$BUILD/downloads" "$BUILD/exact" "$BUILD/a28" "$BUILD/py"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "FGC45_N1_FAIL $*" >&2; exit 1; }

python3 - <<PY
from pathlib import Path
from flopy.utils.get_modflow import run_main
run_main(Path("$BUILD/modflow-bin"),owner="MODFLOW-ORG",repo="modflow6",release_id="6.8.0",
         subset={"mf6","libmf6.so"},downloads_dir=Path("$BUILD/downloads"),force=True,quiet=False)
PY
ARCHIVE="$BUILD/downloads/modflow6-6.8.0-linux.zip"
echo "33edf988b672a9f282d6773304c079d0f180541f6fe0c6555265d9c71841256e  $ARCHIVE" | sha256sum -c - || fail "MODFLOW asset hash"
test -f "$BUILD/modflow-bin/libmf6.so" || fail "missing libmf6.so"

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fPIC -fopenmp)
mapfile -t MODULE_SRC < <(python3 - <<'PY'
from pathlib import Path
lines=Path('tests/fpm/run_ppa_wu05a26_backend_compile.sh').read_text().splitlines()
inside=False
for raw in lines:
    s=raw.strip()
    if s=='MODULE_SRC=(':
        inside=True;continue
    if inside and s==')':break
    if inside and s:print(s)
PY
)
MODULE_SRC+=(
  src/runtime/mod_groundwater_coupling_contract.f90
  src/runtime/mod_groundwater_swap_forcing_adapter.f90
  src/runtime/mod_groundwater_swap_transaction_participant.f90
  src/runtime/mod_fmr_groundwater_head_forcing_adapter.f90
  src/runtime/mod_fmr_groundwater_swap_participant.f90
  src/runtime/mod_groundwater_interface_mass_ledger.f90
  src/runtime/mod_groundwater_tile_aggregation.f90
  src/runtime/mod_groundwater_multiswap_types.f90
  src/runtime/mod_modflow6_swap_predictor_response.f90
  src/runtime/mod_modflow6_swap_prescribed_qbot_bottom_face.f90
  src/runtime/mod_modflow6_swap_predictor_tangent_adapter.f90
  src/runtime/mod_modflow6_swap_predictor_origin.f90
  src/runtime/mod_modflow6_swap_predictor_candidate_assembler.f90
  src/runtime/mod_modflow6_multiswap_cell_response.f90
  src/runtime/mod_modflow6_linear_response_backend.f90
  src/runtime/mod_modflow6_api_binding.f90
  src/adapter/mod_modflow6_fgc34_c_bridge.f90
  tests/fgc/support/mod_fgc45_real_multiswap_c_bridge.f90
)
# Additive C3A backend prerequisites; existing gate semantics stay fixed.
mapfile -t MODULE_SRC < <(python3 tests/support/augment_bartholomeus_backend_sources.py "${MODULE_SRC[@]}")
python3 tests/fpe/build_fpe_a28_fgc45_rfm_bridge.py "$BUILD/exact/mod_fgc45_real_multiswap_c_bridge.f90" exact
python3 tests/fpe/build_fpe_a28_fgc45_rfm_bridge.py "$BUILD/a28/mod_fgc45_real_multiswap_c_bridge.f90" a28

compile_variant(){
 local name="$1"; local out="$BUILD/$name"; local objects=()
for source in "${MODULE_SRC[@]}"; do
  if [[ "$source" == "tests/fgc/support/mod_fgc45_real_multiswap_c_bridge.f90" ]]; then source="$out/mod_fgc45_real_multiswap_c_bridge.f90"; fi
  obj="$out/$(basename "${source%.*}").o"
  gfortran "${COMMON[@]}" -O2 -J "$out" -I "$out" -c "$source" -o "$obj" || fail "compile $source"
  objects+=("$obj")
done
gfortran -shared -fopenmp -O2 "${objects[@]}" -o "$out/libfgc45_multiswap.so" || fail "link shared library"
}
compile_variant exact
compile_variant a28

cp tests/fgc/test_fgc45_real_multiswap_modflow_end_to_end.py "$BUILD/py/e2e.py"
python3 - "$BUILD/py/e2e.py" <<'PY'
from pathlib import Path
p=Path(__import__('sys').argv[1]);s=p.read_text()
s=s.replace("import tempfile\n","import tempfile\nimport time\n",1)
s=s.replace("            for outer in range(1,min(40,session.max_solve_iterations)+1):","            t0=time.perf_counter()\n            for outer in range(1,min(40,session.max_solve_iterations)+1):",1)
s=s.replace('            require(converged,"real N:1 SWAP + MODFLOW coupling did not converge")','            require(converged,"real N:1 SWAP + MODFLOW coupling did not converge")\n            print(f"A28_FGC45_SECONDS={time.perf_counter()-t0:.17g}")',1)
p.write_text(s)
PY
export PYTHONPATH="$ROOT/src/adapter:$ROOT/tests/fgc/support"
for mode in exact a28; do
 LIBMF6="$BUILD/modflow-bin/libmf6.so" FGC45_MULTISWAP_LIB="$BUILD/$mode/libfgc45_multiswap.so" python3 "$BUILD/py/e2e.py" > "$BUILD/$mode.txt"
 grep -Fq 'FGC45_REAL_MULTISWAP_MODFLOW_END_TO_END=PASS' "$BUILD/$mode.txt" || { cat "$BUILD/$mode.txt"; fail "$mode coupled"; }
done
python3 - "$BUILD/exact.txt" "$BUILD/a28.txt" <<'PY'
import re,sys
def R(p):
 t=open(p).read()
 def v(k):return float(re.search(rf'^{k}=(.+)$',t,re.M).group(1))
 return {k:v(k) for k in ["FGC45_FINAL_HEAD_M","FGC45_FINAL_Q1_M_PER_S","FGC45_FINAL_Q2_M_PER_S","FGC45_FINAL_WEIGHTED_Q_M_PER_S","FGC45_FINAL_FLUX_RESIDUAL","FGC45_LEDGER1_M","FGC45_LEDGER2_M","A28_FGC45_SECONDS"]}
e,a=R(sys.argv[1]),R(sys.argv[2])
for k in e:
 print(f"A28_FGC45|{k}|EXACT={e[k]:.17e}|A28={a[k]:.17e}|DIFF={a[k]-e[k]:.17e}")
for k in ["FGC45_FINAL_HEAD_M","FGC45_FINAL_Q1_M_PER_S","FGC45_FINAL_Q2_M_PER_S","FGC45_FINAL_WEIGHTED_Q_M_PER_S","FGC45_LEDGER1_M","FGC45_LEDGER2_M"]:
 if abs(a[k]-e[k])>1e-12*max(1.0,abs(e[k])):raise SystemExit(f"coupled drift {k}")
print("A28_FGC45_RFM_COUPLED_CORRECTNESS=PASS")
PY
