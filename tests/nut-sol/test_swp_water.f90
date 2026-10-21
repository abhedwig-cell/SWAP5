program swp_water_contract
 use iso_fortran_env,only:real64
 use mod_column_swp_water
 implicit none
 real(real64)::width(256)
 real(real64),allocatable::heads(:),cofgen(:,:)
 integer::n,i
 character(1024)::path
 call get_command_argument(1,path)
 call import_column_swp_water(trim(path),n,width,heads,cofgen)
 do i=1,n
   print '(A,I0,9ES25.16)','NODE ',i,width(i),heads(i),cofgen(1:7,i)
 end do
 print '(A)','SWP_WATER_CONTRACT_COMPLETED'
end program
