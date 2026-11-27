"""Compose existing ordinary Snow water/CDE calendars without drainage."""
import hashlib
from pathlib import Path
import re

import thermal_output_clock as clock
import thermal_output_step as step
import thermal_output_reset as reset
from snow_undrained import codec
import snow_undrained_state as native

FUNCTION='hybrid_snow_soil_trial_residual'


def owner(selected):return reset if selected['flprintdt'] and selected['swres'] else step if selected['flprintdt'] else clock


def trial_source(original,watstor,selected):
    result=clock.soil_trial_source(original,watstor)
    result=native.replace(result,'swdra/=1.or.','swdra/=0.or.')
    if selected['swbotb']==6:
        result=native.replace(result,'(swbotb/=5.and.swbotb/=8)','swbotb/=6')
    elif selected['swbotb']==9:
        result=native.replace(result,'(swbotb/=5.and.swbotb/=8)','swbotb/=9')
    return native.replace(result,'nprintday<2','(nprintday<1.or.nprintday>1440)')


def integral(original,watstor,selected):
    if selected['kind']=='cde':
        import cde_clock_output as cclock
        import cde_interval_output as interval
        if selected['flprintdt'] or selected['nprintday']>1:
            result=cclock.render_integral(original,watstor,selected)
        else:
            from implicit_snow_interval import compose
            result=compose(interval.render_integral(original,selected),
                clock.thermal.render_integral(original,None,selected),clock.render_integral(original,watstor,selected))
    else:result=owner(selected).render_integral(original,watstor,selected)
    pattern=r'real\(8\) function hybrid_snow_soil_trial_residual\(candidate_bottom_cm_d\) result\(residual\).*?end function(?: hybrid_snow_soil_trial_residual)?'
    matches=list(re.finditer(pattern,result,re.S|re.I))
    if len(matches)!=1:raise ValueError('Changed complete original Snow soil helper')
    actual=matches[0].group()
    parents=[clock.soil_trial_source(original,watstor),step.soil_trial_source(original,watstor)]
    parents+=[parents[1].replace('nprintday/=1','(nprintday<1.or.nprintday>1440)')]
    if not any(actual==v.strip() for v in parents):raise ValueError('Foreign qualified Snow soil helper parent')
    return result[:matches[0].start()]+trial_source(original,watstor,selected).strip()+result[matches[0].end():]


def timecontrol(original,selected,start_clock):
    from snow_water_groundwater_build import timecontrol as qualified
    result=qualified(original,selected,start_clock)
    if selected['kind']=='cde' and (selected['flprintdt'] or selected['nprintday']>1):
        result=cde_events(result)
    return result


def macro(original,selected):
    result=owner(selected).render_macro(original)
    if selected['kind']=='cde':
        anchor='      use MOD_integral,only:hybrid_output_calendar_checkpoint'
        result=native.replace(result,anchor,anchor+'\n      use hybrid_original_cde_output_state,only:hybrid_cde_output_checkpoint')
        for restoring in ('.true.','.false.'):
            anchor=f'        call hybrid_output_calendar_checkpoint(unit,{restoring})'
            result=native.replace(result,anchor,anchor+f'\n        call hybrid_cde_output_checkpoint(unit,{restoring})')
    return result


def apply_build(output,donor_build,project,patched,selected):
    folder=Path(__file__).parent;regular=clock.regular;ordinary=clock.ordinary
    originals=donor_build/'swap-selected';sha=lambda p:hashlib.sha256(p.read_bytes().replace(b'\r\n',b'\n')).hexdigest()
    if sha(originals/'hysteresis.f90')!=clock.thermal.HYSTERESIS_SHA:raise ValueError('Changed original water Snow hysteresis provider')
    (output/(regular.PROVIDER+'.f90')).write_bytes((clock.ROOT/'src/process'/(regular.PROVIDER+'.f90')).read_bytes())
    (output/'hybrid_age_output_state.f90').write_text(clock.state_source(project),encoding='cp1252')
    for name in (clock.DOMAIN,clock.SNOW_PROVIDER):
        provider='cde_interval_snow_state' if name==clock.SNOW_PROVIDER and project.solute else name
        (output/(name+'.f90')).write_bytes((folder/(provider+'.f90')).read_bytes())
    original=(originals/'integral.f90').read_text(encoding='cp1252');watstor=(originals/'watstor.f90').read_text(encoding='cp1252')
    (output/'integral.f90').write_text(integral(original,watstor,selected),encoding='cp1252')
    (output/'age_output_calendar_probe.f90').write_text(probe(project,selected),encoding='cp1252')
    path=output/'swap.f90';text=regular.render_swap(path.read_text(encoding='cp1252'))
    anchor='use hybrid_day_window, only:';text=native.replace(text,anchor,'use MOD_integral,only:hybrid_output_crop_apply\n'+anchor)
    anchor='         call hybrid_apply_wofost(fl_cropemergence)'
    path.write_text(native.replace(text,anchor,anchor+'\n         call hybrid_output_crop_apply()'),encoding='cp1252')
    path=output/'macropore.f90';path.write_text(macro(path.read_text(encoding='cp1252'),selected),encoding='cp1252')
    path=output/'swap_main.f90';text=path.read_text(encoding='cp1252');anchor='use MOD_grid, only: numnod'
    imports='\nuse MOD_integral,only:hybrid_output_calendar_apply\nuse hybrid_thermal_output_snow_calendar_state,only:snow_output_calendar_apply'
    if project.solute:imports+='\nuse hybrid_original_cde_output_state,only:hybrid_cde_output_apply'
    text=native.replace(text,anchor,anchor+imports)
    anchor="\n   write(*,'(a,*(1x,es25.17e3))') 'HYBRID_HYDRAULIC', gwl, qbot, h(1:numnod)"
    path.write_text(native.replace(text,anchor,'\n   call hybrid_output_calendar_apply()\n   call snow_output_calendar_apply()'+('\n   call hybrid_cde_output_apply()' if project.solute else '')+'\n   call hybrid_original_output_initial_emit()'+anchor),encoding='cp1252')
    (output/'timecontrol.f90').write_text(timecontrol((originals/'timecontrol.f90').read_text(encoding='cp1252'),selected,project.start_clock),encoding='cp1252')
    path=output/'headcalc.f90';text=path.read_text(encoding='cp1252');anchor='   use hybrid_step_budget, only: projected_water_residual'
    text=native.replace(text,anchor,'   use MOD_integral,only:'+FUNCTION+'\n'+anchor)
    anchor='         if (abs(budget_total+budget_step)>1d-10*(t1900-budget_start+dt)) flnonconv=.true.'
    path.write_text(head_trial(text,selected),encoding='cp1252')
    if selected['swcsv']:
        path=output/'swap_csv_output.f90';text=path.read_text(encoding='cp1252');original=(originals/'swap_csv_output.f90').read_bytes()
        if selected['swcsv']==3:
            anchor='      else if (swcsv == 3) then ! binary\n         ! datetime';ordinary.binary_patch().source(original)
            text=native.replace(text,anchor,'      else if (swcsv == 3) then ! binary\n         allocate(buffer(parlen-1))\n         ! datetime')
        for before,after in ordinary.output_patch('vector').edits(original):text=native.replace(text,before,after)
        path.write_text(text,encoding='cp1252')
    extra=[]
    if project.solute:
        import cde_interval_source as bridge
        if sha(originals/'solute.f90')!=bridge.ORIGINAL_SHA:raise ValueError('Changed original CDE source')
        for name in ('cde_interval_receipt','cde_clock_events'):
            (output/(name+'.f90')).write_bytes((folder/(name+'.f90')).read_bytes())
        (output/'original_cde_output_state.f90').write_bytes((folder/'cde_interval_output_state.f90').read_bytes())
        from snow_undrained_cde_positive import source as preserve_positive
        path=output/'solute.f90';path.write_text(preserve_positive(bridge.source(path.read_text(encoding='cp1252'))),encoding='cp1252')
        patched.insert(patched.index('solute')+1,'original_cde_output_state')
        extra=['cde_interval_receipt']+(['cde_clock_events'] if selected['flprintdt'] or selected['nprintday']>1 else [])
    patched=[regular.PROVIDER,*extra,'hybrid_age_output_state',clock.DOMAIN,'integral',clock.SNOW_PROVIDER,'timecontrol',*patched]
    patched.insert(patched.index('swap'),'age_output_calendar_probe')
    if not selected['swkimpl']:
        from implicit_interception_partition import source as exact_partition
        meteo=output/'MOD_meteo.f90'
        parent=(meteo if meteo.exists() else originals/'MOD_meteo.f90').read_text(encoding='cp1252')
        meteo.write_text(exact_partition(parent),encoding='cp1252')
        patched=['MOD_meteo',*(name for name in patched if name!='MOD_meteo')]
        from groundwater_snow_retry import apply_build as retry
        patched=retry(output,patched)
    return patched



def cde_events(time_source):
    anchor='   use MOD_timer';assert time_source.count(anchor)==1
    time_source=time_source.replace(anchor,anchor+'\n   use hybrid_cde_clock_events,only:close_cde_clock_event,CDE_CLOCK_EVENT_OK',1)
    anchor='      real(8) :: dtEventEOD, dtEventPrint, dtEventRain, dtEventSSDI, dtEventRunon';assert time_source.count(anchor)==1
    time_source=time_source.replace(anchor,anchor+'\n      real(8)::hybrid_cde_old_dt,hybrid_cde_old_limit\n      integer::hybrid_cde_event_status\n      logical::hybrid_cde_event_changed',1)
    anchor='   end function get_dtevent';assert time_source.count(anchor)==1
    closure="""      hybrid_cde_old_dt=dt;hybrid_cde_old_limit=get_dtEvent
      call close_cde_clock_event(tcum,dt_irr_event,dtCrit,dt,get_dtEvent,hybrid_cde_event_changed,hybrid_cde_event_status)
      if(hybrid_cde_event_status/=CDE_CLOCK_EVENT_OK)error stop 'Invalid actual local CDE clock event'
      if(hybrid_cde_event_changed)write(*,'(a,7(1x,es25.17e3))')'CDE_CLOCK_EVENT_CLOSURE', &
       tcum,hybrid_cde_old_dt,hybrid_cde_old_limit,dt_irr_event,dtCrit,dt,get_dtEvent
"""
    time_source=time_source.replace(anchor,closure+anchor,1)
    return time_source


def head_trial(text,selected=None):
    anchor='\n   implicit none\n'
    text=native.replace(text,anchor,anchor+'   real(8)::hybrid_snow_trial_guard\n')
    anchor='         if (abs(budget_total+budget_step)>1d-10*(t1900-budget_start+dt)) flnonconv=.true.'
    guard="""
         if(swbotb==8.and..not.flboth)then
            hybrid_snow_trial_guard=hybrid_snow_soil_trial_residual(0d0)
         else
            hybrid_snow_trial_guard=hybrid_snow_soil_trial_residual(-kmean(NN+1)*hgrad(NN+1))
         end if
         if(abs(hybrid_snow_trial_guard)>1d-10)flnonconv=.true."""
    if selected is not None and selected['swbotb']==6:
        # Literal original Boundbottom assigns qbot=0 for bottom6. This is an
        # independent candidate receipt, not a substituted accepted flux/store.
        guard='\n         hybrid_snow_trial_guard=hybrid_snow_soil_trial_residual(0d0)\n         if(abs(hybrid_snow_trial_guard)>1d-10)flnonconv=.true.'
    elif selected is not None and selected['swbotb']==9:
        guard='\n         hybrid_snow_trial_guard=hybrid_snow_soil_trial_residual(qbot)\n         if(abs(hybrid_snow_trial_guard)>1d-10)flnonconv=.true.'
    return native.replace(text,anchor,anchor+guard)


def probe(project,selected):
    if selected['kind']!='cde':return clock.probe_source(project)
    import cde_clock_output as cclock
    import cde_interval_output as interval
    if selected['flprintdt'] or selected['nprintday']>1:return cclock.probe_source(project,selected)
    from implicit_snow_interval import compose
    return compose(interval.probe_source(project,selected),clock.thermal.probe_source(project),clock.probe_source(project))
