"""Use the original plate solver's actual trial lower-boundary flux.

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


def enabled(project):
    from frost_boundary_composition import selection
    selected=selection(project.input_directory,project.original_output)
    return bool(selected and selected['bottom']==5)


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


def head_source(text):
    return _replace(_replace(text,IMPORT,TRIAL_IMPORT),GUARD,TRIAL_GUARD)


def original_head_source(text):
    original=_replace(_replace(text,TRIAL_IMPORT,IMPORT),TRIAL_GUARD,GUARD)
    if head_source(original)!=text:raise ValueError('Foreign plate terminal trial source')
    return original


def apply_build(output,project,patched):
    if not enabled(project):return patched
    for name,render in [('terminal_water_receipt',receipt_source),('headcalc',head_source)]:
        if name not in patched:raise ValueError('Missing original plate terminal trial source')
        path=Path(output)/(name+'.f90')
        path.write_text(render(path.read_text(encoding='cp1252')),encoding='cp1252')
    return patched


def validate(bundle,project):
    if not enabled(project):return
    text=(Path(bundle)/'headcalc.f90').read_text(encoding='cp1252')
    original_head_source(text)
