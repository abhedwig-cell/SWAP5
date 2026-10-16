program test_input
 use iso_fortran_env,only:real64
 use mod_soil_n_amendment_input
 use mod_soil_n_amendment_calendar
 use mod_b111_soil_n_addition,only:b111_soil_n_material_t
 implicit none
 type(soil_n_amendment_calendar_t)::plan
 type(b111_soil_n_material_t),allocatable::m(:)
 integer,allocatable::ix(:)
 character(512)::mode,path,origin,arg
 character(32)::date
 integer::code,line,expected,unit,ios,count
 real(real64)::day,want
 call get_command_argument(1,mode);call get_command_argument(2,path)
 if(trim(mode)=='dates')then
  open(newunit=unit,file=trim(path),status='old');count=0
  do
   read(unit,*,iostat=ios)date,want
   if(ios<0)exit
   if(ios/=0)error stop 10
   call parse_soil_n_date(trim(date),day,code)
   if(want<0d0)then
    if(code==0)error stop 11
   else
    if(code/=0.or.day/=want)error stop 12
   end if
   count=count+1
  end do
  close(unit);print '(A,I0)','INDEPENDENT_GREGORIAN_CASES=',count;stop
 end if
 call get_command_argument(3,origin);call get_command_argument(4,arg);read(arg,*)expected
 call read_soil_n_amendment_tables(trim(path),trim(origin),plan,code,line)
 if(expected<0)then
  if(code==0.or.plan%ready())error stop 1
  call select_soil_n_amendments(plan,0d0,1d0,m,ix,code)
  if(code==0.or.size(m)/=0.or.size(ix)/=0)error stop 2
  print '(A)','INVALID_INPUT_NO_PUBLISHED_PLAN=PASS';stop
 end if
 if(code/=0.or..not.plan%ready().or.line/=0)then
  print *, 'read diagnostics',code,line,trim(path)
  error stop 3
 end if
 call parse_soil_n_date(trim(origin),day,code)
 call select_soil_n_amendments(plan,day,day+1d0,m,ix,code)
 if(code/=0.or.size(m)/=expected)error stop 4
 if(trim(mode)=='literal')then
  if(expected/=2.or.any(ix/=[1,2]))error stop 5
  if(m(1)%application_kg_m2/=1d-4*100d0.or.m(2)%application_kg_m2/=1d-4*200d0)error stop 6
  if(m(1)%application_age/=3.16d0.or.m(2)%application_age/=.99d0)error stop 7
  if(m(1)%ammonium_n_fraction/=.01d0.or.m(2)%nitrate_n_fraction/=.03d0)error stop 8
  if(m(1)%volatilization_fraction/=.1d0.or.m(2)%volatilization_fraction/=.2d0)error stop 9
  ! Read failure must invalidate an already valid output object as well.
  call read_soil_n_amendment_tables('absent-amendment-input.snm',trim(origin),plan,code,line)
  if(code==0.or.plan%ready())error stop 13
  call read_soil_n_amendment_tables(trim(path),trim(origin),plan,code,line)
  if(code/=0.or..not.plan%ready())error stop 14
  call select_soil_n_amendments(plan,day+2d0,day+3d0,m,ix,code)
  if(code/=0.or.size(m)/=0)error stop 15
  call select_soil_n_amendments(plan,day,day+1d0,m,ix,code)
  if(code/=0.or.size(m)/=2.or.any(ix/=[1,2]))error stop 16
 end if
 print '(A)','INPUT_ACTUAL_CALENDAR_UNITS_POSITIONS_EMPTY_ABA_RESET=PASS'
end program
