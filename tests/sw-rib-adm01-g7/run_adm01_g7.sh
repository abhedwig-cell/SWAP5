#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-adm01-g7-${GITHUB_RUN_ID:-local}-$$"
RIBASIM_ROOT="${SW_RIB_ADM01_G7_RIBASIM_ROOT:-$ROOT/.ribasim-product-release}"
MODEL_ROOT="$RIBASIM_ROOT/generated_testmodels/swap5_sw_rib_adm01_g7"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "SW_RIB_ADM01_G7_FAIL $*" >&2; exit 91; }

declare -A BLOBS=(
  ["src/process/mod_drainage_extended_exchange.f90"]="25d76013d25c2eaa2d254865149c740bc3257617"
  ["src/runtime/mod_fmr_drainage_response_binding.f90"]="263cf55b2c336d149ba41b4d04f510e10c4207e2"
  ["src/runtime/mod_fmr_serialized_reference_backend.f90"]="0cdf05c1fc066f80aad7807c35a4e718fdecdb09"
  ["src/runtime/mod_fmr_surface_water_head_forcing_adapter.f90"]="1029cd4658a28f4aaf21db3cd480872c2d17722a"
  ["src/runtime/mod_fmr_surface_water_swap_participant.f90"]="5fd5007cf8e523d3b2cd4236114e887d0c383f0a"
)
for path in "${!BLOBS[@]}"; do
  actual="$(git rev-parse "HEAD:$path")"
  test "$actual" = "${BLOBS[$path]}" || fail "production postimage drift $path $actual"
done
echo 'SW_RIB_ADM01_G7_FAPP09_POSTIMAGES=PASS'

bash tests/fci/run_fci109_fapp09_admission.sh > "$BUILD/fci109.txt" 2>&1 || {
  cat "$BUILD/fci109.txt" >&2
  fail "F-CI109 replay"
}
grep -Fq 'F-CI109 FAPP09 CANONICAL ADMISSION GATE PASS' "$BUILD/fci109.txt" || fail "F-CI109 marker"
echo 'SW_RIB_ADM01_G7_FCI109_REPLAY=PASS'

RIBASIM_PIN=eae77424a4078497d40d8197237cb83e3aba6a83
test -d "$RIBASIM_ROOT/.git" || fail "exact Ribasim checkout missing"
ACTUAL_PIN="$(git -C "$RIBASIM_ROOT" rev-parse HEAD)"
test "$ACTUAL_PIN" = "$RIBASIM_PIN" || fail "Ribasim pin mismatch $ACTUAL_PIN"
echo "SW_RIB_ADM01_G7_RIBASIM_PIN=PASS sha=$ACTUAL_PIN"

(
  cd "$RIBASIM_ROOT"
  pyver="$(pixi run python -c 'import ribasim; print(ribasim.__version__)')"
  test "$pyver" = "2026.1.2"
  echo "SW_RIB_ADM01_G7_PYTHON_VERSION=PASS version=$pyver"
  pixi run python "$ROOT/tests/sw-rib-adm01-g7/generate_adm01_g7_real_ribasim.py" "$MODEL_ROOT"
  grep -R -Fq 'ribasim_version = "2026.1.2"' "$MODEL_ROOT" || exit 82
  echo 'SW_RIB_ADM01_G7_MODEL_METADATA=PASS'
  pixi run instantiate-julia
  JULIA_NUM_THREADS=2 pixi run julia --startup-file=no --project=.     "$ROOT/tests/sw-rib-adm01-g7/adm01_g7_realization.jl" "$MODEL_ROOT"
) > "$BUILD/ribasim.txt" 2>&1 || {
  cat "$BUILD/ribasim.txt" >&2
  fail "live Ribasim realization"
}
cat "$BUILD/ribasim.txt"
grep -Fq 'SW_RIB_ADM01_G7_REAL_RIBASIM=PASS' "$BUILD/ribasim.txt" || fail "live Ribasim final marker"
grep -Fq 'SW_RIB_ADM01_G7_RIBASIM_SAME_ORIGIN_RECOMPOSITION=PASS' "$BUILD/ribasim.txt" || fail "Ribasim recomposition marker"
test "$(grep -c '^G7_ITER,' "$BUILD/ribasim.txt")" -ge 4 || fail "iteration receipt count"
grep -Fq 'G7_ITER,E3_NEGATIVE_INFILTRATION_LIMITED,' "$BUILD/ribasim.txt" || fail "E3 iteration evidence"

python3 - "$BUILD/compile-order.txt" <<'PY'
from pathlib import Path
import re,sys
test=Path("tests/sw-rib-adm01-g7/test_adm01_g7_live_receipt.f90")
stub=Path("tests/fsi/fsi04_real_headcalc_stubs.f90")
top=Path("tests/fmr/mod_fmr04_fixed_top_provider.f90")
headcalc=Path("src/legacy/b1_10_port/headcalc.f90")
candidates=[stub,top]+sorted(p for p in Path("src").rglob("*.f90") if "src/legacy/" not in p.as_posix())+[headcalc,test]
mr=re.compile(r"^\s*module\s+(?!procedure\b|subroutine\b|function\b)([a-zA-Z_]\w*)",re.I)
ur=re.compile(r"^\s*use(?:\s*,\s*[^:]*)?\s*(?:::\s*)?([a-zA-Z_]\w*)",re.I)
mods={}; uses={}
for p in candidates:
    ls=p.read_text(errors="replace").splitlines()
    mods[p]=[m.group(1).lower() for l in ls if (m:=mr.match(l))]
    uses[p]=[u.group(1).lower() for l in ls if (u:=ur.match(l))]
providers={}
for p in [stub,top]:
    for m in mods[p]: providers[m]=p
for p in candidates:
    if p in (stub,top,headcalc,test): continue
    for m in mods[p]: providers.setdefault(m,p)
required=set(); unresolved=set()
def add(p):
    if p in required:return
    required.add(p)
    for m in uses.get(p,[]):
        q=providers.get(m)
        if q is not None and q!=p:add(q)
        elif q is None and (m.startswith("mod_") or m=="variables"):unresolved.add((p.as_posix(),m))
add(test); add(headcalc)
if unresolved:
    for p,m in sorted(unresolved): print(f"unresolved {m} used by {p}",file=sys.stderr)
    raise SystemExit(2)
deps={p:{providers[m] for m in uses.get(p,[]) if m in providers and providers[m] in required and providers[m]!=p} for p in required}
order=[]; temp=set(); done=set()
def visit(p):
    if p in done:return
    if p in temp:raise RuntimeError(f"cycle {p}")
    temp.add(p)
    for q in sorted(deps[p],key=lambda x:x.as_posix()):visit(q)
    temp.remove(p); done.add(p); order.append(p)
for p in sorted(required,key=lambda x:x.as_posix()):visit(p)
Path(sys.argv[1]).write_text("\n".join(p.as_posix() for p in order)+"\n")
print(f"SW_RIB_ADM01_G7_COMPILE_CLOSURE_FILES={len(order)}")
PY

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
for opt in 0 2; do
  OUT="$BUILD/o$opt"; mkdir -p "$OUT"; objects=()
  while IFS= read -r source; do
    key="$(printf '%s' "$source" | tr '/.' '__')"
    obj="$OUT/$key.o"
    gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$source" -o "$obj" || fail "compile O$opt $source"
    objects+=("$obj")
  done < "$BUILD/compile-order.txt"
  gfortran -O"$opt" "${objects[@]}" -o "$OUT/test" || fail "link O$opt"

  : > "$OUT/stable.txt"
  iter_count=0
  while IFS=',' read -r prefix case_id iteration head_cm requested realized residual disposition; do
    test "$prefix" = "G7_ITER" || continue
    iter_count=$((iter_count+1))
    outfile="$OUT/${case_id}_${iteration}.txt"
    "$OUT/test" "$case_id" "$iteration" "$head_cm" "$requested" "$realized" "100.0" "$disposition" \
      > "$outfile" 2>&1 || {
        cat "$outfile" >&2
        fail "F-APP09 live receipt O$opt $case_id iteration $iteration"
      }
    cat "$outfile"
    grep '^SW_RIB_ADM01_G7_' "$outfile" >> "$OUT/stable.txt"
  done < "$BUILD/ribasim.txt"

  test "$iter_count" -ge 4 || fail "O$opt insufficient iteration evidence"
  grep -Fq 'SW_RIB_ADM01_G7_ITER_COMMIT_PASS=E1_POSITIVE_DRAINAGE,1' "$OUT/stable.txt" || fail "O$opt E1 commit"
  grep -Fq 'SW_RIB_ADM01_G7_ITER_COMMIT_PASS=E2_NEGATIVE_INFILTRATION_SUFFICIENT,1' "$OUT/stable.txt" || fail "O$opt E2 commit"
  grep -Fq 'SW_RIB_ADM01_G7_ITER_RECOMPOSE_PASS=E3_NEGATIVE_INFILTRATION_LIMITED,' "$OUT/stable.txt" || fail "O$opt E3 recomposition"
  grep -Fq 'SW_RIB_ADM01_G7_ITER_COMMIT_PASS=E3_NEGATIVE_INFILTRATION_LIMITED,' "$OUT/stable.txt" || fail "O$opt E3 final commit"
  test "$(grep -c '^SW_RIB_ADM01_G7_FAPP09_LIVE_RECEIPT=PASS' "$OUT/stable.txt")" -eq "$iter_count" || fail "O$opt receipt marker count"
  echo "SW_RIB_ADM01_G7_O${opt}=PASS"
done

diff -u "$BUILD/o0/stable.txt" "$BUILD/o2/stable.txt" || fail "O0/O2 receipt transaction drift"
echo 'SW_RIB_ADM01_G7_O0_O2_IDENTITY=PASS'
echo 'SW_RIB_ADM01_G7_GATE=PASS'
