#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
p = ROOT / 'tests/fsi/run_fsi07_gate.sh'
s = p.read_text()

replacements = [
    (
        "grep -Eq '^subroutine[[:space:]]+headcalc\\(worker,[[:space:]]*fsi_workspace,[[:space:]]*history,[[:space:]]*state_binding\\)' \"$HEADCALC\"",
        "grep -Fq 'subroutine headcalc(worker, fsi_workspace, history, state_binding, evaluation_context, boundary_conditions)' \"$HEADCALC\"",
    ),
    (
        "assert contract['provider_boundary']['real_parallel_headcalc_admission_expected_after_fsi07'] is False",
        "assert contract['provider_boundary']['real_headcalc_parallel_reentrancy_qualified'] is True\nassert contract['provider_boundary']['parallel_reference_backend_admitted'] is False\nassert contract['provider_boundary']['full_swap_parallel_admitted'] is False",
    ),
    (
        "# Full real HeadCalc parallel admission still fails closed. Mutable whole-solve\n# state is isolated now, but direct legacy process/provider calls remain shared.\ngrep -Fq 'call boundtop_state_bridge(2)' \"$HEADCALC\"\ngrep -Fq 'use MOD_MvG' \"$HEADCALC\"\ngrep -Fq 'use MOD_drain' \"$HEADCALC\"\ngrep -Fq 'use MOD_irrigation' \"$HEADCALC\"\necho 'F-SI07_REAL_PARALLEL_ADMISSION BLOCKED_LEGACY_PROVIDER_GLOBALS'\necho 'F-SI07_GATE PASS'",
        "# The real common reference route is qualified for the exact admitted fixture.\n# General heterogeneous-provider backend admission remains fail closed because\n# constitutive and source/sink process providers are still legacy shared inputs.\ngrep -Fq 'call boundtop_state_bridge(2)' \"$HEADCALC\"\ngrep -Fq 'use MOD_MvG' \"$HEADCALC\"\ngrep -Fq 'use MOD_drain' \"$HEADCALC\"\ngrep -Fq 'use MOD_irrigation' \"$HEADCALC\"\n\nbash \"$ROOT/tests/fsi/run_fsi07_common_route_gate.sh\"\nbash \"$ROOT/tests/fsi/run_fsi07_provider_concurrency_gate.sh\"\n\necho 'F-SI07_REAL_HEADCALC_PARALLEL_REENTRANCY QUALIFIED_ADMITTED_FIXTURE'\necho 'F-SI07_PARALLEL_REFERENCE_BACKEND BLOCKED_HETEROGENEOUS_LEGACY_PROVIDERS'\necho 'F-SI07_FINAL_GATE PASS'",
    ),
]

for old, new in replacements:
    count = s.count(old)
    if count != 1:
        raise SystemExit(f'F-SI07 final gate materializer: expected one match, got {count}: {old[:80]}')
    s = s.replace(old, new, 1)

p.write_text(s)
print('F-SI07_FINAL_QUALIFICATION_GATE_MATERIALIZED')
