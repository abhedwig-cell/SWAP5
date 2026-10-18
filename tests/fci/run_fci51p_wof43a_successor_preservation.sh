#!/usr/bin/env bash
set -euo pipefail
# Generated Python caches must not mutate the guarded source working tree.
export PYTHONDONTWRITEBYTECODE=1
cd "$(dirname "$0")/../.."
fail(){ echo "FCI51P_SUCCESSOR_FAIL $*" >&2; exit 51; }
HISTORICAL=8695974b783e76b3807890be9e1c0ecb5d2f8d5f
SUCCESSOR=75114770c4d4d300f9d8037207d5498fa0e1f44e
QUALIFIED=d064bf436bc39e6dd34ad7b41bd9f359f9a9c1da
PROVIDER=src/crop/mod_crop_et_canopy_view_provider.f90
RATE=src/crop/mod_wofost_rate_table.f90
OLD=1234bcb8e3b47ebe8e67b0bac6af35e09e9056da
NEW=040299d7fac3499f5b72f3b166cb08973530885d
RATE_BLOB=5a0e8387157c5d1e1a6a94a24c19c7519c6bfcd5
[[ "$(git rev-parse "$HISTORICAL:$PROVIDER")" == "$OLD" ]] || fail 'historical provider drift'
[[ "$(git rev-parse "$HISTORICAL:$RATE")" == "$RATE_BLOB" ]] || fail 'historical dependency drift'
if [[ "$(git hash-object "$RATE")" != "$RATE_BLOB" ]]; then
  # Exact already-admitted snapshot_values extension; all production is pinned
  # by the CI-only successor. The historical rate blob above is still checked.
  python3 -B integration/audits/surface_age_ci/authority.py --source-only
  [[ "$(git hash-object "$RATE")" == 6c38364075e1cfff508999e0a48fab8bb7396823 ]] || fail 'current dependency drift'
  echo 'FCI51P_CURRENT_QUALIFIED_RATE_TABLE_SOURCE=PASS'
fi
if git merge-base --is-ancestor "$SUCCESSOR" HEAD; then
  git merge-base --is-ancestor "$QUALIFIED" "$SUCCESSOR" || fail 'qualified CO2 lineage missing'
  for path in "$PROVIDER" src/crop/mod_crop_co2_response_resolver.f90 src/runtime/mod_fmr_crop_co2_response_binding.f90; do
    [[ "$(git rev-parse "$QUALIFIED:$path")" == "$(git rev-parse "$SUCCESSOR:$path")" ]] || fail "qualified admission drift: $path"
    if [[ "$(git hash-object "$path")" != "$(git rev-parse "$SUCCESSOR:$path")" ]]; then
      python3 -B integration/audits/surface_age_ci/authority.py --source-only
      [[ "$path" == "$PROVIDER" && "$(git hash-object "$path")" == 7e007ea0f228c8e0dfeddafd2a340575233de576 ]] || fail "current successor drift: $path"
      echo 'FCI51P_CURRENT_READ_ONLY_CONFIGURATION_EXTENSION=PASS'
    fi
  done
  [[ "$(git hash-object "$PROVIDER")" == "$NEW" || "$(git hash-object "$PROVIDER")" == 7e007ea0f228c8e0dfeddafd2a340575233de576 ]] || fail 'unexpected CO2 provider'
  echo 'FCI51P_QUALIFIED_CO2_SUCCESSOR_IDENTITY=PASS'
else
  [[ "$(git hash-object "$PROVIDER")" == "$OLD" ]] || fail 'unadmitted provider drift'
fi
echo 'FCI51P_HISTORICAL_AUTHORITIES_PRESERVED=PASS'
BUILD=$(mktemp -d /tmp/swap5-fci51p-successor.XXXXXX)
trap 'rm -rf "$BUILD"' EXIT
FLAGS=(-std=f2008 -ffree-line-length-none -Wall -Wextra -Werror -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
for opt in 0 2; do
  out="$BUILD/o$opt"; mkdir -p "$out"
  for test in tests/fwof/test_fwof43a_crop_et_canopy_view_provider.f90 tests/fvq/test_fvq37_crop_et_canopy_view_independent.f90; do
    name=$(basename "${test%.f90}")
    gfortran "${FLAGS[@]}" -O"$opt" -J "$out" -I "$out" src/crop/mod_wofost_rate_table.f90 "$PROVIDER" "$test" -o "$out/$name"
    "$out/$name" > "$out/$name.txt"
  done
  grep -Fxq 'FWO43A_CROP_ET_CANOPY_VIEW_TEST PASS' "$out/test_fwof43a_crop_et_canopy_view_provider.txt"
  grep -Fxq 'FVQ37_INDEPENDENT_GRID_CASES=29000' "$out/test_fvq37_crop_et_canopy_view_independent.txt"
  grep -Fxq 'FVQ37_INDEPENDENT_EDGE_CASES=13' "$out/test_fvq37_crop_et_canopy_view_independent.txt"
  grep -Fxq 'FVQ37_INDEPENDENT_CROP_ET_CANOPY_QUALIFICATION PASS' "$out/test_fvq37_crop_et_canopy_view_independent.txt"
  echo "FCI51P_ORIGINAL_OWNER_AND_INDEPENDENT_O${opt}=PASS"
done
for test in test_fwof43a_crop_et_canopy_view_provider test_fvq37_crop_et_canopy_view_independent; do
  cmp "$BUILD/o0/$test.txt" "$BUILD/o2/$test.txt"
done
if git merge-base --is-ancestor "$SUCCESSOR" HEAD; then
  python3 tests/fmig431/run_swap431_crop_co2_response.py
fi
echo 'FCI51P_SUCCESSOR_O0_O2_PRESERVATION=PASS'
