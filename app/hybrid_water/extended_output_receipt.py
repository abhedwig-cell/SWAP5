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
    text=text.replace(anchor,observer+'\n'+COUNTERS+'\n'+anchor,1)
    anchor='   use MOD_integral_global';assert text.count(anchor)==1
    text=text.replace(anchor,'   use iso_fortran_env,only:extended_output_real=>real128\n'+anchor,1)
    anchor='   public\n';assert text.count(anchor)==1
    declarations='''   logical,save::extended_counter_active=.false.
   real(8),save::extended_counter_origin(2)=0d0
   real(8),allocatable,save::extended_level_origin(:)
   real(extended_output_real),save::extended_counter_sum(2)=0
   real(extended_output_real),allocatable,save::extended_level_sum(:)
'''
    text=text.replace(anchor,declarations+anchor,1)
    anchor='call begin_output_receipt(hybrid_output_frame,';assert text.count(anchor)==1
    text=text.replace(anchor,'call hybrid_extended_counter_begin()\n'+anchor,1)
    for selector,kind in [('flzerocumu','1'),('flzerointr','2')]:
        anchor='      if (iTask == 1 .OR. '+selector+') then';assert text.count(anchor)==1
        text=text.replace(anchor,anchor+'\n         call hybrid_extended_counter_reset('+kind+')',1)
    return text


COUNTERS='''subroutine hybrid_extended_counter_begin()
use MOD_drain,only:nrlevs
if(allocated(extended_level_origin))deallocate(extended_level_origin,extended_level_sum)
allocate(extended_level_origin(nrlevs),extended_level_sum(nrlevs))
extended_counter_origin=[iqdra,iruno];extended_level_origin=cqdrain(1:nrlevs)
extended_counter_sum=0;extended_level_sum=0
extended_counter_active=.true.
end subroutine
subroutine hybrid_extended_counter_reset(kind)
use MOD_drain,only:nrlevs
use variables,only:t1900
integer,intent(in)::kind
if(.not.extended_counter_active)return
if(kind==1)then
 write(*,'(a,1x,i0,*(1x,es25.17e3))') 'HYBRID_EXTENDED_OUTPUT_COUNTER_RESET',kind,t1900,cqdrain(1:nrlevs),extended_level_origin
 extended_level_sum=extended_level_sum+real(cqdrain(1:nrlevs),extended_output_real)-real(extended_level_origin,extended_output_real)
 extended_level_origin=0d0
else if(kind==2)then
 write(*,'(a,1x,i0,*(1x,es25.17e3))') 'HYBRID_EXTENDED_OUTPUT_COUNTER_RESET',kind,t1900,iqdra,iruno,extended_counter_origin
 extended_counter_sum=extended_counter_sum+real([iqdra,iruno],extended_output_real)-real(extended_counter_origin,extended_output_real)
 extended_counter_origin=0d0
else
 error stop 'Foreign extended output counter reset'
end if
end subroutine
subroutine hybrid_extended_counter_read(counters,levels)
use MOD_drain,only:nrlevs
real(8),intent(out)::counters(2),levels(nrlevs)
if(.not.extended_counter_active)error stop 'Inactive extended original counters'
counters=real(extended_counter_sum+real([iqdra,iruno],extended_output_real)-real(extended_counter_origin,extended_output_real),8)
levels=real(extended_level_sum+real(cqdrain(1:nrlevs),extended_output_real)-real(extended_level_origin,extended_output_real),8)
end subroutine
'''


def state_source(text):
    """Retain raw interval counters and bind the day transfer to its real owner."""
    anchor='  subroutine extended_drain_witness()';assert text.count(anchor)==1
    prefix,text=text.split(anchor,1);prefix+=anchor
    old='    use MOD_integral, only: iqdra,iruno,cqdrain';assert text.count(old)==1
    text=text.replace(old,old+',hybrid_extended_counter_read\n    use hybrid_age_output_state,only:hybrid_output_frame',1)
    old='    real(8), allocatable :: values(:)';assert text.count(old)==1
    text=text.replace(old,old+'\n    real(8)::original_counters(2)\n    real(8),allocatable::original_levels(:)',1)
    old="      if (origin_pending.or.accepted_steps<1) error stop 'Empty extended drain accepted window'"
    assert text.count(old)==1
    text=text.replace(old,old+'''
      allocate(original_levels(nrlevs))
      call hybrid_extended_counter_read(original_counters,original_levels)
      if(maxval(abs(original_counters-[hybrid_output_frame%flow_cm(14),hybrid_output_frame%flow_cm(9)]))>1d-10) &
        error stop 'Original reset segments differ from full-day transfer'
      write(*,'(a,*(1x,es25.17e3))') 'HYBRID_EXTENDED_OUTPUT_INTERVAL_COUNTERS', &
        t1900,iqdra,iruno,cqdrain(1:nrlevs),original_counters,original_levels
''',1)
    old='        stock_origin,swst,real(flux,8),iqdra,iruno, &\n        cqdrain(1:nrlevs)-original_level_origin,real(level_flux,8)'
    assert text.count(old)==1
    return prefix+text.replace(old,'''        stock_origin,swst,real(flux,8),hybrid_output_frame%flow_cm(14),hybrid_output_frame%flow_cm(9), &
        original_levels,real(level_flux,8)''',1)


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
