"""Read-only complete HeadCalc identity for the qualified ordinary source forms.

These are actual B96 numeric compiler postimages, shared across O0/O2. The
project and existing native/output metadata independently select the form.
No field in the caller's mutable donor-generated hash inventory authorizes it.
"""
import hashlib
from pathlib import Path

HEADS = {
    'groundwater': 'a13d2e813001ff1d366cca902c8384a4347e00627a4996fb5ed5f7a612fde4f9',
    'cde': '8564da21cbc664908d9f0faa78e2a32da3422e72b16d9d23a1cda8ef12a97d08',
    'cde-step': '0d5c03b9de4748cdff7b734ead3d4b2147e65464410cdd9f9e22ffda1097249a',
    'water-step': 'f20a1f5e12c3d206d962f49491398b160328bc992fe60594750812b8a40898c3',
    'water': '1ba937ea6db926f0a91d985c9e9db386ae8322e3ed253b81ff6bf82566c73150',
}


def validate(bundle, project, identity):
    if not identity.get('ordinary_implicit_pond_switch'):
        return
    from experimental_project import inspect
    report = inspect(project.input_directory)
    if report['boundary']['SWBOTB'] == 1:
        if identity['original_output'].get('groundwater_cde_clock'):
            from groundwater_cde_clock_source_guard import validate as validate_groundwater_clock
            return validate_groundwater_clock(bundle,identity)
        form = 'groundwater'
    else:
        step = identity['original_output'].get('flprintdt')
        if type(step) is not bool:
            raise ValueError('Foreign ordinary implicit original output source form')
        form = ('cde' if project.solute else 'water')+('-step' if step else '')
    if project.solute and identity['original_output'].get('native_codec') == 'S5IOC001':
        # The original dense daily CDE route adds private solute output state,
        # but its HeadCalc has the ordinary water trial body, not a subdaily
        # CDE output-clock trial. Bind that choice to actual original inputs.
        from original_output import selection as dense_original_selection
        dense=dense_original_selection(project)
        if (dense['nprintday'] != 1 or dense['flprintdt'] or
                dense['requested_period'] != 1):
            raise ValueError('Foreign actual ordinary dense CDE source form')
        form='water'
    if project.solute:
        # Ordinary interval output carries private CDE state without adding
        # the distinct subdaily hydraulic trial. Select the existing complete
        # water-trial parent from actual inputs, never a mutable source hash.
        from cde_interval_output import active_selection as interval_selection
        from cde_clock_output import active_selection as clock_selection
        interval=interval_selection(project)
        if interval is not None and clock_selection(project) is None:
            if identity['original_output'].get('cde_interval_output') is not True:
                raise ValueError('Foreign actual ordinary CDE interval source form')
            form='water'
    source = (Path(bundle)/'headcalc.f90').read_bytes().replace(b'\r\n', b'\n')
    if not project.solute:
        from perstep_output_domain import active_selection as perstep_selection
        perstep=perstep_selection(project)
        if perstep is not None and not perstep['swsnow']:
            if identity['original_output'].get('perstep_domain') is not True:
                raise ValueError('Foreign actual ordinary per-step source form')
            from initial_profile_calendar import perstep_water_parent_inverse
            source=perstep_water_parent_inverse(source.decode('cp1252')).encode('cp1252')
            form='water'
    if report['boundary']['SWBOTB'] == 5:
        # Invert only the literal admitted prescribed-head receipt projection.
        # The whole numerical body must still equal the qualified air-boundary
        # parent below; no generated/candidate hash authorizes a provider.
        from groundwater_snow_retry import inverse
        from lower_boundary_receipt import render_headcalc
        template=('logical                          :: flboth, flok\n'
                  '         budget_step=projected_water_residual()\n'
                  '            budget_step = projected_water_residual()\n')
        source=render_headcalc(inverse(source.decode('cp1252'),
            lambda text:render_headcalc(text,5),template),8).encode('cp1252')
    if project.solute and form=='cde-step':
        # The retained B96 cde-step hash is the actual bottom5 receipt form,
        # not another soil/clock equation. Above, that literal boundary receipt
        # has been inverted to bottom8. Compare the COMPLETE canonical body
        # with the retained B96 cde parent (including all clock trial terms).
        from cde_clock_output import active_selection as clock_selection
        clock=clock_selection(project)
        if clock is not None and clock['flprintdt']:
            form='cde'
    if report['boundary']['SWBOTB']==6:
        from closed_zero_boundary import input_domain as closed_domain
        text=(Path(project.input_directory)/'swap.swp').read_text(encoding='cp1252')
        if closed_domain(text,report['selectors'],project.original_output):
            # The newly composed ordinary closed6 dense domains all retain
            # the exact qualified water HeadCalc. Reconstruct only the known
            # independent bottom8 receipt before comparing the WHOLE body.
            from lower_boundary_receipt import render_headcalc
            source=render_headcalc(source.decode('cp1252'),8).encode('cp1252')
            form='water'
            from cde_clock_output import active_selection as actual_clock_selection
            clock=actual_clock_selection(project) if project.solute else None
            if clock is not None and clock.get('closed_implicit_calendar'):
                # Invert only the literal original zero-bottom trial receipt;
                # the entire remaining HeadCalc must equal its qualified parent.
                from analytical_cde_calendar import HEAD_GUARD,head_guard
                actual=head_guard(6).encode('cp1252')
                if source.count(actual)!=1:raise ValueError('Foreign complete closed implicit CDE clock trial receipt')
                source=source.replace(actual,HEAD_GUARD.encode('cp1252'),1)
                form='cde'
    if hashlib.sha256(source).hexdigest() != HEADS[form]:
        raise ValueError('Foreign actual ordinary implicit coupled HeadCalc provider')
