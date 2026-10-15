program test_calendar
 use iso_fortran_env,only:real64
 use ieee_arithmetic,only:ieee_value,ieee_quiet_nan
 use mod_b111_soil_n_addition,only:b111_soil_n_material_t
 use mod_soil_n_amendment_calendar
 implicit none
 type(soil_n_amendment_calendar_t)::plan,bad,empty
 type(b111_soil_n_material_t)::m(4),defs(4)
 type(b111_soil_n_material_t),allocatable::chosen(:)
 integer,allocatable::indices(:)
 real(real64)::dates(4),dose(4),d(4),q(4),v,total
 integer::code,i,day,negative
 dates=[0d0,0d0,1d0,3d0];dose=[100d0,200d0,300d0,400d0]
 m%application_age=1d0;m%organic_matter_fraction=.5d0;m%organic_n_fraction=.02d0
 do i=1,4
  m(i)%ammonium_n_fraction=.01d0*real(i,real64);m(i)%volatilization_fraction=.1d0*real(i,real64)
 end do
 call create_soil_n_amendment_calendar(0d0,dates,dose,m,plan,code)
 call require(code==0.and.plan%ready(),'immutable plan initialize')
 total=0d0
 do day=0,3
  call select_soil_n_amendments(plan,real(day,real64),real(day+1,real64),chosen,indices,code)
  call require(code==0,'daily selection')
  write(*,'(A,I1,A,I1,A,8I3)')'SELECT_DAY=',day,' COUNT=',size(indices),' INDICES=',indices
  do i=1,size(indices)
   call require(chosen(i)%application_kg_m2==1d-4*dose(indices(i)),'single unit conversion')
   call require(chosen(i)%ammonium_n_fraction==m(indices(i))%ammonium_n_fraction.and. &
    chosen(i)%volatilization_fraction==m(indices(i))%volatilization_fraction,'material identity/order')
   total=total+chosen(i)%application_kg_m2
  end do
 end do
 call require(abs(total-.1d0)<=1d-15,'all corrected source mass')
 call select_soil_n_amendments(plan,0d0,1d0,chosen,indices,code)
 call require(code==0.and.all(indices==[1,2]),'pure plan A/B/A, no consumed forcing cursor')
 call create_soil_n_amendment_calendar(0d0,dates(:0),dose(:0),m(:0),empty,code)
 call require(code==0.and.empty%ready(),'empty valid forcing')
 call select_soil_n_amendments(empty,0d0,1d0,chosen,indices,code)
 call require(code==0.and.size(chosen)==0,'empty day')
 negative=0
 do i=1,14
  d=dates;q=dose;defs=m;v=0d0
  select case(i)
  case(1);d(1)=ieee_value(0d0,ieee_quiet_nan)
  case(2);d(4)=1d100
  case(3);d(4)=.5d0
  case(4);d(1)=-1d0
  case(5);d(3)=4d0
  case(6);q(2)=-1d0
  case(7);q(2)=500001d0
  case(8);q(2)=ieee_value(0d0,ieee_quiet_nan)
  case(9);defs(2)%ammonium_n_fraction=1.01d0
  case(10);defs(2)%application_kg_m2=.01d0
  case(11);defs(2)%application_age=100.01d0
  case(12);defs(2)%volatilization_fraction=-.1d0
  case(13);v=ieee_value(0d0,ieee_quiet_nan)
  case(14);v=1d100
  end select
  call create_soil_n_amendment_calendar(v,d,q,defs,bad,code)
  call require(code/=0.and..not.bad%ready(),'invalid plan not published')
  call select_soil_n_amendments(bad,0d0,1d0,chosen,indices,code)
  call require(code/=0.and.size(chosen)==0,'invalid plan fail closed');negative=negative+1
 end do
 call create_soil_n_amendment_calendar(0d0,[(0d0,i=1,65)],[(1d0,i=1,65)],[(m(1),i=1,65)],bad,code)
 call require(code/=0,'per-day batch bound');negative=negative+1
 call create_soil_n_amendment_calendar(0d0,dates,dose(:3),m,bad,code)
 call require(code/=0,'shape bounds before access');negative=negative+1
 do i=1,4
  v=0d0;q(1)=1d0
  select case(i)
  case(1);v=ieee_value(0d0,ieee_quiet_nan)
  case(2);v=1d100
  case(3);q(1)=2d0
  case(4);v=.5d0;q(1)=1.5d0
  end select
  call select_soil_n_amendments(plan,v,q(1),chosen,indices,code)
  call require(code/=0.and.size(chosen)==0,'query finite/grid/window bounds');negative=negative+1
 end do
 call require(negative==20,'all20 invalid paths')
 call select_soil_n_amendments(plan,0d0,1d0,chosen,indices,code)
 call require(code==0.and.all(indices==[1,2]).and.all(dates==[0d0,0d0,1d0,3d0]).and. &
  all(dose==[100d0,200d0,300d0,400d0]),'original plan/inputs unchanged')
 print '(A)','CALENDAR_R2_SOURCE_ORDER_UNITS_20_INVALID_EMPTY_ABA=PASS'
contains
 subroutine require(ok,label)
  logical,intent(in)::ok
  character(*),intent(in)::label
  if(.not.ok)then;print *,'FAIL ',label;error stop 1;end if
 end subroutine
end program
