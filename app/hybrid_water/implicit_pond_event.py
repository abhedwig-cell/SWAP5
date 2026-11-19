"""Original pond-flux event predictor; pending only across a rejected trial."""
from pathlib import Path
import hashlib,re
from implicit_conductivity_retry import enabled

POLICY='original-implicit-pond-depletion-event-v1'
STATE='implicit_pond_event_state'


def metadata(project):
    if not enabled(project):return None
    sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
    return dict(policy=POLICY,source_sha256=sha(Path(__file__)),provider_sha256=sha(Path(__file__).with_name(STATE+'.f90')),inputs='actual original converged pond deficit, pondm1, q0 and qtop',water_guard_cm=1e-10,clock_ulp_floor=8,ownership='pending only after original full rollback; consumed by TimeControl5 before HeadCalc; compiled native read/write requires no pending event',accepted_state_added=False,physical_equations_changed=False)


def headcalc_source(text):
    anchor='   use hybrid_step_budget, only: projected_water_residual';assert text.count(anchor)==1
    text=text.replace(anchor,'   use hybrid_implicit_pond_event_state,only:request_implicit_pond_event,assert_no_implicit_pond_event\n'+anchor,1)
    anchor='   integer                          :: i, j, itry,  MaxIt1, NN, iBackTr, ierror, mass_polish_at';assert text.count(anchor)==1
    text=text.replace(anchor,anchor+'\n   logical::implicit_pond_event_requested',1)
    anchor='   mass_polish_at = 0';assert text.count(anchor)==1
    text=text.replace(anchor,'   call assert_no_implicit_pond_event()\n'+anchor,1)
    anchor='            deviat = pond - pondm1 + epd*dt + reva*dt - (nraidt+nird+Melt)*dt - runon*dt + runots - qtop * dt';assert text.count(anchor)==1
    text=text.replace(anchor,anchor+'''
            call request_implicit_pond_event(t1900,dt,pondm1,pond,q0,qtop,deviat,implicit_pond_event_requested)
            ! Exit the original Newton loop to its complete original rollback.
            if(implicit_pond_event_requested)exit''',1)
    return text


def time_source(text):
    anchor='   use ieee_arithmetic,only:ieee_is_finite';assert text.count(anchor)==1
    text=text.replace(anchor,'   use hybrid_implicit_pond_event_state,only:take_implicit_pond_event\n'+anchor,1)
    anchor='   implicit none';assert text.count(anchor)>=1
    text=text.replace(anchor,anchor+'\n   logical::implicit_pond_event_taken',1)
    anchor='            dt=dt/fact_dt_fldect';assert text.count(anchor)==1
    return text.replace(anchor,'''            call take_implicit_pond_event(t1900,dt,implicit_pond_event_taken)
            if(.not.implicit_pond_event_taken)dt=dt/fact_dt_fldect''',1)


def apply_build(output,project,patched):
    if not enabled(project):return patched
    (output/(STATE+'.f90')).write_bytes(Path(__file__).with_name(STATE+'.f90').read_bytes())
    path=output/'headcalc.f90';path.write_text(headcalc_source(path.read_text(encoding='cp1252')),encoding='cp1252')
    path=output/'timecontrol.f90';path.write_text(time_source(path.read_text(encoding='cp1252')),encoding='cp1252')
    path=output/'macropore.f90';text=path.read_text(encoding='cp1252')
    begin='    subroutine hybrid_macro_checkpoint(';end='    end subroutine hybrid_macro_checkpoint'
    assert text.count(begin)==text.count(end)==1
    first=text.index(begin);last=text.index(end,first)+len(end);body=text[first:last]
    anchor='      use MOD_grid, only: numnod';assert body.count(anchor)==1
    body=body.replace(anchor,'      use hybrid_implicit_pond_event_state,only:assert_no_implicit_pond_event\n'+anchor,1)
    matches=list(re.finditer(r'(?m)^([ \t]*)if \(restoring\) then$',body));assert len(matches)==1
    anchor=matches[0].group();body=body.replace(anchor,matches[0][1]+'call assert_no_implicit_pond_event()\n'+anchor,1)
    path.write_text(text[:first]+body+text[last:],encoding='cp1252')
    return [STATE,*patched]
