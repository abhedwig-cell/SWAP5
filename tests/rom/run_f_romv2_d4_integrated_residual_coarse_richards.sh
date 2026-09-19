#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

BASE=ad8a0fbebcf2426e0aab0baaff133b058f8a1d8e
PREREG=integration/f-rom/F-ROMV2_D4_PREREGISTRATION.json
PREREG_BLOB=d47d62c11bc75edce78c28f749ac6e4575e87b17
TEST=tests/rom/test_f_romv2_d4_integrated_residual_coarse_richards.f90
ANALYZER=tests/rom/analyze_f_romv2_d4_integrated_residual_coarse_richards.py
COMPILER=tests/rom/compile_f_rom0_fortran_closure.py
MATERIALIZER=tests/rom/materialize_f_rom0_headcalc_stubs.py
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-romv2-d4-${GITHUB_RUN_ID:-local}-$$"
EVIDENCE="${F_ROMV2_D4_EVIDENCE_DIR:-$ROOT/F-ROMV2-D4-EVIDENCE}"
mkdir -p "$BUILD" "$EVIDENCE"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "F_ROMV2_D4_GATE_FAIL $*" >&2; exit 1; }

git fetch --no-tags origin integration/f-ci-canonical
LIVE="$(git rev-parse FETCH_HEAD)"
[[ "$LIVE" == "$BASE" ]] || fail "canonical advanced after D4 preregistration: $LIVE"
git merge-base --is-ancestor "$BASE" HEAD || fail "D4 candidate is not descendant of preregistered canonical"
git diff --quiet "$BASE"...HEAD -- src reference || fail "D4 mutated src/reference"
[[ "$(git rev-parse HEAD:$PREREG)" == "$PREREG_BLOB" ]] || fail "D4 preregistration blob drift"

python3 - "$PREREG" <<'PY'
import json,sys
p=json.load(open(sys.argv[1]))
assert p["phase"]=="PREREGISTERED_BEFORE_EXECUTION"
assert [(g["id"],g["nodes"],g["dz_cm"]) for g in p["scope"]["geometries"]]==[
 ("R16",16,10),("R8",8,20),("R4",4,40),("R2",2,80)]
assert p["scientific_role"]["blind_confirmation"] is False
assert p["hydrological_evaluation"]["reporting"].startswith("Absolute and relative")
assert p["research_numerical_policy"]["id"]=="STRICT_FIRST_INTEGRATED_WATER_DEPTH_REATTEMPT"
assert p["research_numerical_policy"]["depth_budget"]["epsilon_depth_cm"]==1e-12
assert "NO_D2_OR_D3_RESIDUAL_MAGNITUDE_FITTING" in p["firewalls"]
assert "NO_POST_RESULT_POLICY_RETUNING" in p["firewalls"]
print("F_ROMV2_D4_PREREGISTRATION_LOCK=PASS")
PY

: > "$EVIDENCE/geometry-status.tsv"
for spec in "R16 16 10" "R8 8 20" "R4 4 40" "R2 2 80"; do
  read -r id n dz <<<"$spec"
  stub="$BUILD/stubs_n${n}.f90"
  python3 "$MATERIALIZER" --source tests/fsi/fsi04_real_headcalc_stubs.f90 --output "$stub" --nodes "$n" --dz-cm "$dz"
  rc0=99; rc2=99; complete0=0; complete2=0; identity=0
  for opt in 0 2; do
    outdir="$BUILD/${id}_o${opt}"
    python3 "$COMPILER" --root "$ROOT" --stub "$stub" --target "$TEST" \
      --external-source src/legacy/b1_10_port/headcalc.f90 --build "$outdir" --opt "$opt"
    set +e
    "$outdir/rom0_test" > "$EVIDENCE/${id}_o${opt}.txt" 2>&1
    rc=$?
    set -e
    if grep -Fq 'F_ROMV2_D4_EXECUTION_COMPLETE=PASS' "$EVIDENCE/${id}_o${opt}.txt"; then complete=1; else complete=0; fi
    if [[ "$opt" == "0" ]]; then rc0=$rc; complete0=$complete; else rc2=$rc; complete2=$complete; fi
  done
  if [[ "$rc0" -eq 0 && "$rc2" -eq 0 && "$complete0" -eq 1 && "$complete2" -eq 1 ]]; then
    cmp "$EVIDENCE/${id}_o0.txt" "$EVIDENCE/${id}_o2.txt" || fail "${id} successful O0/O2 drift"
    identity=1
    scientific_status=COMPLETE
    echo "F_ROMV2_D4_${id}_O0_O2_IDENTITY=PASS"
  else
    scientific_status=INTEGRATED_MASS_POLICY_NO_GO
    echo "F_ROMV2_D4_${id}_INTEGRATED_MASS_POLICY_NO_GO rc0=${rc0} rc2=${rc2}"
    grep 'F_ROMV2_D4_POLICY_REJECT|' "$EVIDENCE/${id}_o0.txt" | tail -1 > "$EVIDENCE/${id}_policy_reject.txt" || true
    grep 'F_ROMV2_D4_POLICY_REJECT|' "$EVIDENCE/${id}_o2.txt" | tail -1 >> "$EVIDENCE/${id}_policy_reject.txt" || true
  fi
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$id" "$rc0" "$rc2" "$complete0" "$complete2" "$identity" "$scientific_status" >> "$EVIDENCE/geometry-status.tsv"
done

python3 - "$EVIDENCE/geometry-status.tsv" "$EVIDENCE/geometry-status.json" <<'PY'
import json,sys
out={"schema":"swap5.f-romv2-d4.geometry-execution-status.v1","geometries":{}}
for line in open(sys.argv[1]):
    g,rc0,rc2,c0,c2,ident,status=line.rstrip().split("\t")
    out["geometries"][g]={"o0_exit_code":int(rc0),"o2_exit_code":int(rc2),
      "o0_complete":bool(int(c0)),"o2_complete":bool(int(c2)),
      "o0_o2_identity":bool(int(ident)),"scientific_status":status}
open(sys.argv[2],"w").write(json.dumps(out,indent=2,sort_keys=True)+"\n")
PY

python3 - "$EVIDENCE/geometry-status.json" <<'PY'
import json,sys
s=json.load(open(sys.argv[1]))
assert s["geometries"]["R16"]["scientific_status"]=="COMPLETE", "R16 development reference failed"
PY

args=(--r16 "$EVIDENCE/R16_o2.txt" --status "$EVIDENCE/geometry-status.json" --prereg "$PREREG" --output "$EVIDENCE/F-ROMV2_D4_RESULT.json")
for g in R8 R4 R2; do
  key="$(echo "$g" | tr '[:upper:]' '[:lower:]')"
  status="$(python3 - "$EVIDENCE/geometry-status.json" "$g" <<'PY'
import json,sys
print(json.load(open(sys.argv[1]))["geometries"][sys.argv[2]]["scientific_status"])
PY
)"
  if [[ "$status" == "COMPLETE" ]]; then args+=("--$key" "$EVIDENCE/${g}_o2.txt"); fi
done
python3 "$ANALYZER" "${args[@]}" | tee "$EVIDENCE/analyzer.txt"

sha256sum "$EVIDENCE"/R*_o*.txt "$EVIDENCE/geometry-status.json" "$EVIDENCE/F-ROMV2_D4_RESULT.json" "$EVIDENCE/analyzer.txt" > "$EVIDENCE/sha256.txt"
echo "F_ROMV2_D4_INTEGRATED_MASS_SCREEN=PASS"
