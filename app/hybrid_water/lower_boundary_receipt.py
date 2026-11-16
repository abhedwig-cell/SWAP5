"""Original soil-air boundary trial flux for the independent water receipt.

The original solver owns flboth and its constitutive gradient. Its later Fluxes
routine reconstructs qbot from storage; that value is not an independent trial
boundary input. This adapter changes neither routine's physical calculation.
"""
POLICY='original-soil-air-trial-flux-v1'

def enabled(project):
    if not project.input_directory or project.macro:return False
    from experimental_project import inspect
    return inspect(project.input_directory)['boundary']['SWBOTB']==8

def render_budget(source):
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
    replace('    integer :: domain, bottom','''    integer :: domain, bottom
    boundary_flow=qbot
    if(swmacro==0.and.swbotb==8)then
      if(.not.present(candidate_bottom_cm_d))error stop 'Missing soil-air trial boundary receipt'
      if(.not.ieee_is_finite(candidate_bottom_cm_d))error stop 'Nonfinite soil-air trial boundary receipt'
      boundary_flow=candidate_bottom_cm_d
    end if''')
    replace('swbotb==6 .or. swbotb==7 .or.', 'swbotb==6 .or. swbotb==7 .or. swbotb==8 .or.')
    replace('external=dt*(nraidt+nird+runon+qssdisum+qbot-qrosum-epd-reva-qdrtot)-runots',
            'external=dt*(nraidt+nird+runon+qssdisum+boundary_flow-qrosum-epd-reva-qdrtot)-runots')
    return source

def render_headcalc(source):
    anchor='         budget_step=projected_water_residual()'
    if source.count(anchor)!=1:raise ValueError('Changed original converged trial receipt anchor')
    if 'logical                          :: flboth, flok' not in source:
        raise ValueError('Changed original soil-air boundary trial ownership')
    return source.replace(anchor,'''         if(swmacro==0.and.swbotb==8)then
           if(flboth)then
             budget_step=projected_water_residual(-kmean(NN+1)*hgrad(NN+1))
           else
             budget_step=projected_water_residual(0d0)
           end if
         else
           budget_step=projected_water_residual()
         end if''')
