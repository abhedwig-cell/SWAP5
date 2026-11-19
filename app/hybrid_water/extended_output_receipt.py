"""Read the existing daily output frame across original subdaily resets."""
import math
import struct
from datetime import date,timedelta


def validate_candidate(raw,receipt,project):
    """Validate the composed typed calendar before launching a physical worker."""
    from extended_drainage import size,selection
    from original_output import selection as output_selection
    selected=output_selection(project);n=project.nodes;r=selection(project)['levels']
    prefix=raw[:-size(project)];expected_reals=6068+10*n+(3*n+3)*r
    def require(ok,message):
        if not ok:raise ValueError('Original extended drain output '+message)
    positions=[];marker=struct.pack('<2i',1,n);at=prefix.find(marker)
    while at>=0:
        if at+160<=len(prefix):
            header=struct.unpack_from('<20i',prefix,at)
            if header[:4]==(1,n,r,expected_reals) and prefix[at:at+80]==prefix[at+80:at+160]:positions.append((at,header))
        at=prefix.find(marker,at+1)
    require(len(positions)==1,'calendar shape/witness differs');at,h=positions[0]
    end=at+160+16*expected_reals
    extra=20+8*(3*n+41+r) if project.age else 24+16*(18+n) if project.solute else 0
    require(end+extra==len(prefix),'private section size differs')
    day=receipt['day'];period=selected['period'];step=selected['flprintdt'];npd=selected['nprintday']
    completed=date.fromisoformat(project.start_date)+timedelta(days=day-1)
    counter=min(day,completed.timetuple().tm_yday) if selected['swres'] and period else day
    if period and not step:counter%=period
    short=step or npd>1
    require((h[4],h[5],h[6],h[7],h[8],h[11],h[18],h[19])==
            (period,npd,day,counter,1 if step or not short else day*npd+1,selected['swres'],int(short),int(step)),
            'calendar policy/day/counters differ')
    require(all(value in (0,1) for value in h[12:20]) and all(1<=value<=3000 for value in h[9:11]),'calendar flags/pointers differ')
    first=prefix[at+160:at+160+8*expected_reals]
    require(first==prefix[at+160+8*expected_reals:end],'calendar value witness differs')
    values=struct.unpack('<'+str(expected_reals)+'d',first)
    require(all(map(math.isfinite,values)) and values[-1]>=0,'calendar values nonfinite/negative')
    clock=project.start_clock;balance=values[-6008:-3008];interval=values[-3008:-8]
    require(h[9]==1+sum(0<value<clock+day-1e-8 for value in balance),'balance date pointer differs')
    past=0<interval[0]<clock-1e-8;expected=1 if past else 1+sum(0<value<clock+day-1e-8 for value in interval)
    require(h[10]==1 if past else h[10]<=expected if step else h[10]==expected,'interval date pointer differs')
    if project.solute:
        header=struct.unpack_from('<3i',prefix,end)
        require(header==(1,n,18+n) and header==struct.unpack_from('<3i',prefix,end+12),'CDE private shape differs')
        first=prefix[end+24:end+24+8*(18+n)]
        require(first==prefix[end+24+8*(18+n):],'CDE private value witness differs')
        values=struct.unpack('<'+str(18+n)+'d',first)
        require(all(map(math.isfinite,values)) and values[0]>=0,'CDE private values invalid')
    if project.age:
        body=struct.unpack_from('<'+str(3*n+41+r)+'d',prefix,end)
        require(all(map(math.isfinite,body)) and min(body[:3*n+3])>=0,'AGE private values invalid')
        require(body[3*n+3:3*n+6]==(0.,0.,0.) and list(body[3*n+6:3*n+14])==receipt['age_state_cm_day'][3:],'AGE forcing/cumulative state differs')
        totals=struct.unpack_from('<3d',prefix,len(prefix)-44);exports=struct.unpack_from('<16d',prefix,len(prefix)-172)
        require(list(totals)==receipt['age_state_cm_day'][:3] and list(exports)==receipt['age_effluent'][:16],'AGE stock/effluent receipt differs')
        saved_day=struct.unpack_from('<i',prefix,len(prefix)-20)[0];saved_period=struct.unpack_from('<d',prefix,len(prefix)-16)[0]
        flags=struct.unpack_from('<2i',prefix,len(prefix)-8)
        require(saved_day==day and saved_period==values[-1] and flags==h[12:14],'AGE private clock/reset differs')


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
use variables,only:t1900
if(allocated(extended_level_origin))deallocate(extended_level_origin,extended_level_sum)
allocate(extended_level_origin(nrlevs),extended_level_sum(nrlevs))
extended_counter_origin=[iqdra,iruno];extended_level_origin=cqdrain(1:nrlevs)
extended_counter_sum=0;extended_level_sum=0
extended_counter_active=.true.
write(*,'(a,*(1x,es25.17e3))') 'HYBRID_EXTENDED_OUTPUT_COUNTER_BEGIN',t1900,iqdra,iruno,cqdrain(1:nrlevs)
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
