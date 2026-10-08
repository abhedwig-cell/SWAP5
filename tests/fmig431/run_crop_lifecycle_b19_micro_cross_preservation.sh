#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

# This gate does not change or bypass the current canonical preservation
# allowlist. It supplies independent source and execution evidence for a
# future explicitly reviewed B19/MICRO admission decision.
BASE="6cef5580daa7387e241a88c6a7216c265557c307"
git cat-file -e "$BASE^{commit}"
for path in \
  src/process/mod_frost_divdra_drainage_effect.f90 \
  src/runtime/mod_fmr_serialized_reference_backend.f90 \
  src/runtime/mod_fmr_production_application_bootstrap.f90 \
  src/process/mod_root_water_uptake_process.f90; do
  test "$(git rev-parse "HEAD:$path")" = "$(git rev-parse "$BASE:$path")" || {
    echo "SW431_CROP_B19_MICRO_PRODUCTION_DRIFT=$path" >&2
    exit 1
  }
done
echo 'SW431_CROP_B19_MICRO_SHARED_PRODUCTION_BLOBS=PASS'

bash tests/fmig431/run_crop_lifecycle_continuation.sh
bash tests/fmig431/run_crop_lifecycle_fkt_compatibility.sh

# Independent standard MICRO gates; these are not a substitution for their
# owning workstream's full source/canonical admission requirements.
MICRO02_RESULT="${TMPDIR:-/tmp}/crop-micro02-$$.json" \
  python3 tests/physics/run_ppa_micro02_de_willigen.py
MICRO03_RESULT="${TMPDIR:-/tmp}/crop-micro03-$$.json" \
  python3 tests/physics/run_ppa_micro03_runtime.py

# Historical B19 admission verifier pins an older application-bootstrap blob
# and is not a moving-current source check. Preserve exact unchanged shared
# production blobs above and execute a bounded current-head B19 O0/O2 case.
B19_BUILD="$(mktemp -d "${TMPDIR:-/tmp}/ppa-wu05b19-low-air-runtime-XXXXXX")"
trap 'rm -rf "$B19_BUILD"' EXIT
python3 tests/frost/build_ppa_wu05b19_runtime.py --route low_air --build "$B19_BUILD"
python3 tests/frost/run_ppa_wu05b19_qualification.py --workers 2 --cases 1 --build "$B19_BUILD"
echo 'SW431_CROP_B19_CURRENT_SOURCE_RUNTIME_CASE1=PASS'
git diff --check
echo 'SW431_CROP_B19_MICRO_CROSS_PRESERVATION=PASS'
