#!/usr/bin/env python3
from pathlib import Path
import subprocess

path = Path('src/runtime/mod_energy_conservation_ledger.f90')
expected = 'a6aea349308e8b6b0aedaaa22a64e41f9101b48d'
actual = subprocess.check_output(['git', 'hash-object', str(path)], text=True).strip()
if actual != expected:
    raise SystemExit(f'EB-I20R1 preblob mismatch: {actual}')

text = path.read_text()

def replace_once(old: str, new: str, label: str) -> None:
    global text
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'EB-I20R1 {label}: expected one match, found {count}')
    text = text.replace(old, new, 1)

replace_once(
"""    integer(int64) :: preparation_generation = 0_int64
    integer(int64) :: prepared_generation = 0_int64
    integer(int64) :: lineage_id = 0_int64
""",
"""    integer(int64) :: preparation_generation = 0_int64
    integer(int64) :: prepared_generation = 0_int64
    integer(int64) :: prepared_lineage_id = 0_int64
    integer(int64) :: prepared_origin_revision_value = -1_int64
    real(real64) :: prepared_t0_value = 0.0_real64
    real(real64) :: prepared_t1_value = 0.0_real64
    integer(int64) :: lineage_id = 0_int64
""",
'prepared owner fields')

replace_once(
"""    self%prepared_generation = self%preparation_generation + 1_int64
    self%preparation_generation = self%prepared_generation
    self%prepared_active = .true.

    prepared%generation = self%prepared_generation
""",
"""    self%prepared_generation = self%preparation_generation + 1_int64
    self%preparation_generation = self%prepared_generation
    self%prepared_lineage_id = self%lineage_id
    self%prepared_origin_revision_value = self%origin_revision_value
    self%prepared_t0_value = self%t0_value
    self%prepared_t1_value = self%t1_value
    self%prepared_active = .true.

    prepared%generation = self%prepared_generation
""",
'capture prepared owner provenance')

replace_once(
"""    ready = .false.
    if (.not. self%prepared_active .or. .not. prepared%ready() .or. .not. receipt%ready()) return
    if (prepared%generation /= self%prepared_generation) return
    if (receipt%current_lineage_id() /= prepared%lineage_id) return
""",
"""    ready = .false.
    if (.not. receipt%ready()) return
    if (.not. prepared_matches_ledger(self, prepared)) return
    if (receipt%current_lineage_id() /= prepared%lineage_id) return
""",
'receipt owner binding')

replace_once(
"""    status = ENERGY_LEDGER_INVALID_PROVENANCE
    if (.not. self%prepared_active .or. .not. prepared%ready()) return
    if (prepared%generation /= self%prepared_generation) return
    call clear_prepared(self, prepared)
""",
"""    status = ENERGY_LEDGER_INVALID_PROVENANCE
    if (.not. prepared_matches_ledger(self, prepared)) return
    call clear_prepared(self, prepared)
""",
'abort owner binding')

replace_once(
"""    self%prepared_active = .false.
    self%prepared_generation = 0_int64
    prepared = prepared_energy_trial_t()
  end subroutine clear_prepared

  pure logical function same_fkt_time(a, b) result(matches)
""",
"""    self%prepared_active = .false.
    self%prepared_generation = 0_int64
    self%prepared_lineage_id = 0_int64
    self%prepared_origin_revision_value = -1_int64
    self%prepared_t0_value = 0.0_real64
    self%prepared_t1_value = 0.0_real64
    prepared = prepared_energy_trial_t()
  end subroutine clear_prepared

  pure logical function prepared_matches_ledger(self, prepared) result(matches)
    class(energy_trial_ledger_t), intent(in) :: self
    type(prepared_energy_trial_t), intent(in) :: prepared

    matches = .false.
    if (.not. self%prepared_active .or. .not. prepared%ready()) return
    if (prepared%generation /= self%prepared_generation) return
    if (prepared%lineage_id /= self%prepared_lineage_id) return
    if (prepared%origin_revision_value /= self%prepared_origin_revision_value) return
    if (.not. same_fkt_time(prepared%t0_value, self%prepared_t0_value)) return
    if (.not. same_fkt_time(prepared%t1_value, self%prepared_t1_value)) return
    matches = .true.
  end function prepared_matches_ledger

  pure logical function same_fkt_time(a, b) result(matches)
""",
'clear and helper')

path.write_text(text)
