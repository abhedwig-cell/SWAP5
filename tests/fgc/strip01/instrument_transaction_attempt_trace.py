"""Generate a local-only transaction source override for STRIP01 retry tracing."""
import argparse
from pathlib import Path


def replace_once(source: str, before: str, after: str) -> str:
    count = source.count(before)
    if count != 1:
        raise RuntimeError(f"expected one source anchor, found {count}: {before[:80]!r}")
    return source.replace(before, after, 1)


def patch_certificate(source: str, before: str, after: str) -> str:
    start = source.index("  subroutine execute_model_certificate_interval(")
    end = source.index("  end subroutine execute_model_certificate_interval", start)
    body = source[start:end]
    body = replace_once(body, before, after)
    return source[:start] + body + source[end:]


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[3])
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    source = (args.root / "src/transaction/mod_transaction_reference.f90").read_text()

    source = replace_once(source, "  implicit none\n  private\n", "  implicit none\n  private\n\n  integer, save :: strip01_trace_transaction_sequence = 0\n")
    source = patch_certificate(source,
        "    integer :: retry_index\n\n    result = transaction_result_t()\n    result%requested_t0 = t0\n    result%requested_t1 = t1\n    result%accepted_t1 = t0\n    result%temporal_acceptance_source = TX_TEMPORAL_MODEL_CERTIFICATE\n",
        "    integer :: retry_index\n    integer :: trace_id\n\n    result = transaction_result_t()\n    result%requested_t0 = t0\n    result%requested_t1 = t1\n    result%accepted_t1 = t0\n    result%temporal_acceptance_source = TX_TEMPORAL_MODEL_CERTIFICATE\n    trace_id = 0\n    if (abs(t0 - 0.004_real64) <= 1.0e-14_real64 .and. &\n        abs(t1 - 0.005_real64) <= 1.0e-14_real64) then\n      strip01_trace_transaction_sequence = strip01_trace_transaction_sequence + 1\n      trace_id = strip01_trace_transaction_sequence\n    end if\n")
    source = patch_certificate(source,
        "      if (.not. outcome%solver_ok) then\n        result%solver_rejections = result%solver_rejections + 1\n",
        "      if (.not. outcome%solver_ok) then\n        call strip01_trace_attempt(trace_id, retry_index, t0, t1, attempt_t1, attempt_dt, 'solver', &\n             outcome, .false., .false., .false., huge(0.0_real64))\n        result%solver_rejections = result%solver_rejections + 1\n")
    source = patch_certificate(source,
        "      if (.not. mass_ok) then\n        result%mass_rejections = result%mass_rejections + 1\n",
        "      if (.not. mass_ok) then\n        call strip01_trace_attempt(trace_id, retry_index, t0, t1, attempt_t1, attempt_dt, 'mass', &\n             outcome, mass_ok, temporal_ok, .false., mass_residual)\n        result%mass_rejections = result%mass_rejections + 1\n")
    source = patch_certificate(source,
        "      if (.not. temporal_ok) then\n        result%temporal_rejections = result%temporal_rejections + 1\n",
        "      if (.not. temporal_ok) then\n        call strip01_trace_attempt(trace_id, retry_index, t0, t1, attempt_t1, attempt_dt, 'temporal', &\n             outcome, mass_ok, temporal_ok, certificate_valid, mass_residual)\n        result%temporal_rejections = result%temporal_rejections + 1\n")
    source = replace_once(source,
        "      result%accepted_storage_start = storage0\n      result%accepted_storage_end = storage_candidate\n",
        "      call strip01_trace_attempt(trace_id, retry_index, t0, t1, attempt_t1, attempt_dt, 'accept', &\n           outcome, mass_ok, temporal_ok, certificate_valid, mass_residual)\n\n      result%accepted_storage_start = storage0\n      result%accepted_storage_end = storage_candidate\n")
    helper = '''
  subroutine strip01_trace_attempt(trace_id, retry_index, t0, requested_t1, attempt_t1, attempt_dt, reason, &
       outcome, mass_ok, temporal_ok, certificate_valid, mass_residual)
    integer, intent(in) :: trace_id, retry_index
    real(real64), intent(in) :: t0, requested_t1, attempt_t1, attempt_dt, mass_residual
    character(len=*), intent(in) :: reason
    type(trial_outcome_t), intent(in) :: outcome
    logical, intent(in) :: mass_ok, temporal_ok, certificate_valid
    character(len=1024) :: trace_path
    integer :: env_status, unit, io_status
    if (trace_id <= 0) return
    call get_environment_variable('STRIP01_ATTEMPT_TRACE', trace_path, status=env_status)
    if (env_status /= 0 .or. len_trim(trace_path) == 0) return
    open(newunit=unit, file=trim(trace_path), status='unknown', position='append', action='write', iostat=io_status)
    if (io_status /= 0) return
    write(unit,'(I0,",",I0,4(",",ES24.16E3),",",A,",",L1,",",L1,",",I0,",",L1, &
         & 4(",",ES24.16E3),6(",",I0),3(",",L1))',iostat=io_status) &
         trace_id,retry_index,t0,requested_t1,attempt_t1,attempt_dt,trim(reason),outcome%solver_ok, &
         outcome%mass_accounting_complete,outcome%missing_mass_contribution_mask, &
         outcome%temporal_certificate_available,outcome%temporal_indicator,outcome%mass_in,outcome%mass_out, &
         mass_residual,outcome%nonlinear_iterations,outcome%internal_retries,outcome%headcalc_calls, &
         outcome%jacobian_builds,outcome%linear_solves,outcome%backtracking_attempts,mass_ok,temporal_ok, &
         certificate_valid
    close(unit)
  end subroutine strip01_trace_attempt

'''
    source = replace_once(source, "  subroutine publish_local_terminal_sensitivity(", helper + "  subroutine publish_local_terminal_sensitivity(")
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(source)


if __name__ == "__main__":
    main()
