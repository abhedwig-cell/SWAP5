"""Read the existing daily output frame across original subdaily resets."""


def integral_terms(text,original,watstor):
    from age_output_clock import trial_receipt_source
    observer=trial_receipt_source(original,watstor)
    old='real(8) function hybrid_output_trial_residual() result(residual)'
    assert observer.count(old)==1
    observer=observer.replace(old,'subroutine hybrid_extended_output_trial_terms(terms)',1)
    observer=observer.replace('implicit none\n','implicit none\nreal(8),intent(out)::terms(28)\n',1)
    assert observer.count('projected_soil,terms(28)')==1
    observer=observer.replace('projected_soil,terms(28)','projected_soil',1)
    old='residual=real(sum(real(terms,real128)),8)\nend function'
    assert observer.count(old)==1
    observer=observer.replace(old,'end subroutine',1)
    observer=observer.replace('swdra/=1','swdra/=2')
    anchor='end module MOD_integral';assert text.count(anchor)==1
    return text.replace(anchor,observer+'\n'+anchor,1)


def terminal_source(module):
    text='''module MODULE
  use iso_fortran_env,only:real128
  implicit none
  private
  public::terminal_water_terms,terminal_water_residual
contains
  subroutine terminal_water_terms(terms)
    use MOD_integral,only:hybrid_extended_output_trial_terms
    real(8),intent(out)::terms(28)
    call hybrid_extended_output_trial_terms(terms)
  end subroutine
  real(8) function terminal_water_residual() result(residual)
    use variables,only:tcum,dt
    real(8) :: terms(28)
    call terminal_water_terms(terms)
    residual=real(sum(real(terms,real128)),8)
    if(tcum+dt>=1d0-1d-8)write(*,'(a,29(1x,es25.17e3))') 'EXTENDED_DRAIN_TERMINAL_WATER',residual,terms
  end function
end module MODULE
'''.replace('MODULE',module)
    from extended_trial_receipt import render
    return render(text)
