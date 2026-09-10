#!/usr/bin/env python3
from __future__ import annotations

import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BASE_SRC_TREE = "3fe4ccff367479e54ab5db106e5faf8b480d8ec0"
HISTORICAL_PARALLEL_CANDIDATE = "e8858ce4816fc6ddfaf9ec252832c76cd3094705"
SERIAL_RUNTIME = "src/runtime/mod_fmr_serialized_multiswap_runtime.f90"
SERIAL_RUNTIME_BLOB = "6559237c887e9a8476beb479546becdfe9339920"
SCHEDULER = "src/runtime/mod_fmr_parallel_physical_scheduler.f90"
SCHEDULER_BLOB = "544a1ca16fdeebdfce7f89d1ddf1825fa32fa654"
WORKER_POOL = "src/runtime/mod_fmr_parallel_worker_pool.f90"
WORKER_POOL_BLOB = "f9a31effda51a298b7db74fdba492fc6b6047339"


def git(*args: str) -> str:
    return subprocess.check_output(["git", "-C", str(ROOT), *args], text=True).strip()


def require(condition: bool, label: str) -> None:
    if not condition:
        raise SystemExit(f"FMR26_APPLY_FAIL {label}")
    print(f"FMR26_APPLY_{label}=PASS")


def historical_bytes(path: str) -> bytes:
    return subprocess.check_output(
        ["git", "-C", str(ROOT), "show", f"{HISTORICAL_PARALLEL_CANDIDATE}:{path}"]
    )


def main() -> int:
    require(git("rev-parse", "HEAD:src") == BASE_SRC_TREE, "BASE_SRC_TREE_LOCK")
    require(git("rev-parse", f"HEAD:{SERIAL_RUNTIME}") == SERIAL_RUNTIME_BLOB, "SERIAL_RUNTIME_BLOB_LOCK")
    require(not (ROOT / SCHEDULER).exists(), "SCHEDULER_ABSENT_PREIMAGE")
    require(not (ROOT / WORKER_POOL).exists(), "WORKER_POOL_ABSENT_PREIMAGE")
    require(git("rev-parse", f"{HISTORICAL_PARALLEL_CANDIDATE}:{SCHEDULER}") == SCHEDULER_BLOB,
            "HISTORICAL_SCHEDULER_BLOB_LOCK")
    require(git("rev-parse", f"{HISTORICAL_PARALLEL_CANDIDATE}:{WORKER_POOL}") == WORKER_POOL_BLOB,
            "HISTORICAL_WORKER_POOL_BLOB_LOCK")

    serial_path = ROOT / SERIAL_RUNTIME
    text = serial_path.read_text(encoding="utf-8")
    public_anchor = "  public :: fmr_run_serialized_physical_multiswap\n\ncontains\n"
    require(text.count(public_anchor) == 1, "PUBLIC_ANCHOR_UNIQUE")
    text = text.replace(
        public_anchor,
        "  public :: fmr_run_serialized_physical_multiswap\n"
        "  public :: fmr_execute_serialized_physical_column\n\ncontains\n",
        1,
    )

    execute_anchor = "  subroutine execute_column(backend, transaction_control, column, templates, parameter_registry, forcing_registry, &\n"
    require(text.count(execute_anchor) == 1, "EXECUTE_COLUMN_ANCHOR_UNIQUE")

    wrapper = '''  ! F-MR26 compatibility seam for the already-qualified restricted parallel V1\n  ! worker pool.  This deliberately exposes only the no-receipt route.  The\n  ! authoritative checkpoint, trial, mass, commit and rollback implementation\n  ! remains execute_column below; parallel commit-receipt routing is not admitted.\n  subroutine fmr_execute_serialized_physical_column(backend, transaction_control, column, templates, &\n                                                     parameter_registry, forcing_registry, state_registry, &\n                                                     numerical_config, t0, t1, output, diagnostic, runtime, &\n                                                     active_physical_calls)\n    type(fmr_serialized_reference_backend_t), intent(inout) :: backend\n    type(kernel_executor_t), intent(inout) :: transaction_control\n    type(fmr_logical_column_t), intent(in) :: column\n    type(fmr_template_t), intent(in) :: templates(:)\n    type(fmr_b110_physical_parameters_t), intent(in) :: parameter_registry(:)\n    type(fmr_b110_physical_forcing_t), intent(in) :: forcing_registry(:)\n    type(kernel_committed_state_t), intent(inout) :: state_registry(:)\n    type(canonical_numerical_config_t), intent(in) :: numerical_config\n    real(real64), intent(in) :: t0, t1\n    type(fmr_serialized_column_result_t), intent(inout) :: output\n    type(fmr_column_diagnostics_t), intent(inout) :: diagnostic\n    type(fmr_serialized_batch_diagnostics_t), intent(inout) :: runtime\n    integer, intent(inout) :: active_physical_calls\n\n    call execute_column(backend, transaction_control, column, templates, parameter_registry, forcing_registry, &\n                        state_registry, numerical_config, t0, t1, output, diagnostic, runtime, &\n                        active_physical_calls)\n  end subroutine fmr_execute_serialized_physical_column\n\n'''
    text = text.replace(execute_anchor, wrapper + execute_anchor, 1)
    serial_path.write_text(text, encoding="utf-8")

    (ROOT / SCHEDULER).write_bytes(historical_bytes(SCHEDULER))
    (ROOT / WORKER_POOL).write_bytes(historical_bytes(WORKER_POOL))

    require(git("hash-object", str(ROOT / SCHEDULER)) == SCHEDULER_BLOB, "SCHEDULER_POSTIMAGE_BLOB")
    require(git("hash-object", str(ROOT / WORKER_POOL)) == WORKER_POOL_BLOB, "WORKER_POOL_POSTIMAGE_BLOB")

    changed = sorted(p for p in git("diff", "--name-only", "--", "src").splitlines() if p)
    require(changed == sorted([SERIAL_RUNTIME, SCHEDULER, WORKER_POOL]), "EXACT_THREE_SOURCE_DELTA")
    require("fmr_execute_serialized_physical_column" in text, "NO_RECEIPT_WRAPPER_PRESENT")
    require("call execute_column(" in wrapper, "WRAPPER_DELEGATES_TO_CURRENT_EXECUTOR")

    print("FMR26_APPLY_READY_TO_COMMIT=PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
