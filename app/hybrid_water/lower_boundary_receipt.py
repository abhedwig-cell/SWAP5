"""Original soil-air boundary trial flux for the independent water receipt.

The original solver owns flboth and its constitutive gradient. Its later Fluxes
routine reconstructs qbot from storage; that value is not an independent trial
boundary input. This adapter changes neither routine's physical calculation.
"""
POLICY='original-soil-air-trial-flux-v1'

def selected_boundary(project):
    if not project.input_directory or project.macro:return None
    from experimental_project import inspect
    boundary=inspect(project.input_directory)['boundary']['SWBOTB']
    return boundary if boundary in (5,8) else None

def enabled(project):return selected_boundary(project) is not None

def policy(boundary):
    if boundary==8:return POLICY
    if boundary==5:return 'original-prescribed-head-trial-flux-v1'
    raise ValueError('Unsupported independent original boundary receipt')

def render_budget(source,boundary=8):
    policy(boundary)
    label='soil-air' if boundary==8 else 'prescribed-head'
    def replace(old,new):
        nonlocal source
        if source.count(old)!=1:raise ValueError('Changed original trial-budget source anchor')
        source=source.replace(old,new)
    replace('  implicit none','  use ieee_arithmetic,only:ieee_is_finite\n  implicit none')
    replace('function projected_water_residual() result(residual)',
            'function projected_water_residual(candidate_bottom_cm_d) result(residual)')
    replace('    real(8) :: delta_matrix, delta_macro, new_stock, rapid, external',
            '    real(8),intent(in),optional::candidate_bottom_cm_d\n'
            '    real(8)::boundary_flow\n'
            '    real(8) :: delta_matrix, delta_macro, new_stock, rapid, external')
    replace('    integer :: domain, bottom',f'''    integer :: domain, bottom
    boundary_flow=qbot
    if(swmacro==0.and.swbotb=={boundary})then
      if(.not.present(candidate_bottom_cm_d))error stop 'Missing {label} trial boundary receipt'
      if(.not.ieee_is_finite(candidate_bottom_cm_d))error stop 'Nonfinite {label} trial boundary receipt'
      boundary_flow=candidate_bottom_cm_d
    end if''')
    replace('swbotb==6 .or. swbotb==7 .or.', f'swbotb==6 .or. swbotb==7 .or. swbotb=={boundary} .or.')
    replace('external=dt*(nraidt+nird+runon+qssdisum+qbot-qrosum-epd-reva-qdrtot)-runots',
            'external=dt*(nraidt+nird+runon+qssdisum+boundary_flow-qrosum-epd-reva-qdrtot)-runots')
    return source

def render_headcalc(source,boundary=8):
    policy(boundary)
    anchors=('         budget_step=projected_water_residual()',
             '            budget_step = projected_water_residual()')
    if any(source.count(anchor)!=1 for anchor in anchors):
        raise ValueError('Changed original convergence/final trial receipt anchors')
    if 'logical                          :: flboth, flok' not in source:
        raise ValueError('Changed original soil-air boundary trial ownership')
    for anchor in anchors:
        indent=anchor[:len(anchor)-len(anchor.lstrip())]
        if boundary==8:
            lines=['if(swmacro==0.and.swbotb==8)then','  if(flboth)then',
                   '    budget_step=projected_water_residual(-kmean(NN+1)*hgrad(NN+1))',
                   '  else','    budget_step=projected_water_residual(0d0)','  end if',
                   'else','  budget_step=projected_water_residual()','end if']
        else:
            lines=['if(swmacro==0.and.swbotb==5)then',
                   '  budget_step=projected_water_residual(-kmean(NN+1)*hgrad(NN+1))',
                   'else','  budget_step=projected_water_residual()','end if']
        source=source.replace(anchor,'\n'.join(indent+line for line in lines))
    return source

def render_readswap(source,original_start_clock):
    import math
    if not math.isfinite(original_start_clock):raise ValueError('Invalid original validation clock')
    anchor="call checkdate(ifnd,dates,tend,tstart,'date5 ','readswap//swbotb=5      ')"
    if source.count(anchor)!=1:raise ValueError('Changed original prescribed-head table validation anchor')
    # Only validation uses the bound original input interval. Original AFGEN,
    # values, actual worker clock and every physical calculation remain intact.
    return source.replace(anchor,
        f"call checkdate(ifnd,dates,tend,{original_start_clock:.17g}d0,'date5 ','readswap//swbotb=5      ')")
