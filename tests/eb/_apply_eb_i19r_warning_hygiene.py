from pathlib import Path
import subprocess

EXPECTED = {
    'src/runtime/mod_fmr_serialized_reference_backend.f90': 'a4b4891f5e7223691264eff80cdfc6dbb3851a5a',
    'src/runtime/mod_fmr_serialized_multiswap_runtime.f90': '345febcbb567084163928b81b6bc0303f31d05d9',
    'src/runtime/mod_fmr_bottom_sensible_energy.f90': '1f3d6f975278f960feac4388b0cdd36a0f5f162d',
}

for raw_path, expected_blob in EXPECTED.items():
    actual = subprocess.check_output(['git', 'hash-object', raw_path], text=True).strip()
    if actual != expected_blob:
        raise SystemExit(f'EB-I19R source precondition failed: {raw_path} {actual} != {expected_blob}')


def replace_once(path: str, old: str, new: str, label: str) -> None:
    p = Path(path)
    text = p.read_text()
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'EB-I19R anchor {label!r} in {path} matched {count} times')
    p.write_text(text.replace(old, new, 1))


backend = 'src/runtime/mod_fmr_serialized_reference_backend.f90'
replace_once(
    backend,
    '        self%model%state_profile_admitted .and. config%max_committed_substeps <= huge(0)/2) then\n',
    '        self%model%state_profile_admitted .and. config%max_committed_substeps <= ishft(huge(0), -1)) then\n',
    'overflow-safe carrier capacity bound without integer division warning',
)
replace_once(
    backend,
    """    if (self%model%bottom_thermal_carrier_active .and. self%model%bottom_thermal_carrier_valid .and. &
        result%completed .and. candidate%ready()) then
      call self%model%bottom_thermal_carrier%materialize_candidate(t0, t1, self%bottom_thermal_candidate, &
           bottom_thermal_ok)
      if (.not. bottom_thermal_ok) call self%bottom_thermal_candidate%clear()
    end if
""",
    """    if (self%model%bottom_thermal_carrier_active .and. self%model%bottom_thermal_carrier_valid .and. &
        result%completed) then
      if (candidate%ready()) then
        call self%model%bottom_thermal_carrier%materialize_candidate(t0, t1, self%bottom_thermal_candidate, &
             bottom_thermal_ok)
        if (.not. bottom_thermal_ok) call self%bottom_thermal_candidate%clear()
      end if
    end if
""",
    'candidate readiness evaluation order',
)

runtime = 'src/runtime/mod_fmr_serialized_multiswap_runtime.f90'
replace_once(
    runtime,
    """      call external_temperature_provider(request, response)
      if (.not. response%ready() .or. .not. response%identity_matches(request)) then
        prepared%provider_invalid_count_value = prepared%provider_invalid_count_value + 1
        cycle
      end if
""",
    """      call external_temperature_provider(request, response)
      if (.not. response%ready()) then
        prepared%provider_invalid_count_value = prepared%provider_invalid_count_value + 1
        cycle
      end if
      if (.not. response%identity_matches(request)) then
        prepared%provider_invalid_count_value = prepared%provider_invalid_count_value + 1
        cycle
      end if
""",
    'provider readiness and identity evaluation order',
)

energy = 'src/runtime/mod_fmr_bottom_sensible_energy.f90'
replace_once(
    energy,
    '    if (.not. candidate%ready() .or. .not. parameters%ready()) return\n',
    '    if (.not. candidate%ready()) return\n    if (.not. parameters%ready()) return\n',
    'candidate and parameter readiness evaluation order',
)

for raw_path in EXPECTED:
    new_blob = subprocess.check_output(['git', 'hash-object', raw_path], text=True).strip()
    print(f'EB_I19R_PATCHED_BLOB path={raw_path} blob={new_blob}')

print('EB_I19R_WARNING_HYGIENE_TRANSFORMATION=PASS')
