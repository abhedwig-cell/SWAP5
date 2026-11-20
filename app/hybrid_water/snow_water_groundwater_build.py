"""Compose literal water Snow calendars with the actual groundwater reaction."""
import hashlib
from pathlib import Path
import re

import thermal_output_clock as clock
import thermal_output_step as step
import thermal_output_reset as reset
import groundwater_snow_clock as epoch
from snow_water_groundwater import codec
import snow_water_groundwater_state as native

FUNCTION='hybrid_implicit_groundwater_trial'
WATER_TIME={'interval':'88b3d17865169672767b2d53460a625e191a6f6527067261e41bd99fd98e7c84',
    'clock':'75bf57289000cc1ae4ed411b505bc072c469f355823b272ba8655883d6d11e63',
    'step':'fa2f3581b7ad6552a707ae88d84bd5ddb03aa1fdc75ab0925842a261d94536e3'}


def owner(selected):return reset if selected['flprintdt'] and selected['swres'] else step if selected['flprintdt'] else clock


def trial_source(original,watstor,selected):
    from groundwater_snow_cde import trial_source as qualified
    result=qualified(original,watstor,selected)
    if not selected['flprintdt'] and selected['nprintday']==1:
        result=native.replace(result,'nprintday<2','nprintday/=1')
    return native.replace(result,'hybrid_groundwater_cde_clock_trial',FUNCTION)


def integral(original,watstor,selected):
    implementation=owner(selected);result=implementation.render_integral(original,watstor,selected)
    return native.replace(result,implementation.soil_trial_source(original,watstor),trial_source(original,watstor,selected))


def timecontrol(original,selected,start_clock):
    kind='step' if selected['flprintdt'] else 'clock' if selected['nprintday']>1 else 'interval'
    result=owner(selected).render_timecontrol(original) if kind!='interval' else original
    if hashlib.sha256(result.encode('cp1252')).hexdigest()!=WATER_TIME[kind]:
        raise ValueError('Changed complete qualified water Snow TimeControl parent')
    if kind=='interval':
        result=complete_day(result)
    result=native.replace(result,epoch.OLD,epoch.NEW)
    return native.replace(result,epoch.ANCHOR,epoch.declaration(start_clock)+epoch.ANCHOR)


def macro(original,selected):
    result=owner(selected).render_macro(original)
    begin='    subroutine hybrid_macro_checkpoint(';end='    end subroutine hybrid_macro_checkpoint'
    if result.count(begin)!=1 or result.count(end)!=1:raise ValueError('Ambiguous water Snow native owner')
    low=result.index(begin);high=result.index(end,low)+len(end);body=result[low:high]
    codes=re.findall(r"'(S5[A-Z0-9]{6})'",body)
    if len(codes)!=2 or len(set(codes))!=1:raise ValueError('Ambiguous water Snow native codec')
    body=body.replace(codes[0],codec(selected).decode())
    anchor='      use MOD_grid, only: numnod'
    imports=('      use hybrid_snow_water_groundwater_native_state,only:snow_water_groundwater_native_checkpoint\n'
             '      use hybrid_snow_water_groundwater_root_state,only:snow_water_groundwater_root_checkpoint\n')
    body=native.replace(body,anchor,imports+anchor)
    for restoring in ('.true.','.false.'):
        anchor='        read(unit,iostat=ios) trailing' if restoring=='.true.' else '      end if\n      close(unit)'
        calls=f'        call snow_water_groundwater_native_checkpoint(unit,{restoring})\n'
        calls+=f'        call snow_water_groundwater_root_checkpoint(unit,{restoring},clock)\n'
        body=native.replace(body,anchor,calls+anchor)
    return result[:low]+body+result[high:]


def apply_build(output,donor_build,project,patched,selected):
    folder=Path(__file__).parent;regular=clock.regular;ordinary=clock.ordinary
    originals=donor_build/'swap-selected';sha=lambda p:hashlib.sha256(p.read_bytes().replace(b'\r\n',b'\n')).hexdigest()
    if sha(originals/'hysteresis.f90')!=clock.thermal.HYSTERESIS_SHA:raise ValueError('Changed original water Snow hysteresis provider')
    (output/(regular.PROVIDER+'.f90')).write_bytes((clock.ROOT/'src/process'/(regular.PROVIDER+'.f90')).read_bytes())
    (output/'hybrid_age_output_state.f90').write_text(clock.state_source(project),encoding='cp1252')
    for name in (clock.DOMAIN,clock.SNOW_PROVIDER):(output/(name+'.f90')).write_bytes((folder/(name+'.f90')).read_bytes())
    original=(originals/'integral.f90').read_text(encoding='cp1252');watstor=(originals/'watstor.f90').read_text(encoding='cp1252')
    (output/'integral.f90').write_text(integral(original,watstor,selected),encoding='cp1252')
    (output/'age_output_calendar_probe.f90').write_text(clock.probe_source(project),encoding='cp1252')
    path=output/'swap.f90';text=regular.render_swap(path.read_text(encoding='cp1252'))
    anchor='use hybrid_day_window, only:';text=native.replace(text,anchor,'use MOD_integral,only:hybrid_output_crop_apply\n'+anchor)
    anchor='         call hybrid_apply_wofost(fl_cropemergence)'
    path.write_text(native.replace(text,anchor,anchor+'\n         call hybrid_output_crop_apply()'),encoding='cp1252')
    path=output/'macropore.f90';path.write_text(macro(path.read_text(encoding='cp1252'),selected),encoding='cp1252')
    path=output/'swap_main.f90';text=path.read_text(encoding='cp1252');anchor='use MOD_grid, only: numnod'
    text=native.replace(text,anchor,anchor+'\nuse MOD_integral,only:hybrid_output_calendar_apply\nuse hybrid_thermal_output_snow_calendar_state,only:snow_output_calendar_apply')
    anchor="\n   write(*,'(a,*(1x,es25.17e3))') 'HYBRID_HYDRAULIC', gwl, qbot, h(1:numnod)"
    path.write_text(native.replace(text,anchor,'\n   call hybrid_output_calendar_apply()\n   call snow_output_calendar_apply()\n   call hybrid_original_output_initial_emit()'+anchor),encoding='cp1252')
    (output/'timecontrol.f90').write_text(timecontrol((originals/'timecontrol.f90').read_text(encoding='cp1252'),selected,project.start_clock),encoding='cp1252')
    path=output/'headcalc.f90';text=path.read_text(encoding='cp1252');anchor='   use hybrid_step_budget, only: projected_water_residual'
    text=native.replace(text,anchor,'   use MOD_integral,only:'+FUNCTION+'\n'+anchor)
    anchor='         if (abs(budget_total+budget_step)>1d-10*(t1900-budget_start+dt)) flnonconv=.true.'
    path.write_text(native.replace(text,anchor,anchor+'\n         if(abs('+FUNCTION+'(groundwater_bottom,groundwater_delta))>1d-10)flnonconv=.true.'),encoding='cp1252')
    if selected['swcsv']:
        path=output/'swap_csv_output.f90';text=path.read_text(encoding='cp1252');original=(originals/'swap_csv_output.f90').read_bytes()
        if selected['swcsv']==3:
            anchor='      else if (swcsv == 3) then ! binary\n         ! datetime';ordinary.binary_patch().source(original)
            text=native.replace(text,anchor,'      else if (swcsv == 3) then ! binary\n         allocate(buffer(parlen-1))\n         ! datetime')
        for before,after in ordinary.output_patch('vector').edits(original):text=native.replace(text,before,after)
        path.write_text(text,encoding='cp1252')
    patched=[regular.PROVIDER,'hybrid_age_output_state',clock.DOMAIN,'integral',clock.SNOW_PROVIDER,'timecontrol',*patched]
    patched.insert(patched.index('swap'),'age_output_calendar_probe')
    if not selected['swkimpl']:
        from groundwater_snow_retry import apply_build as retry
        patched=retry(output,patched)
    return patched


def native_build(output,project,patched,selected):
    sources=[native.state_source(selected['swkimpl']),native.root_source(selected['swkimpl'])]
    for name,source in zip((native.STATE,native.ROOT_STATE),sources):(output/(name+'.f90')).write_text(source,encoding='cp1252')
    path=output/'macropore.f90';text=path.read_text(encoding='cp1252')
    path.write_text('\n'.join(sources)+'\n'+text,encoding='cp1252')
    return patched


def complete_day(source):
    # The original daily Snow update covers one full day. Use the existing
    # qualified dtCrit coincidence rule for dense/interval output as well.
    patch="""      if(tcum<1d0.and.dt>0d0)then
         if(abs(dt-(1d0-tcum))<=dtCrit)dt=1d0-tcum
      end if

"""
    return native.replace(source,'! 2.11 set flags and variables',patch+'! 2.11 set flags and variables')
