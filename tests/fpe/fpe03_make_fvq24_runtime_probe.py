#!/usr/bin/env python3
from pathlib import Path
import sys

if len(sys.argv) != 3:
    raise SystemExit('usage: fpe03_make_fvq24_runtime_probe.py BASE_FPE03 OUT')

src = Path(sys.argv[1])
out = Path(sys.argv[2])
text = src.read_text(encoding='utf-8')


def replace_once(old: str, new: str, label: str) -> None:
    global text
    n = text.count(old)
    if n != 1:
        raise SystemExit(f'{label}: expected one anchor, found {n}')
    text = text.replace(old, new, 1)

replace_once(
    'program test_fpe03_reference_stress\n',
    'program test_fpe03_fvq24_admitted_runtime_probe\n',
    'program name',
)
replace_once('  integer, parameter :: ncases = 24\n', '  integer, parameter :: ncases = 5\n', 'case count')
replace_once(
    '  real(real64), parameter :: t1 = 1000.625_real64\n',
    '  real(real64), parameter :: t1 = 1001.125_real64\n',
    'exact one-day step duration',
)

start = text.index('  subroutine initialize_cases(c)\n')
end = text.index('  end subroutine initialize_cases\n', start) + len('  end subroutine initialize_cases\n')
text = text[:start] + """  subroutine initialize_cases(c)
    type(stress_case_t), intent(out) :: c(ncases)

    ! Exact F-VQ24 / F-SI18 scientifically admitted five-case stimulus.
    call set_uniform(c(1), 'fvq24_baseline',      -75.0_real64, -(1.0_real64 + 0.0_real64),     -1.0_real64)
    call set_uniform(c(2), 'fvq24_plus_3e-12',   -75.0_real64, -(1.0_real64 + 3.0e-12_real64), -1.0_real64)
    call set_uniform(c(3), 'fvq24_minus_3e-12',  -75.0_real64, -(1.0_real64 - 3.0e-12_real64), -1.0_real64)
    call set_uniform(c(4), 'fvq24_plus_1e-11',   -75.0_real64, -(1.0_real64 + 1.0e-11_real64), -1.0_real64)
    call set_uniform(c(5), 'fvq24_minus_1e-11',  -75.0_real64, -(1.0_real64 - 1.0e-11_real64), -1.0_real64)
  end subroutine initialize_cases
""" + text[end:]

replace_once(
    '    forcing%bottom_head = spec%heads(numnod)\n',
    '    forcing%bottom_head = -100.0_real64\n',
    'F-VQ24 unused bottom-head stimulus lock',
)
replace_once(
    "  write(*,'(A)') 'FPE03_REFERENCE_STRESS_CHARACTERIZATION PASS'\n",
    "  write(*,'(A)') 'FPE03_FVQ24_STIMULUS_SOURCE=SCIENTIFICALLY_ADMITTED_FVQ24'\n"
    "  write(*,'(A)') 'FPE03_FVQ24_STEP_DURATION=1.0'\n"
    "  write(*,'(A)') 'FPE03_FVQ24_PERTURBATIONS=0,+3E-12,-3E-12,+1E-11,-1E-11'\n"
    "  write(*,'(A)') 'FPE03_FVQ24_RUNTIME_PROBE PASS'\n",
    'final marker',
)
replace_once(
    'end program test_fpe03_reference_stress\n',
    'end program test_fpe03_fvq24_admitted_runtime_probe\n',
    'end program',
)

# Structural stimulus locks: do not silently alter the admitted physical/numerical case.
required = [
    'real(real64), parameter :: t0 = 1000.125_real64',
    'real(real64), parameter :: t1 = 1001.125_real64',
    "call set_uniform(c(2), 'fvq24_plus_3e-12'",
    "call set_uniform(c(5), 'fvq24_minus_1e-11'",
    'parameters%bottom_mode = 7',
    'parameters%max_iterations = 8',
    'parameters%max_backtracking = 4',
    'parameters%min_step_duration = 1.0e-6_real64',
    'parameters%compartment_balance_tolerance = 1.0e-12_real64',
    'parameters%total_balance_tolerance = 1.0e-12_real64',
    'parameters%head_abs_tolerance = 1.0e-12_real64',
    'parameters%head_rel_tolerance = 1.0e-12_real64',
    'parameters%ponding_tolerance = 1.0e-12_real64',
    'parameters%root_extraction_active = .false.',
    'parameters%macropore_active = .false.',
    'forcing%bottom_head = -100.0_real64',
    'forcing%drainage_flux_by_level(1,i) = 1.0e-5_real64*real(i,real64)',
    'forcing%drainage_flux_by_level(2,i) = -2.0e-6_real64*real(i+1,real64)',
    'forcing%subsurface_irrigation_source(i) = forcing%drainage_flux_by_level(1,i) + &',
    'config%transaction%temporal_tolerance = 0.0_real64',
    'config%transaction%mass_tolerance = hard_mass_gate',
    'config%transaction%retry_scale = 0.5_real64',
    'config%transaction%max_retries = 2',
]
for token in required:
    if token not in text:
        raise SystemExit(f'FPE03_FVQ24 stimulus/runtime lock missing after transform: {token}')

out.parent.mkdir(parents=True, exist_ok=True)
out.write_text(text, encoding='utf-8')
print(f'FPE03_FVQ24_RUNTIME_PROBE_GENERATED={out}')
print('FPE03_FVQ24_CASES=5')
print('FPE03_FVQ24_SCIENTIFIC_STIMULUS_CHANGED=NO')
print('FPE03_FVQ24_TRANSACTION_POLICY_CHANGED=NO')
