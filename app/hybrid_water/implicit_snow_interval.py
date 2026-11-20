"""Compose the existing Snow soil frame with the existing CDE interval owner.

The frame observes actual net rain/melt and the candidate groundwater reaction.
It is private within a day; no accepted state or physical equation is added.
"""
import difflib
from pathlib import Path


def selected(project):
    from cde_interval_output import active_selection
    output=active_selection(project)
    return output if output and output.get('groundwater_snow_cde_output') and output.get('implicit_snow_composition') else None


def compose(actual,before,after):
    """Apply only literal existing-owner edits; fail on overlapping owner seams."""
    old=before.splitlines(keepends=True);new=after.splitlines(keepends=True)
    edits=[]
    for tag,i,j,k,l in difflib.SequenceMatcher(a=old,b=new,autojunk=False).get_opcodes():
        if tag=='equal':continue
        a=''.join(old[i:j]);b=''.join(new[k:l])
        if not a:
            if i==0:raise ValueError('Unanchored Snow soil composition')
            start=i-1
            a=''.join(old[start:i]);b=a+b
            while actual.count(a)>1 and start>0:
                start-=1;a=''.join(old[start:i]);b=old[start]+b
        if actual.count(a)!=1:raise ValueError('Overlapping existing Snow soil/interval source owners: '+repr(a[:120]))
        edits.append((a,b))
    for a,b in reversed(edits):actual=actual.replace(a,b,1)
    return actual


def trial_source(original,watstor,output):
    from groundwater_snow_cde import trial_source as snow_trial
    text=snow_trial(original,watstor,output)
    old='nprintday<2'
    if text.count(old)!=1:raise ValueError('Changed original daily Snow soil trial domain')
    return text.replace(old,'nprintday/=1',1).replace('hybrid_groundwater_cde_clock_trial','hybrid_implicit_groundwater_trial')


def integral(original,watstor,selected_output):
    import cde_interval_output as interval
    import original_output_thermal as thermal
    import thermal_output_clock as clock
    result=compose(interval.render_integral(original,selected_output),
                   thermal.render_integral(original,None,selected_output),
                   clock.render_integral(original,watstor,selected_output))
    old=clock.soil_trial_source(original,watstor)
    if result.count(old)!=1:raise ValueError('Changed actual composed Snow soil trial')
    return result.replace(old,trial_source(original,watstor,selected_output),1)


def apply_build(output,donor_build,project,patched):
    selected_output=selected(project)
    if selected_output is None:return patched
    import cde_interval_output as interval
    import original_output_thermal as thermal
    import thermal_output_clock as clock
    source=(donor_build/'swap-selected/integral.f90').read_text(encoding='cp1252')
    stock=(donor_build/'swap-selected/watstor.f90').read_text(encoding='cp1252')
    path=output/'hybrid_age_output_state.f90'
    if path.read_text(encoding='cp1252')!=interval.regular.state_source(project):
        raise ValueError('Changed original interval private output frame')
    path.write_text(clock.state_source(project),encoding='cp1252')
    path=output/'integral.f90';actual=path.read_text(encoding='cp1252')
    if actual!=interval.render_integral(source,selected_output):
        raise ValueError('Changed complete original CDE interval integral owner')
    path.write_text(integral(source,stock,selected_output),encoding='cp1252')
    path=output/'age_output_calendar_probe.f90';actual=path.read_text(encoding='cp1252')
    if actual!=interval.probe_source(project,selected_output):
        raise ValueError('Changed complete original CDE interval probe owner')
    path.write_text(compose(actual,thermal.probe_source(project),clock.probe_source(project)),encoding='cp1252')
    return patched
