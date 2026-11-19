"""Explicit conservation-based availability bound on original pond evaporation."""
from pathlib import Path
import hashlib
from implicit_conductivity_retry import enabled

POLICY='original-implicit-pond-evaporation-availability-v1'
PROVIDER='implicit_pond_availability'


def metadata(project):
    if not enabled(project):return None
    sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
    return dict(policy=POLICY,source_sha256=sha(Path(__file__)),provider_sha256=sha(Path(__file__).with_suffix('.f90')),inputs='actual otherwise converged original pond deficit, epd, dt and pond endpoints',guard_cm=1e-10,ownership='HeadCalc local cap initialized unbounded on every invocation; no accepted/native state',physical_correction='limit original wet-pond evaporation to available water and reevaluate original vector; negative implied evaporation keeps original strict rollback')


def top_source(text):
    anchor='      subroutine boundtop(iTask)';assert text.count(anchor)==1
    text=text.replace(anchor,'      subroutine boundtop(iTask,implicit_pond_evaporation_cap)',1)
    anchor='      integer, intent(in)  :: iTask';assert text.count(anchor)==1
    text=text.replace(anchor,anchor+'\n      real(8),intent(in),optional::implicit_pond_evaporation_cap',1)
    anchor='         epd = epond';assert text.count(anchor)==1
    return text.replace(anchor,anchor+'\n         if(present(implicit_pond_evaporation_cap))epd=min(epd,implicit_pond_evaporation_cap)',1)


def head_source(text):
    anchor='   use hybrid_step_budget, only: projected_water_residual';assert text.count(anchor)==1
    text=text.replace(anchor,'   use hybrid_implicit_pond_availability,only:close_implicit_pond_evaporation\n'+anchor,1)
    anchor='   logical::implicit_pond_event_requested';assert text.count(anchor)==1
    text=text.replace(anchor,anchor+'\n   logical::implicit_pond_cap_changed\n   real(8)::implicit_pond_evaporation_cap',1)
    anchor='   call assert_no_implicit_pond_event()';assert text.count(anchor)==1
    text=text.replace(anchor,anchor+'\n   implicit_pond_evaporation_cap=huge(1d0)',1)
    anchor='            call request_implicit_pond_event(t1900,dt,pondm1,pond,q0,qtop,deviat,implicit_pond_event_requested)';assert text.count(anchor)==1
    text=text.replace(anchor,'''            call close_implicit_pond_evaporation(dt,pondm1,pond,epd,deviat,implicit_pond_evaporation_cap,implicit_pond_cap_changed)
            if(implicit_pond_cap_changed)then
               ! Reevaluate the literal original residual with available pond water.
               call vector_F(2,hgrad)
               sumold=0.5d0*dot_product(F(1:NN),F(1:NN))
               mass_polish_at=0
               cycle
            end if
'''+anchor,1)
    anchor='   call boundtop(2)';assert text.count(anchor)==1
    return text.replace(anchor,'   call boundtop(2,implicit_pond_evaporation_cap)',1)


def apply_build(output,project,patched):
    if not enabled(project):return patched
    (output/(PROVIDER+'.f90')).write_bytes(Path(__file__).with_suffix('.f90').read_bytes())
    path=output/'boundtop.f90';path.write_text(top_source(path.read_text(encoding='cp1252')),encoding='cp1252')
    path=output/'headcalc.f90';path.write_text(head_source(path.read_text(encoding='cp1252')),encoding='cp1252')
    return [PROVIDER,*patched]
