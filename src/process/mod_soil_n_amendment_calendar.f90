! Immutable daily forcing plan, not a second accepted event/state owner.
module mod_soil_n_amendment_calendar
 use iso_fortran_env,only:real64
 use ieee_arithmetic,only:ieee_is_finite
 use mod_b111_soil_n_addition,only:b111_soil_n_material_t
 implicit none
 private
 integer,parameter,public::N_CALENDAR_OK=0,N_CALENDAR_INVALID=1
 type,public::soil_n_amendment_calendar_t
  private
  logical::valid=.false.
  real(real64)::origin=0d0
  real(real64),allocatable::dates(:),dose_kg_ha(:)
  type(b111_soil_n_material_t),allocatable::definitions(:)
 contains
  procedure::ready=>calendar_ready
 end type
 public::create_soil_n_amendment_calendar,select_soil_n_amendments
contains
 pure logical function calendar_ready(self)result(ok)
  class(soil_n_amendment_calendar_t),intent(in)::self
  ok=self%valid
 end function
 pure logical function material_valid(m)result(ok)
  type(b111_soil_n_material_t),intent(in)::m
  real(real64)::v(7)
  v=[m%application_kg_m2,m%application_age,m%organic_matter_fraction,m%organic_n_fraction, &
    m%ammonium_n_fraction,m%nitrate_n_fraction,m%volatilization_fraction]
  ok=.false.
  if(.not.all(ieee_is_finite(v)))return
  if(v(1)/=0d0.or.v(2)<0d0.or.v(2)>100d0)return
  if(any(v(3:7)<0d0).or.any(v(3:7)>1d0))return
  ok=.true.
 end function
 subroutine create_soil_n_amendment_calendar(origin,dates,dose_kg_ha,definitions,plan,status)
  real(real64),intent(in)::origin,dates(:),dose_kg_ha(:)
  type(b111_soil_n_material_t),intent(in)::definitions(:)
  type(soil_n_amendment_calendar_t),intent(out)::plan
  integer,intent(out)::status
  integer::i,n,same_day
  plan=soil_n_amendment_calendar_t();status=N_CALENDAR_INVALID
  n=size(dates)
  if(n>4096.or.size(dose_kg_ha)/=n.or.size(definitions)/=n)return
  if(.not.ieee_is_finite(origin))return
  if(abs(origin)>1d9-1d0)return
  if(.not.all(ieee_is_finite(dates)).or..not.all(ieee_is_finite(dose_kg_ha)))return
  if(any(abs(dates)>1d9-1d0).or.any(dates<origin))return
  if(any(dose_kg_ha<0d0).or.any(dose_kg_ha>5d5))return
  if(any(dates-origin/=anint(dates-origin)))return
  same_day=0
  do i=1,n
   if(.not.material_valid(definitions(i)))return
   if(i>1)then
    if(dates(i)<dates(i-1))return
    if(dates(i)==dates(i-1))then
     same_day=same_day+1
    else
     same_day=1
    end if
   else
    same_day=1
   end if
   if(same_day>64)return
  end do
  plan%origin=origin;plan%dates=dates;plan%dose_kg_ha=dose_kg_ha;plan%definitions=definitions
  plan%valid=.true.;status=N_CALENDAR_OK
 end subroutine
 subroutine select_soil_n_amendments(plan,t0,t1,materials,record_indices,status)
  type(soil_n_amendment_calendar_t),intent(in)::plan
  real(real64),intent(in)::t0,t1
  type(b111_soil_n_material_t),allocatable,intent(out)::materials(:)
  integer,allocatable,intent(out)::record_indices(:)
  integer,intent(out)::status
  integer::i,n,k
  allocate(materials(0),record_indices(0));status=N_CALENDAR_INVALID
  if(.not.plan%ready())return
  if(.not.all(ieee_is_finite([t0,t1])))return
  if(max(abs(t0),abs(t1))>1d9)return
  if(t0<plan%origin.or.t1-t0/=1d0)return
  if(t0-plan%origin/=anint(t0-plan%origin))return
  ! Literal R2 grouping/trigger on the declared daily grid; preserve file order.
  n=count(abs(plan%dates+1d0-t1)<1d-3)
  deallocate(materials,record_indices);allocate(materials(n),record_indices(n));k=0
  do i=1,size(plan%dates)
   if(abs(plan%dates(i)+1d0-t1)>=1d-3)cycle
   k=k+1;materials(k)=plan%definitions(i);record_indices(k)=i
   materials(k)%application_kg_m2=1d-4*plan%dose_kg_ha(i)
  end do
  status=N_CALENDAR_OK
 end subroutine
end module
