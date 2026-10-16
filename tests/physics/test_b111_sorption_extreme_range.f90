program test_sorption_extremes
 use iso_fortran_env,only:real64
 use mod_b111_solute_sorption
 implicit none
 type(b111_sorption_result_t)::r
 integer::i,j
 real(real64)::x,p,tol
 real(real64),parameter::exps(4)=[0.5_real64,1.0005_real64,2.0_real64,4.0_real64]
 do j=1,size(exps)
   p=exps(j)
   do i=1,10000
     x=10.0_real64**(-10.0_real64+real(i-1,real64)*14.0_real64/9999.0_real64)
     call b111_sorption_partition_total(0.2_real64,0.1_real64,1.0_real64,1.0_real64,p,x,1.0_real64,r)
     if(r%status/=B111_SORP_OK)then
       print *, 'FAIL status',j,i,p,x,r%status
       error stop 1
     endif
     tol=8192.0_real64*epsilon(1.0_real64)*max(1.0_real64,x)
     if(abs(r%total_density-x)>tol)then
       print *, 'FAIL closure',j,i,p,x,r%total_density-x
       error stop 2
     endif
   enddo
 enddo
 print *, 'SORPTION_EXTREMES_PASS',size(exps)*10000
end program
