program test_ksatexm_input
 use iso_fortran_env,only:real64
 use mod_column_swp_water
 use mod_b110_default_mvg_provider
 implicit none
 real(real64)::width(256),pond,k1,k0
 real(real64),allocatable::heads(:),cof(:,:)
 type(b110_default_mvg_parameters_t)::active,inactive
 integer::n,i,bottom
 logical::ok
 character(1024)::path,bbc
 call get_command_argument(1,path);call get_command_argument(2,bbc)
 if(len_trim(bbc)>0)then
  call rdinit(75,0,trim(bbc));call rdsinr('swbotb',1,8,bottom);close(75)
  call import_column_swp_water(trim(path),n,width,heads,cof,source_pond=pond, &
    initial_bottom_mode=bottom,allow_ksatexm=.true.)
 else
  call import_column_swp_water(trim(path),n,width,heads,cof,source_pond=pond,allow_ksatexm=.true.)
 end if
 call initialize_b110_default_mvg_parameters(active,cof,enable_ksatexm_extension=.true.)
 call initialize_b110_default_mvg_parameters(inactive,cof)
 do i=1,n
  call evaluate_b110_default_mvg_conductivity(active,i,1d0,k1,ok)
  if(.not.ok.or.abs(k1-max(cof(3,i),cof(10,i)))>1d-11*max(1d0,k1))error stop 'saturated source conductivity'
  call evaluate_b110_default_mvg_conductivity(active,i,-5d0,k1,ok)
  if(.not.ok)error stop 'active below threshold'
  call evaluate_b110_default_mvg_conductivity(inactive,i,-5d0,k0,ok)
  if(.not.ok.or.k1/=k0)error stop 'below threshold preservation'
  write(*,'(A,I0,12(1x,ES25.17E3))')'NODE ',i,cof(1:12,i)
 end do
 print '(A)','KSATEXM_REAL_INPUT_AND_PROVIDER_PASS'
end program
