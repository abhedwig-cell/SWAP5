#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TX_SOURCE="${A23BN_TX_SOURCE:-/mnt/data/A23BL/src/transaction/mod_transaction_reference.f90}"
B16_SOURCE="${A23BN_B16_SOURCE:-/mnt/data/A23BM/B1.6-gnu-source}"
TTLIB="${A23BN_TTLIB:-/mnt/data/A23BM/libttutil427_gfortran.a}"
CASE="${A23BN_CASE:-$ROOT/probe_case}"
BUILD="${A23BN_BUILD:-$ROOT/.a23bn-build}"
rm -rf "$BUILD"; mkdir -p "$BUILD"
files=(ttutilprefs.f90 params.f90 description.f90 wofost_soil_interface.f90 interface_atmosphere.f90 arrays.f90 wofost_soil_declarations.f90 sptabulated.f90 variables.f90 WC_K_models_04_11.f90 interface_plant.f90 swap_base.f90 fixed.f90 snow.f90 wofostnut.f90 MOD_drainage.f90 temperature.f90 MOD_RIA.f90 MOD_MvG_functions.f90 irrigation.f90 MOD_meteo.f90 MOD_runon.f90 MOD_Kavg_Szym.f90 surfacewater.f90 divdra.f90 calcgwl.f90 macropore.f90 integral.f90 RWU_micro.f90 drainage.f90 timecontrol.f90 frozencond.f90 solute.f90 wofost.f90 boundtop.f90 soilwater.f90 MOD_cropdevelopment.f90 oxygenstress.f90 rootextraction.f90 swap_csv_output.f90 tillage.f90 swap.f90 MOD_out_PEARL_ANIMO.f90 tridag.f90 initialize.f90 readswap.f90 wofost_soil_watern.f90 hysteresis.f90 functions.f90 watstor.f90 macroporeoutput.f90 swapoutput.f90 wofost_soil_balancecheck.f90 wofost_soil_parameters.f90 wofost_soil_orgmatn.f90 fluxes.f90 wofost_soil_rateconstants.f90 wofost_soil_cropresidues.f90 wofost_soil_amendments.f90 macrorate.f90 headcalc.f90 management_soil.f90 boundbottom.f90)
for opt in 0 2; do
  O="$BUILD/o$opt"; mkdir -p "$O"
  BFLAGS=(-O$opt -cpp -Dlinux -std=legacy -fallow-argument-mismatch -fno-range-check -ffree-line-length-none -finit-local-zero -J "$O" -I "$O")
  for f in "${files[@]}"; do gfortran "${BFLAGS[@]}" -c "$B16_SOURCE/$f" -o "$O/${f%.f90}.o"; done
  COMMON=(-O$opt -std=f2008 -Wall -Wextra -Werror -fcheck=all -fbacktrace -ffree-line-length-none -J "$O" -I "$O")
  gfortran "${COMMON[@]}" -c "$TX_SOURCE" -o "$O/mod_transaction_reference.o"
  gfortran "${COMMON[@]}" -c "$ROOT/src/adapter/mod_a23bn_hupsel_native_adapter.f90" -o "$O/mod_a23bn_hupsel_native_adapter.o"
  gfortran "${COMMON[@]}" -c "$ROOT/tests/adapter/test_a23bn_hupsel_native_adapter.f90" -o "$O/test_a23bn.o"
  objs=$(find "$O" -maxdepth 1 -name '*.o' ! -name 'test_a23bn.o' ! -name 'mod_transaction_reference.o' ! -name 'mod_a23bn_hupsel_native_adapter.o' -printf '%p ')
  gfortran -O$opt -o "$O/test_a23bn" "$O/mod_transaction_reference.o" "$O/mod_a23bn_hupsel_native_adapter.o" "$O/test_a23bn.o" $objs "$TTLIB"
  rm -rf "$O/case"; cp -a "$CASE" "$O/case"
  (cd "$O/case" && ../test_a23bn) | tee "$O/gate.log"
  grep -q 'A23BN_NATIVE_PHYSICAL_GATE PASS' "$O/gate.log"
done
sha256sum "$BUILD/o0/gate.log" "$BUILD/o2/gate.log"
echo A23BN_O0_O2_GATE_PASS
