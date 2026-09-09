#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

POSTIMAGE="ef3e3dc3ba9722a942f7296b089bccdd05d55b96"
GOV_PARENT="2c0a627906cf718452236dab27d3a92082329b1c"
CANDIDATE_A="4a792636ef73d25c671c5e0953cefd11978cd0ec"
EXPECTED_SRC_TREE="b0a17a9610ee82ea1900a3ff3db3b5ba215443ca"
EXPECTED_REFERENCE_TREE="9d08625217d7c0a7385df9da6a04183bcd9cb9e6"
PRESERVATION_HEAD="5d5ece58b2b8e053a270992ded52377dd524f9c4"
REACHABILITY_HEAD="e06e3af07efd72a893e860b5d90ccd85efc3c643"
ARTIFACTS="$ROOT/fci19-postimage-artifacts"
TMP_BASE="$ROOT/tests/fci/run_fci19_candidate_a_preservation_gate.sh"
TMP_V2="$ROOT/tests/fci/run_fci19_candidate_a_preservation_gate_v2.sh"
TMP_LINEAGE="$ROOT/tests/fci/.fci19_postimage_lineage_$$.sh"

rm -rf "$ARTIFACTS"
mkdir -p "$ARTIFACTS"
cleanup() {
  rm -f "$TMP_BASE" "$TMP_V2" "$TMP_LINEAGE"
}
trap cleanup EXIT

fail() {
  echo "FCI19_POSTIMAGE_FAIL $*" >&2
  exit 1
}

# The materialized governed postimage must be a one-parent governance-line child.
[[ "$(git rev-parse "$POSTIMAGE^")" == "$GOV_PARENT" ]] || fail "unexpected governed postimage parent"
echo 'FCI19_POSTIMAGE_GOVERNANCE_PARENT=PASS'

# The materialization itself may change only source/reference content relative to
# the qualified CI19 governance parent. All governance, docs, tests and tooling
# remain inherited from the CI19 planning line at the exact postimage commit.
mapfile -t materialized_delta < <(git diff --name-only "$GOV_PARENT".."$POSTIMAGE")
[[ "${#materialized_delta[@]}" -gt 0 ]] || fail "postimage unexpectedly has no materialized source delta"
for path in "${materialized_delta[@]}"; do
  case "$path" in
    src/*|reference/*) ;;
    *) fail "postimage changed non-source governance path: $path" ;;
  esac
done
printf '%s\n' "${materialized_delta[@]}" > "$ARTIFACTS/materialization-delta.txt"
echo 'FCI19_POSTIMAGE_ONLY_SRC_REFERENCE_MATERIALIZED=PASS'

# Exact tree identity is the primary source qualification boundary.
[[ "$(git rev-parse "$POSTIMAGE:src")" == "$EXPECTED_SRC_TREE" ]] || fail "postimage src tree mismatch"
[[ "$(git rev-parse "$POSTIMAGE:reference")" == "$EXPECTED_REFERENCE_TREE" ]] || fail "postimage reference tree mismatch"
[[ "$(git rev-parse "$CANDIDATE_A:src")" == "$EXPECTED_SRC_TREE" ]] || fail "Candidate A src tree provenance mismatch"
[[ "$(git rev-parse "$CANDIDATE_A:reference")" == "$EXPECTED_REFERENCE_TREE" ]] || fail "Candidate A reference tree provenance mismatch"
echo 'FCI19_POSTIMAGE_CANDIDATE_A_SRC_TREE_IDENTITY=PASS'
echo 'FCI19_POSTIMAGE_CANDIDATE_A_REFERENCE_TREE_IDENTITY=PASS'

# Qualification commits themselves are forbidden from changing production or reference bytes.
git diff --exit-code "$POSTIMAGE"..HEAD -- src reference || fail "qualification changed src/reference"
echo 'FCI19_POSTIMAGE_QUALIFICATION_SOURCE_IMMUTABILITY=PASS'

# The exact integration tree at the governed postimage is inherited unchanged
# from the CI19 governance parent. Qualification metadata may be added only after it.
[[ "$(git rev-parse "$POSTIMAGE:integration")" == "$(git rev-parse "$GOV_PARENT:integration")" ]] || \
  fail "CI19 integration/governance tree changed during postimage materialization"
echo 'FCI19_POSTIMAGE_GOVERNANCE_TREE_IDENTITY=PASS'

# Rehydrate the exact already-successful composition-preservation gate from the
# tested qualification head. Do not duplicate or weaken its scientific oracles.
[[ ! -e "$TMP_BASE" && ! -e "$TMP_V2" ]] || fail "temporary preservation paths already exist"
git show "$PRESERVATION_HEAD:tests/fci/run_fci19_candidate_a_preservation_gate.sh" > "$TMP_BASE"
git show "$PRESERVATION_HEAD:tests/fci/run_fci19_candidate_a_preservation_gate_v2.sh" > "$TMP_V2"
chmod +x "$TMP_BASE" "$TMP_V2"

bash "$TMP_V2" > "$ARTIFACTS/composition-preservation.out" 2>&1 || {
  cat "$ARTIFACTS/composition-preservation.out" >&2
  fail "composition preservation replay"
}
grep -Fq 'FCI19_GATE PASS_CANDIDATE_A_COMPOSITION_PRESERVATION' "$ARTIFACTS/composition-preservation.out" || \
  fail "missing composition preservation terminal marker"
echo 'FCI19_POSTIMAGE_COMPOSITION_PRESERVATION=PASS'

# Rehydrate and reexecute the exact successful source-lineage reachability gate.
git show "$REACHABILITY_HEAD:tests/fci/run_fci19_source_lineage_reachability_gate.sh" > "$TMP_LINEAGE"
chmod +x "$TMP_LINEAGE"
bash "$TMP_LINEAGE" > "$ARTIFACTS/source-lineage-reachability.out" 2>&1 || {
  cat "$ARTIFACTS/source-lineage-reachability.out" >&2
  fail "source-lineage reachability replay"
}
grep -Fq 'FCI19_LINEAGE_REACHABILITY_GATE PASS' "$ARTIFACTS/source-lineage-reachability.out" || \
  fail "missing reachability terminal marker"
echo 'FCI19_POSTIMAGE_SOURCE_LINEAGE_REACHABILITY=PASS'

# Reassert source/reference immutability after all executable replays.
git diff --exit-code "$POSTIMAGE"..HEAD -- src reference || fail "post-test source/reference drift"
[[ "$(git rev-parse HEAD:src)" == "$EXPECTED_SRC_TREE" ]] || fail "post-test src tree mismatch"
[[ "$(git rev-parse HEAD:reference)" == "$EXPECTED_REFERENCE_TREE" ]] || fail "post-test reference tree mismatch"

echo "$POSTIMAGE" > "$ARTIFACTS/governed-postimage.txt"
echo "$EXPECTED_SRC_TREE" > "$ARTIFACTS/src-tree.txt"
echo "$EXPECTED_REFERENCE_TREE" > "$ARTIFACTS/reference-tree.txt"
git rev-parse HEAD > "$ARTIFACTS/qualification-head.txt"
sha256sum "$ARTIFACTS"/*.out "$ARTIFACTS"/*.txt > "$ARTIFACTS/artifact-sha256.txt"

echo 'FCI19_POSTIMAGE_HARD_MASS_AND_ROLLBACK_REPLAY=PASS'
echo 'FCI19_POSTIMAGE_NO_SCOPE_BROADENING=PASS'
echo 'FCI19_CANONICAL_POSTIMAGE_GATE PASS_RESTRICTED_GOVERNED_CANDIDATE'
