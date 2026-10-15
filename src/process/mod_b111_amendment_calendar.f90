! Immutable external forcing, never a physical state or consumed-event owner.
module mod_b111_amendment_calendar
 use iso_fortran_env,only:real64
 use ieee_arithmetic,only:ieee_is_finite
 use mod_b111_soil_n_addition,only:b111_soil_n_material_t
 implicit none
 private
 integer,parameter,public::AMCAL_OK=0,AMCAL_INVALID=1
 type,public::amendment_calendar_row_t
  real(real64)::source_day=0d0,dosage_kg_ha=0d0,volatilization_fraction=0d0
  integer::material_index=0
 end type
 type,public::amendment_calendar_t
  private
  real(real64)::first_day=0d0,end_day=0d0
  real(real64),allocatable::days(:)
  type(b111_soil_n_material_t),allocatable::materials(:)
 contains
  procedure::ready=>calendar_ready
  procedure::select_day=>calendar_select_day
 end type
 public::initialize_amendment_calendar,b111_amendment_due
contains
 pure logical function bounded_integer_day(day)result(ok)
  real(real64),intent(in)::day
  ok=.false.
  if(.not.ieee_is_finite(day))return
  if(abs(day)>1d8)return
  ok=day==real(nint(day),real64)
 end function
 pure logical function b111_amendment_due(source_day,evaluation_day)result(due)
  real(real64),intent(in)::source_day,evaluation_day
  due=.false.
  if(.not.all(ieee_is_finite([source_day,evaluation_day])))return
  if(max(abs(source_day),abs(evaluation_day))>1d8)return
  due=abs(source_day+1d0-evaluation_day)<1d-3
 end function
 subroutine initialize_amendment_calendar(first_day,end_day,rows,definitions,calendar,status)
  real(real64),intent(in)::first_day,end_day
  type(amendment_calendar_row_t),intent(in)::rows(:)
  type(b111_soil_n_material_t),intent(in)::definitions(:)
  type(amendment_calendar_t),intent(out)::calendar
  integer,intent(out)::status
  type(amendment_calendar_t)::trial
  real(real64)::v(7)
  integer::i,k
  calendar=amendment_calendar_t();status=AMCAL_INVALID
  if(.not.bounded_integer_day(first_day).or..not.bounded_integer_day(end_day))return
  if(end_day<=first_day.or.size(rows)>3660.or.size(definitions)>64)return
  do i=1,size(definitions)
   associate(m=>definitions(i))
    v=[m%application_kg_m2,m%application_age,m%organic_matter_fraction,m%organic_n_fraction, &
       m%ammonium_n_fraction,m%nitrate_n_fraction,m%volatilization_fraction]
   end associate
   if(.not.all(ieee_is_finite(v)))return
   if(v(1)/=0d0.or.v(7)/=0d0.or.v(2)<0d0.or.v(2)>100d0)return
   if(minval(v(3:6))<0d0.or.maxval(v(3:6))>1d0)return
  end do
  allocate(trial%days(size(rows)),trial%materials(size(rows)))
  do i=1,size(rows)
   if(.not.bounded_integer_day(rows(i)%source_day))return
   if(rows(i)%source_day<first_day.or.rows(i)%source_day>=end_day)return
   if(i>1)then
    ! No sorting or disputed same/near-date grouping correction.
    if(rows(i)%source_day<=rows(i-1)%source_day)return
   end if
   if(.not.all(ieee_is_finite([rows(i)%dosage_kg_ha,rows(i)%volatilization_fraction])))return
   if(rows(i)%dosage_kg_ha<0d0.or.rows(i)%dosage_kg_ha>500000d0)return
   if(rows(i)%volatilization_fraction<0d0.or.rows(i)%volatilization_fraction>1d0)return
   k=rows(i)%material_index
   if(k<1.or.k>size(definitions))return
   trial%days(i)=rows(i)%source_day;trial%materials(i)=definitions(k)
   trial%materials(i)%application_kg_m2=1d-4*rows(i)%dosage_kg_ha
   trial%materials(i)%volatilization_fraction=rows(i)%volatilization_fraction
  end do
  trial%first_day=first_day;trial%end_day=end_day
  calendar=trial;status=AMCAL_OK
 end subroutine
 pure logical function calendar_ready(self)result(ok)
  class(amendment_calendar_t),intent(in)::self
  ok=allocated(self%days).and.allocated(self%materials)
 end function
 subroutine calendar_select_day(self,t0,t1,materials,event_index,status)
  class(amendment_calendar_t),intent(in)::self
  real(real64),intent(in)::t0,t1
  type(b111_soil_n_material_t),allocatable,intent(out)::materials(:)
  integer,intent(out)::event_index,status
  integer::i
  allocate(materials(0));event_index=0;status=AMCAL_INVALID
  if(.not.self%ready())return
  if(.not.bounded_integer_day(t0).or..not.bounded_integer_day(t1))return
  if(t1-t0/=1d0.or.t0<self%first_day.or.t1>self%end_day)return
  status=AMCAL_OK
  do i=1,size(self%days)
   if(self%days(i)>t0)exit
   if(.not.b111_amendment_due(self%days(i),t1))cycle
   deallocate(materials);allocate(materials(1));materials(1)=self%materials(i)
   event_index=i;return
  end do
 end subroutine
end module
