#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fwof38-gate-a-$$"
EXPECTED_FWO34_OUTPUT_SHA="d36bb86e5e2dfd3fde242321442cf7393efd3cd218259eeeb35c37cb1559d007"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

python3 - "$ROOT/src/runtime/mod_fmr_wofost_accepted_window_lineage.f90" "$BUILD/mod_fmr_wofost_accepted_window_lineage.f90" <<'PY'
from pathlib import Path
import sys
src = Path(sys.argv[1]).read_text(encoding='utf-8')

anchor_type = '''  end type fmr_wofost_crop_event_token_t\n\n'''
insert_type = '''  end type fmr_wofost_crop_event_token_t\n\n  ! Compact opaque identity of one frozen accepted physical crop event.\n  ! This is provenance metadata, not crop physics and not a second commit owner.\n  type, public :: fmr_wofost_crop_event_identity_t\n    private\n    logical :: initialized = .false.\n    integer(int64) :: lineage_id = 0_int64\n    integer(int64) :: final_revision = -1_int64\n    real(real64) :: t0 = 0.0_real64\n    real(real64) :: t1 = 0.0_real64\n    real(real64) :: actual_root_uptake_integral = 0.0_real64\n    real(real64) :: potential_transpiration_integral = 0.0_real64\n  contains\n    procedure, public :: ready => crop_event_identity_ready\n  end type fmr_wofost_crop_event_identity_t\n\n'''
if src.count(anchor_type) != 1:
    raise SystemExit(f'FWOF38 identity type anchor count={src.count(anchor_type)}')
src = src.replace(anchor_type, insert_type, 1)

anchor_public = '''  public :: commit_wofost_crop_event_delivery\n\ncontains\n'''
insert_public = '''  public :: commit_wofost_crop_event_delivery\n  public :: identify_wofost_crop_event\n  public :: same_wofost_crop_event_identity\n  public :: crop_event_identity_matches_interval\n\ncontains\n'''
if src.count(anchor_public) != 1:
    raise SystemExit(f'FWOF38 identity public anchor count={src.count(anchor_public)}')
src = src.replace(anchor_public, insert_public, 1)

anchor_proc = '''  pure logical function crop_event_token_ready(self) result(ready)\n'''
insert_proc = '''  subroutine identify_wofost_crop_event(token, identity, status)\n    type(fmr_wofost_crop_event_token_t), intent(in) :: token\n    type(fmr_wofost_crop_event_identity_t), intent(out) :: identity\n    integer, intent(out) :: status\n\n    identity = fmr_wofost_crop_event_identity_t()\n    status = FMR_WOFOST_LINEAGE_EVENT_TOKEN_MISMATCH\n    if (.not. token%ready()) return\n\n    identity%lineage_id = token%lineage_id\n    identity%final_revision = token%final_revision\n    identity%t0 = token%t0\n    identity%t1 = token%t1\n    identity%actual_root_uptake_integral = token%actual_root_uptake_integral\n    identity%potential_transpiration_integral = token%potential_transpiration_integral\n    identity%initialized = .true.\n    status = FMR_WOFOST_LINEAGE_OK\n  end subroutine identify_wofost_crop_event\n\n  pure logical function crop_event_identity_ready(self) result(ready)\n    class(fmr_wofost_crop_event_identity_t), intent(in) :: self\n    ready = self%initialized .and. self%lineage_id > 0_int64 .and. self%final_revision >= 0_int64 .and. &\n         ieee_is_finite(self%t0) .and. ieee_is_finite(self%t1) .and. self%t1 > self%t0 .and. &\n         ieee_is_finite(self%actual_root_uptake_integral) .and. &\n         ieee_is_finite(self%potential_transpiration_integral) .and. &\n         self%actual_root_uptake_integral >= 0.0_real64 .and. &\n         self%potential_transpiration_integral >= 0.0_real64\n  end function crop_event_identity_ready\n\n  pure logical function same_wofost_crop_event_identity(left, right) result(matches)\n    type(fmr_wofost_crop_event_identity_t), intent(in) :: left, right\n    matches = .false.\n    if (.not. left%ready() .or. .not. right%ready()) return\n    matches = left%lineage_id == right%lineage_id .and. &\n         left%final_revision == right%final_revision .and. &\n         same_time(left%t0, right%t0) .and. same_time(left%t1, right%t1) .and. &\n         same_real_bits(left%actual_root_uptake_integral, right%actual_root_uptake_integral) .and. &\n         same_real_bits(left%potential_transpiration_integral, right%potential_transpiration_integral)\n  end function same_wofost_crop_event_identity\n\n  pure logical function crop_event_identity_matches_interval(identity, t0, t1) result(matches)\n    type(fmr_wofost_crop_event_identity_t), intent(in) :: identity\n    real(real64), intent(in) :: t0, t1\n    matches = .false.\n    if (.not. identity%ready()) return\n    matches = same_time(identity%t0, t0) .and. same_time(identity%t1, t1)\n  end function crop_event_identity_matches_interval\n\n  pure logical function crop_event_token_ready(self) result(ready)\n'''
if src.count(anchor_proc) != 1:
    raise SystemExit(f'FWOF38 identity procedure anchor count={src.count(anchor_proc)}')
src = src.replace(anchor_proc, insert_proc, 1)

Path(sys.argv[2]).write_text(src, encoding='utf-8')
print('FWOF38_GATE_A_DISPOSABLE_IDENTITY_API_PATCH=PASS')
PY

# Preserve the exact F-WOF34 oracle transcript against the additive API.
COMMON=(-std=f2008 -Wall -Wextra -Werror -ffree-line-length-none -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
for opt in 0 2; do
  OUT="$BUILD/fwo34-o$opt"
  mkdir -p "$OUT"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" \
    src/transaction/mod_transaction_reference.f90 \
    src/runtime/mod_canonical_contracts.f90 \
    src/runtime/mod_canonical_interval_runtime.f90 \
    src/kernel/mod_kernel_transactions.f90 \
    src/crop/mod_wofost_actual_biomass_state.f90 \
    src/crop/mod_wofost_crop_owner_state.f90 \
    src/crop/mod_wofost_one_day_structural_evolution.f90 \
    "$BUILD/mod_fmr_wofost_accepted_window_lineage.f90" \
    tests/fwof/test_fwof34_accepted_window_runtime_lineage.f90 \
    -o "$OUT/test"
  "$OUT/test" > "$OUT/out.txt"
done
cmp "$BUILD/fwo34-o0/out.txt" "$BUILD/fwo34-o2/out.txt"
FWO_SHA="$(sha256sum "$BUILD/fwo34-o0/out.txt" | awk '{print $1}')"
[[ "$FWO_SHA" == "$EXPECTED_FWO34_OUTPUT_SHA" ]] || {
  echo "FWOF38_GATE_A_FWO34_TRANSCRIPT_CHANGED actual=$FWO_SHA" >&2
  exit 1
}
echo "FWOF38_GATE_A_FWO34_EXACT_TRANSCRIPT_PRESERVATION=PASS SHA256=$FWO_SHA"

# Derive an identity-specific test from the frozen current F-WOF34 fixture.
python3 - "$ROOT/tests/fwof/test_fwof34_accepted_window_runtime_lineage.f90" "$BUILD/test_identity.f90" <<'PY'
from pathlib import Path
import sys
src = Path(sys.argv[1]).read_text(encoding='utf-8')
old_decl = '  type(fmr_wofost_crop_event_token_t) :: token1, token2\n'
new_decl = old_decl + '  type(fmr_wofost_crop_event_identity_t) :: identity1, identity2\n'
if src.count(old_decl) != 1:
    raise SystemExit(f'FWOF38 identity declaration anchor count={src.count(old_decl)}')
src = src.replace(old_decl, new_decl, 1)

anchor = "  print '(a)', 'FWOF34_FROZEN_AGGREGATE_RETRY_BITWISE_IDENTITY=PASS'\n"
extra = anchor + '''\n  call identify_wofost_crop_event(token1, identity1, status)\n  call require(status == FMR_WOFOST_LINEAGE_OK .and. identity1%ready(), 'first event identity')\n  call identify_wofost_crop_event(token2, identity2, status)\n  call require(status == FMR_WOFOST_LINEAGE_OK .and. identity2%ready(), 'second event identity')\n  call require(same_wofost_crop_event_identity(identity1, identity2), 'prepared token identities equal')\n  call require(crop_event_identity_matches_interval(identity1, 0.0_real64, 1.0_real64), &\n       'identity matches accepted window interval')\n  call require(.not. crop_event_identity_matches_interval(identity1, 0.0_real64, 0.5_real64), &\n       'identity rejects wrong interval')\n  print '(a)', 'FWOF38_GATE_A_EVENT_IDENTITY_REPEAT_PREPARE_IDENTITY=PASS'\n  print '(a)', 'FWOF38_GATE_A_EVENT_IDENTITY_INTERVAL_BINDING=PASS'\n'''
if src.count(anchor) != 1:
    raise SystemExit(f'FWOF38 identity test anchor count={src.count(anchor)}')
src = src.replace(anchor, extra, 1)
Path(sys.argv[2]).write_text(src, encoding='utf-8')
print('FWOF38_GATE_A_IDENTITY_TEST_MATERIALIZED=PASS')
PY

for opt in 0 2; do
  OUT="$BUILD/identity-o$opt"
  mkdir -p "$OUT"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" \
    src/transaction/mod_transaction_reference.f90 \
    src/runtime/mod_canonical_contracts.f90 \
    src/runtime/mod_canonical_interval_runtime.f90 \
    src/kernel/mod_kernel_transactions.f90 \
    src/crop/mod_wofost_actual_biomass_state.f90 \
    src/crop/mod_wofost_crop_owner_state.f90 \
    src/crop/mod_wofost_one_day_structural_evolution.f90 \
    "$BUILD/mod_fmr_wofost_accepted_window_lineage.f90" \
    "$BUILD/test_identity.f90" \
    -o "$OUT/test"
  "$OUT/test" > "$OUT/out.txt"
  grep -Fq 'FWOF38_GATE_A_EVENT_IDENTITY_REPEAT_PREPARE_IDENTITY=PASS' "$OUT/out.txt"
  grep -Fq 'FWOF38_GATE_A_EVENT_IDENTITY_INTERVAL_BINDING=PASS' "$OUT/out.txt"
  echo "FWOF38_GATE_A_IDENTITY_O${opt}=PASS"
done
cmp "$BUILD/identity-o0/out.txt" "$BUILD/identity-o2/out.txt"
echo 'FWOF38_GATE_A_IDENTITY_O0_O2_OUTPUT_IDENTITY=PASS'
echo 'FWOF38_GATE_A_EVENT_IDENTITY_API_GATE PASS'
