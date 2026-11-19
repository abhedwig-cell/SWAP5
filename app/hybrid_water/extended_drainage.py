"""Experimental original extended-drain transaction/native composition.

The first integrated development route uses existing daily compatibility
output. Scientific/public qualification is owned by the migration evidence.
"""
from pathlib import Path
import hashlib
import math
import re
import struct

POLICY = 'original-extended-drainage-atomic-state-v1'
MODULE = 'hybrid_extended_drainage_state'
TERMINAL_MODULE = 'hybrid_extended_drain_terminal'
MAGIC = b'S5EDR001'
TEMPLATE = Path(__file__).with_name('extended_drainage_state.f90')
SURFACE_SOURCE_LF_SHA256 = '734aac3c4f186775be36b169cf4d6e63332f07d6f69ee5ebfc6be3d7f958b0df'


def corrected_surfacewater_source(original):
    """Preserve actual positive water instead of the proved legacy dry loss."""
    if hashlib.sha256(original.encode('cp1252')).hexdigest() != SURFACE_SOURCE_LF_SHA256:
        raise ValueError('Changed original extended surfacewater provider')
    old='            if (swstmax < 1.0d-7) then'
    assert original.count(old)==1
    return original.replace(old,'            if (swstmax <= 0.0d0) then',1)


def surfacewater_source(original):
    text=corrected_surfacewater_source(original)
    edits=[
        ('      use MOD_grid,      only: numnod, dz\n',
         '      use '+MODULE+',only:extended_drain_surface_flux\n      use MOD_grid,      only: numnod, dz\n'),
        ('            real(8)              :: swsttara,rday,wsmax,vtair\n',
         '            real(8)              :: extended_supply\n            real(8)              :: swsttara,rday,wsmax,vtair\n'),
        ('\n            overfl = .FALSE.\n', '\n            overfl = .FALSE.\n            extended_supply=0d0\n'),
        ('\n              swst = 0.0d0\n','\n              extended_supply=wsmax\n              swst = 0.0d0\n'),
        ('\n              swst = swstmax\n','\n              extended_supply=wsmax\n              swst = swstmax\n'),
        ('\n                swst = swsttara\n','\n                extended_supply=(swsttara-swstmax)/dt\n                swst = swsttara\n'),
        ('      !        ponding in case of extended drainage may limit timestep\n',
         '            call extended_drain_surface_flux(extended_supply,wdis)\n\n      !        ponding in case of extended drainage may limit timestep\n')]
    for old,new in edits:
        assert text.count(old)==1,old
        text=text.replace(old,new,1)
    return text


def terminal_source():
    # Reuse the admitted no-snow complete original double receipt. Only the
    # selected drainage dispatch differs; no store or physical flux is changed.
    from weather_terminal_receipt import source, MODULE as previous
    text=source();assert text.count('swdra/=1')==1
    return text.replace(previous,TERMINAL_MODULE).replace('swdra/=1','swdra/=2').replace('WEATHER_TERMINAL_WATER','EXTENDED_DRAIN_TERMINAL_WATER')


def strict_trial_build(output, donor_build, patched):
    import implicit_conductivity_retry as retry
    path=output/'headcalc.f90';text=path.read_text(encoding='cp1252')
    old='   use hybrid_step_budget, only: projected_water_residual';assert text.count(old)==1
    text=text.replace(old,'   use '+TERMINAL_MODULE+',only:terminal_water_residual\n'+old,1)
    # The original extended rates are computed before HeadCalc and remain
    # fixed during Newton, just like the admitted basic/tabulated domain.
    # Reuse its literal existing linear PondRunoff tangent and original guard.
    text=text.replace(old,old+', linear_pond_top_jacobian\n   use variables, only: rsro, rsroexp, pondmx',1)
    old='   if (ftoph) dFdhM(1) = dFdhM(1) + kmean(1)/disnod(1)';assert text.count(old)==1
    text=text.replace(old,'''   if (ftoph) then
      if (flrunoff .and. rsroexp==1d0 .and. rsro>=1d-3) then
         dFdhM(1)=dFdhM(1)+linear_pond_top_jacobian(kmean(1)/disnod(1),dt,pond,pondmx,rsro)
      else
         dFdhM(1)=dFdhM(1)+kmean(1)/disnod(1)
      end if
   end if''',1)
    old='         if (abs(budget_total+budget_step)>1d-10*(t1900-budget_start+dt)) flnonconv=.true.'
    assert text.count(old)==1
    text=text.replace(old,old+'\n         if(abs(terminal_water_residual())>1d-10*(t1900-budget_start+dt))flnonconv=.true.',1)
    text=retry.headcalc_source(text);assert text.count('swmacro==0.and.swkimpl==1')==1
    path.write_text(text.replace('swmacro==0.and.swkimpl==1','swmacro==0.and.swkimpl==0'),encoding='cp1252')
    path=output/'timecontrol.f90';text=(path if path.exists() else donor_build/'swap-selected/timecontrol.f90').read_text(encoding='cp1252')
    text=retry.time_source(text);assert text.count('swmacro==0.and.swkimpl==1')==1
    text=text.replace('swmacro==0.and.swkimpl==1','swmacro==0.and.swkimpl==0').replace('implicit original','extended-drain original').replace('Implicit original','Extended-drain original').replace('Named implicit policy','Named extended-drain policy')
    path.write_text(text,encoding='cp1252')
    (output/(TERMINAL_MODULE+'.f90')).write_text(terminal_source(),encoding='cp1252')
    if 'timecontrol' not in patched:patched.append('timecontrol')
    return patched


def describe(directory, selected, original_output):
    if selected.get('SWDRA') != 2:
        return None
    from experimental_project import one
    required = dict(SWMACRO=0, SWSOPHY=0, SWHYST=0, SWSNOW=0, SWFROST=0,
                    SWHEA=1, SWCALT=2, SWKIMPL=0, SWMETDETAIL=0, SWBBCFILE=0)
    if any(selected.get(k) != v for k,v in required.items()) or selected.get('SWBR',0) != 0:
        raise ValueError('Unqualified extended drainage process composition')
    if selected.get('SWSOLU') not in (0,1) or selected.get('SWBOTB') != 6:
        raise ValueError('Extended drainage requires bounded water/CDE bottom6')
    if original_output is True:
        raise ValueError('Extended drainage original output/calendar composition is not yet implemented')
    directory = Path(directory)
    main = (directory/'swap.swp').read_text(encoding='cp1252')
    name = one(main,'DRFIL',r"'[^']+'").strip("'")
    prefix = one(main,'PATHDRAIN',r"'[^']*'").strip("'").strip()
    path = (directory/(prefix+name+'.dra')).resolve()
    if not path.is_relative_to(directory.resolve()) or not path.is_file():
        raise ValueError('Missing or external original extended drainage input')
    text = path.read_text(encoding='cp1252')
    def integer(key):return int(one(text,key,r'[+-]?\d+'))
    swsrf, swsec, levels, division = map(integer,('SWSRF','SWSEC','NRSRF','SWDIVD'))
    if swsrf not in (2,3) or swsec not in (1,2) or not 1 <= levels <= 25:
        raise ValueError('Unqualified extended surfacewater domain')
    if levels <= swsrf-2 or division not in (0,1) or selected['SWSOLU'] and division == 0:
        raise ValueError('Original extended drain partition is invalid')
    return dict(file=path.relative_to(directory.resolve()).as_posix(), levels=levels,
                swsrf=swsrf, swsec=swsec, nrpri=swsrf-2, nrsec=levels-(swsrf-2), swdivd=division)


def selection(project):
    if not project.input_directory or project.macro:
        return None
    from experimental_project import inspect
    record = inspect(project.input_directory,original_output=project.original_output).get('extended_drainage')
    if record is not None and project.time_step_policy != 'original-adaptive-day-seed-v1':
        raise ValueError('Extended drainage requires original time stepping')
    return record


def enabled(project):return selection(project) is not None


def domain(project):
    s = selection(project)
    return [1,project.nodes,s['levels'],s['swsrf'],s['swsec'],s['nrpri'],s['nrsec'],s['swdivd']]


def size(project):
    s = selection(project)
    return 92+16*(11+3*s['levels']+s['levels']*project.nodes)


def metadata(project):
    if not enabled(project):return None
    sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
    return dict(policy=POLICY,source_sha256=sha(Path(__file__)),template_sha256=sha(TEMPLATE),
                terminal_renderer_sha256=sha(Path(__file__).with_name('weather_terminal_receipt.py')),
                terminal_template_sha256=sha(Path(__file__).with_name('terminal_water_receipt.f90')),
                strict_retry_source_sha256=sha(Path(__file__).with_name('implicit_conductivity_retry.py')),
                pond_tangent_provider_sha256=sha(Path(__file__).with_name('hybrid_step_budget.f90')),
                strict_trial_water_guard_cm=1e-10,strict_retry_clock_floor_ulps=8,
                codec=MAGIC.decode(),domain=domain(project),bytes=size(project),
                ownership='Original MOD_drain dynamic values; exact rejected-trial restore, no new physical store',
                physical_equations_changed=False,original_surfacewater_lf_sha256=SURFACE_SOURCE_LF_SHA256,
                reference_defect_correction='Original positive storage is preserved; swstmax<=0 replaces lossy1e-7 dry cutoff',
                surface_inventory='Actual original branch supply/discharge; signed accepted transfers; prescribed-stage volume reaction explicit',
                original_cumulative_level_differences='Raw worker audit checked against actual daily transfers; cumulative origin is not physical restart state')


def state_witness(tokens, project, day):
    if len(tokens) < 3:raise ValueError('Missing original extended drain witness')
    clock=float(tokens[0]);adjustments=int(tokens[1]);count=int(tokens[2]);values=list(map(float,tokens[3:]))
    expected=(size(project)-92)//16
    if (clock != project.start_clock+day or count != expected or len(values) != count
            or adjustments < 0 or not all(map(math.isfinite,[clock,*values])) or min(values[2],values[4]) < 0):
        raise ValueError('Invalid original extended drain witness')
    return dict(adjustments=adjustments,values=values)


def validate_candidate(raw, receipt, project):
    if not enabled(project):return
    length=size(project);expected=domain(project);count=(length-92)//16
    if len(raw) < length+48 or raw[:8] != MAGIC:
        raise ValueError('Foreign original extended drain codec')
    start=len(raw)-length
    header=struct.unpack_from('<8i',raw,start);copy=struct.unpack_from('<8i',raw,start+32)
    clock,clock_copy,adjustments,adjustment_copy=struct.unpack_from('<2d2i',raw,start+64)
    values=struct.unpack_from('<'+str(count)+'d',raw,start+88)
    witness=struct.unpack_from('<'+str(count)+'d',raw,start+88+8*count)
    trailer=struct.unpack_from('<i',raw,len(raw)-4)[0]
    if (list(header) != expected or header != copy or trailer != length
            or not math.isfinite(clock) or clock != clock_copy or clock != project.start_clock+receipt.get('day',-1)
            or adjustments != adjustment_copy or adjustments < 0
            or not all(map(math.isfinite,values)) or min(values[2],values[4]) < 0 or values != witness
            or dict(adjustments=adjustments,values=list(values)) != receipt.get('extended_drainage_state')):
        raise ValueError('Original extended drain native state differs from accepted receipt')


def flux_witness(tokens, project, receipt, origin):
    s=selection(project);r=s['levels']
    if len(tokens)!=13+2*r:raise ValueError('Incomplete actual original surfacewater ledger')
    clock=float(tokens[0]);steps=int(tokens[1]);rejected=int(tokens[2]);v=list(map(float,tokens[3:]))
    if clock!=project.start_clock+receipt['day'] or steps<1 or rejected<0 or not all(map(math.isfinite,[clock,*v])):
        raise ValueError('Invalid actual original surfacewater clock or values')
    start,end,secondary,primary,runoff,supply,discharge,reaction,iqdra,iruno=v[:10]
    original,independent=v[10:10+r],v[10+r:]
    if start!=origin['values'][2] or end!=receipt['extended_drainage_state']['values'][2] or min(start,end,supply,discharge)<0:
        raise ValueError('Original surfacewater inventory origin differs')
    if s['swsec']==2 and reaction!=0 or s['swsec']==1 and (supply!=0 or discharge!=0):
        raise ValueError('Mixed prescribed/simulated original surfacewater authority')
    flow=receipt['external_flux_cm']
    if iqdra!=flow[13] or iruno!=flow[8]:raise ValueError('Original soil/surface transfer witness differs')
    residual=math.fsum([start,-end,secondary,runoff,supply,-discharge,reaction])
    checks=[residual,math.fsum([secondary,primary,-iqdra]),math.fsum([runoff,-iruno]),
            math.fsum([*original,-iqdra]),math.fsum([*independent[s['nrpri']:],-secondary]),
            math.fsum([*independent[:s['nrpri']],-primary]),*(a-b for a,b in zip(original,independent))]
    combined=math.fsum([*receipt['stock_start_cm'],*(-x for x in receipt['stock_end_cm']),start,-end,
                       *flow[:7],*(-flow[i] for i in range(7,16) if i not in (8,13)),
                       -primary,supply,-discharge,reaction])
    if max(map(abs,[*checks,combined]))>1e-10:
        raise ValueError('Actual original secondary or combined water guard exceeded1e-10cm')
    return dict(stock_start_cm=start,stock_end_cm=end,secondary_exchange_cm=secondary,primary_exchange_cm=primary,
                runoff_from_soil_cm=runoff,supply_cm=supply,discharge_cm=discharge,prescribed_stage_reaction_cm=reaction,
                independent_level_exchange_cm=independent,
                independent_surface_residual_cm=residual,independent_combined_residual_cm=combined,
                accepted_steps=steps,rejected_steps=rejected,
                authority='original simulated surfacewater' if s['swsec']==2 else 'original prescribed-stage volume constraint')


def apply_build(output, donor_build, project, patched):
    if not enabled(project):return patched
    patched=strict_trial_build(output,donor_build,patched)
    (output/(MODULE+'.f90')).write_bytes(TEMPLATE.read_bytes())
    (output/'surfacewater.f90').write_text(surfacewater_source((donor_build/'swap-selected/surfacewater.f90').read_text(encoding='cp1252')),encoding='cp1252')
    path=output/'macropore.f90';text=path.read_text(encoding='cp1252')
    first=text.index('    subroutine hybrid_macro_checkpoint(')
    last=text.index('    end subroutine hybrid_macro_checkpoint',first)
    body=text[first:last];codecs=re.findall(r"'(S5[A-Z0-9]{6})'",body)
    assert len(codecs)==2 and len(set(codecs))==1
    body=body.replace(codecs[0],MAGIC.decode())
    old='      use MOD_grid, only: numnod';assert body.count(old)==1
    body=body.replace(old,'      use '+MODULE+',only:extended_drain_checkpoint\n'+old,1)
    for restoring,anchor in [('.true.','        read(unit,iostat=ios) trailing'),('.false.','      end if\n      close(unit)')]:
        assert body.count(anchor)==1
        body=body.replace(anchor,f'        call extended_drain_checkpoint(unit,{restoring})\n'+anchor,1)
    path.write_text(text[:first]+body+text[last:],encoding='cp1252')
    path=output/'swap.f90';text=path.read_text(encoding='cp1252')
    anchor='use MOD_drain,           only: drain'
    assert text.count(anchor)==1
    text=text.replace(anchor,'use '+MODULE+',only:extended_drain_trial_begin,extended_drain_trial_end\n'+anchor,1)
    anchor='         if (swdra > 0)    call drain(2)';assert text.count(anchor)==1
    text=text.replace(anchor,'         call extended_drain_trial_begin()\n'+anchor,1)
    anchor='         if (swdra == 2)   call drain(3)';assert text.count(anchor)==1
    text=text.replace(anchor,anchor+'\n         call extended_drain_trial_end(fldecdt)',1)
    path.write_text(text,encoding='cp1252')
    path=output/'swap_main.f90';text=path.read_text(encoding='cp1252')
    anchor='use MOD_grid, only: numnod';assert text.count(anchor)==1
    text=text.replace(anchor,'use '+MODULE+',only:extended_drain_witness,extended_drain_window_begin\n'+anchor,1)
    anchor='      call swap(iCaller, iTask, tstart_in, tend_in)';assert text.count(anchor)==1
    text=text.replace(anchor,'      call extended_drain_window_begin()\n'+anchor,1)
    lines=text.splitlines(keepends=True);assert sum("'HYBRID_HYDRAULIC'" in line for line in lines)==2
    text=''.join(line+('   call extended_drain_witness()\n' if "'HYBRID_HYDRAULIC'" in line else '') for line in lines)
    path.write_text(text,encoding='cp1252')
    return [TERMINAL_MODULE,MODULE,'surfacewater',*patched]
