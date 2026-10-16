program test_b111_sorption_mass_closure
 use iso_fortran_env, only: real64
 use mod_b111_solute_sorption
 implicit none
 type(b111_sorption_result_t)::r
 real(real64)::x,exponent,scale
 integer::i,j
 do j=1,3
  select case(j)
  case(1);exponent=2.0_real64
  case(2);exponent=0.5_real64
  case(3);exponent=1.0005_real64
  end select
  do i=1,10000
   x=0.1_real64+real(i,real64)/100.0_real64
   call b111_sorption_partition_total(0.2_real64,0.1_real64,1.0_real64,1.0_real64,exponent,x,2.0_real64,r)
   if(r%status/=B111_SORP_OK)then
    print *, 'partition status failed',i,j,r%status
    error stop 1
   endif
   scale=max(1.0_real64,x)
   if(abs(r%total_density-x)>8192.0_real64*epsilon(1.0_real64)*scale)then
    print *, 'partition mass mismatch',i,j,exponent,r%total_density-x
    error stop 2
   endif
  enddo
 enddo
 print '(A)','B111_SORPTION_MASS_CLOSURE_PASS'
end program
