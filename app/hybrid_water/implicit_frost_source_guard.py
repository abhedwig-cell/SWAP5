"""Read-only complete closure to qualified implicit soil and explicit Frost parents."""
import hashlib
from pathlib import Path

# Actual complete explicit Frost TimeControl at runtime6e, present in the
# immutable Windows science archives. This is a parent, never a candidate SHA.
EXPLICIT_FROST_TIME = '14403e7f9b0a9434388b62fb00c4ef672ac004f7d54ab3c8fbbb8fdd5364b472'
TERMINAL_PARTS = ('   use hybrid_terminal_water_receipt, only: terminal_water_residual\n',
    '   use variables, only: tcum\n',
    '\n         if(tcum+dt>=1d0-1d-8)then\n'
    '            if(abs(terminal_water_residual())>1d-10)flnonconv=.true.\n'
    '         end if')


def validate_source(bundle, project, identity, reference):
    from experimental_project import inspect
    from implicit_frost_composition import input_domain, codec
    report = inspect(project.input_directory); output = identity['original_output']
    if (not input_domain(report['selectors'], report['boundary'], project.original_output)
            or (identity.get('implicit_conductivity') or {}).get('implicit_frost_composition') is not True
            or output.get('thermal_output') is not True or output.get('swfrost') != 1
            or output.get('native_codec') != codec(project).decode()):
        raise ValueError('Foreign actual implicit Frost source domain')
    bundle = Path(bundle); folder = Path(__file__).parent
    from implicit_frost_surface_conductivity import restore
    source = restore((bundle/'headcalc.f90').read_text(encoding='cp1252'))
    for part in TERMINAL_PARTS:
        if source.count(part) != 1:
            raise ValueError('Foreign actual implicit Frost terminal water owner')
        source = source.replace(part, '', 1)
    # Compare the whole actual soil body to its already qualified ordinary
    # implicit parent. Only the known boundary receipt projection is restored.
    from lower_boundary_receipt import render_headcalc
    from ordinary_pond_source_guard import HEADS
    if hashlib.sha256(render_headcalc(source, 8).encode('cp1252')).hexdigest() != HEADS['water']:
        raise ValueError('Foreign complete actual implicit Frost HeadCalc parent')

    from groundwater_snow_retry import inverse, TIME_TEMPLATE
    from implicit_conductivity_retry import time_source
    from implicit_pond_event import time_source as event
    source = inverse((bundle/'timecontrol.f90').read_text(encoding='cp1252'),
                     lambda text: event(time_source(text)), TIME_TEMPLATE)
    if hashlib.sha256(source.encode('cp1252')).hexdigest() != EXPLICIT_FROST_TIME:
        raise ValueError('Foreign complete actual implicit Frost TimeControl parent')
    from ordinary_implicit_pond_switch import actual_source
    actual_source((bundle/'boundtop.f90').read_bytes(), True)
    for name in ('implicit_pond_event_state.f90', 'implicit_pond_availability.f90',
                 'original_output_thermal_domain.f90', 'terminal_water_receipt.f90'):
        expected=(folder/name).read_bytes().replace(b'\r\n', b'\n')
        if name=='terminal_water_receipt.f90':
            from frost_calendar_state import selection as calendar_selection
            if calendar_selection(project.input_directory,project.original_output) is not None:
                from frost_calendar_terminal_water import source as terminal_day_source
                expected=terminal_day_source().encode('cp1252')
        if (bundle/name).read_bytes().replace(b'\r\n', b'\n') != expected:
            raise ValueError('Foreign actual implicit Frost private provider: ' + name)
    from frost_reference import source as frost_source
    if (bundle/'frozencond.f90').read_bytes() != frost_source(
            (Path(reference)/'build/swap-selected/frozencond.f90').read_bytes()):
        raise ValueError('Foreign actual qualified Frost process source')
    body = (bundle/'macropore.f90').read_text(encoding='cp1252').split(
        '    subroutine hybrid_macro_checkpoint(', 1)[1].split('    end subroutine hybrid_macro_checkpoint', 1)[0]
    for part, count in (('use hybrid_implicit_pond_event_state,only:assert_no_implicit_pond_event', 1),
                        ('call assert_no_implicit_pond_event()', 1), ("'" + codec(project).decode() + "'", 2)):
        if body.count(part) != count:
            raise ValueError('Foreign actual implicit Frost native event/codec owner')
    from implicit_frost_root_state import metadata as root_metadata, validate_source as validate_root
    if identity['frost_drainage_composition'].get('root_diagnostic_carry')!=root_metadata(project):
        raise ValueError('Foreign implicit Frost root diagnostic state policy')
    validate_root(bundle, project, reference)
