program test_calendar_contract
 use iso_fortran_env,only:real64
 use ieee_arithmetic,only:ieee_value,ieee_quiet_nan
 use mod_b111_amendment_calendar
 use mod_b111_soil_n_addition,only:b111_soil_n_material_t
 implicit none
 type(amendment_calendar_row_t)::rows(3),bad(3)
 type(b111_soil_n_material_t)::defs(2),wrong(2)
 type(b111_soil_n_material_t),allocatable::selected(:)
 type(amendment_calendar_t)::calendar,invalid
 real(real64)::days(3),dose(3),amount(3),evaluation
 logical::due(3)
 integer::code,index,i,j,groups,cases
 character(40)::mode
 call get_command_argument(1,mode)
 if(trim(mode)=='legacy-unsorted')then
  call literal_calendar([1d0,0d0],[10d0,20d0],2,1d0,amount(:2),due(:2),groups)
  error stop 'original source failed to reject unsorted dates'
 end if
 defs(1)%application_age=3.16d0;defs(1)%organic_matter_fraction=.5d0;defs(1)%organic_n_fraction=.025d0
 defs(1)%ammonium_n_fraction=.02d0;defs(1)%nitrate_n_fraction=.01d0
 defs(2)=defs(1);defs(2)%application_age=.99d0;defs(2)%nitrate_n_fraction=.03d0
 days=[0d0,2d0,5d0];dose=[400d0,100d0,0d0]
 do i=1,3
  rows(i)%source_day=days(i);rows(i)%dosage_kg_ha=dose(i)
  rows(i)%material_index=merge(2,1,i==2);rows(i)%volatilization_fraction=.1d0*i
 end do
 call initialize_amendment_calendar(0d0,7d0,rows,defs,calendar,code)
 call require(code==AMCAL_OK.and.calendar%ready(),'valid original-compatible calendar')
 do i=0,6
  call literal_calendar(days,dose,3,real(i+1,real64),amount,due,groups)
  call require(groups==3,'original grouping is singleton on sorted daily domain')
  call calendar%select_day(real(i,real64),real(i+1,real64),selected,index,code)
  call require(code==0.and.size(selected)==count(due),'original trigger day selection')
  if(size(selected)==1)then
   j=findloc(due,.true.,dim=1)
   call require(index==j.and.selected(1)%application_kg_m2==amount(j),'original kg/ha and row association')
   call require(selected(1)%application_age==defs(rows(j)%material_index)%application_age,'complete definition association')
   call require(selected(1)%nitrate_n_fraction==defs(rows(j)%material_index)%nitrate_n_fraction,'material index composition')
   call require(selected(1)%volatilization_fraction==rows(j)%volatilization_fraction,'per-event volatilization')
  else
   call require(index==0,'empty day index')
  end if
 end do
 cases=0
 do i=-120,120
  evaluation=1d0+real(i,real64)*1d-5
  call literal_calendar(days,dose,3,evaluation,amount,due,groups)
  call require(b111_amendment_due(0d0,evaluation).eqv.due(1),'original strict trigger boundary')
  cases=cases+1
 end do
 do i=1,15
  bad=rows;wrong=defs
  select case(i)
  case(1);bad(2)%source_day=bad(1)%source_day
  case(2);bad(2)%source_day=-1d0
  case(3);bad(2)%source_day=.0005d0
  case(4);bad(2)%source_day=ieee_value(0d0,ieee_quiet_nan)
  case(5);bad(2)%source_day=huge(1d0)
  case(6);bad(3)%material_index=3
  case(7);bad(2)%material_index=0
  case(8);bad(3)%dosage_kg_ha=-1d0
  case(9);bad(3)%dosage_kg_ha=500001d0
  case(10);bad(3)%volatilization_fraction=1.01d0
  case(11);bad(3)%volatilization_fraction=ieee_value(0d0,ieee_quiet_nan)
  case(12);wrong(2)%application_age=huge(1d0)
  case(13);wrong(1)%application_kg_m2=1d0
  case(14);wrong(1)%volatilization_fraction=.1d0
  case(15);wrong(1)%nitrate_n_fraction=ieee_value(0d0,ieee_quiet_nan)
  end select
  call initialize_amendment_calendar(0d0,7d0,bad,wrong,invalid,code)
  call require(code/=0.and..not.invalid%ready(),'invalid complete calendar rejected')
 end do
 call calendar%select_day(0d0,2d0,selected,index,code);call require(code/=0.and.size(selected)==0,'invalid interval no forcing')
 call calendar%select_day(.0005d0,1.0005d0,selected,index,code);call require(code/=0,'fractional interval rejected')
 call initialize_amendment_calendar(1d0,7d0,rows,defs,invalid,code)
 call require(code/=0,'past first event not silently skipped')
 call initialize_amendment_calendar(0d0,7d0,rows(:0),defs(:0),invalid,code)
 call invalid%select_day(0d0,1d0,selected,index,code)
 call require(code==0.and.size(selected)==0,'empty calendar valid inactive forcing')
 call require(all(rows%source_day==days).and.all(rows%dosage_kg_ha==dose),'constructor input nonmutation')
 ! Equal dates remain two legacy groups, demonstrating why they are outside this domain.
 call literal_calendar([0d0,0d0],[1d0,2d0],2,1d0,amount(:2),due(:2),groups)
 call require(groups==2,'immutable grouping conflict retained')
 print '(A,I0)','CALENDAR_LITERAL_TRIGGER_CASES=',cases
 print '(A)','CALENDAR_REAL_UNITS_INDEX_SORT_DOMAIN_15_INVALID_EMPTY=PASS'
contains
 subroutine require(ok,label)
  logical,intent(in)::ok
  character(*),intent(in)::label
  if(.not.ok)then;print *,label;error stop 1;end if
 end subroutine
end program
