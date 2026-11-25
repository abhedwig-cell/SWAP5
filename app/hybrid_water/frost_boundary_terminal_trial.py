"""Use the original bounded solver's actual trial lower-boundary flux.

Fluxes reconstructs global qbot later. At HeadCalc convergence that global is
not the current candidate. Only the independent trial receipt receives this
argument; physical fluxes, state and the absolute 1e-10 guard stay unchanged.
"""
from pathlib import Path

IMPORT='   use hybrid_terminal_water_receipt, only: terminal_water_residual'
TRIAL_IMPORT='   use hybrid_terminal_water_receipt, only: terminal_water_trial_residual'
GUARD='            if(abs(terminal_water_residual())>1d-10)flnonconv=.true.'
TRIAL_GUARD='''            if(flboth)then
               if(abs(terminal_water_trial_residual(-kmean(NN+1)*hgrad(NN+1)))>1d-10)flnonconv=.true.
            else
               if(abs(terminal_water_trial_residual(0d0))>1d-10)flnonconv=.true.
            end if'''
HEAD5_TRIAL_GUARD='            if(abs(terminal_water_trial_residual(-kmean(NN+1)*hgrad(NN+1)))>1d-10)flnonconv=.true.'


def enabled(project):
    from frost_boundary_composition import selection
    selected=selection(project.input_directory,project.original_output)
    return bool(selected and (selected['bottom']==8 or selected['bottom']==5 and selected['implicit']==1))


def _replace(text, before, after):
    if text.count(before)!=1:raise ValueError('Changed original plate terminal trial anchor')
    return text.replace(before,after,1)


def receipt_source(text):
    edits=[
        ('  public :: terminal_water_terms, terminal_water_residual',
         '  public :: terminal_water_terms, terminal_water_residual, terminal_water_trial_residual'),
        ('  subroutine terminal_water_terms(terms)',
         '  subroutine terminal_water_trial_terms(terms,candidate_bottom_cm_d)'),
        ('    real(8), intent(out) :: terms(28)',
         '    real(8), intent(in) :: candidate_bottom_cm_d\n    real(8), intent(out) :: terms(28)'),
        ('    qbotts=qbot*dt','    qbotts=candidate_bottom_cm_d*dt'),
        ('  real(8) function terminal_water_residual() result(residual)',
         '''  subroutine terminal_water_terms(terms)
    use variables, only: qbot
    real(8),intent(out)::terms(28)
    call terminal_water_trial_terms(terms,qbot)
  end subroutine

  real(8) function terminal_water_trial_residual(candidate_bottom_cm_d) result(residual)
    real(8),intent(in)::candidate_bottom_cm_d
    real(8)::terms(28)
    call terminal_water_trial_terms(terms,candidate_bottom_cm_d)
    residual=real(sum(real(terms,real128)),8)
  end function

  real(8) function terminal_water_residual() result(residual)''')]
    for before,after in edits:text=_replace(text,before,after)
    return text


def trial_guard(bottom):
    if bottom==8:return TRIAL_GUARD
    if bottom==5:return HEAD5_TRIAL_GUARD
    raise ValueError('Foreign actual trial lower boundary')


def head_source(text,bottom=8):
    return _replace(_replace(text,IMPORT,TRIAL_IMPORT),GUARD,trial_guard(bottom))


def original_head_source(text,bottom=8):
    original=_replace(_replace(text,TRIAL_IMPORT,IMPORT),trial_guard(bottom),GUARD)
    if head_source(original,bottom)!=text:raise ValueError('Foreign plate terminal trial source')
    return original


def apply_build(output,project,patched):
    if not enabled(project):return patched
    from frost_boundary_composition import selection
    bottom=selection(project.input_directory,project.original_output)['bottom']
    for name,render in [('terminal_water_receipt',receipt_source),('headcalc',lambda text:head_source(text,bottom))]:
        if name not in patched:raise ValueError('Missing original plate terminal trial source')
        path=Path(output)/(name+'.f90')
        path.write_text(render(path.read_text(encoding='cp1252')),encoding='cp1252')
    return patched


def validate(bundle,project):
    if not enabled(project):return
    from frost_boundary_composition import selection
    text=(Path(bundle)/'headcalc.f90').read_text(encoding='cp1252')
    original_head_source(text,selection(project.input_directory,project.original_output)['bottom'])
