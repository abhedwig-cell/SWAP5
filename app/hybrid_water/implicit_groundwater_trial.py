"""Literal original daily receipt projection for implicit groundwater trials."""
from pathlib import Path
import hashlib
import age_groundwater_output as original

POLICY='original-implicit-groundwater-independent-daily-trial-receipt-v1'
FUNCTION='hybrid_implicit_groundwater_trial'


def enabled(project):
    from snow_water_groundwater import selection as snow_selection
    if snow_selection(project) is not None:return False
    if not project.input_directory or project.macro or project.age or not project.original_output:return False
    from experimental_project import inspect
    report=inspect(project.input_directory)
    if report['boundary']['SWBOTB']!=1:return False
    if report['selectors']['SWSNOW']==1:
        from cde_clock_output import active_selection
        selected=active_selection(project)
        # The existing Snow clock installs the actual soil/pond projection,
        # including net rain, melt and the actual groundwater candidate once.
        # The no-Snow whole-frame clone is a different control volume.
        if selected is not None and selected.get('groundwater_snow_cde_output'):
            return False
    if report['selectors']['SWKIMPL']==1:return True
    from implicit_groundwater_state import enabled as water_state
    return water_state(project)


def metadata(project):
    if not enabled(project):return None
    sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
    root=Path(__file__).resolve().parents[2]
    from experimental_project import inspect
    policy=POLICY if inspect(project.input_directory)['selectors']['SWKIMPL'] else 'original-explicit-groundwater-independent-daily-trial-receipt-v1'
    result=dict(policy=policy,source_sha256=sha(Path(__file__)),original_projection_owner_sha256=sha(Path(original.__file__)),receipt_provider_sha256=sha(root/'src/process/mod_original_output_receipt.f90'),reaction_provider_sha256=sha(root/'src/process/mod_prescribed_groundwater_reaction.f90'),original_integral_sha256=original.regular.INTEGRAL_SHA,original_watstor_sha256=original.clock.WATSTOR_SHA,guard_cm=1e-10,ownership='read-only original daily receipt clone before Integral/Fluxes; no accepted state assignment')
    from implicit_snow_interval import selected as snow_interval
    if snow_interval(project):
        result.update(snow_interval_composition_sha256=sha(Path(__file__).with_name('implicit_snow_interval.py')),
            snow_soil_owner_sha256=sha(Path(__file__).with_name('thermal_output_clock.py')),
            snow_groundwater_owner_sha256=sha(Path(__file__).with_name('groundwater_snow_cde.py')),
            control_volume='existing actual soil/pond with net rain/melt and actual groundwater delta')
    return result


def apply_build(output,donor_build,project,patched):
    from implicit_snow_root_carry import apply_build as snow_root_build
    patched=snow_root_build(output,project,patched)
    if not enabled(project):return patched
    from implicit_snow_interval import apply_build as snow_interval_build
    patched=snow_interval_build(output,donor_build,project,patched)
    source=(donor_build/'swap-selected/integral.f90').read_text(encoding='cp1252')
    stock=(donor_build/'swap-selected/watstor.f90').read_text(encoding='cp1252')
    trial=original.trial_source(source,stock).replace('hybrid_groundwater_age_trial',FUNCTION).replace('Foreign original AGE groundwater trial domain','Foreign implicit groundwater trial domain')
    path=output/'integral.f90';text=path.read_text(encoding='cp1252');anchor='end module MOD_integral';assert text.count(anchor)==1
    from implicit_snow_interval import selected as snow_interval
    selected=snow_interval(project)
    if selected is not None:
        from implicit_snow_interval import trial_source as snow_trial
        expected=snow_trial(source,stock,selected)
        if text.count(expected)!=1:raise ValueError('Changed actual implicit Snow interval groundwater trial')
    else:path.write_text(text.replace(anchor,trial+'\n'+anchor,1),encoding='cp1252')
    path=output/'headcalc.f90';text=path.read_text(encoding='cp1252');anchor='   use hybrid_step_budget, only: projected_water_residual';assert text.count(anchor)==1
    text=text.replace(anchor,'   use MOD_integral,only:'+FUNCTION+'\n'+anchor,1)
    anchor='         if (abs(budget_total+budget_step)>1d-10*(t1900-budget_start+dt)) flnonconv=.true.';assert text.count(anchor)==1
    text=text.replace(anchor,anchor+'\n         if(abs('+FUNCTION+'(groundwater_bottom,groundwater_delta))>1d-10)flnonconv=.true.',1)
    path.write_text(text,encoding='cp1252')
    return patched
