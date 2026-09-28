module MOD_swap_base
  implicit none
  character(len=256) :: project=''
  integer :: swscre=0, swmacro=0, swsolve=1, swirfix=0, swinco=0, swrain=0, swmetdetail=0, swrunon=0
  logical :: fl_initialize=.false.
end module

module MOD_meteo
  implicit none
  logical :: fl_update_meteo=.false.
  integer :: meteo_rec=1, i_metdetail=1, rain_rec=1
  real(8) :: raintim(32)=0.0d0, dt_meteo=1.0d0
end module

module MOD_runon
  implicit none
  integer :: runon_rec=1
  real(8) :: runontim(32)=0.0d0
end module

module MOD_swap_mp
  implicit none
  logical :: fldecmprat=.false.
end module

module plant_interface
  implicit none
  integer :: sw_inter=0
  real(8) :: dt_interc_event=1.0d0
end module

module MOD_irrigation
  implicit none
  logical :: flheadirg=.false., flirrigate=.false.
  integer :: nirri=1
  real(8) :: dt_irr_event=1.0d0
contains
  subroutine irrigation(task)
    integer,intent(in)::task
    if(task<0) error stop 'unreachable'
  end subroutine
end module

module variables
  implicit none
  logical :: fldecdt=.false., flrunend=.false., fldaystart=.false., fldtmin=.false.
  logical :: flzerointr=.false., flzerocumu=.false., floutput=.false., flheader=.false.
  logical :: flbaloutput=.false., flprintdt=.false., flprintshort=.false., fldayend=.false.
  logical :: floutputshort=.false.
  integer :: nprintday=1, period=1, isteps=0, ioutdat=1, ioutdatint=1, cntper=0, nprintcount=1
  integer :: iyear=2000, daynr=1, daycum=1, imonth=1, msteps=1000, swheader=0, swres=0
  integer :: numbit=0, maxit=8, numbit_crit=4
  real(8) :: outper=0.0d0, t1900=0.0d0, tstart=0.0d0, t=0.0d0, tcum=0.0d0, tend=1.0d0
  real(8) :: dt=0.01d0, dtold=0.01d0, dtmin=0.001d0, dtmax=0.02d0
  real(8) :: fact_dt_increase=2.0d0, fact_dt_decrease=0.5d0, fact_dt_fldect=2.0d0, timjan1=0.0d0
  real(8) :: outdatint(64)=0.0d0, outdat(64)=0.0d0
  character(len=11) :: date='2000-01-01'
end module
