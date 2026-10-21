program test_perf01_empty_pond_mass
 use iso_fortran_env,only:real64
 use mod_b111_pond_solute_exchange,only:old_result=>b111_pond_solute_result_t,old_evaluate=>evaluate_b111_pond_solute_exchange
 use mod_perf01_candidate_pond_solute_exchange,only:new_result=>b111_pond_solute_result_t,new_evaluate=>evaluate_b111_pond_solute_exchange
 implicit none
 type(old_result)::a
 type(new_result)::b
 real(real64)::before,dt,q,p,macro,runoff
 integer::j,k
 real(real64),parameter::times(4)=[8.907733573954024d-7,1d-12,1d-5,.1d0]
 before=2.1175823681357508d-22
 dt=times(1);q=-.99997375599011162d0
 call old_evaluate(before,.25d0,.125d0,.25d0,.375d0,q,0d0,0d0,dt,a,.5d0,3d0,0d0)
 if(a%status/=1.or.a%mass_after>=0d0)error stop 'actual negative-roundoff counterexample missing'
 print '(A,ES25.17E3)','ACTUAL_INCUMBENT_EMPTY_POND_MASS=',a%mass_after
 do j=1,size(times)
  dt=times(j)
  do k=0,7
   before=real(k,real64)*2.1175823681357508d-22
   call new_evaluate(before,.25d0,.125d0,.25d0,.375d0,q,0d0,0d0,dt,b,.5d0,3d0,0d0)
   if(b%status/=0.or.b%mass_after/=0d0.or.b%balance_residual/=0d0)error stop 'exact zero-pool conservation'
   if(b%soil_transfer/=before+b%rain_input+b%irrigation_input+b%runon_input)error stop 'all available solute enters soil'
  enddo
 enddo
 do k=1,3
  p=0d0;macro=0d0;runoff=0d0
  if(k==1)p=1d-7
  if(k==2)macro=.2d0
  if(k==3)runoff=1d-8
  call old_evaluate(before,.25d0,.125d0,.25d0,.375d0,q,macro,p,dt,a,.5d0,3d0,runoff)
  call new_evaluate(before,.25d0,.125d0,.25d0,.375d0,q,macro,p,dt,b,.5d0,3d0,runoff)
  if(a%status/=b%status.or.a%mass_after/=b%mass_after.or.a%pond_concentration/=b%pond_concentration.or. &
     a%soil_transfer/=b%soil_transfer.or.a%runoff_output/=b%runoff_output)error stop 'general mixing branch changed'
 enddo
 print '(A)','EMPTY_POND_EXACT_MASS_LIMIT_AND_INCUMBENT_NEGATIVE_ROUNDOFF_PASS'
end program
