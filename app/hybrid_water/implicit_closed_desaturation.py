"""Start closed implicit Newton trials and check the original convergence block.

The trial start and convergence evaluation order change. Original watcon/hconduc, root extraction,
surface equations, rejected-step rollback and every convergence/mass criterion
continue to own acceptance. No accepted state, parameter, flux or clock is fixed.
"""
from pathlib import Path
import hashlib

POLICY='original-closed-implicit-residual-start-and-conditional-convergence-v3'
TRIGGER='      if(numbit==1.and.swmacro==0.and.swbotb==6.and.swkimpl==1.and.pond==0d0)then\n         if(sum(F(1:NN))/=0d0.and.maxval(abs(F(1:NN)))>CritDevBalCp)then\n            call closed_desaturation_trial()\n            sumold=0.5d0*dot_product(F(1:NN),F(1:NN))\n            cycle\n         end if\n      end if\n'
PRECHECK='      if(.not.closed_current_iterate_checked.and.swmacro==0.and.swbotb==6.and.swkimpl==1)then\n         if(maxval(abs(F(1:NN)))<=CritDevBalCp.and.abs(sum(F(1:NN)))<=CritDevBalTot)then\n            closed_current_iterate_checked=.true.\n            sump=0.5d0*dot_product(F(1:NN),F(1:NN))\n            sum1=sum(F(1:NN))\n            Fmax=maxval(abs(F(1:NN)))\n            goto 1\n         end if\n      end if\n'
ANCHOR='!     special case: SwKimpl = 1'
ROUTINE_ANCHOR='   subroutine alternative_solver()'
ITERATE_EDITS=(
    ('   logical::implicit_pond_event_requested',
     '   logical::implicit_pond_event_requested\n   logical::closed_current_iterate_checked'),
    ('   call assert_no_implicit_pond_event()',
     '   call assert_no_implicit_pond_event()\n   closed_current_iterate_checked=.false.'),
    ('         call vector_F(2, hgrad)',
     '         call vector_F(2, hgrad)\n         closed_current_iterate_checked=.false.'),
    ('               call vector_F(2,hgrad)',
     '               call vector_F(2,hgrad)\n               closed_current_iterate_checked=.false.'),
    ('            mass_polish_at=numbit',
     '            mass_polish_at=numbit\n            closed_current_iterate_checked=.false.'))


def routine():
    return Path(__file__).with_name('implicit_closed_desaturation_trial.f90').read_text(encoding='utf8')


def selected(item):
    return item is not None and item['bottom']==6 and item.get('drainage',1)==0


def source(text):
    if text.count(ANCHOR)!=1 or text.count(ROUTINE_ANCHOR)!=1 or 'subroutine closed_desaturation_trial' in text:
        raise ValueError('Foreign complete original closed implicit initial-iterate seam')
    result=text
    for before,after in ITERATE_EDITS:
        if result.count(before)!=1 or after in result:
            raise ValueError('Foreign complete original closed implicit iterate ownership seam')
        result=result.replace(before,after,1)
    result=result.replace(ANCHOR,TRIGGER+PRECHECK+ANCHOR,1).replace(ROUTINE_ANCHOR,routine()+'\n'+ROUTINE_ANCHOR,1)
    if restore(result)!=text:raise ValueError('Incomplete original closed implicit initial-iterate inverse')
    return result


def restore(text):
    if 'closed_desaturation_trial' not in text:return text
    body=routine()+'\n'
    if text.count(TRIGGER)!=1 or text.count(PRECHECK)!=1 or text.count(body)!=1:
        raise ValueError('Foreign original-residual initial-iterate body')
    text=text.replace(TRIGGER,'',1).replace(PRECHECK,'',1).replace(body,'',1)
    for before,after in reversed(ITERATE_EDITS):
        if text.count(after)!=1:
            raise ValueError('Foreign complete closed implicit iterate ownership')
        text=text.replace(after,before,1)
    return text


def metadata(item):
    if not selected(item):return None
    sha=lambda p:hashlib.sha256(p.read_bytes().replace(b'\r\n',b'\n')).hexdigest()
    return dict(policy=POLICY,new_numerical_policy=True,
        providers={p.name:sha(p) for p in [Path(__file__),Path(__file__).with_name('implicit_closed_desaturation_trial.f90')]},
        trigger='actual first Newton iterate; closed bottom6, implicit1, zero trial pond, nonzero original total residual and original compartment criterion exceeded',
        search='signed uniform trial-head shift, bracket/bisect original vector_F sum for wetting or drying; original watcon/hconduc, conductivity means and root extraction on every probe',
        search_iteration_bound='existing MaxIt1; no changed original Newton/backtracking limits',
        accepted_state_added=False,physical_equations_changed=False,tolerances_changed=False,
        original_full_residual_and_budget_acceptance_required=True,
        convergence_order='evaluate unchanged complete convergence/pond/strict-budget block once per current iterate before an ill-conditioned Newton solve; a failed full check requires Newton progress, while the unchanged mandatory polish may recheck an already feasible iterate; no physical state or tolerance is assigned',
        transient_iterate_check_flag='HeadCalc local only; initialized on every call; reset only after actual vector_F reevaluation or the original mandatory polish; no accepted/native state')


def validate(bundle,item):
    path=Path(bundle)/'headcalc.f90';text=path.read_text(encoding='cp1252')
    if selected(item):
        parent=restore(text)
        if parent==text or source(parent)!=text:raise ValueError('Missing complete closed implicit initial-iterate provider')
    elif 'closed_desaturation_trial' in text:
        raise ValueError('Closed implicit initial iterate outside its actual selected domain')
