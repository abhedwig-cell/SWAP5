#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILDROOT="${RUNNER_TEMP:-/tmp}/f-pdi-vt04-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILDROOT"
dump_logs () {
  rc=$?
  echo "F-PDI-VT04 technical failure rc=$rc"
  for x in /tmp/fpdivt04-*.log; do
    if [[ -f "$x" ]]; then echo "===== $x ====="; tail -200 "$x"; fi
  done
  exit $rc
}
trap dump_logs ERR
trap 'rm -rf "$BUILDROOT"' EXIT

SRC_SHA="c22bd832ddf3e53e330a552f5e31e74f183362d1"
CASE_SHA="a839e2e905f34dd264ad0c739f638454b3023def"

git clone -q https://github.com/SWAP-model/SWAP.git "$BUILDROOT/control-src"
git -C "$BUILDROOT/control-src" checkout -q "$SRC_SHA"
cp -a "$BUILDROOT/control-src" "$BUILDROOT/candidate-src"

git clone -q https://github.com/SWAP-model/swap-testcases.git "$BUILDROOT/cases-src"
git -C "$BUILDROOT/cases-src" checkout -q "$CASE_SHA"

patch_swap009 () {
python3 - "$1/src/soil/WC_K_models_04_11.f90" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); s=p.read_text()
old="Kvap = Kvap_func (WC, dabs(h), Temp) * Conv"
assert s.count(old)==4
s=s.replace(old,"Kvap = Kvap_func (WC, h, Temp) * Conv")
p.write_text(s)
PY
}

patch_temp () {
python3 - "$1/src/soil/WC_K_models_04_11.f90" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]);s=p.read_text()
decl="real(8)                :: fKvap, Da, MgRT, Rho_sv"
assert decl in s
s=s.replace(decl,"real(8)                :: fKvap, Da, MgRT, Rho_sv, TK",1)
assert "MgRT      = MgR/(Temp+273.15d0)" in s
assert "Da        = 2.14d-5*((Temp+273.15d0)/273.15d0)**2" in s
assert "Rho_sv    = 1.0d-3*dexp(31.3716d0 - 6014.79d0/Temp - 7.92495d-3*Temp)/Temp" in s
s=s.replace("MgRT      = MgR/(Temp+273.15d0)","TK        = Temp + 273.15d0\nMgRT      = MgR/TK",1)
s=s.replace("Da        = 2.14d-5*((Temp+273.15d0)/273.15d0)**2","Da        = 2.14d-5*(TK/273.15d0)**2",1)
s=s.replace("Rho_sv    = 1.0d-3*dexp(31.3716d0 - 6014.79d0/Temp - 7.92495d-3*Temp)/Temp","Rho_sv    = 1.0d-3*dexp(31.3716d0 - 6014.79d0/TK - 7.92495d-3*TK)/TK",1)
p.write_text(s)
PY
}

patch_swap009 "$BUILDROOT/control-src"
patch_swap009 "$BUILDROOT/candidate-src"
patch_temp "$BUILDROOT/candidate-src"

python3 -m pip install -q meson ninja

meson setup "$BUILDROOT/control-build" "$BUILDROOT/control-src" >/tmp/fpdivt04-control-meson.log
meson compile -C "$BUILDROOT/control-build" >/tmp/fpdivt04-control-build.log
meson setup "$BUILDROOT/candidate-build" "$BUILDROOT/candidate-src" >/tmp/fpdivt04-candidate-meson.log
meson compile -C "$BUILDROOT/candidate-build" >/tmp/fpdivt04-candidate-build.log

mkdir -p "$BUILDROOT/control-vap" "$BUILDROOT/candidate-vap" "$BUILDROOT/control-novap" "$BUILDROOT/candidate-novap"
python3 "$ROOT/research/pdi_vt/f_pdi_vt04_make_case.py" "$BUILDROOT/cases-src/cases/grassgrowth/legacy" "$BUILDROOT/control-vap" --swvapor 1 | tee /tmp/fpdivt04-vap-case-hash.txt
cp -a "$BUILDROOT/control-vap/." "$BUILDROOT/candidate-vap/"
python3 "$ROOT/research/pdi_vt/f_pdi_vt04_make_case.py" "$BUILDROOT/cases-src/cases/grassgrowth/legacy" "$BUILDROOT/control-novap" --swvapor 0 | tee /tmp/fpdivt04-novap-case-hash.txt
cp -a "$BUILDROOT/control-novap/." "$BUILDROOT/candidate-novap/"

run_swap () {
  local exe="$1"; local dir="$2"; local label="$3"
  set +e
  (cd "$dir" && "$exe") >"/tmp/${label}.log" 2>&1
  rc=$?
  set -e
  if [[ "$rc" -ne 0 && "$rc" -ne 100 ]]; then
    echo "$label unexpected rc=$rc"
    tail -100 "/tmp/${label}.log"
    return 1
  fi
  grep -q "Swap normal completion" "/tmp/${label}.log"
  echo "$label NORMAL rc=$rc"
}

CTRL="$BUILDROOT/control-build/swap"
CAND="$BUILDROOT/candidate-build/swap"
[[ -x "$CTRL" && -x "$CAND" ]]

run_swap "$CTRL" "$BUILDROOT/control-vap" control_vap
run_swap "$CAND" "$BUILDROOT/candidate-vap" candidate_vap
run_swap "$CTRL" "$BUILDROOT/control-novap" control_novap
run_swap "$CAND" "$BUILDROOT/candidate-novap" candidate_novap

python3 "$ROOT/research/pdi_vt/f_pdi_vt04_compare.py"   "$BUILDROOT/control-vap" "$BUILDROOT/candidate-vap"   "$BUILDROOT/control-novap" "$BUILDROOT/candidate-novap" | tee "${1:-/tmp/f_pdi_vt04.json}"

echo "--- control vapor tail ---"
tail -40 /tmp/control_vap.log
echo "--- candidate vapor tail ---"
tail -40 /tmp/candidate_vap.log
