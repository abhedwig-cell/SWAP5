! Adapter for the bounded daily ETref MET format, using original TTUTIL.
! This executable prepares forcing; it owns no accepted water or solute state.
program read_swp_daily
  use iso_fortran_env, only: real64
  use ieee_arithmetic, only: ieee_is_finite
  use mod_reference_et_demand_process,only:reference_et_demand_parameters_t,reference_et_demand_forcing_t, &
    reference_et_demand_canopy_view_t,reference_et_demand_result_t,reference_et_demand_diagnostics_t, &
    evaluate_restricted_reference_et_demand,REF_ET_DEMAND_OK
  implicit none
  integer :: n,i,mode,u,datea(6),first,last
  integer,allocatable :: dd(:),mm(:),yyyy(:)
  real(real64),allocatable :: tmin(:),tmax(:),rain(:),etref(:),times(:)
  real(real64) :: tstart,tend
  character(1024) :: swp,met,declared
  character(32)::option
  logical::with_etref
  type(reference_et_demand_parameters_t)::parameters
  type(reference_et_demand_forcing_t)::forcing
  type(reference_et_demand_canopy_view_t)::canopy
  type(reference_et_demand_result_t)::demand
  type(reference_et_demand_diagnostics_t)::diagnostics
  logical :: rdinqr
  call get_command_argument(1,swp)
  call get_command_argument(2,met)
  call get_command_argument(3,option)
  with_etref=trim(option)=='etref'
  call require(len_trim(option)==0.or.with_etref,'unknown daily input mode')
  call rdinit(74,0,trim(swp))
  call rdstim('tstart',tstart)
  call rdstim('tend',tend)
  call require(ieee_is_finite(tstart).and.ieee_is_finite(tend),'nonfinite calendar')
  call require(tstart==aint(tstart).and.tend==aint(tend),'whole-day calendar required')
  call require(tend>=tstart.and.tend-tstart<2048d0,'calendar outside capacity')
  call rdscha('metfil',declared)
  call lowerc(declared)
  call require(trim(declared)==trim(met),'METFIL must match explicitly staged MET basename')
  call require(index(trim(met),'/')==0.and.index(trim(met),'..')==0,'single MET basename required')
  n=len_trim(met)
  call require(n>=5,'MET filename')
  call require(met(n-3:n)=='.met','single-file .MET format required')
  call rdsinr('swetr',0,1,mode);call require(mode==1,'only prescribed daily ETref selected')
  call rdsinr('swcrop',0,2,mode);call require(mode==0,'live crop route not selected')
  call rdsinr('swrain',0,3,mode);call require(mode==0,'only uniform daily rainfall selected')
  call rdsinr('swsnow',0,1,mode);call require(mode==0,'snow coupling not selected')
  call rdsinr('swhea',0,2,mode);call require(mode==0,'heat coupling not selected')
  if(rdinqr('swmetdetail'))then
    call rdsinr('swmetdetail',0,1,mode);call require(mode==0,'subdaily MET not selected')
  end if
  if(rdinqr('swfrost'))then
    call rdsinr('swfrost',0,1,mode);call require(mode==0,'frost not selected')
  end if
  if(rdinqr('swdivide'))then
    call rdsinr('swdivide',0,1,mode);call require(mode==0,'PM-direct not selected')
  end if
  if(with_etref)then
    call rdsinr('swredu',0,2,mode);call require(mode==0,'empirical evaporation not selected')
    call rdsinr('swcfbs',0,1,mode);call require(mode==0,'soil factor not selected')
    call rdsdor('cfevappond',0d0,10d0,parameters%pond_evaporation_factor)
    if(rdinqr('swevap'))then
      call rdsinr('swevap',0,1,mode);call require(mode==1,'disabled evaporation not selected')
    end if
  end if
  close(74)
  call rdinit(74,0,trim(met))
  call rdinne('yyyy',n)
  call require(n>=1.and.n<=100000,'MET record capacity')
  allocate(dd(n),mm(n),yyyy(n),tmin(n),tmax(n),rain(n),etref(n),times(n))
  ! Same native fields, units and daily ETref ranges as LoadMeteoData.
  call rdfinr('dd',1,31,dd,n,n)
  call rdfinr('mm',1,12,mm,n,n)
  call rdfint('yyyy',yyyy,n,n)
  call rdfdor('tmin',-1d5,1d5,tmin,n,n)
  call rdfdor('tmax',-1d5,1d5,tmax,n,n)
  call rdfdor('rain',0d0,1d3,rain,n,n)
  call rdfdor('etref',-0.00001d0,100d0,etref,n,n)
  close(74)
  call require(all(ieee_is_finite(tmin)).and.all(ieee_is_finite(tmax)).and. &
    all(ieee_is_finite(rain)).and.all(ieee_is_finite(etref)),'nonfinite MET')
  ! Original LoadMeteoData only rejects forward gaps. Index slicing also needs
  ! strictly consecutive records: reject duplicates/reversed dates explicitly.
  do i=1,n
    datea=0;datea(1:3)=[yyyy(i),mm(i),dd(i)]
    call dtardp(datea,0.0,times(i))
    if(i>1)call require(times(i)-times(i-1)==1d0,'MET dates must be consecutive and unique')
  end do
  call require(times(1)<=tstart.and.times(n)>=tend,'incomplete MET calendar')
  first=nint(tstart-times(1))+1;last=nint(tend-times(1))+1
  ! Positive ETref requires soil/crop/pond partitioning, not a rain-only adapter.
  if(with_etref)then
    call require(all(etref(first:last)>=0d0),'negative ETref not selected')
  else
    call require(all(etref(first:last)==0d0),'nonzero ETref needs physical evaporation coupling')
  end if
  open(newunit=u,file='daily.csv',status='new',action='write')
  if(with_etref)then
    write(u,'(A)')'end_day,t1900,rain_cm_day,tmin_c,tmax_c,tav_c,etref_mm_day,soil_demand_cm_day,pond_demand_cm_day'
  else
    write(u,'(A)')'end_day,t1900,rain_cm_day,tmin_c,tmax_c,tav_c,etref_cm_day'
  end if
  do i=first,last
    write(u,'(I0,6(A,ES25.16E3))',advance='no')i-first+1,',',times(i),',',rain(i)*0.1d0, &
      ',',tmin(i),',',tmax(i),',',(tmax(i)+tmin(i))*0.5d0,',',etref(i)
    if(with_etref)then
      forcing%reference_et_mm_per_day=etref(i)
      call evaluate_restricted_reference_et_demand(parameters,forcing,canopy,demand,diagnostics)
      call require(diagnostics%status==REF_ET_DEMAND_OK.and.diagnostics%result_produced,'ETref demand rejected')
      write(u,'(2(A,ES25.16E3))')',',demand%potential_soil_evaporation_cm_per_day, &
        ',',demand%potential_pond_evaporation_cm_per_day
    else
      write(u,'(A)')''
    end if
  end do
  close(u)
  print '(A)','SWP_NATIVE_DAILY_MET_IMPORTED'
contains
  subroutine require(ok,message)
    logical,intent(in)::ok
    character(*),intent(in)::message
    if(.not.ok)then
      print '(A)','SWP_DAILY_REJECTED: '//message
      error stop 1
    end if
  end subroutine
end program
