"""Explicit additional Newton polishing for corrected NoHeat RIA primary trials."""
import hashlib
import json
from pathlib import Path

POLICY = 'ria12-strict-water-1e-12-polish-v1'


def selection(directory, original_output):
    from original_ria12_corrected import selection as corrected
    selected = corrected(directory, original_output)
    if selected is None or selected['bottom'] != 6 or selected['drainage'] != 1:
        raise ValueError('RIA water polishing requires corrected NoHeat primary1/6 water/CDE original output')
    return selected


def require_project(project):
    if project.water_polish_policy != POLICY:
        return None
    if project.macro or project.age or project.time_step_policy != 'original-adaptive-day-seed-v1':
        raise ValueError('RIA water polishing requires original adaptive no-macro water/CDE')
    return selection(project.input_directory, project.original_output)


def apply_build(output, donor_build, project, patched):
    if require_project(project) is None:
        return patched
    path = Path(output) / 'headcalc.f90'
    source = path.read_text(encoding='cp1252')
    original = '         if (abs(budget_total+budget_step)>1d-10*(t1900-budget_start+dt)) flnonconv=.true.'
    additional = '         if (abs(budget_total+budget_step)>1d-12) flnonconv=.true.'
    if source.count(original) != 1 or additional in source:
        raise ValueError('Foreign original NoHeat RIA Newton water-budget owner')
    actual = source.replace(original, original + '\n' + additional, 1)
    path.write_text(actual, encoding='cp1252')
    if 'headcalc' not in patched:
        patched.append('headcalc')
    record = dict(policy=POLICY, original_scientific_day_and_global_water_limit_cm='1e-10',
                  additional_local_Newton_polishing_target_cm_per_day='1e-12',
                  original_guard_literal_retained=original, additional_guard_literal=additional,
                  before_lf_sha256=hashlib.sha256(source.replace('\r\n', '\n').encode('cp1252')).hexdigest(),
                  after_lf_sha256=hashlib.sha256(actual.replace('\r\n', '\n').encode('cp1252')).hexdigest(),
                  physical_equations_changed=False, inventories_or_fluxes_corrected=False,
                  native_state_layout_changed=False, automatic_fallback=False, canonical_admission=False)
    (Path(output) / 'RIA12_WATER_POLISH_BUILD_V1.json').write_text(json.dumps(record, indent=2) + '\n')
    return patched
