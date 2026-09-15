#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
: "${FVQ09_B0_DISTRIBUTION:?Set FVQ09_B0_DISTRIBUTION to the exact licensed SWAP_4.3.1.zip}"
: "${FVQ09_TTUTIL_ROOT:?Set FVQ09_TTUTIL_ROOT to the exact TTUTIL source root}"
: "${FVQ09_CASE:?Set FVQ09_CASE to the exact admitted Hupsel qualification case}"

OUT="${FVQ09_OUTPUT_DIR:-$PWD/fvq09-real-observation}"
BUILD="${FVQ09_BUILD:-${TMPDIR:-/tmp}/swap5-fvq09-real-$$}"
OFFSET="${FVQ09_OFFSET:-760}"
PREFIX="${FVQ09_PREFIX_DAYS:-0.25}"
DURATION="${FVQ09_DURATION_DAYS:-1.0}"
rm -rf "$BUILD"
mkdir -p "$BUILD" "$OUT"
trap 'rm -rf "$BUILD"' EXIT

# Fail before materialization/compilation unless every external artifact is
# byte-exact and independently admitted in the persisted F-VQ09 contract.
set +e
python "$ROOT/tools/vq/fvq09_asset_bundle.py" validate-bundle \
  --b0 "$FVQ09_B0_DISTRIBUTION" \
  --ttutil "$FVQ09_TTUTIL_ROOT" \
  --case "$FVQ09_CASE" \
  > "$OUT/bundle.json"
BUNDLE_RC=$?
set -e
if [[ $BUNDLE_RC -ne 0 ]]; then
  cat "$OUT/bundle.json"
  echo "F-VQ09 real execution blocked by external asset admission" >&2
  exit "$BUNDLE_RC"
fi

gfortran --version | head -n 1 > "$OUT/compiler.txt"
python "$ROOT/tools/vq/fvq09_materialize_production_source.py" \
  --b0 "$FVQ09_B0_DISTRIBUTION" \
  --output "$BUILD/source" \
  > "$OUT/materialization.json"

# Normalize the admitted legacy source for GNU/Linux compilation without
# changing any physical formula. This is the same DEC-conditional projection
# used by the qualified real F-CI07 runner.
GNU="$BUILD/gnu"
python - "$BUILD/source" "$GNU" "$FVQ09_TTUTIL_ROOT/ttutilprefs.f90" <<'PY'
from pathlib import Path
import shutil,sys
src,out,prefs=map(Path,sys.argv[1:])
if out.exists(): shutil.rmtree(out)
shutil.copytree(src,out)
shutil.copy2(prefs,out/'ttutilprefs.f90')
def cond_value(text):
    t=text.strip().lower().replace(' ','')
    if 'defined(multiswap)' in t or 'defined(with_sss)' in t or 'defined(with_animo)' in t: return False
    if '(linux==0)' in t or 'linux==0' in t: return False
    raise RuntimeError(f'unknown DEC conditional: {text}')
for p in out.glob('*.f90'):
    lines=p.read_text(encoding='latin1').splitlines(keepends=True); result=[]; stack=[]; active=True
    for line in lines:
        s=line.strip(); u=s.upper()
        if u.startswith('!DEC$ IF'):
            c=cond_value(s); stack.append((active,c)); active=active and c; continue
        if u.startswith('!DEC$ ELSE'):
            parent,c=stack[-1]; active=parent and not c; continue
        if u.startswith('!DEC$ END IF'):
            parent,_=stack.pop(); active=parent; continue
        if active: result.append(line)
    if stack: raise RuntimeError(f'unclosed DEC block in {p.name}')
    p.write_text(''.join(result),encoding='latin1')
PY

TT="$FVQ09_TTUTIL_ROOT"
TTB="$BUILD/ttbuild"
mkdir -p "$TTB"
TTFLAGS=(-O2 -std=legacy -fallow-argument-mismatch -fno-range-check -ffixed-line-length-none -J "$TTB" -I "$TTB" -I "$TT")
gfortran "${TTFLAGS[@]}" -c "$TT/ttutilprefs.f90" -o "$TTB/ttutilprefs.o"
gfortran "${TTFLAGS[@]}" -c "$TT/rdmodulettutil.f90" -o "$TTB/rdmodulettutil.o"
gfortran "${TTFLAGS[@]}" -c "$TT/outdat.f90" -o "$TTB/outdat.o"
gfortran "${TTFLAGS[@]}" -c "$TT/ttutil.f90" -o "$TTB/ttutil.o"
for f in "$TT"/*.for "$TT"/*.f90; do
  case "$(basename "$f")" in ttutilprefs.f90|rdmodulettutil.f90|outdat.f90|ttutil.f90) continue;; esac
  gfortran "${TTFLAGS[@]}" -c "$f" -o "$TTB/$(basename "${f%.*}").o"
done
TTLIB="$BUILD/libttutil.a"
ar rcs "$TTLIB" "$TTB"/*.o

FILES=(ttutilprefs.f90 params.f90 description.f90 wofost_soil_interface.f90 interface_atmosphere.f90 arrays.f90 wofost_soil_declarations.f90 sptabulated.f90 variables.f90 WC_K_models_04_11.f90 interface_plant.f90 swap_base.f90 fixed.f90 snow.f90 wofostnut.f90 MOD_drainage.f90 temperature.f90 MOD_RIA.f90 MOD_MvG_functions.f90 irrigation.f90 MOD_meteo.f90 MOD_runon.f90 MOD_Kavg_Szym.f90 surfacewater.f90 divdra.f90 calcgwl.f90 macropore.f90 integral.f90 RWU_micro.f90 drainage.f90 timecontrol.f90 frozencond.f90 solute.f90 wofost.f90 boundtop.f90 soilwater.f90 MOD_cropdevelopment.f90 oxygenstress.f90 rootextraction.f90 swap_csv_output.f90 tillage.f90 swap.f90 MOD_out_PEARL_ANIMO.f90 tridag.f90 initialize.f90 readswap.f90 wofost_soil_watern.f90 hysteresis.f90 functions.f90 watstor.f90 macroporeoutput.f90 swapoutput.f90 wofost_soil_balancecheck.f90 wofost_soil_parameters.f90 wofost_soil_orgmatn.f90 fluxes.f90 wofost_soil_rateconstants.f90 wofost_soil_cropresidues.f90 wofost_soil_amendments.f90 macrorate.f90 headcalc.f90 management_soil.f90 boundbottom.f90)

for opt in 0 2; do
  O="$BUILD/o$opt"
  mkdir -p "$O"
  STRICT=(-O$opt -std=f2008 -Wall -Wextra -Werror -fcheck=all -fbacktrace -ffree-line-length-none -J "$O" -I "$O")
  BFLAGS=(-O$opt -cpp -Dlinux -std=legacy -fallow-argument-mismatch -fno-range-check -ffree-line-length-none -finit-local-zero -J "$O" -I "$O")

  # Modules required by the controlled legacy source itself.
  gfortran "${STRICT[@]}" -c "$ROOT/src/runtime/mod_a23bu_worker_execution_context.f90" -o "$O/worker.o"
  gfortran "${STRICT[@]}" -c "$ROOT/src/adapter/mod_b1_10_trial_mass.f90" -o "$O/trial_mass.o"
  gfortran "${STRICT[@]}" -c "$ROOT/src/adapter/mod_b1_10_interval_seam.f90" -o "$O/interval.o"

  for f in "${FILES[@]}"; do
    gfortran "${BFLAGS[@]}" -c "$GNU/$f" -o "$O/legacy_${f%.f90}.o"
  done

  # Qualified canonical adapters/runtime bound to production-source head da5026d8.
  gfortran "${STRICT[@]}" -c "$ROOT/src/transaction/mod_transaction_reference.f90" -o "$O/transaction.o"
  gfortran "${STRICT[@]}" -c "$ROOT/src/runtime/mod_canonical_contracts.f90" -o "$O/contracts.o"
  gfortran "${STRICT[@]}" -c "$ROOT/src/adapter/mod_b1_10_water_checkpoint.f90" -o "$O/water_checkpoint.o"
  gfortran "${STRICT[@]}" -c "$ROOT/src/adapter/mod_b1_10_legacy_trial_capsule.f90" -o "$O/legacy_capsule.o"
  gfortran "${STRICT[@]}" -c "$ROOT/src/adapter/mod_b1_10_process_checkpoint.f90" -o "$O/process_checkpoint.o"
  gfortran "${STRICT[@]}" -c "$ROOT/src/adapter/mod_b1_10_transaction_binding.f90" -o "$O/transaction_binding.o"
  gfortran "${STRICT[@]}" -c "$ROOT/src/adapter/mod_b1_10_mass_seam.f90" -o "$O/mass_seam.o"
  gfortran "${STRICT[@]}" -c "$ROOT/src/adapter/mod_b1_10_temporal_characterization.f90" -o "$O/temporal_characterization.o"
  gfortran "${STRICT[@]}" -c "$ROOT/src/adapter/mod_b1_10_physical_interval_executor.f90" -o "$O/physical_executor.o"
  gfortran "${STRICT[@]}" -c "$ROOT/src/adapter/mod_b1_10_reference_model.f90" -o "$O/reference_model.o"
  gfortran "${STRICT[@]}" -c "$ROOT/src/adapter/mod_b1_10_trial_status.f90" -o "$O/trial_status.o"
  gfortran "${STRICT[@]}" -c "$ROOT/src/adapter/mod_b1_10_recoverable_interval_executor.f90" -o "$O/recoverable_executor.o"
  gfortran "${STRICT[@]}" -c "$ROOT/src/adapter/mod_b1_10_recoverable_reference_model.f90" -o "$O/recoverable_model.o"
  gfortran "${STRICT[@]}" -c "$ROOT/tools/vq/fvq09_real_b1_10_temporal_probe.f90" -o "$O/probe.o"

  objs=$(find "$O" -maxdepth 1 -name '*.o' ! -name 'probe.o' -printf '%p ')
  gfortran -O$opt -o "$O/fvq09_probe" "$O/probe.o" $objs "$TTLIB"

  C="$O/case"
  rm -rf "$C"
  cp -a "$FVQ09_CASE" "$C"
  python - "$C/swap.swp" <<'PY'
from pathlib import Path
import re,sys
p=Path(sys.argv[1]); s=p.read_text(encoding='latin1')
s,n=re.subn(r'(?m)^\s*SWCSV\s*=\s*1\b.*$', '  SWCSV = 0                  ! F-VQ09 observer-output suppression', s)
if n!=1: raise SystemExit(f'SWCSV anchor changed: {n}')
p.write_text(s,encoding='latin1')
PY
  (cd "$C" && "$O/fvq09_probe" "$OFFSET" "$PREFIX" "$DURATION" > probe.log 2>&1)
  grep -q 'FVQ09_REAL_TEMPORAL_PROBE_PASS' "$C/probe.log"
  python "$ROOT/tools/vq/fvq09_observation.py" \
    --probe-log "$C/probe.log" \
    --bundle "$OUT/bundle.json" \
    --materialization "$OUT/materialization.json" \
    --compiler "$OUT/compiler.txt" \
    --optimization "O$opt" \
    > "$OUT/observation-o$opt.json"
done

echo "F-VQ09 real observations written to $OUT"
echo FVQ09_REAL_TEMPORAL_HARNESS_PASS
