"""Run the existing gross pond restart witness with the selected matrix codec."""
from pathlib import Path

from matrix_logical_runtime import ROOT
from native_n_crc_runtime import run


def qualify(compiler, flags, objects, output, role, events):
    module = ROOT / 'src/runtime/mod_fmr_b111_pond_joint_application.f90'
    driver = ROOT / 'tests/nut-sol/test_pond_joint.f90'
    pond_object = output / 'gross-pond.o'
    if role == 'incumbent':
        run([compiler, *flags, '-J' + str(output), '-c', module, '-o', pond_object],
            output, events, 'gross-pond-module')
    assert pond_object.is_file()
    case = output / role
    original = driver.read_text()
    # Select the gross branch. The separate trace oracle uses a different
    # literal interface and is outside this restart continuation witness.
    start = original.index("  if(trim(mode)=='gross-resume')then")
    routines = original.index("\ncontains", start)
    trace = original.index('  subroutine verify_actual_trace(', routines)
    parameters = original.index('  subroutine parameters(', trace)
    projected = (original[:start].replace('  use b111_literal_oracle\n', '', 1)
                 + '  call verify_gross_dynamic()\n' + original[routines:trace]
                 + original[parameters:])
    source = case / 'gross_pond.f90'
    source.write_text(projected)
    executable = case / 'gross-pond.exe'
    response = executable.with_suffix('.args')
    args = [*flags, '-I' + str(output), str(source), *map(str, objects),
            str(pond_object), '-o', str(executable)]
    response.write_text('\n'.join('"' + arg.replace('\\', '/') + '"' for arg in args))
    run([compiler, '@' + str(response)], output, events, role + '-gross-pond-link')
    checkpoint = case / 'gross-checkpoint'
    for mode in ('gross-write', 'gross-resume'):
        measured = run([executable, mode, checkpoint, 'unused', 'wet'],
                       output, events, role + '-' + mode)
        assert b'MC_SOL01_GROSS_POSITIVE_RUNON_RUNOFF_JOINT_V2=PASS' in measured.stdout
    start = checkpoint.with_suffix('.gross').read_bytes()
    endpoint = checkpoint.with_suffix('.gross-next').read_bytes()
    assert start[:8] == endpoint[:8] == b'S5MJ0002'
    assert checkpoint.with_suffix('.gross-fresh').read_bytes() == endpoint
    return start, endpoint
