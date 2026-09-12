#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"; cd "$ROOT"

CANON=c6494f913303b7aefc4f9c53c6c157082d54ea4b
BLOCKED=860f697cd785f3de01a36c9f0f06043e6dcb689a
COMP=8a1aeedbaeb5bd015e7e8d098d605968bbecd94e
OWNER=dcde6360f902081c94927486455e5233b81dfc1b
VQ=a76f338f5fdebed8346ffdbbd04dc7461d15a137
POST=89f7d11413e1f3ae24c648f24f56577b982f23e6
OLD_AUTH=828ba0f0ed933fb62107f849ae0bb7cc32c47c30
CB=integration/f-ci-canonical
OB=work/f-gc21p1-r1-warning-hygiene-remediation
VB=qualification/f-vq63-fgc21p1-r1-exact-bottom-interface-independent-qualification

for spec in "$CB:$CANON" "$OB:$OWNER" "$VB:$VQ"; do
  b=${spec%%:*}; e=${spec##*:}
  a=$(git ls-remote origin "refs/heads/$b" | awk '{print $1}')
  test "$a" = "$e" || { echo "FCI55R_FAIL live authority drift: $b expected=$e actual=$a" >&2; exit 20; }
done

git fetch --quiet --no-tags origin "$CB" "$OB" "$VB"
test "$(git rev-parse "$COMP^")" = "$CANON"
git merge-base --is-ancestor "$CANON" "$COMP"
git merge-base --is-ancestor "$COMP" HEAD
git merge-base --is-ancestor "$BLOCKED" HEAD

# F-CI55R is governance/test reconciliation only: production and reference trees may not move.
test "$(git rev-parse HEAD:src)" = "$(git rev-parse "$BLOCKED:src")"
test "$(git rev-parse HEAD:reference)" = "$(git rev-parse "$BLOCKED:reference")"
test "$(git rev-parse HEAD:src)" = "$(git rev-parse "$COMP:src")"

expected=(
  src/kernel/mod_kernel_transactions.f90
  src/runtime/mod_canonical_contracts.f90
  src/runtime/mod_canonical_interval_runtime.f90
  src/runtime/mod_fmr_serialized_reference_backend.f90
  src/transaction/mod_transaction_reference.f90
)
blobs=(
  c7c5b7d3357e4e6739c8f647d6232baca45563e6
  3cbb81b25626e6574ae83416f088dc52882f91fc
  f41f725df4be883d277a8fd5afe5a6f1bc14ad1b
  d565b893a08d92c46077995fdec544584aa04664
  834487df4e7a38c7c8ffd83805d98933714c6977
)
for i in 0 1 2 3 4; do
  p=${expected[$i]}; b=${blobs[$i]}
  test "$(git rev-parse "HEAD:$p")" = "$b"
  test "$(git rev-parse "$COMP:$p")" = "$b"
  test "$(git rev-parse "$POST:$p")" = "$b"
done

# Only preregistered F-CI55R governance/test files may differ from blocked F-CI55.
allowed='^(\.github/workflows/fci-canonical\.yml|\.github/workflows/fci55r-moving-preservation-reconciliation\.yml|integration/f-ci/F-CI55R_(PRE_REGISTRATION|ARCHITECTURE_AUDIT|STATUS)\.json|tests/fci/run_fci55r_moving_preservation_reconciliation\.sh)$'
git diff --name-only "$BLOCKED..HEAD" | grep -Ev "$allowed" | grep . && {
  echo 'FCI55R_FAIL non-allowlisted remediation delta' >&2; exit 21;
} || true

# The broad moving-preservation workflow may change only its AUTH line.
mapfile -t wf_names < <(git diff --name-only "$BLOCKED..HEAD" -- .github/workflows/fci-canonical.yml)
test ${#wf_names[@]} -eq 1
test "${wf_names[0]}" = '.github/workflows/fci-canonical.yml'
patch=$(git diff --unified=0 "$BLOCKED..HEAD" -- .github/workflows/fci-canonical.yml)
test "$(printf '%s\n' "$patch" | grep -c '^-' || true)" -eq 2
test "$(printf '%s\n' "$patch" | grep -c '^+' || true)" -eq 2
printf '%s\n' "$patch" | grep -Fq -- "-          AUTH=$OLD_AUTH"
printf '%s\n' "$patch" | grep -Fq -- "+          AUTH=$COMP"
# Excluding diff headers, there must be exactly one removed and one added content line.
test "$(printf '%s\n' "$patch" | grep '^-' | grep -v '^---' | wc -l)" -eq 1
test "$(printf '%s\n' "$patch" | grep '^+' | grep -v '^+++' | wc -l)" -eq 1

# Dependency surface must be byte-identical after normalizing only the AUTH value.
old=$(mktemp); new=$(mktemp)
git show "$BLOCKED:.github/workflows/fci-canonical.yml" | sed "s/AUTH=$OLD_AUTH/AUTH=__FCI55R_AUTH__/" > "$old"
sed "s/AUTH=$COMP/AUTH=__FCI55R_AUTH__/" .github/workflows/fci-canonical.yml > "$new"
cmp "$old" "$new"
rm -f "$old" "$new"

grep -Fq "AUTH=$COMP" .github/workflows/fci-canonical.yml
! grep -Fq "AUTH=$OLD_AUTH" .github/workflows/fci-canonical.yml

python3 - <<'PY'
import json, subprocess
owner=json.loads(subprocess.check_output(['git','show','dcde6360f902081c94927486455e5233b81dfc1b:integration/f-gc/F-GC21P1_R1_STATUS.json']))
vq=json.loads(subprocess.check_output(['git','show','a76f338f5fdebed8346ffdbbd04dc7461d15a137:integration/f-vq/F-VQ63_STATUS.json']))
audit=json.load(open('integration/f-ci/F-CI55R_ARCHITECTURE_AUDIT.json'))
assert owner['owner_qualified'] is True
assert owner['canonical_admission'] is False
assert vq['decision']=='INDEPENDENTLY_QUALIFIED_FOR_CANONICAL_ADMISSION'
assert vq['independently_qualified'] is True
assert audit['overall']=='30_OF_30_NO_ADVERSE_DELTA_FOR_MOVING_PRESERVATION_RECONCILIATION'
assert len(audit['invariants'])==30 and all(x['status']=='PASS' for x in audit['invariants'])
assert audit['mass_conservation']=='HARD_PRESERVED_NO_TOLERANCE_RELAXATION'
PY

# Independent scientific/transactional oracle still passes on the exact five-file source postimage.
B=$(mktemp -d)
git show "$VQ:tests/fvq/test_fvq63_fgc21p1_r1_exact_bottom_interface.f90" > "$B/test.f90"
for O in 0 2; do
  mkdir "$B/o$O"
  F=(-std=f2008 -ffree-line-length-none -Wall -Wextra -Werror -Wno-error=compare-reals -fcheck=all -O$O -J "$B/o$O" -I "$B/o$O")
  gfortran "${F[@]}" -c src/transaction/mod_transaction_reference.f90 -o "$B/o$O/a.o"
  gfortran "${F[@]}" -c src/runtime/mod_canonical_contracts.f90 -o "$B/o$O/b.o"
  gfortran "${F[@]}" -c src/runtime/mod_canonical_interval_runtime.f90 -o "$B/o$O/c.o"
  gfortran "${F[@]}" -c "$B/test.f90" -o "$B/o$O/t.o"
  gfortran -O$O "$B/o$O/a.o" "$B/o$O/b.o" "$B/o$O/c.o" "$B/o$O/t.o" -o "$B/o$O/test"
  "$B/o$O/test" > "$B/o$O/out"
  grep -Fq 'FVQ63_INDEPENDENT_EXACT_BOTTOM_INTERFACE_QUALIFICATION PASS' "$B/o$O/out"
done
cmp "$B/o0/out" "$B/o2/out"
rm -rf "$B"

echo 'FCI55R_MOVING_PRESERVATION_RECONCILIATION PASS'
