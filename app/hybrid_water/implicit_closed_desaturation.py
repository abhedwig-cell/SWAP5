"""Start degenerate closed implicit Newton trials on the original residual manifold.

Only the initial trial iterate changes. Original watcon/hconduc, root extraction,
surface equations, rejected-step rollback and every convergence/mass criterion
continue to own acceptance. No accepted state, parameter, flux or clock is fixed.
"""
from pathlib import Path
import hashlib

POLICY='original-closed-implicit-saturated-residual-initial-iterate-v1'
TRIGGER='      if(numbit==1.and.swmacro==0.and.swbotb==6.and.swkimpl==1.and.pond==0d0)then\n         if(all(dimoca(1:NN)==0d0).and.sum(F(1:NN))>0d0.and.maxval(abs(F(1:NN)))>CritDevBalCp)then\n            call closed_desaturation_trial()\n            sumold=0.5d0*dot_product(F(1:NN),F(1:NN))\n            cycle\n         end if\n      end if\n'
ANCHOR='!     special case: SwKimpl = 1'
ROUTINE_ANCHOR='   subroutine alternative_solver()'


def routine():
    return Path(__file__).with_name('implicit_closed_desaturation_trial.f90').read_text(encoding='utf8')


def selected(item):
    return item is not None and item['bottom']==6 and item.get('drainage',1)==0


def source(text):
    if text.count(ANCHOR)!=1 or text.count(ROUTINE_ANCHOR)!=1 or 'subroutine closed_desaturation_trial' in text:
        raise ValueError('Foreign complete original closed implicit initial-iterate seam')
    result=text.replace(ANCHOR,TRIGGER+ANCHOR,1).replace(ROUTINE_ANCHOR,routine()+'\n'+ROUTINE_ANCHOR,1)
    if restore(result)!=text:raise ValueError('Incomplete original closed implicit initial-iterate inverse')
    return result


def restore(text):
    if 'closed_desaturation_trial' not in text:return text
    body=routine()+'\n'
    if text.count(TRIGGER)!=1 or text.count(body)!=1:
        raise ValueError('Foreign original-residual initial-iterate body')
    return text.replace(TRIGGER,'',1).replace(body,'',1)


def metadata(item):
    if not selected(item):return None
    sha=lambda p:hashlib.sha256(p.read_bytes().replace(b'\r\n',b'\n')).hexdigest()
    return dict(policy=POLICY,new_numerical_policy=True,
        providers={p.name:sha(p) for p in [Path(__file__),Path(__file__).with_name('implicit_closed_desaturation_trial.f90')]},
        trigger='actual first Newton iterate; closed bottom6, implicit1, zero trial pond, every moisture capacity zero, positive total residual and original compartment criterion exceeded',
        search='uniform trial-head shift, bracket/bisect sum of original vector_F; original watcon/hconduc, conductivity means and root extraction on every probe',
        search_iteration_bound='existing MaxIt1; no changed original Newton/backtracking limits',
        accepted_state_added=False,physical_equations_changed=False,tolerances_changed=False,
        original_full_residual_and_budget_acceptance_required=True)


def validate(bundle,item):
    path=Path(bundle)/'headcalc.f90';text=path.read_text(encoding='cp1252')
    if selected(item):
        parent=restore(text)
        if parent==text or source(parent)!=text:raise ValueError('Missing complete closed implicit initial-iterate provider')
    elif 'closed_desaturation_trial' in text:
        raise ValueError('Closed implicit initial iterate outside its actual selected domain')
