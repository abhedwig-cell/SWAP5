"""Experimental paired-vapor diagnostic composition; not publicly qualified.

Existing numerical equations and physical stores remain unchanged. This saved
prototype is reconciled with candidate7e solely for a bounded causal probe.
"""
import hashlib, json, re, struct
from pathlib import Path

SHA = lambda raw: hashlib.sha256(raw).hexdigest()
VERSION = 7
POLICY = 'existing-original-active-vapor-explicit-paired9-daily-v1'


def selected_context(selected):
    if (selected.get('SWBOTB') != 9 or selected.get('SWSNOW') != 0
            or selected.get('SWDRA') not in (0, 1)):
        return None
    return dict(bottom=9, drainage=selected['SWDRA'], native_domain_version=VERSION)


def selection(directory, original_output=True):
    from prescribed_head_flux_boundary import selection as paired_selection
    paired = paired_selection(directory, original_output, vapor=True)
    if paired is None:
        return None
    from experimental_project import switches
    from hydraulic_vapor import selection as active_selection
    selected = switches((Path(directory)/'swap.swp').read_text(encoding='cp1252'))
    active = active_selection(directory, selected, original_output)
    if active is None:
        return None
    return dict(paired, vapor_policy=POLICY, native_domain_version=VERSION,
                active_original_vapor_layers=active['active_layers'])


def enabled(project):
    return bool(project.input_directory and not project.macro and not project.age
                and project.time_step_policy == 'original-adaptive-day-seed-v1'
                and selection(project.input_directory, project.original_output) is not None)


def native_source(original):
    text = original.decode('cp1252').replace('\r\n', '\n')
    if SHA(text.encode('cp1252')) != 'a181df32399d64a4052f4e8d3d11133bb7388fd890c8f0e9139594bbc29877b0':
        raise ValueError('Changed complete original vapor native3 owner')
    edits = [('.or.swdra/=1.or.swbotb/=6)', '.or.(swdra/=0.and.swdra/=1).or.swbotb/=9)'),
             ('expected(1:14)=[3,', 'expected(1:14)=[7,')]
    for old, new in edits:
        if text.count(old) != 1:
            raise ValueError('Changed exact paired vapor domain seam')
        text = text.replace(old, new, 1)
    return text.encode('cp1252')


def cde_offset(aux, nodes, project=None):
    if aux[:8] != b'S5HPC007' or len(aux) < 104:
        raise ValueError('Incomplete CDE paired vapor domain')
    domain = struct.unpack_from('<14i', aux, 48)
    layers = domain[2]
    if (not 1 <= layers <= 1000 or domain[:12] != (7,nodes,layers,0,1,0,0,0,0,0,1,2)
            or domain[12] not in (0,1) or domain[13] != 9):
        raise ValueError('Foreign CDE paired vapor domain')
    count = 14+2*layers
    size = 4*count
    if len(aux) < 48+2*size:
        raise ValueError('Incomplete CDE paired vapor witness')
    header = struct.unpack_from('<'+str(count)+'i', aux, 48)
    if header != struct.unpack_from('<'+str(count)+'i', aux, 48+size):
        raise ValueError('Foreign CDE paired vapor witness')
    models, flags = header[14:14+layers], header[14+layers:]
    if (any(m not in range(1,12) for m in models) or any(f not in (0,1) for f in flags)
            or not any(flags) or any(f and m < 8 for m,f in zip(models,flags))):
        raise ValueError('Foreign CDE paired vapor layers')
    if project is not None:
        from hydraulic_vapor import describe
        active = describe(project)
        from experimental_project import switches
        context = selected_context(switches((Path(project.input_directory)/'swap.swp').read_text(encoding='cp1252')))
        if (active is None or context is None or not enabled(project)
                or domain[12:] != (context['drainage'],context['bottom'])
                or tuple(active['models']) != models
                or tuple(f if m >= 8 else 0 for m,f in zip(active['models'],active['SWVAPOR'])) != flags):
            raise ValueError('CDE paired vapor differs from actual project')
    return 48+2*size


def metadata(project):
    if not enabled(project):
        return None
    from experimental_project import switches
    selected = switches((Path(project.input_directory)/'swap.swp').read_text(encoding='cp1252'))
    return dict(policy=POLICY, **selected_context(selected),
                source_sha256=SHA(Path(__file__).read_bytes().replace(b'\r\n',b'\n')),
                physical_equations_changed=False, new_physical_water_store=False,
                original_Kelvin_sign_correction_unchanged=True,
                all_actual_node_storage_included=True,
                external_flux_owner='literal original BoundBottom QBOT9; existing paired9 projected_water_residual',
                internal_NN_gradient_substituted_for_external_flux=False,
                old_native_domains_3_4_5_6_unchanged=True,
                fixed_absolute_water_limit_cm=1e-10)


def diagnostic_build(output, project, patched):
    """Bounded IO-only trial witness for this unqualified diagnostic route."""
    if not enabled(project):
        return patched
    path=Path(output)/'headcalc.f90'
    before=path.read_text(encoding='cp1252')
    marker='PAIRED_VAPOR_THERMAL02_TRIAL_WITNESS'
    if marker in before:
        raise ValueError('Repeated diagnostic instrumentation')
    use_anchor='   ! input\n'
    uses=('   use iso_fortran_env, only: paired_debug_output=>output_unit\n'
          '   use MOD_SoilTemperature, only: paired_debug_tsoil=>tsoil\n')
    declaration='   integer, save :: paired_debug_count=0\n'
    implicit='   implicit none\n'
    guard='         if (abs(budget_total+budget_step)>1d-10*(t1900-budget_start+dt)) flnonconv=.true.'
    witness=('         if(paired_debug_count<120)then\n'
             '            paired_debug_count=paired_debug_count+1\n'
             "            write(paired_debug_output,'(a,3(1x,i0),1x,l1,*(1x,es25.17e3))') &\n"
             "              'PAIRED_VAPOR_THERMAL02_TRIAL_WITNESS',paired_debug_count,itry,numbit,flnonconv, &\n"
             '              t1900,dt,budget_start,budget_total,budget_step,h(numnod),hm1(numnod), &\n'
             '              theta(numnod),thetm1(numnod),paired_debug_tsoil(numnod),qbot,qtop,pond,pondm1, &\n'
             '              maxval(abs(F(1:NN)))\n'
             '            flush(paired_debug_output)\n'
             '         end if\n')
    if any(before.count(anchor)!=1 for anchor in (use_anchor,implicit,guard)):
        raise ValueError('Foreign exact HeadCalc diagnostic seam')
    after=before.replace(use_anchor,uses+use_anchor,1).replace(implicit,implicit+declaration,1).replace(guard,witness+guard,1)
    inverse=after.replace(uses,'',1).replace(declaration,'',1).replace(witness,'',1)
    if inverse!=before or after.count(guard)!=1:
        raise ValueError('Diagnostic changed original numerical body')
    path.write_text(after,encoding='cp1252')
    if 'headcalc' not in patched:patched.append('headcalc')
    record=dict(status='UNQUALIFIED_PAIRED_VAPOR_BOUNDED_IO_ONLY_DIAGNOSTIC',maximum_witness_rows=120,
                before_lf_sha256=SHA(before.encode('cp1252')),after_lf_sha256=SHA(after.encode('cp1252')),
                literal_mass_guard=guard,physical_equations_changed=False,physical_state_or_flux_corrected=False,
                acceptance_threshold_changed=False,accepted_native_state_changed=False,
                transient_process_debug_counter_added=True,debug_counter_checkpointed=False,
                source_inverse_exact=True,canonical_admission=False)
    (Path(output)/'PAIRED_VAPOR_THERMAL02_DIAGNOSTIC_BUILD_V1.json').write_text(json.dumps(record,indent=2)+'\n')
    return patched
