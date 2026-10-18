program native_labels
 use iso_fortran_env,only:real64
 use mod_soil_n_unified_input
 use mod_soil_n_historical_activation
 use mod_soil_n_amendment_calendar
 use mod_b111_soil_n_addition
 implicit none
 type(soil_n_amendment_calendar_t)::plan
 type(soil_n_historical_initial_t)::initial
 type(soil_n_historical_rates_t)::rates
 type(b111_soil_n_material_t),allocatable::items(:)
 integer,allocatable::indices(:)
 integer::code,line,expected
 character(512)::path,arg
 call get_command_argument(1,path);call get_command_argument(2,arg);read(arg,*)expected
 call read_soil_n_snm_keyword_file(trim(path),'1900-12-30',plan,initial,rates,code,line)
 if(expected<0)then
  if(code==0.or.plan%ready().or.line/=-expected)error stop 1
  if(any(initial%fom_kg_m3/=0d0))error stop 2
 else
  if(code/=0.or..not.plan%ready())then
   print *,code,line;error stop 3
  end if
  call select_soil_n_amendments(plan,365d0,366d0,items,indices,code)
  if(code/=0.or.size(items)/=2.or.any(indices/=[2,3]))error stop 4
  ! iMat [2,1,2]: date365 selects first then second row, regardless of labels.
  if(items(1)%ammonium_n_fraction/=.21d0.or.items(2)%ammonium_n_fraction/=.07d0)error stop 5
  if(items(1)%nitrate_n_fraction/=.10d0.or.items(2)%nitrate_n_fraction/=.03d0)error stop 6
  if(abs(items(1)%application_kg_m2-.005d0)>1d-15.or.abs(items(2)%application_kg_m2-.0025d0)>1d-15)error stop 7
 end if
 print '(A)','NATIVE_LABEL_POSITION_OR_ATOMIC_REJECTION=PASS'
end program
