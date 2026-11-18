"""Explicit direct-soil input successor, delegating all inactive routes literally."""
from dataclasses import replace
from pathlib import Path
import hashlib
import age_irrigation_source as surface

ROOT=surface.ROOT
POLICY='original-fixed-direct-soil-age-transport-then-input-v1'
MAGICS={b'S5AI0002':b'S5DI0002',b'S5AI0003':b'S5DI0003',b'S5AI0004':b'S5DI0004',b'S5AI0005':b'S5DI0005',b'S5AIO001':b'S5DIO001',b'S5AIH001':b'S5DIH001'}


def enabled(project):return getattr(project,'age_direct_soil_source',False)
def shadow(project):return replace(project,age_irrigation_source=True,age_direct_soil_source=False)


def selection(project):
    if not enabled(project):return surface.selection(project)
    if project.age_irrigation_source:raise ValueError('Select one explicit incoming-age source policy')
    surface.selection(shadow(project))
    return dict(policy=POLICY,irrigation_types=[0,1,2],units='days',source='actual original current CIRR and compartment qssdi',native_static_parameters_preserved=True,subsurface=True,source_order='literal transport then direct input each microstep')


def magic(project):return MAGICS[surface.magic(shadow(project))] if enabled(project) else surface.magic(project)


def metadata(project):
    if not enabled(project):return surface.metadata(project)
    sha=lambda p:hashlib.sha256(p.read_bytes().replace(b'\r\n',b'\n')).hexdigest()
    return dict(**selection(project),native_codec=magic(project).decode(),base_native_codec=surface.base_magic(project).decode(),surface_source=surface.metadata(shadow(project)),
                source_sha256=sha(Path(__file__)),ledger_sha256=sha(Path(__file__).with_name('direct_soil_age.py')),
                state_sha256=sha(Path(__file__).with_name('direct_soil_age_state.f90')),
                provider_sha256=sha(ROOT/'src/process/mod_direct_soil_age_substep.f90'),
                age_state_fields=12,direct_state_bytes=24,physical_age_providers_changed=False,
                age_tolerance='8192*epsilon*max(1,actual_age_inventory,actual_age_fluxes)')


def output_metadata(project):
    if not enabled(project):return surface.output_metadata(project)
    result=surface.output_metadata(shadow(project))
    return None if result is None else dict(result,native_codec=magic(project).decode(),irrigation_source=metadata(project))


def age_identity(original,project):
    if not enabled(project):return surface.age_identity(original,project)
    result=dict(surface.age_identity(original,shadow(project)),native_codec=magic(project).decode(),irrigation_source=metadata(project),age_state_fields=12)
    if project.original_output:result['original_output']=output_metadata(project)
    return result


def fixed_metadata(project):return metadata(project) if enabled(project) else surface.fixed_metadata(project)


def render_irrigation(source,project=None):
    result=surface.render_irrigation(source)
    if project is None or not enabled(project):return result
    anchor="         if(any(irtype(1:ifnd)==2))error stop 'Fixed current-age source supports sprinkler and surface irrigation only'"
    if result.count(anchor)!=1:raise ValueError('Changed surface source reader preimage')
    result=result.replace(anchor,"         if(any(irtype(1:ifnd)<0).or.any(irtype(1:ifnd)>2))error stop 'Invalid direct soil age irrigation type'",1)
    anchor='                  qssdi(nod_ssdi(1):nod_ssdi(2)) = irrate(nirri)'
    if result.count(anchor)!=1:raise ValueError('Changed original fixed direct source producer')
    return result.replace(anchor,'                  if(swsolu==2)cirr=irconc(nirri)\n'+anchor,1)


def change(source,old,new):
    if source.count(old)!=1:raise ValueError('Changed direct soil source preimage: '+old[:100])
    return source.replace(old,new,1)


def apply_build(output,project,patched):
    if not enabled(project):return surface.apply_build(output,project,patched)
    patched=surface.apply_build(output,shadow(project),patched)
    path=output/'solute.f90';source=path.read_text(encoding='cp1252')
    anchor='submodule (MOD_Solute) MOD_calc_AgeTracer'
    source=change(source,anchor,anchor+'\n      use hybrid_direct_soil_age_state,only:direct_soil_age_input_total\n      use mod_direct_soil_age_substep,only:direct_soil_age_receipt_t,advance_direct_soil_age_substep,DIRECT_AGE_OK')
    source=change(source,'      use MOD_irrigation,only: nird, cirr','      use MOD_irrigation,only: nird, cirr,qssdi')
    source=change(source,'      type(b111_age_tracer_substep_receipt_t)::age_receipt','      type(b111_age_tracer_substep_receipt_t)::age_receipt\n      type(direct_soil_age_receipt_t)::direct_receipt')
    source=change(source,'         age_cumulative=0d0','         age_cumulative=0d0\n         direct_soil_age_input_total=0d0')
    anchor='            call advance_b111_age_tracer_substep(age_before,age_forcing,age_candidate,age_receipt)'
    source=change(source,anchor,"""            call advance_direct_soil_age_substep(age_before,age_forcing,qssdi(1:numnod),cirr,age_candidate,direct_receipt)
            if(direct_receipt%status/=DIRECT_AGE_OK)error stop 'Direct soil age source or transport refused'
            age_receipt=direct_receipt%transport
            direct_soil_age_input_total=direct_soil_age_input_total+direct_receipt%total_direct_input_cm_day""")
    path.write_text(source,encoding='cp1252')
    # Preserve the original eleven-value observer/native prefix. Only this
    # explicit protocol appends the independently checkpointed source amount.
    for name in ('swap_main.f90','swap_csv_output.f90'):
        path=output/name;source=path.read_text(encoding='cp1252')
        anchor='use MOD_solute,only:hybrid_age_observe' if name=='swap_main.f90' else 'use MOD_solute,only:hybrid_age_observe'
        # Import statements are generated by two literal accepted adapters.
        lines=[line for line in source.splitlines() if 'use MOD_solute' in line and 'hybrid_age_observe' in line]
        if len(lines)!=1:raise ValueError('Changed actual age protocol imports')
        source=change(source,lines[0],lines[0]+'\nuse hybrid_direct_soil_age_state,only:direct_soil_age_input_total')
        lines=[line for line in source.splitlines() if "'HYBRID_AGE_CUMULATIVE'" in line]
        if len(lines)!=1:raise ValueError('Changed actual age observation protocol')
        line=lines[0];new=line.replace('11(1x,es25.17e3)','12(1x,es25.17e3)')+',direct_soil_age_input_total'
        if line==new:raise ValueError('Missing age protocol shape')
        source=change(source,line,new);path.write_text(source,encoding='cp1252')
    path=output/'macropore.f90';source=path.read_text(encoding='cp1252')
    old=surface.magic(shadow(project)).decode();new=magic(project).decode()
    if source.count("'"+old+"'")!=2:raise ValueError('Changed actual surface native codec')
    source=source.replace("'"+old+"'","'"+new+"'")
    anchor='      use hybrid_age_irrigation_source_domain,only:hybrid_age_irrigation_source_checkpoint'
    source=change(source,anchor,anchor+'\n      use hybrid_direct_soil_age_state,only:direct_soil_age_checkpoint')
    source=change(source,'        read(unit,iostat=ios) trailing','        call direct_soil_age_checkpoint(unit,.true.)\n        read(unit,iostat=ios) trailing')
    source=change(source,'      end if\n      close(unit)','        call direct_soil_age_checkpoint(unit,.false.)\n      end if\n      close(unit)');path.write_text(source,encoding='cp1252')
    for name,path in [('mod_direct_soil_age_substep',ROOT/'src/process/mod_direct_soil_age_substep.f90'),('direct_soil_age_state',Path(__file__).with_name('direct_soil_age_state.f90'))]:(output/(name+'.f90')).write_bytes(path.read_bytes())
    # State has only original-grid imports and can compile first. The composed
    # provider follows its literal B111 provider and precedes original solute.
    patched.insert(0,'direct_soil_age_state');patched.insert(patched.index('solute'),'mod_direct_soil_age_substep')
    return patched


def validate_age(values,project):
    from direct_soil_age import validate
    from conserved_original_age import validate as old
    return validate(values) if enabled(project) else old(values)


def age_ledger(previous,current,project):
    from direct_soil_age import ledger
    from conserved_original_age import ledger as old
    return ledger(previous,current) if enabled(project) else old(previous,current)
