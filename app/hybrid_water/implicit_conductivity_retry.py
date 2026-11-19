"""Explicit numerical correction of original DTMIN nonconvergence continuation."""
from pathlib import Path
import hashlib

POLICY='original-implicit-nonconverged-trial-retry-v1'
CLOCK_ULPS=8


def enabled(project):
    if not project.input_directory or project.macro:return False
    from experimental_project import inspect
    return inspect(project.input_directory)['selectors']['SWKIMPL']==1


def time_source(source):
    anchor='   use MOD_timer';assert source.count(anchor)==1
    source=source.replace(anchor,'   use ieee_arithmetic,only:ieee_is_finite\n   use variables,only:swkimpl\n'+anchor,1)
    anchor='      if (fldecdt) then';assert source.count(anchor)==1
    correction=f'''
         ! Named implicit policy: never continue an unconverged no-macro step.
         ! Preserve the actual original reduction factor and rollback owner.
         if(swmacro==0.and.swkimpl==1)then
            if(.not.ieee_is_finite(dt).or..not.ieee_is_finite(t1900).or.dt<=0d0) &
               error stop 'Invalid implicit original trial clock'
            dt=dt/fact_dt_fldect
            if(dt<={CLOCK_ULPS}d0*spacing(t1900).or.t1900+dt<=t1900) &
               error stop 'Implicit original retry reached clock resolution'
            fldtmin=dt<=dtmin
            fldecdt=.false.
            return
         end if'''
    return source.replace(anchor,anchor+correction,1)


def headcalc_source(source):
    anchor='   if (.NOT.fldtmin) then';assert source.count(anchor)==1
    source=source.replace(anchor,'   if (.NOT.fldtmin.or.(swmacro==0.and.swkimpl==1)) then',1)
    decl='   integer                          :: i, j, itry,  MaxIt1, NN, iBackTr, ierror, mass_polish_at'
    assert source.count(decl)==1
    source=source.replace(decl,decl+'\n   integer,save::implicit_failed_trace_count=0',1)
    anchor='!     test for waterbalance of ponding layer';assert source.count(anchor)==1
    source=source.replace(anchor,anchor+'\n      deviat=0d0',1)
    anchor='   if (.NOT.fldtmin.or.(swmacro==0.and.swkimpl==1)) then';assert source.count(anchor)==1
    witness='''   if(implicit_failed_trace_count<64)then
      implicit_failed_trace_count=implicit_failed_trace_count+1
      write(*,'(a,*(1x,es25.17e3))')'ACTUAL_FAILED_IMPLICIT_NEWTON',t1900,dt,sum1,Fmax,deviat, &
         budget_step,budget_total,dble(numbit),dble(mass_polish_at), &
         merge(1d0,0d0,any(flnonconv1)),merge(1d0,0d0,any(flnonconv2)), &
         merge(1d0,0d0,flnonconv3),merge(1d0,0d0,ftoph),merge(1d0,0d0,fldtmin), &
         h(1),h(NN),pond,pondm1,epd,reva,qtop,k(1),kmean(1),hgrad(1),hold(1),theta(1),thetm1(1)
      flush(6)
   end if
'''
    return source.replace(anchor,witness+anchor,1)


def metadata(project):
    if not enabled(project):return None
    from age_output_clock import TIME_SHA
    return dict(policy=POLICY,source_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),original_timecontrol_sha256=TIME_SHA,newton='literal original Newton/backtracking, every exhausted implicit trial rolls back',minimum='actual original factor may reduce below input DTMIN only after nonconvergence',clock_ulp_floor=CLOCK_ULPS,water_guard_cm=1e-10,physical_equations_changed=False)


def apply_build(output,donor_build,project,patched):
    if not enabled(project):return patched
    path=output/'headcalc.f90';path.write_text(headcalc_source(path.read_text(encoding='cp1252')),encoding='cp1252')
    path=output/'timecontrol.f90'
    source=(path if path.exists() else donor_build/'swap-selected/timecontrol.f90').read_text(encoding='cp1252')
    path.write_text(time_source(source),encoding='cp1252')
    if 'timecontrol' not in patched:patched.append('timecontrol')
    return patched
