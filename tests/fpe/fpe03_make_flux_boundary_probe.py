#!/usr/bin/env python3
from pathlib import Path
import sys

if len(sys.argv) != 3:
    raise SystemExit('usage: fpe03_make_flux_boundary_probe.py BASE_OVERLAY OUT')

base_path = Path(sys.argv[1])
out_path = Path(sys.argv[2])
text = base_path.read_text()


def replace_once(old: str, new: str, label: str) -> None:
    global text
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{label}: expected one anchor, found {count}')
    text = text.replace(old, new, 1)

replace_once(
    'program test_fpe03_nonstationary_snow_overlay\n  use, intrinsic :: iso_fortran_env',
    'program test_fpe03_flux_boundary_probe\n  use, intrinsic :: iso_fortran_env',
    'program name',
)
replace_once(
    '  integer, parameter :: ncases = 4\n',
    '  integer, parameter :: ncases = 13\n',
    'case count',
)

start = text.index('  subroutine initialize_cases(c)\n')
end = text.index('  end subroutine initialize_cases\n', start) + len('  end subroutine initialize_cases\n')
text = text[:start] + """  subroutine initialize_cases(c)
    type(stress_case_t), intent(out) :: c(ncases)

    ! Exact admitted FMR06/FVQ17 active-SNOW hydraulic baseline.
    call set_uniform(c(1), 'admitted_snow_baseline', -75.0_real64, -1.0_real64, -1.0_real64)

    ! Diagnostic-only logarithmic top-flux scan around the admitted equilibrium.
    ! No solver controls, physics or scientific admission are changed.
    call set_uniform(c(2),  'flux_plus_1e-4',  -75.0_real64, -(1.0_real64 + 1.0e-4_real64),  -1.0_real64)
    call set_uniform(c(3),  'flux_minus_1e-4', -75.0_real64, -(1.0_real64 - 1.0e-4_real64),  -1.0_real64)
    call set_uniform(c(4),  'flux_plus_1e-6',  -75.0_real64, -(1.0_real64 + 1.0e-6_real64),  -1.0_real64)
    call set_uniform(c(5),  'flux_minus_1e-6', -75.0_real64, -(1.0_real64 - 1.0e-6_real64),  -1.0_real64)
    call set_uniform(c(6),  'flux_plus_1e-8',  -75.0_real64, -(1.0_real64 + 1.0e-8_real64),  -1.0_real64)
    call set_uniform(c(7),  'flux_minus_1e-8', -75.0_real64, -(1.0_real64 - 1.0e-8_real64),  -1.0_real64)
    call set_uniform(c(8),  'flux_plus_1e-10',  -75.0_real64, -(1.0_real64 + 1.0e-10_real64), -1.0_real64)
    call set_uniform(c(9),  'flux_minus_1e-10', -75.0_real64, -(1.0_real64 - 1.0e-10_real64), -1.0_real64)
    call set_uniform(c(10), 'flux_plus_1e-12',  -75.0_real64, -(1.0_real64 + 1.0e-12_real64), -1.0_real64)
    call set_uniform(c(11), 'flux_minus_1e-12', -75.0_real64, -(1.0_real64 - 1.0e-12_real64), -1.0_real64)
    call set_uniform(c(12), 'flux_plus_1e-14',  -75.0_real64, -(1.0_real64 + 1.0e-14_real64), -1.0_real64)
    call set_uniform(c(13), 'flux_minus_1e-14', -75.0_real64, -(1.0_real64 - 1.0e-14_real64), -1.0_real64)
  end subroutine initialize_cases
""" + text[end:]

replace_once(
    "  write(*,'(A)') 'FPE03_NONSTATIONARY_SNOW_PERTURBATIONS=DIAGNOSTIC_NOT_SCIENTIFIC_ADMISSION'\n",
    "  write(*,'(A)') 'FPE03_FLUX_BOUNDARY_LEVELS=1E-4,1E-6,1E-8,1E-10,1E-12,1E-14'\n"
    "  write(*,'(A)') 'FPE03_FLUX_BOUNDARY_PERTURBATIONS=DIAGNOSTIC_NOT_SCIENTIFIC_ADMISSION'\n",
    'perturbation marker',
)
replace_once(
    "  write(*,'(A)') 'FPE03_NONSTATIONARY_SNOW_OVERLAY PASS'\n",
    "  write(*,'(A)') 'FPE03_FLUX_BOUNDARY_PROBE PASS'\n",
    'final marker',
)
replace_once(
    'end program test_fpe03_nonstationary_snow_overlay\n',
    'end program test_fpe03_flux_boundary_probe\n',
    'end program name',
)

out_path.parent.mkdir(parents=True, exist_ok=True)
out_path.write_text(text)
print(f'FPE03_FLUX_BOUNDARY_PROBE_GENERATED={out_path}')
print('FPE03_FLUX_BOUNDARY_CASES=13')
print('FPE03_FLUX_BOUNDARY_NONZERO_PERTURBATIONS=12')
print('FPE03_FLUX_BOUNDARY_SCIENTIFIC_ADMISSION_EXPANDED=NO')
