from pathlib import Path
import re

def replace_once(text, pattern, repl, label, flags=0):
    out, n = re.subn(pattern, repl, text, count=1, flags=flags)
    if n != 1:
        raise SystemExit(f"{label}: expected one replacement, got {n}")
    return out

# 1. Legacy binding: PPA was based on the pre-workspace-component local name.
p = Path("src/adapter/mod_reference_richards_legacy_binding.f90")
s = p.read_text()
s = s.replace("ws%ws%state_binding%", "ws%state_binding%")
s = re.sub(r"(?<!ws%)state_binding%", "ws%state_binding%", s)
p.write_text(s)

# 2. Serialized backend: combine the current prepared-parameter fast path with
# the PPA target-selector continuation route.
p = Path("src/runtime/mod_fmr_serialized_reference_backend.f90")
s = p.read_text()

header = """  subroutine fmr_serialized_backend_run_trial(self, column, template, parameters, committed, forcing, config, &
                                               t0, t1, checkpoint, result, candidate, diagnostics, &
                                               trusted_prepared_parameters, target_selector)
    class(fmr_serialized_reference_backend_t), intent(inout) :: self"""
s = replace_once(
    s,
    r"  subroutine fmr_serialized_backend_run_trial\(self, column, template, parameters, committed, forcing, config, &\n.*?\n    class\(fmr_serialized_reference_backend_t\), intent\(inout\) :: self",
    header,
    "backend run_trial header",
    re.S,
)

# Forward target_selector by name from the irrigation wrapper so it cannot bind
# to trusted_prepared_parameters.
s = s.replace(
    "         diagnostics,target_selector)\n",
    "         diagnostics,target_selector=target_selector)\n",
)

# Reconcile the post-trial section. The union merge contains both alternatives;
# replace the entire region once with the semantically composed route.
post = """    if (present(target_selector)) then
      call fmr_trial_from_checkpoint(self%kernel, parameters, committed, forcing, config, t0, t1, checkpoint, &
           result, candidate, diagnostics, target_selector)
    else
      call fmr_trial_from_checkpoint(self%kernel, parameters, committed, forcing, config, t0, t1, checkpoint, &
           result, candidate, diagnostics)
    end if
    self%model%last_observation%snow_event_evaluation_calls = self%model%snow_event_evaluation_calls
    self%model%last_observation%black_evaporation_evaluation_calls = &
         self%model%black_evaporation_evaluation_calls
    self%model%last_observation%boesten_evaporation_evaluation_calls = &
         self%model%boesten_evaporation_evaluation_calls
    self%model%last_observation%soil_temperature_evaluation_calls = &
         self%model%soil_temperature_evaluation_calls
    self%model%last_observation%drainage_response_evaluation_calls = &
         self%model%drainage_response_evaluation_calls
    self%model%last_observation%common_work_payload_bytes = &
         serialized_common_work_payload_bytes(self%model)
    self%model%last_observation%soil_temperature_optional_payload_bytes = &
         serialized_optional_work_payload_bytes(self%model)
    if (associated(self%model%constitutive)) nullify(self%model%constitutive%parameters)
    nullify(self%model%hydraulic_parameters)
    nullify(self%model%trusted_parameter_source)
    self%model%trusted_prepared_default_mvg = .false.
"""
s = replace_once(
    s,
    r"    call fmr_trial_from_checkpoint\(self%kernel, parameters, committed, forcing, config, t0, t1, checkpoint, &\n.*?(?=    if \(self%model%bottom_thermal_carrier_active)",
    post,
    "backend post-trial composition",
    re.S,
)

p.write_text(s)
print("PPA_RECONCILE_RESOLVER=PASS")
