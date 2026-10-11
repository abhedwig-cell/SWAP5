#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"; cd "$ROOT"
CANON=c6494f913303b7aefc4f9c53c6c157082d54ea4b
COMP=8a1aeedbaeb5bd015e7e8d098d605968bbecd94e
OWNER=dcde6360f902081c94927486455e5233b81dfc1b
VQ=a76f338f5fdebed8346ffdbbd04dc7461d15a137
POST=89f7d11413e1f3ae24c648f24f56577b982f23e6
CB=integration/f-ci-canonical
OB=work/f-gc21p1-r1-warning-hygiene-remediation
VB=qualification/f-vq63-fgc21p1-r1-exact-bottom-interface-independent-qualification
for spec in "$CB:$CANON" "$OB:$OWNER" "$VB:$VQ"; do
  b=${spec%%:*}; e=${spec##*:}; a=$(git ls-remote origin "refs/heads/$b" | awk '{print $1}'); test "$a" = "$e" || exit 20
done
git fetch --quiet --no-tags origin "$CB" "$OB" "$VB"
test "$(git rev-parse "$COMP^")" = "$CANON"
mapfile -t d < <(git diff --name-only "$CANON..$COMP")
expected=(src/kernel/mod_kernel_transactions.f90 src/runtime/mod_canonical_contracts.f90 src/runtime/mod_canonical_interval_runtime.f90 src/runtime/mod_fmr_serialized_reference_backend.f90 src/transaction/mod_transaction_reference.f90)
blobs=(c7c5b7d3357e4e6739c8f647d6232baca45563e6 3cbb81b25626e6574ae83416f088dc52882f91fc f41f725df4be883d277a8fd5afe5a6f1bc14ad1b d565b893a08d92c46077995fdec544584aa04664 834487df4e7a38c7c8ffd83805d98933714c6977)
test ${#d[@]} -eq 5
for i in 0 1 2 3 4; do
  test "${d[$i]}" = "${expected[$i]}"
  test "$(git rev-parse "HEAD:${expected[$i]}")" = "${blobs[$i]}"
  test "$(git rev-parse "$POST:${expected[$i]}")" = "${blobs[$i]}"
done
allowed='^(.github/workflows/fci55-fgc21p1-r1-current-canonical-admission.yml|integration/f-ci/F-CI55_(PRE_REGISTRATION|ARCHITECTURE_AUDIT|STATUS).json|tests/fci/run_fci55_fgc21p1_r1_current_canonical_admission.sh)$'
git diff --name-only "$COMP..HEAD" | grep -Ev "$allowed" | grep . && exit 22 || true
python3 - <<'PY'
import json,subprocess
owner=json.loads(subprocess.check_output(['git','show','dcde6360f902081c94927486455e5233b81dfc1b:integration/f-gc/F-GC21P1_R1_STATUS.json']))
vq=json.loads(subprocess.check_output(['git','show','a76f338f5fdebed8346ffdbbd04dc7461d15a137:integration/f-vq/F-VQ63_STATUS.json']))
audit=json.load(open('integration/f-ci/F-CI55_ARCHITECTURE_AUDIT.json'))
assert owner['owner_qualified'] and not owner['canonical_admission']
assert vq['decision']=='INDEPENDENTLY_QUALIFIED_FOR_CANONICAL_ADMISSION' and vq['independently_qualified']
assert audit['overall']=='30_OF_30_NO_ADVERSE_DELTA_FOR_CANONICAL_ADMISSION'
assert len(audit['invariants'])==30 and all(x['status']=='PASS' for x in audit['invariants'])
assert audit['mass_conservation']=='HARD_PRESERVED_NO_TOLERANCE_RELAXATION'
PY
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
echo 'FCI55_CURRENT_CANONICAL_ADMISSION_GATE PASS'
