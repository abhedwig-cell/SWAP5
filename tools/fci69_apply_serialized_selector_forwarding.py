from pathlib import Path


def once(path: str, old: str, new: str) -> None:
    p = Path(path)
    text = p.read_text()
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"FCI69_PATCH_ANCHOR_MISMATCH {path} count={count} anchor={old[:100]!r}")
    p.write_text(text.replace(old, new, 1))
    print(f"FCI69_PATCHED {path}")


B = "src/runtime/mod_fmr_serialized_reference_backend.f90"

once(
    B,
    """  use mod_canonical_contracts, only: canonical_state_t, canonical_forcing_t, canonical_interval_t, &
       canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_parameters_t, kernel_model_t, kernel_committed_state_t, &
""",
    """  use mod_canonical_contracts, only: canonical_state_t, canonical_forcing_t, canonical_interval_t, &
       canonical_numerical_config_t
  use mod_canonical_interval_runtime, only: canonical_subinterval_target_selector
  use mod_kernel_transactions, only: kernel_parameters_t, kernel_model_t, kernel_committed_state_t, &
""",
)

once(
    B,
    """  subroutine fmr_serialized_backend_run_trial(self, column, template, parameters, committed, forcing, config, &
                                               t0, t1, checkpoint, result, candidate, diagnostics)
""",
    """  subroutine fmr_serialized_backend_run_trial(self, column, template, parameters, committed, forcing, config, &
                                               t0, t1, checkpoint, result, candidate, diagnostics, target_selector)
""",
)

once(
    B,
    """    type(kernel_candidate_state_t), intent(out) :: candidate
    type(kernel_diagnostics_t), intent(out) :: diagnostics
    logical :: bottom_thermal_ok
""",
    """    type(kernel_candidate_state_t), intent(out) :: candidate
    type(kernel_diagnostics_t), intent(out) :: diagnostics
    procedure(canonical_subinterval_target_selector), optional :: target_selector
    logical :: bottom_thermal_ok
""",
)

once(
    B,
    """    call fmr_trial_from_checkpoint(self%kernel, parameters, committed, forcing, config, t0, t1, checkpoint, &
         result, candidate, diagnostics)
""",
    """    if (present(target_selector)) then
      call fmr_trial_from_checkpoint(self%kernel, parameters, committed, forcing, config, t0, t1, checkpoint, &
           result, candidate, diagnostics, target_selector)
    else
      call fmr_trial_from_checkpoint(self%kernel, parameters, committed, forcing, config, t0, t1, checkpoint, &
           result, candidate, diagnostics)
    end if
""",
)

print("FCI69_SERIALIZED_SELECTOR_FORWARDING_PATCH=PASS")
