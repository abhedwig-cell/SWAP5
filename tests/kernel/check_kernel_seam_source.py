from pathlib import Path
import re

SOURCE = Path('src/kernel/swap5_kernel_seam.f90')
text = SOURCE.read_text(encoding='utf-8')
code = '\n'.join(line.split('!', 1)[0] for line in text.splitlines()).lower()

required = {
    'deferred implementation marker': "'deferred_no_kernel_implementation'",
    'single kernel type': 'type, abstract, public :: swap5_kernel_t',
    'generic interval': 'type, public :: swap5_interval_t',
    'parameters input-only': 'class(swap5_parameters_t), intent(in) :: parameters',
    'committed state input-only': 'class(swap5_committed_state_t), intent(in) :: committed_state',
    'forcing input-only': 'class(swap5_forcing_t), intent(in) :: forcing',
    'numerics input-only': 'class(swap5_numerical_config_t), intent(in) :: numerics',
    'worker scratch mutable': 'class(swap5_worker_scratch_t), intent(inout) :: scratch',
    'result caller-owned': 'class(swap5_trial_result_t), intent(inout) :: result',
    'deferred trial': 'procedure(swap5_kernel_trial_ifc), deferred, nopass, public :: trial',
}
missing = [name for name, token in required.items() if token not in code]
if missing:
    raise SystemExit('missing required seam properties: ' + ', '.join(missing))

forbidden_patterns = {
    'file open': r'\bopen\s*\(',
    'file read': r'\bread\s*\(',
    'file write': r'\bwrite\s*\(',
    'file close': r'\bclose\s*\(',
    'file keyword': r'\bfile\s*=',
    'unit keyword': r'\bunit\s*=',
    'hidden saved state': r'(^|\n)\s*[^!\n]*\bsave\b',
    'MODFLOW composition': r'\bmodflow\b',
    'calendar clock': r'\bdate_and_time\b',
}
violations = [name for name, pattern in forbidden_patterns.items() if re.search(pattern, code)]
if violations:
    raise SystemExit('forbidden kernel-seam dependency: ' + ', '.join(violations))

uses = [line.strip() for line in code.splitlines() if line.strip().startswith('use')]
if uses != ['use, intrinsic :: iso_fortran_env, only : real64']:
    raise SystemExit(f'unexpected module dependencies: {uses!r}')

print('KRS-1_KERNEL_SEAM_SOURCE_GUARD PASS')
