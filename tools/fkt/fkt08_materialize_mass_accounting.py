#!/usr/bin/env python3
from __future__ import annotations

import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
EXPECTED = {
    "src/transaction/mod_transaction_reference.f90": "4a573316b77252b56bcb429fd519aa57123e9a06",
    "src/runtime/mod_canonical_contracts.f90": "55cd8a9dc529bb2d057845f212b7efff6c80c553",
    "src/runtime/mod_canonical_interval_runtime.f90": "f0bfb2c1359c39b4708350b756aa2211fb982be4",
    "src/kernel/mod_kernel_transactions.f90": "e8605e73a191e863374a26b096e0d597cb70cadd",
}


def git_blob(path: Path) -> str:
    return subprocess.check_output(["git", "-C", str(ROOT), "hash-object", str(path)], text=True).strip()


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected one match, found {count}")
    return text.replace(old, new, 1)


for relative, expected in EXPECTED.items():
    path = ROOT / relative
    actual = git_blob(path)
    if actual != expected:
        raise SystemExit(f"F-KT08 source provenance mismatch for {relative}: {actual} != {expected}")

# 1. Transaction layer: preserve only the finally accepted two-half route mass terms.
path = ROOT / "src/transaction/mod_transaction_reference.f90"
text = path.read_text(encoding="utf-8")
text = replace_once(
    text,
    "use, intrinsic :: iso_fortran_env, only: real64",
    "use, intrinsic :: iso_fortran_env, only: real64, int64",
    "transaction int64 import",
)
text = replace_once(
    text,
    "  integer, parameter, public :: TX_ROUTE_TWO_HALF = 2\n",
    "  integer, parameter, public :: TX_ROUTE_TWO_HALF = 2\n\n"
    "  integer(int64), parameter, public :: TX_MASS_MISSING_NONE = 0_int64\n"
    "  integer(int64), parameter, public :: TX_MASS_MISSING_STORAGE_START = 1_int64\n"
    "  integer(int64), parameter, public :: TX_MASS_MISSING_STORAGE_END = 2_int64\n"
    "  integer(int64), parameter, public :: TX_MASS_MISSING_EXTERNAL_FLUX = 4_int64\n"
    "  integer(int64), parameter, public :: TX_MASS_MISSING_ACTIVE_CONTRIBUTION = 8_int64\n"
    "  integer(int64), parameter, public :: TX_MASS_MISSING_NONFINITE = 16_int64\n"
    "  integer(int64), parameter, public :: TX_MASS_MISSING_UNSPECIFIED = 32_int64\n",
    "transaction missing contribution constants",
)
text = replace_once(
    text,
    "    real(real64) :: mass_out = 0.0_real64\n",
    "    real(real64) :: mass_out = 0.0_real64\n"
    "    logical :: mass_accounting_complete = .false.\n"
    "    integer(int64) :: missing_mass_contribution_mask = TX_MASS_MISSING_UNSPECIFIED\n",
    "trial mass completeness",
)
text = replace_once(
    text,
    "    procedure(temporal_error_iface), deferred :: temporal_error\n",
    "    procedure(temporal_error_iface), deferred :: temporal_error\n"
    "    procedure :: storage_accounting_status => default_storage_accounting_status\n",
    "transaction storage accounting status binding",
)
text = replace_once(
    text,
    "    integer :: accepted_alternative_solver_calls = 0\n    real(real64) :: requested_t0 = 0.0_real64\n",
    "    integer :: accepted_alternative_solver_calls = 0\n"
    "    logical :: accepted_mass_complete = .false.\n"
    "    integer(int64) :: accepted_missing_contribution_mask = TX_MASS_MISSING_UNSPECIFIED\n"
    "    real(real64) :: accepted_storage_start = 0.0_real64\n"
    "    real(real64) :: accepted_storage_end = 0.0_real64\n"
    "    real(real64) :: accepted_storage_change = 0.0_real64\n"
    "    real(real64) :: accepted_total_in = 0.0_real64\n"
    "    real(real64) :: accepted_total_out = 0.0_real64\n"
    "    real(real64) :: accepted_mass_residual = huge(0.0_real64)\n"
    "    real(real64) :: requested_t0 = 0.0_real64\n",
    "transaction accepted mass result fields",
)
text = replace_once(
    text,
    "  subroutine default_restore_attempt_context(self, context)\n"
    "    class(transaction_model_t), intent(inout) :: self\n"
    "    class(transaction_attempt_context_t), intent(in) :: context\n"
    "    if (.not. same_type_as(self, self) .or. .not. same_type_as(context, context)) then\n"
    "      error stop 'unreachable transaction attempt context type'\n"
    "    end if\n"
    "  end subroutine default_restore_attempt_context\n\n",
    "  subroutine default_restore_attempt_context(self, context)\n"
    "    class(transaction_model_t), intent(inout) :: self\n"
    "    class(transaction_attempt_context_t), intent(in) :: context\n"
    "    if (.not. same_type_as(self, self) .or. .not. same_type_as(context, context)) then\n"
    "      error stop 'unreachable transaction attempt context type'\n"
    "    end if\n"
    "  end subroutine default_restore_attempt_context\n\n"
    "  subroutine default_storage_accounting_status(self, state, complete, missing_mask)\n"
    "    class(transaction_model_t), intent(in) :: self\n"
    "    class(transaction_state_t), intent(in) :: state\n"
    "    logical, intent(out) :: complete\n"
    "    integer(int64), intent(out) :: missing_mask\n\n"
    "    if (.not. same_type_as(self, self) .or. .not. same_type_as(state, state)) then\n"
    "      error stop 'unreachable transaction mass-accounting type'\n"
    "    end if\n"
    "    complete = .false.\n"
    "    missing_mask = TX_MASS_MISSING_UNSPECIFIED\n"
    "  end subroutine default_storage_accounting_status\n\n",
    "default storage accounting status",
)
text = replace_once(
    text,
    "    logical :: solver_ok, mass_ok, temporal_ok\n    integer :: retry_index\n",
    "    logical :: solver_ok, mass_ok, temporal_ok\n"
    "    logical :: storage_start_complete, storage_end_complete\n"
    "    integer(int64) :: start_missing_mask, end_missing_mask, accepted_missing_mask\n"
    "    integer :: retry_index\n",
    "transaction mass accounting locals",
)
text = replace_once(
    text,
    "    storage0 = model%storage(checkpoint)\n    attempt_dt = t1 - t0\n",
    "    storage0 = model%storage(checkpoint)\n"
    "    call model%storage_accounting_status(checkpoint, storage_start_complete, start_missing_mask)\n"
    "    attempt_dt = t1 - t0\n",
    "transaction start storage accounting status",
)
text = replace_once(
    text,
    "      storage_half = model%storage(half_state)\n      half_mass_residual = storage_half - storage0 - &\n",
    "      storage_half = model%storage(half_state)\n"
    "      call model%storage_accounting_status(half_state, storage_end_complete, end_missing_mask)\n"
    "      half_mass_residual = storage_half - storage0 - &\n",
    "transaction end storage accounting status",
)
text = replace_once(
    text,
    "      ! Physical state and worker/job-local context commit together. The context\n",
    "      accepted_missing_mask = ior(start_missing_mask, end_missing_mask)\n"
    "      accepted_missing_mask = ior(accepted_missing_mask, half1_outcome%missing_mass_contribution_mask)\n"
    "      accepted_missing_mask = ior(accepted_missing_mask, half2_outcome%missing_mass_contribution_mask)\n"
    "      if (.not. storage_start_complete) accepted_missing_mask = &\n"
    "           ior(accepted_missing_mask, TX_MASS_MISSING_STORAGE_START)\n"
    "      if (.not. storage_end_complete) accepted_missing_mask = &\n"
    "           ior(accepted_missing_mask, TX_MASS_MISSING_STORAGE_END)\n"
    "      if (.not. half1_outcome%mass_accounting_complete .or. &\n"
    "          .not. half2_outcome%mass_accounting_complete) then\n"
    "        accepted_missing_mask = ior(accepted_missing_mask, TX_MASS_MISSING_EXTERNAL_FLUX)\n"
    "      end if\n"
    "      result%accepted_storage_start = storage0\n"
    "      result%accepted_storage_end = storage_half\n"
    "      result%accepted_storage_change = storage_half - storage0\n"
    "      result%accepted_total_in = half1_outcome%mass_in + half2_outcome%mass_in\n"
    "      result%accepted_total_out = half1_outcome%mass_out + half2_outcome%mass_out\n"
    "      result%accepted_mass_residual = half_mass_residual\n"
    "      result%accepted_missing_contribution_mask = accepted_missing_mask\n"
    "      result%accepted_mass_complete = storage_start_complete .and. storage_end_complete .and. &\n"
    "           half1_outcome%mass_accounting_complete .and. half2_outcome%mass_accounting_complete .and. &\n"
    "           accepted_missing_mask == TX_MASS_MISSING_NONE\n\n"
    "      ! Physical state and worker/job-local context commit together. The context\n",
    "accepted mass publication",
)
path.write_text(text, encoding="utf-8")

# 2. Canonical contract: extend the existing mass object, do not create a parallel model.
path = ROOT / "src/runtime/mod_canonical_contracts.f90"
text = path.read_text(encoding="utf-8")
text = replace_once(
    text,
    "use, intrinsic :: iso_fortran_env, only: real64",
    "use, intrinsic :: iso_fortran_env, only: real64, int64",
    "canonical int64 import",
)
text = replace_once(
    text,
    "  use mod_transaction_reference, only: transaction_state_t, transaction_model_t, transaction_policy_t\n",
    "  use mod_transaction_reference, only: transaction_state_t, transaction_model_t, transaction_policy_t, &\n"
    "       TX_MASS_MISSING_UNSPECIFIED\n",
    "canonical missing-mask import",
)
text = replace_once(
    text,
    "  type, public :: canonical_mass_accounting_t\n"
    "    logical :: complete = .false.\n"
    "    real(real64) :: storage_start = 0.0_real64\n"
    "    real(real64) :: storage_end = 0.0_real64\n"
    "    real(real64) :: total_in = 0.0_real64\n"
    "    real(real64) :: total_out = 0.0_real64\n"
    "    real(real64) :: residual = 0.0_real64\n"
    "  end type canonical_mass_accounting_t\n",
    "  type, public :: canonical_mass_accounting_t\n"
    "    logical :: complete = .false.\n"
    "    real(real64) :: interval_t0 = 0.0_real64\n"
    "    real(real64) :: interval_t1 = 0.0_real64\n"
    "    integer(int64) :: origin_lineage_id = 0_int64\n"
    "    integer(int64) :: origin_revision = -1_int64\n"
    "    integer :: accepted_transaction_count = 0\n"
    "    integer(int64) :: missing_contribution_mask = TX_MASS_MISSING_UNSPECIFIED\n"
    "    real(real64) :: storage_start = 0.0_real64\n"
    "    real(real64) :: storage_end = 0.0_real64\n"
    "    real(real64) :: storage_change = 0.0_real64\n"
    "    real(real64) :: total_in = 0.0_real64\n"
    "    real(real64) :: total_out = 0.0_real64\n"
    "    real(real64) :: residual = 0.0_real64\n"
    "  end type canonical_mass_accounting_t\n",
    "canonical mass contract extension",
)
path.write_text(text, encoding="utf-8")

# 3. Canonical runtime: aggregate only accepted transaction mass over exact [t0,t1].
path = ROOT / "src/runtime/mod_canonical_interval_runtime.f90"
text = path.read_text(encoding="utf-8")
text = replace_once(
    text,
    "module mod_canonical_interval_runtime\n  use, intrinsic :: iso_fortran_env, only: real64\n",
    "module mod_canonical_interval_runtime\n"
    "  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite\n"
    "  use, intrinsic :: iso_fortran_env, only: real64, int64\n",
    "canonical runtime numeric imports",
)
text = replace_once(
    text,
    "  use mod_transaction_reference, only: transaction_state_t, transaction_result_t, execute_reference_interval, &\n       TX_STATUS_ACCEPTED\n",
    "  use mod_transaction_reference, only: transaction_state_t, transaction_result_t, execute_reference_interval, &\n"
    "       TX_STATUS_ACCEPTED, TX_MASS_MISSING_NONE, TX_MASS_MISSING_NONFINITE, TX_MASS_MISSING_UNSPECIFIED\n",
    "canonical runtime mass imports",
)
text = replace_once(
    text,
    "    real(real64) :: cursor, next_cursor, tol\n    integer :: isub\n",
    "    real(real64) :: cursor, next_cursor, tol\n"
    "    logical :: aggregate_mass_complete\n"
    "    integer :: isub\n",
    "canonical runtime aggregation local",
)
text = replace_once(
    text,
    "    result%completed_t = interval%t0\n\n    if (.not. allocated(committed)",
    "    result%completed_t = interval%t0\n"
    "    result%mass%interval_t0 = interval%t0\n"
    "    result%mass%interval_t1 = interval%t1\n\n"
    "    if (.not. allocated(committed)",
    "canonical interval mass provenance",
)
text = replace_once(
    text,
    "    call committed%clone(working)\n    call model%prepare_interval(forcing, interval, config)\n    cursor = interval%t0\n",
    "    call committed%clone(working)\n"
    "    call model%prepare_interval(forcing, interval, config)\n"
    "    result%mass%missing_contribution_mask = TX_MASS_MISSING_NONE\n"
    "    aggregate_mass_complete = .true.\n"
    "    cursor = interval%t0\n",
    "canonical mass aggregation initialization",
)
text = replace_once(
    text,
    "      if (tx%status /= TX_STATUS_ACCEPTED) then\n        result%status = CANONICAL_STATUS_TRANSACTION_FAILED\n        result%completed_t = cursor\n        return\n      end if\n\n      next_cursor = tx%accepted_t1\n",
    "      if (tx%status /= TX_STATUS_ACCEPTED) then\n"
    "        result%status = CANONICAL_STATUS_TRANSACTION_FAILED\n"
    "        result%completed_t = cursor\n"
    "        result%mass%missing_contribution_mask = ior(result%mass%missing_contribution_mask, &\n"
    "             TX_MASS_MISSING_UNSPECIFIED)\n"
    "        return\n"
    "      end if\n\n"
    "      call accumulate_accepted_mass(result, tx, aggregate_mass_complete)\n"
    "      next_cursor = tx%accepted_t1\n",
    "canonical accepted mass accumulation call",
)
text = replace_once(
    text,
    "        result%status = CANONICAL_STATUS_NO_PROGRESS\n        result%completed_t = cursor\n        return\n",
    "        result%status = CANONICAL_STATUS_NO_PROGRESS\n"
    "        result%completed_t = cursor\n"
    "        result%mass%missing_contribution_mask = ior(result%mass%missing_contribution_mask, &\n"
    "             TX_MASS_MISSING_UNSPECIFIED)\n"
    "        return\n",
    "canonical no-progress mass fail-closed",
)
text = replace_once(
    text,
    "        result%diagnostics%external_commits = 1\n        ! Full unrounded interval accounting is intentionally not fabricated\n        ! here. It becomes complete only when the physical seam can return\n        ! accepted flux accounting independently of rejected trials.\n        result%mass%complete = .false.\n        return\n",
    "        result%diagnostics%external_commits = 1\n"
    "        call finalize_interval_mass(result, aggregate_mass_complete)\n"
    "        return\n",
    "canonical full interval mass finalization",
)
text = replace_once(
    text,
    "    result%status = CANONICAL_STATUS_SUBSTEP_LIMIT\n    result%completed_t = cursor\n  end subroutine run_canonical_interval\n\n  subroutine accumulate_transaction",
    "    result%status = CANONICAL_STATUS_SUBSTEP_LIMIT\n"
    "    result%completed_t = cursor\n"
    "    result%mass%missing_contribution_mask = ior(result%mass%missing_contribution_mask, &\n"
    "         TX_MASS_MISSING_UNSPECIFIED)\n"
    "  end subroutine run_canonical_interval\n\n"
    "  subroutine accumulate_accepted_mass(result, tx, aggregate_complete)\n"
    "    type(canonical_result_t), intent(inout) :: result\n"
    "    type(transaction_result_t), intent(in) :: tx\n"
    "    logical, intent(inout) :: aggregate_complete\n\n"
    "    if (tx%status /= TX_STATUS_ACCEPTED) return\n"
    "    if (result%mass%accepted_transaction_count == 0) then\n"
    "      result%mass%storage_start = tx%accepted_storage_start\n"
    "    end if\n"
    "    result%mass%storage_end = tx%accepted_storage_end\n"
    "    result%mass%total_in = result%mass%total_in + tx%accepted_total_in\n"
    "    result%mass%total_out = result%mass%total_out + tx%accepted_total_out\n"
    "    result%mass%accepted_transaction_count = result%mass%accepted_transaction_count + 1\n"
    "    result%mass%missing_contribution_mask = ior(result%mass%missing_contribution_mask, &\n"
    "         tx%accepted_missing_contribution_mask)\n"
    "    aggregate_complete = aggregate_complete .and. tx%accepted_mass_complete\n"
    "  end subroutine accumulate_accepted_mass\n\n"
    "  subroutine finalize_interval_mass(result, aggregate_complete)\n"
    "    type(canonical_result_t), intent(inout) :: result\n"
    "    logical, intent(in) :: aggregate_complete\n"
    "    logical :: finite_terms\n\n"
    "    result%mass%storage_change = result%mass%storage_end - result%mass%storage_start\n"
    "    result%mass%residual = result%mass%storage_change - &\n"
    "         (result%mass%total_in - result%mass%total_out)\n"
    "    finite_terms = ieee_is_finite(result%mass%interval_t0) .and. &\n"
    "         ieee_is_finite(result%mass%interval_t1) .and. &\n"
    "         ieee_is_finite(result%mass%storage_start) .and. &\n"
    "         ieee_is_finite(result%mass%storage_end) .and. &\n"
    "         ieee_is_finite(result%mass%storage_change) .and. &\n"
    "         ieee_is_finite(result%mass%total_in) .and. &\n"
    "         ieee_is_finite(result%mass%total_out) .and. ieee_is_finite(result%mass%residual)\n"
    "    if (.not. finite_terms) then\n"
    "      result%mass%missing_contribution_mask = ior(result%mass%missing_contribution_mask, &\n"
    "           TX_MASS_MISSING_NONFINITE)\n"
    "    end if\n"
    "    if (result%mass%accepted_transaction_count <= 0) then\n"
    "      result%mass%missing_contribution_mask = ior(result%mass%missing_contribution_mask, &\n"
    "           TX_MASS_MISSING_UNSPECIFIED)\n"
    "    end if\n"
    "    result%mass%complete = aggregate_complete .and. finite_terms .and. &\n"
    "         result%mass%accepted_transaction_count > 0 .and. &\n"
    "         result%mass%missing_contribution_mask == TX_MASS_MISSING_NONE\n"
    "    if (.not. result%mass%complete .and. &\n"
    "        result%mass%missing_contribution_mask == TX_MASS_MISSING_NONE) then\n"
    "      result%mass%missing_contribution_mask = TX_MASS_MISSING_UNSPECIFIED\n"
    "    end if\n"
    "  end subroutine finalize_interval_mass\n\n"
    "  subroutine accumulate_transaction",
    "canonical mass helper routines",
)
path.write_text(text, encoding="utf-8")

# 4. Kernel: bind canonical accounting to lineage/revision and candidate commit lifecycle.
path = ROOT / "src/kernel/mod_kernel_transactions.f90"
text = path.read_text(encoding="utf-8")
text = replace_once(
    text,
    "    integer(int64) :: origin_revision_value = -1_int64\n  contains\n",
    "    integer(int64) :: origin_revision_value = -1_int64\n"
    "    type(canonical_mass_accounting_t) :: mass\n"
    "  contains\n",
    "kernel candidate mass carrier",
)
text = replace_once(
    text,
    "    call map_runtime_result(runtime_result, result)\n    call map_transaction_diagnostics(runtime_result%diagnostics, diagnostics)\n    if (present(checkpoint)) diagnostics%checkpoint_uses = 1\n",
    "    call map_runtime_result(runtime_result, result)\n"
    "    call map_transaction_diagnostics(runtime_result%diagnostics, diagnostics)\n"
    "    result%mass%origin_lineage_id = committed_state%lineage_id\n"
    "    result%mass%origin_revision = committed_state%revision\n"
    "    if (present(checkpoint)) diagnostics%checkpoint_uses = 1\n",
    "kernel result mass provenance",
)
text = replace_once(
    text,
    "      candidate_state%origin_lineage_id_value = committed_state%lineage_id\n      candidate_state%origin_revision_value = committed_state%revision\n      diagnostics%candidate_materializations = 1\n",
    "      candidate_state%origin_lineage_id_value = committed_state%lineage_id\n"
    "      candidate_state%origin_revision_value = committed_state%revision\n"
    "      candidate_state%mass = result%mass\n"
    "      diagnostics%candidate_materializations = 1\n",
    "kernel candidate mass copy",
)
text = replace_once(
    text,
    "  subroutine kernel_commit_candidate(self, committed_state, candidate_state, diagnostics, did_commit, commit_status)\n",
    "  subroutine kernel_commit_candidate(self, committed_state, candidate_state, diagnostics, did_commit, commit_status, &\n"
    "                                     accepted_mass)\n",
    "kernel commit signature",
)
text = replace_once(
    text,
    "    logical, intent(out) :: did_commit\n    integer, intent(out), optional :: commit_status\n\n    did_commit = .false.\n    if (present(commit_status)) commit_status = KERNEL_COMMIT_STATUS_INVALID_CANDIDATE\n",
    "    logical, intent(out) :: did_commit\n"
    "    integer, intent(out), optional :: commit_status\n"
    "    type(canonical_mass_accounting_t), intent(out), optional :: accepted_mass\n\n"
    "    did_commit = .false.\n"
    "    if (present(commit_status)) commit_status = KERNEL_COMMIT_STATUS_INVALID_CANDIDATE\n"
    "    if (present(accepted_mass)) accepted_mass = canonical_mass_accounting_t()\n",
    "kernel commit accepted mass declaration",
)
text = replace_once(
    text,
    "    call move_alloc(candidate_state%state, committed_state%physical_state)\n    committed_state%revision = committed_state%revision + 1_int64\n",
    "    call move_alloc(candidate_state%state, committed_state%physical_state)\n"
    "    if (present(accepted_mass)) accepted_mass = candidate_state%mass\n"
    "    committed_state%revision = committed_state%revision + 1_int64\n",
    "kernel commit accepted mass publication",
)
text = replace_once(
    text,
    "    candidate_state%origin_lineage_id_value = 0_int64\n    candidate_state%origin_revision_value = -1_int64\n  end subroutine clear_candidate\n",
    "    candidate_state%origin_lineage_id_value = 0_int64\n"
    "    candidate_state%origin_revision_value = -1_int64\n"
    "    candidate_state%mass = canonical_mass_accounting_t()\n"
    "  end subroutine clear_candidate\n",
    "kernel candidate mass clear",
)
path.write_text(text, encoding="utf-8")

print("FKT08_MATERIALIZER_READY")
