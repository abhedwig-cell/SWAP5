"""Original SWBOTB1 constraint reaction; literal delegation for prior modes5/8."""
import lower_boundary_receipt as prior

POLICY='original-prescribed-groundwater-constraint-reaction-v1'


def selected_boundary(project):
    old=prior.selected_boundary(project)
    if old is not None:return old
    if not project.input_directory or project.macro or not project.solute:return None
    from experimental_project import inspect
    return 1 if inspect(project.input_directory)['boundary']['SWBOTB']==1 else None


def policy(boundary):
    return POLICY if boundary==1 else prior.policy(boundary)


def render_budget(source,boundary=8):
    if boundary!=1:return prior.render_budget(source,boundary)
    source=prior.render_budget(source,5)
    def replace(old,new):
        nonlocal source
        if source.count(old)!=1:raise ValueError('Changed prescribed groundwater budget anchor')
        source=source.replace(old,new)
    replace('function projected_water_residual(candidate_bottom_cm_d)',
            'function projected_water_residual(candidate_bottom_cm_d,candidate_matrix_delta_cm)')
    replace('    real(8),intent(in),optional::candidate_bottom_cm_d',
            '    real(8),intent(in),optional::candidate_bottom_cm_d,candidate_matrix_delta_cm')
    replace('if(swmacro==0.and.swbotb==5)then','if(swmacro==0.and.swbotb==1)then')
    replace('swbotb==7 .or. swbotb==5 .or.','swbotb==7 .or. swbotb==1 .or.')
    replace('      boundary_flow=candidate_bottom_cm_d',
            "      if(.not.present(candidate_matrix_delta_cm))error stop 'Missing prescribed groundwater trial storage'\n"
            "      if(.not.ieee_is_finite(candidate_matrix_delta_cm))error stop 'Nonfinite prescribed groundwater trial storage'\n"
            '      boundary_flow=candidate_bottom_cm_d')
    replace('      delta_matrix=sum((theta(1:numnod)-thetm1(1:numnod))*dz(1:numnod))',
            '      delta_matrix=sum((theta(1:numnod)-thetm1(1:numnod))*dz(1:numnod))\n'
            '      if(swbotb==1)delta_matrix=candidate_matrix_delta_cm')
    return source.replace('prescribed-head trial boundary receipt','prescribed groundwater trial boundary receipt')


def render_headcalc(source,boundary=8):
    if boundary!=1:return prior.render_headcalc(source,boundary)
    def replace(old,new):
        nonlocal source
        if source.count(old)!=1:raise ValueError('Changed prescribed groundwater HeadCalc anchor')
        source=source.replace(old,new)
    replace('   use hybrid_step_budget, only: projected_water_residual',
            '   use mod_prescribed_groundwater_reaction, only: prescribed_groundwater_reaction\n'
            '   use hybrid_step_budget, only: projected_water_residual')
    replace('   implicit none','   implicit none\n'
            '   real(8)::groundwater_bottom,groundwater_delta\n'
            '   integer::groundwater_status')
    for anchor in ('         budget_step=projected_water_residual()',
                   '            budget_step = projected_water_residual()'):
        indent=anchor[:len(anchor)-len(anchor.lstrip())]
        lines=['if(swmacro==0.and.swbotb==1)then',
               '  call prescribed_groundwater_reaction(NN,dt,dz(1:numnod),theta(1:numnod), &',
               '    thetm1(1:numnod),cofgen(2,1:numnod), &',
               '    sink(1:numnod)-source(1:numnod)+qrot(1:numnod), &',
               '    -kmean(NN+1)*hgrad(NN+1),groundwater_bottom,groundwater_delta,groundwater_status)',
               "  if(groundwater_status/=0)error stop 'Invalid prescribed groundwater trial receipt'",
               '  budget_step=projected_water_residual(groundwater_bottom,groundwater_delta)',
               'else','  budget_step=projected_water_residual()','end if']
        replace(anchor,'\n'.join(indent+line for line in lines))
    return source


def render_readswap(source,original_start_clock,boundary=5):
    if boundary!=1:return prior.render_readswap(source,original_start_clock)
    import math
    if not math.isfinite(original_start_clock):raise ValueError('Invalid original validation clock')
    anchor="call checkdate(ifnd,dates,tend,tstart,'date1 ','readswap//swbotb=1      ')"
    if source.count(anchor)!=1:raise ValueError('Changed original groundwater table validation anchor')
    return source.replace(anchor,
        f"call checkdate(ifnd,dates,tend,{original_start_clock:.17g}d0,'date1 ','readswap//swbotb=1      ')")


def metadata(project,sha,app,root):
    boundary=selected_boundary(project)
    if boundary is None:return None
    if boundary!=1:
        return dict(policy=prior.policy(boundary),source_sha256=sha(app/'lower_boundary_receipt.py'),
                    template_sha256=sha(app/'hybrid_step_budget.f90'),effective_SWBOTB=boundary)
    return dict(policy=POLICY,source_sha256=sha(app/'groundwater_boundary_receipt.py'),
                predecessor_sha256=sha(app/'lower_boundary_receipt.py'),
                template_sha256=sha(app/'hybrid_step_budget.f90'),effective_SWBOTB=1,
                production_sha256=sha(root/'src/process/mod_prescribed_groundwater_reaction.f90'),
                state='read-only actual Darcy interface and prescribed saturated tail; no new physical store')
