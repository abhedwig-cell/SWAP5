#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fkt21-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"
fail(){ echo "FKT21_QUALIFICATION_FAIL $*" >&2; exit 1; }

# Exact F-SI37 owner-qualified primitive dependency.
[[ "$(git rev-parse HEAD:src/solver/mod_soil_water_accepted_step_direction_contract.f90)" == 52698b1ad2350bf787862a053a49c7c73c3358f0 ]] || fail 'F-SI37 direction contract drift'
[[ "$(git rev-parse HEAD:src/solver/mod_b110_default_mvg_directional_provider.f90)" == b1e794d2f0e661a2abb14280a59175e1cf1d5724 ]] || fail 'F-SI37 constitutive directional provider drift'
[[ "$(git rev-parse HEAD:src/adapter/mod_b110_dynamic_top_boundary_directional_adapter.f90)" == 0a957376b9a9fdea00ab6009f129803fb5341e4a ]] || fail 'F-SI37 dynamic-top directional adapter drift'
[[ "$(git rev-parse HEAD:src/adapter/mod_reference_richards_accepted_step_directional_service.f90)" == ef395ac3fb0cf6f347031bf2081a74b74b5167ae ]] || fail 'F-SI37 accepted-step service drift'

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
run_one(){
  local opt="$1" tag="$2" out="$BUILD/$tag"
  mkdir -p "$out"
  gfortran "${COMMON[@]}" "$opt" -J "$out" -I "$out" -c src/solver/mod_soil_water_accepted_step_direction_contract.f90 -o "$out/contract.o"
  gfortran "${COMMON[@]}" "$opt" -J "$out" -I "$out" -c src/transaction/mod_accepted_trajectory_directional_sensitivity.f90 -o "$out/trajectory.o"
  gfortran "${COMMON[@]}" "$opt" -J "$out" -I "$out" -c tests/fkt/test_fkt21_accepted_trajectory_direction.f90 -o "$out/test.o"
  gfortran "$opt" "$out/contract.o" "$out/trajectory.o" "$out/test.o" -o "$out/test_fkt21"
  "$out/test_fkt21" | tee "$out/output.txt"
  grep -Fq 'FKT21_ACCEPTED_TRAJECTORY_DIRECTION PASS' "$out/output.txt" || fail "PASS marker missing $tag"
  grep -Fq 'FKT21_MODE2_MODE5=PASS' "$out/output.txt" || fail "mode marker missing $tag"
  grep -Fq 'FKT21_WHOLE_TRAJECTORY_CENTERED_FD=PASS' "$out/output.txt" || fail "FD marker missing $tag"
  grep -Fq 'FKT21_REJECT_RETRY=PASS' "$out/output.txt" || fail "retry marker missing $tag"
  grep -Fq 'FKT21_RETRY_EXHAUSTION_NO_PUBLICATION=PASS' "$out/output.txt" || fail "retry exhaustion marker missing $tag"
  grep -Fq 'FKT21_UNAVAILABLE_STEP_FAIL_CLOSED=PASS' "$out/output.txt" || fail "unavailable marker missing $tag"
  grep -Fq 'FKT21_STALE_CROSS_CANDIDATE_REJECTED=PASS' "$out/output.txt" || fail "stale marker missing $tag"
  grep -Fq 'FKT21_NON_DAY_ALIGNED_INTERVAL=PASS' "$out/output.txt" || fail "generic time marker missing $tag"
  grep -Fq 'FKT21_EXCHANGE_DERIVATIVE_ACCUMULATION=PASS' "$out/output.txt" || fail "exchange accumulation marker missing $tag"
  grep -Fq 'FKT21_BOUNDED_COST=PASS' "$out/output.txt" || fail "cost marker missing $tag"
  echo "FKT21_OPT_PASS=$tag"
}
run_one -O0 o0
run_one -O2 o2

grep '^FKT21_' "$BUILD/o0/output.txt" > "$BUILD/o0/stable.txt"
grep '^FKT21_' "$BUILD/o2/output.txt" > "$BUILD/o2/stable.txt"
cmp "$BUILD/o0/stable.txt" "$BUILD/o2/stable.txt" || fail 'O0/O2 marker drift'

# Composition code may not introduce production finite-difference solves or persistent SAVE state.
if grep -Eiq 'finite.?difference|perturb.*solve' src/transaction/mod_accepted_trajectory_directional_sensitivity.f90; then fail 'FD production construction detected'; fi
if grep -Eiq 'save[[:space:]]*::|save[[:space:]]+[a-zA-Z_]' src/transaction/mod_accepted_trajectory_directional_sensitivity.f90; then fail 'persistent SAVE state detected'; fi

echo 'FKT21_O0_O2_GATE=PASS'
echo 'FKT21_QUALIFICATION PASS'
