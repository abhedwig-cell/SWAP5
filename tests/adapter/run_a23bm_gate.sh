#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
REPO="$(cd "$ROOT/../.." && pwd)"
: "${SWAP431_ARCHIVE:?Set SWAP431_ARCHIVE to exact SWAP 4.3.1 distribution zip}"
BUILD="${A23BM_BUILD_DIR:-$ROOT/.a23bm-build}"
rm -rf "$BUILD" && mkdir -p "$BUILD"

python "$REPO/tools/vq/b1_6_reconstruct.py" --archive "$SWAP431_ARCHIVE" --output-dir "$BUILD/B1.6-source" > "$BUILD/b16-reconstruct.json"
python - "$SWAP431_ARCHIVE" "$BUILD" <<'PY'
from pathlib import Path
from zipfile import ZipFile
import sys
archive=Path(sys.argv[1]); build=Path(sys.argv[2])
with ZipFile(archive) as z: (build/'TTUTIL.ZIP').write_bytes(z.read('SWAP_4.3.1/tools/SWAP/source/TTUTIL.ZIP'))
with ZipFile(build/'TTUTIL.ZIP') as z: z.extractall(build/'ttutil')
PY
python "$ROOT/tools/a23bm_prepare_gnu_source.py" --source "$BUILD/B1.6-source" --output "$BUILD/B1.6-gnu-source" --ttutil-prefs "$BUILD/ttutil/TTUTIL/ttutilprefs.f90"

TT="$BUILD/ttutil/TTUTIL"; TTB="$BUILD/ttbuild"; mkdir -p "$TTB"
TTFLAGS=(-O2 -std=legacy -fallow-argument-mismatch -fno-range-check -ffixed-line-length-none -J "$TTB" -I "$TTB" -I "$TT")
gfortran "${TTFLAGS[@]}" -c "$TT/ttutilprefs.f90" -o "$TTB/ttutilprefs.o"
gfortran "${TTFLAGS[@]}" -c "$TT/rdmodulettutil.f90" -o "$TTB/rdmodulettutil.o"
gfortran "${TTFLAGS[@]}" -c "$TT/outdat.f90" -o "$TTB/outdat.o"
gfortran "${TTFLAGS[@]}" -c "$TT/ttutil.f90" -o "$TTB/ttutil.o"
for f in "$TT"/*.for "$TT"/*.f90; do
  case "$(basename "$f")" in ttutilprefs.f90|rdmodulettutil.f90|outdat.f90|ttutil.f90) continue;; esac
  gfortran "${TTFLAGS[@]}" -c "$f" -o "$TTB/$(basename "${f%.*}").o"
done
ar rcs "$BUILD/libttutil427_gfortran.a" "$TTB"/*.o

SRC="$BUILD/B1.6-gnu-source"; B16B="$BUILD/b16obj"; mkdir -p "$B16B"
B16FLAGS=(-O2 -cpp -Dlinux -std=legacy -fallow-argument-mismatch -fno-range-check -ffree-line-length-none -finit-local-zero -J "$B16B" -I "$B16B" -I "$TTB")
files=(ttutilprefs.f90 params.f90 description.f90 wofost_soil_interface.f90 interface_atmosphere.f90 arrays.f90 wofost_soil_declarations.f90 sptabulated.f90 variables.f90 WC_K_models_04_11.f90 interface_plant.f90 swap_base.f90 fixed.f90 snow.f90 wofostnut.f90 MOD_drainage.f90 temperature.f90 MOD_RIA.f90 MOD_MvG_functions.f90 irrigation.f90 MOD_meteo.f90 MOD_runon.f90 MOD_Kavg_Szym.f90 surfacewater.f90 divdra.f90 calcgwl.f90 macropore.f90 integral.f90 RWU_micro.f90 drainage.f90 timecontrol.f90 frozencond.f90 solute.f90 wofost.f90 boundtop.f90 soilwater.f90 MOD_cropdevelopment.f90 oxygenstress.f90 rootextraction.f90 swap_csv_output.f90 tillage.f90 swap.f90 MOD_out_PEARL_ANIMO.f90 tridag.f90 initialize.f90 readswap.f90 wofost_soil_watern.f90 hysteresis.f90 functions.f90 watstor.f90 macroporeoutput.f90 swapoutput.f90 wofost_soil_balancecheck.f90 wofost_soil_parameters.f90 wofost_soil_orgmatn.f90 swap_main.f90 fluxes.f90 wofost_soil_rateconstants.f90 wofost_soil_cropresidues.f90 wofost_soil_amendments.f90 macrorate.f90 headcalc.f90 management_soil.f90 boundbottom.f90)
for f in "${files[@]}"; do gfortran "${B16FLAGS[@]}" -c "$SRC/$f" -o "$B16B/${f%.f90}.o"; done
gfortran -O2 -o "$BUILD/swap_b16_gnu" "$B16B"/*.o "$BUILD/libttutil427_gfortran.a"

python "$ROOT/tools/a23bm_initial_run.py" --archive "$SWAP431_ARCHIVE" --exe "$BUILD/swap_b16_gnu" --start 2002-01-01 --end 2002-01-03 --workdir "$BUILD/seed" --meta "$BUILD/seed.meta"
python "$ROOT/tools/a23bm_initial_run.py" --archive "$SWAP431_ARCHIVE" --exe "$BUILD/swap_b16_gnu" --start 2002-01-01 --end 2002-01-05 --workdir "$BUILD/direct" --meta "$BUILD/direct.meta"

COMMON=(-std=f2008 -Wall -Wextra -Werror -fcheck=all -fbacktrace -ffree-line-length-none)
mkdir -p "$BUILD/o0" "$BUILD/o2"
gfortran "${COMMON[@]}" -O0 -J "$BUILD/o0" -I "$BUILD/o0" "$REPO/src/transaction/mod_transaction_reference.f90" "$ROOT/src/adapter/mod_a23bm_hupsel_legacy_adapter.f90" "$ROOT/tests/adapter/test_a23bm_hupsel_adapter.f90" -o "$BUILD/test_o0"
gfortran "${COMMON[@]}" -O2 -J "$BUILD/o2" -I "$BUILD/o2" "$REPO/src/transaction/mod_transaction_reference.f90" "$ROOT/src/adapter/mod_a23bm_hupsel_legacy_adapter.f90" "$ROOT/tests/adapter/test_a23bm_hupsel_adapter.f90" -o "$BUILD/test_o2"

export A23BM_ARCHIVE="$SWAP431_ARCHIVE" A23BM_EXE="$BUILD/swap_b16_gnu" A23BM_HELPER="$ROOT/tools/a23bm_legacy_advance.py" A23BM_SEED_META="$BUILD/seed.meta" A23BM_DIRECT_META="$BUILD/direct.meta"
export A23BM_WORKROOT="$BUILD/work_o0"; "$BUILD/test_o0" | tee "$BUILD/o0.log"
export A23BM_WORKROOT="$BUILD/work_o2"; "$BUILD/test_o2" | tee "$BUILD/o2.log"

echo A23BM_GATE_PASS
