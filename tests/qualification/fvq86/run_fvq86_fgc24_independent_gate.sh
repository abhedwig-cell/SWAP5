#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$ROOT"

OWNER=194487ec18374ef6097e3dd687038e326f818be8
OWNER_TREE=128693b6b3d5280d528141bd7f306ce95561e1b3
FGC21_OWNER=1da854e4dd2d45fe388ee2a1ef3bd67c76d3d73f
BUILD="${TMPDIR:-/tmp}/swap5-fvq86-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT

git cat-file -e "$OWNER^{commit}"
git cat-file -e "$FGC21_OWNER^{commit}"
test "$(git rev-parse "$OWNER^{tree}")" = "$OWNER_TREE"

# Qualification must add only its own evidence/harness on top of the exact owner
# authority. No production/reference mutation is permitted in F-VQ86.
python3 - "$OWNER" <<'PY'
import subprocess, sys
owner=sys.argv[1]
changed=subprocess.check_output(['git','diff','--name-only',owner,'HEAD'], text=True).splitlines()
allowed_prefixes=(
    '.github/workflows/f-vq86-fgc24-coupled-restart-independent-qualification.yml',
    'tests/qualification/fvq86/',
    'qualification/F-VQ86_STATUS.json',
)
for path in changed:
    assert any(path == p or path.startswith(p) for p in allowed_prefixes), (path, changed)
print('FVQ86_SCOPE_ALLOWLIST=PASS')
PY

# Lock the three F-GC24 production blobs actually introduced/modified by the owner.
test "$(git rev-parse "$OWNER:src/runtime/mod_groundwater_coupled_restart.f90")" = "0596933ff3ae89c61ab7a0913189a4fa3179e50b"
test "$(git rev-parse "$OWNER:src/runtime/mod_groundwater_exchange_service_contract.f90")" = "e99ae052fccd9992b76c12a91422a987dce059e2"
test "$(git rev-parse "$OWNER:src/runtime/mod_groundwater_interface_mass_ledger.f90")" = "a867e04b088f61f686f693d07e470c3e9c33bdec"
git diff --quiet "$OWNER" -- \
  src/runtime/mod_groundwater_coupled_restart.f90 \
  src/runtime/mod_groundwater_exchange_service_contract.f90 \
  src/runtime/mod_groundwater_interface_mass_ledger.f90
echo 'FVQ86_OWNER_PRODUCTION_BLOBS_LOCKED=PASS'

# Independent structural contract audit. This is deliberately narrower and more
# semantic than the owner runner: it verifies that the public restart carrier is
# committed-only, wrapper reservations remain private, and restore cannot return a
# recoverable status after a successful external publication with bad provenance.
python3 - <<'PY'
from pathlib import Path
restart=Path('src/runtime/mod_groundwater_coupled_restart.f90').read_text().lower()
service=Path('src/runtime/mod_groundwater_exchange_service_contract.f90').read_text().lower()
ledger=Path('src/runtime/mod_groundwater_interface_mass_ledger.f90').read_text().lower()

record=restart.split('type, public :: groundwater_coupled_restart_record_t',1)[1].split('end type groundwater_coupled_restart_record_t',1)[0]
for forbidden in ('checkpoint', 'candidate', 'prepared', 'newton', 'jacobian', 'path', 'file_unit'):
    assert forbidden not in record, forbidden
assert 'class(transaction_state_t), allocatable :: swap_physical_state' in record
assert 'type(groundwater_committed_restart_record_t) :: groundwater' in record
assert 'type(groundwater_interface_mass_restart_record_t) :: ledger' in record
assert 'type(groundwater_coupling_origin_t) :: origin' in record

ledger_record=ledger.split('type, public :: groundwater_interface_mass_restart_record_t',1)[1].split('end type groundwater_interface_mass_restart_record_t',1)[0]
assert 'committed_swap_outward_exchange_m' in ledger_record
assert 'committed_exchange_count' in ledger_record
assert 'discarded_trial_count' in ledger_record
for forbidden in ('trial_exchange_m', 'prepared_generation', 'prepared_active'):
    assert forbidden not in ledger_record, forbidden

assert 'procedure, public :: restart_quiescent' in service
quiescence=service.split('pure logical function preparable_restart_quiescent',1)[1].split('end function preparable_restart_quiescent',1)[0]
assert 'if (.not. allocated(self%reservation_slots)) return' in quiescence
assert 'quiescent = .not. any(self%reservation_slots%active)' in quiescence
assert restart.count('service%restart_quiescent()') >= 2
assert 'error stop \'groundwater restart adapter success violated quiescent postcondition\'' in restart
assert 'error stop \'groundwater restart adapter success violated time provenance postcondition\'' in restart
for forbidden in ('.swp', 'midnight', '86400', 'modflow'):
    assert forbidden not in restart, forbidden
compact=restart.replace(' ','')
for forbidden in ('open(', 'read(', 'write('):
    assert forbidden not in compact, forbidden
print('FVQ86_COMMITTED_ONLY_AND_QUIESCENCE_STATIC_AUDIT=PASS')
print('FVQ86_NO_IO_CALENDAR_MODFLOW_DEPENDENCY=PASS')
PY

# Re-run the exact owner gate as prerequisite/postimage preservation evidence.
# It is explicitly not counted as the independent oracle below.
bash tests/fgc/run_fgc24_coupled_restart_split_process_gate.sh >"$BUILD/owner-replay.log" 2>&1
for marker in \
  'FGC24_TRUE_PROCESS_SPLIT_EQUIVALENCE_O0=PASS' \
  'FGC24_TRUE_PROCESS_SPLIT_EQUIVALENCE_O2=PASS' \
  'FGC24_O0_O2_SIGNATURE_IDENTITY=PASS' \
  'F-GC24 COUPLED RESTART SPLIT-PROCESS GATE PASS'; do
  grep -Fq "$marker" "$BUILD/owner-replay.log"
done
echo 'FVQ86_OWNER_POSTIMAGE_REPLAY=PASS'

# Reuse only the previously admitted dummy backend fixtures. The F-VQ86 program
# below supplies a separate adversarial sequence and assertions.
python3 - "$FGC21_OWNER" "$BUILD/fgc21_fixture.f90" <<'PY'
from pathlib import Path
import subprocess, sys
owner=sys.argv[1]; out=Path(sys.argv[2])
text=subprocess.check_output(['git','show',f'{owner}:tests/fgc/test_fgc21_restricted_predictor_corrector_window.f90'], text=True)
marker='\nprogram test_fgc21_restricted_predictor_corrector_window\n'
assert text.count(marker)==1
out.write_text(text.split(marker,1)[0]+'\n')
PY
python3 - "$OWNER" "$BUILD/fgc24_fixture.f90" <<'PY'
from pathlib import Path
import subprocess, sys
owner=sys.argv[1]; out=Path(sys.argv[2])
text=subprocess.check_output(['git','show',f'{owner}:tests/fgc/test_fgc24_coupled_restart_split_process.f90'], text=True)
marker='\nprogram test_fgc24_coupled_restart_split_process\n'
assert text.count(marker)==1
out.write_text(text.split(marker,1)[0]+'\n')
PY

echo 'FVQ86_PINNED_OWNER_FIXTURES=PASS'

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -Werror -Wno-error=compare-reals -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
SOURCES=(
  src/transaction/mod_transaction_reference.f90
  src/runtime/mod_canonical_contracts.f90
  src/runtime/mod_canonical_interval_runtime.f90
  src/kernel/mod_kernel_transactions.f90
  src/kernel/mod_kernel_committed_persistence.f90
  src/runtime/mod_groundwater_coupling_contract.f90
  src/runtime/mod_groundwater_coupling_policy.f90
  src/runtime/mod_groundwater_exchange_service_contract.f90
  src/runtime/mod_groundwater_interface_mass_ledger.f90
  src/runtime/mod_groundwater_swap_forcing_adapter.f90
  src/runtime/mod_groundwater_predictor_corrector_window.f90
  src/runtime/mod_groundwater_coupled_restart.f90
)

for opt in 0 2; do
  dir="$BUILD/o$opt"
  mkdir -p "$dir"
  : >"$dir/compiler.txt"
  if ! gfortran "${COMMON[@]}" -O"$opt" -J "$dir" -I "$dir" \
      "${SOURCES[@]}" "$BUILD/fgc21_fixture.f90" "$BUILD/fgc24_fixture.f90" \
      tests/qualification/fvq86/test_fvq86_fgc24_independent.f90 \
      -o "$dir/test" 2>"$dir/compiler.txt"; then
    echo "FVQ86_COMPILE_O${opt}=FAIL" >&2
    cat "$dir/compiler.txt" >&2
    exit 30
  fi
  if grep -E 'Warning:' "$dir/compiler.txt" | grep -v -F '[-Wcompare-reals]'; then
    echo "FVQ86_UNEXPECTED_NON_COMPARE_REAL_WARNING_O${opt}=FAIL" >&2
    cat "$dir/compiler.txt" >&2
    exit 31
  fi

  "$dir/test" oracle >"$dir/oracle.log" 2>&1
  for marker in \
    'FVQ86_PREPARED_RESERVATION_FAIL_CLOSED=PASS' \
    'FVQ86_PROVENANCE_AND_LAYOUT_PREPUBLICATION_REJECTION=PASS' \
    'FVQ86_ADAPTER_REJECTION_LOCAL_ATOMICITY=PASS' \
    'FVQ86_COMMITTED_RESTORE_EXACTLY_ONCE=PASS' \
    'FVQ86_TRANSIENT_TOKEN_NONRESURRECTION=PASS' \
    'FVQ86_EXACT_INTERFACE_MASS_RESTORE=PASS'; do
    grep -Fq "$marker" "$dir/oracle.log"
  done
  echo "FVQ86_INDEPENDENT_ORACLE_O${opt}=PASS"

  if "$dir/test" postcondition >"$dir/postcondition.log" 2>&1; then
    echo "FVQ86_FAIL_HARD_POSTCONDITION_O${opt}=FAIL" >&2
    cat "$dir/postcondition.log" >&2
    exit 32
  fi
  grep -Fq 'groundwater restart adapter success violated time provenance postcondition' "$dir/postcondition.log"
  echo "FVQ86_FAIL_HARD_POSTCONDITION_O${opt}=PASS"
done

cmp "$BUILD/o0/oracle.log" "$BUILD/o2/oracle.log"
echo 'FVQ86_INDEPENDENT_ORACLE_O0_O2_IDENTITY=PASS'
sha256sum "$BUILD/o0/oracle.log" | awk '{print "FVQ86_ORACLE_SHA256=" $1}'
echo 'F-VQ86 F-GC24 INDEPENDENT QUALIFICATION GATE PASS'
