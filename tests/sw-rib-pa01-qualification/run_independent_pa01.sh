#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-sw-rib-pa01-vq-$$"
mkdir -p "$BUILD"
PRESERVE="$ROOT/tests/fpm/.sw-rib-pa01-vq-preservation-$$.sh"
trap 'rm -rf "$BUILD" "$PRESERVE"' EXIT
cd "$ROOT"

fail(){ echo "SW_RIB_PA01_VQ_FAIL $*" >&2; exit 92; }

CANONICAL=a2d99ddd149ffaa422d9c422f96bd66e92c8555d
CANDIDATE=0a33c6d96e1f8f76c1794e3ac690e6b641de369a
OWNER=52c1a9aebddc435ef3792378f958305a96308ed0

git cat-file -e "$CANONICAL^{commit}"
git cat-file -e "$CANDIDATE^{commit}"
git cat-file -e "$OWNER^{commit}"
[[ "$(git merge-base "$CANONICAL" "$CANDIDATE")" == "$CANONICAL" ]] || fail "candidate not descended from frozen canonical"
git merge-base --is-ancestor "$CANDIDATE" HEAD || fail "qualification head not descended from frozen candidate"
[[ -z "$(git diff --name-only "$CANDIDATE..HEAD" -- src reference)" ]] || fail "qualification branch changes src/reference"
echo 'SW_RIB_PA01_VQ_CANDIDATE_AND_SCOPE_LOCK=PASS'

declare -A BLOBS=(
  [src/process/mod_drainage_extended_exchange.f90]=25d76013d25c2eaa2d254865149c740bc3257617
  [src/runtime/mod_fmr_drainage_response_binding.f90]=263cf55b2c336d149ba41b4d04f510e10c4207e2
  [src/runtime/mod_ribasim_surface_water_profile_contract.f90]=2c6ce53cf0d039c56724aab43af1bfaafe6f21b3
)
for p in "${!BLOBS[@]}"; do
  [[ "$(git rev-parse "$CANDIDATE:$p")" == "${BLOBS[$p]}" ]] || fail "candidate blob drift $p"
  [[ "$(git rev-parse "HEAD:$p")" == "${BLOBS[$p]}" ]] || fail "qualification blob drift $p"
done
echo 'SW_RIB_PA01_VQ_EXACT_THREE_PRODUCTION_BLOBS=PASS'

python3 - <<'PY'
from pathlib import Path
p=Path("src/runtime/mod_ribasim_surface_water_profile_contract.f90").read_text()
required=[
    "FMR_OPTIONAL_STATE_LAYOUT_BASE",
    "FMR_OPTIONAL_STATE_LAYOUT_FIXED_WEIR_SURFACE_WATER",
    "RIBASIM_SW_PROFILE_OWNER_CONFLICT",
    "RIBASIM_SW_PROFILE_UNSUPPORTED_OPTIONAL_STATE_LAYOUT",
    "if (optional_state_layout_id /= FMR_OPTIONAL_STATE_LAYOUT_BASE)",
    "allocated(effective_forcing%drainage_response_controls)",
    "RIBASIM_PROFILE_REJECTED",
    "e7fc8ade52a4bedeec10e508d2065577f33eb76a",
    "RIBASIM_SW_CORE_VERSION = '2026.1.1'",
    "RIBASIM_SW_PYTHON_VERSION_AT_PIN = '2026.1.0'",
]
for needle in required:
    assert needle in p, needle
assert "configure_fixed_weir_surface_water" not in p
assert "RIBASIM_SW_STTAB_EPSILON_M = 1.0e-5_real64" in p
print("SW_RIB_PA01_VQ_PROFILE_SOURCE_AUDIT=PASS")
PY

# Replay the candidate gate without changing the candidate's production source.
bash tests/sw-rib-pa01/run_pa01_candidate.sh | tee "$BUILD/candidate.txt"
grep -Fq 'SW-RIB-PA01 CANDIDATE GATE PASS' "$BUILD/candidate.txt" || fail "candidate gate replay"
echo 'SW_RIB_PA01_VQ_CANDIDATE_REPLAY=PASS'

# Replay the historical F-PM14 preservation gate on this exact candidate.
# The only adjustment is an ephemeral compile-list dependency required because
# the unchanged F-PM14 binding now imports the newly admitted stateless process.
git show "$OWNER:tests/fpm/run_fpm14_precomputed_divdra_fixed_weir_preservation.sh" > "$PRESERVE"
python3 - "$PRESERVE" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1])
s=p.read_text()
needle="  src/runtime/mod_fmr_drainage_response_binding.f90\n"
replacement="  src/process/mod_drainage_extended_exchange.f90\n"+needle
if s.count(needle) != 1:
    raise SystemExit(f"expected one F-PM14 binding compile dependency, got {s.count(needle)}")
p.write_text(s.replace(needle,replacement))
PY
chmod +x "$PRESERVE"
bash "$PRESERVE" | tee "$BUILD/preservation.txt"
grep -Fq 'FPM14_PRECOMPUTED_DIVDRA_FIXED_WEIR_PRESERVATION_GATE=PASS' "$BUILD/preservation.txt" || fail "F-PM14 preservation replay"
echo 'SW_RIB_PA01_VQ_FPM14_AND_FIXED_WEIR_PRESERVATION=PASS'

git diff --check "$CANDIDATE..HEAD"
echo "SW_RIB_PA01_VQ_EXACT_HEAD=$(git rev-parse HEAD)"
echo 'SW-RIB-PA01 INDEPENDENT QUALIFICATION GATE PASS'
