#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

CANDIDATE="4a792636ef73d25c671c5e0953cefd11978cd0ec"
ARTIFACTS="$ROOT/fci19-lineage-artifacts"
rm -rf "$ARTIFACTS"
mkdir -p "$ARTIFACTS"

fail() {
  echo "FCI19_LINEAGE_FAIL $*" >&2
  exit 1
}

# Qualification-only branch: Candidate A production/reference bytes are immutable.
git diff --exit-code "$CANDIDATE"..HEAD -- src reference || fail "production/reference drift from Candidate A"
echo 'FCI19_LINEAGE_CANDIDATE_SOURCE_IDENTITY=PASS'

check_blob() {
  local path="$1" expected="$2" actual
  actual="$(git hash-object "$path")"
  [[ "$actual" == "$expected" ]] || fail "blob mismatch $path expected=$expected actual=$actual"
  printf '%s %s\n' "$actual" "$path" >> "$ARTIFACTS/qualified-process-blobs.txt"
}

# Exact independently/owner-qualified process and adapter identities already present in Candidate A.
check_blob src/process/mod_irrigation_process.f90 c0755c1e0d0b7ca1a35e73cf26158c29e9940aec
check_blob src/process/mod_root_water_uptake_process.f90 e6134587cf3c0164bbe09f2f4c87aef6886aaeb3
check_blob src/runtime/mod_fmr_crop_root_uptake_input_adapter.f90 9105126c219cbd06fadfa7757ba95d7b7bd0499b
check_blob src/runtime/mod_fmr_root_uptake_process_binding.f90 2fc348f18e8561096fa34dd3c11c64b359583f11
check_blob src/runtime/mod_fmr_serialized_multiswap_runtime.f90 7a60f8b8d18672098fed1c6890a95aac738ed21d
check_blob src/runtime/mod_fmr_serialized_reference_backend.f90 6f39d60a87c1987ae95d7faec2f55f865af90a08
check_blob src/solver/mod_reference_linear_solver.f90 b292d284e5549049eac1c80df4cc30008154eb96

echo 'FCI19_LINEAGE_QUALIFIED_BLOB_IDENTITIES=PASS'

# Prove that the process APIs which still lack a concrete higher-level production
# composition are not silently imported by the admitted serialized runtime.
grep -RIn --include='*.f90' --include='*.F90' -E '^[[:space:]]*use[[:space:]]+mod_irrigation_process([,[:space:]]|$)' src \
  > "$ARTIFACTS/irrigation-imports.txt" || true
[[ ! -s "$ARTIFACTS/irrigation-imports.txt" ]] || {
  cat "$ARTIFACTS/irrigation-imports.txt" >&2
  fail "irrigation process has an in-src production importer"
}
echo 'FCI19_LINEAGE_IRRIGATION_RUNTIME_COMPOSITION_ABSENT=PASS'

grep -RIn --include='*.f90' --include='*.F90' -E '^[[:space:]]*use[[:space:]]+mod_fmr_crop_root_uptake_input_adapter([,[:space:]]|$)' src \
  > "$ARTIFACTS/crop-root-adapter-imports.txt" || true
[[ ! -s "$ARTIFACTS/crop-root-adapter-imports.txt" ]] || {
  cat "$ARTIFACTS/crop-root-adapter-imports.txt" >&2
  fail "crop root-uptake adapter has an in-src production importer"
}
echo 'FCI19_LINEAGE_CONCRETE_CROP_ROOT_RUNTIME_COMPOSITION_ABSENT=PASS'

# The structural root process chain may exist as callable qualified seams, but it
# must terminate before the admitted serialized runtime unless a separate
# production-composition gate exists.
grep -RIn --include='*.f90' --include='*.F90' -E '^[[:space:]]*use[[:space:]]+mod_fmr_root_uptake_process_binding([,[:space:]]|$)' src \
  > "$ARTIFACTS/root-binding-imports.txt" || true
if grep -Eq 'src/runtime/mod_(fmr_serialized_multiswap_runtime|fmr_serialized_reference_backend|canonical_interval_runtime)\.f90:' \
     "$ARTIFACTS/root-binding-imports.txt"; then
  cat "$ARTIFACTS/root-binding-imports.txt" >&2
  fail "root uptake process binding reached admitted serialized/canonical runtime"
fi

grep -RIn --include='*.f90' --include='*.F90' -E '^[[:space:]]*use[[:space:]]+mod_root_water_uptake_process([,[:space:]]|$)' src \
  > "$ARTIFACTS/root-process-imports.txt" || true
if grep -Eq 'src/runtime/mod_(fmr_serialized_multiswap_runtime|fmr_serialized_reference_backend|canonical_interval_runtime)\.f90:' \
     "$ARTIFACTS/root-process-imports.txt"; then
  cat "$ARTIFACTS/root-process-imports.txt" >&2
  fail "dynamic root uptake process reached admitted serialized/canonical runtime"
fi
echo 'FCI19_LINEAGE_DYNAMIC_ROOT_PROCESS_NOT_SILENTLY_RUNTIME_BOUND=PASS'

# The admitted serialized runtime consumes precomputed qssdi/qrot forcing.
# Verify the exact public forcing fields and backend bindings remain explicit.
grep -Fq 'real(real64), allocatable :: subsurface_irrigation_source(:)' src/runtime/mod_fmr_serialized_reference_backend.f90 || \
  fail "explicit qssdi forcing field missing"
grep -Fq 'real(real64), allocatable :: root_extraction_sink(:)' src/runtime/mod_fmr_serialized_reference_backend.f90 || \
  fail "explicit qrot forcing field missing"
grep -Fq 'self%qssdi = forcing%subsurface_irrigation_source' src/runtime/mod_fmr_serialized_reference_backend.f90 || \
  fail "explicit qssdi forcing copy missing"
grep -Fq 'self%qrot = forcing%root_extraction_sink' src/runtime/mod_fmr_serialized_reference_backend.f90 || \
  fail "explicit qrot forcing copy missing"
echo 'FCI19_LINEAGE_PRECOMPUTED_QSSDI_QROT_RUNTIME_CONTRACT=PASS'

# F-KT09 is generic opt-in only. There must still be no Richards-specific import
# or calendar coupling in the generic transaction source.
if grep -Ein 'mod_soil_water|mod_reference_richards|pressure_head' src/transaction/mod_transaction_reference.f90 \
     > "$ARTIFACTS/transaction-model-specific.txt"; then
  cat "$ARTIFACTS/transaction-model-specific.txt" >&2
  fail "model-specific logic leaked into generic transaction source"
fi
if grep -Ein 'calendar|midnight|day_start|day_end' src/transaction/mod_transaction_reference.f90 \
     > "$ARTIFACTS/transaction-calendar-specific.txt"; then
  cat "$ARTIFACTS/transaction-calendar-specific.txt" >&2
  fail "calendar-specific logic leaked into generic transaction source"
fi
echo 'FCI19_LINEAGE_GENERIC_TRANSACTION_SEAM=PASS'

# F-SI20/F-VQ28/F-VQ29 are evidence descendants, not hidden Candidate A
# production deltas. F-SI22 already established no post-F-KT09 production delta;
# repeat the direct source-tree assertion against its head for fail-closed provenance.
SI22_HEAD="1ac759b39ee743bfa0992d6b9da09f2cfeda38b9"
git diff --exit-code "$CANDIDATE".."$SI22_HEAD" -- src reference || fail "F-SI22 unexpectedly changes production/reference source"
echo 'FCI19_LINEAGE_FSI22_NO_PRODUCTION_DELTA=PASS'

# Record the complete current production-source delta from the F-CI18 qualified
# production-source head for machine-readable reconciliation.
git diff --name-status da5026d8b87ad2f3c7912360891839a120ecccb6.."$CANDIDATE" -- src reference \
  > "$ARTIFACTS/fci18-production-to-candidate-a-delta.txt"

sha256sum "$ARTIFACTS"/*.txt > "$ARTIFACTS/artifact-sha256.txt"
printf '%s\n' "$CANDIDATE" > "$ARTIFACTS/candidate-a.txt"
git rev-parse HEAD > "$ARTIFACTS/qualification-head.txt"

echo 'FCI19_LINEAGE_REACHABILITY_GATE PASS'
