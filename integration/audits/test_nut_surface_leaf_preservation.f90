program leaf_preservation
 use iso_fortran_env,only:real64,int64
 use mod_b111_pond_solute_exchange
 use old_pond_reference,only:old_evaluate=>evaluate_b111_pond_solute_exchange,old_result=>b111_pond_solute_result_t
 implicit none
 type(b111_pond_solute_result_t)::r
 type(old_result)::old
 real(real64)::m,rr,ir,runon,c,q,a,v,dt,ro,x(9),y(9),available,storage
 integer::i,unchanged,corrected
 unchanged=0;corrected=0
 do i=1,20000
  dt=real(mod(i,31)+1,real64)*1d-4
  rr=.05d0*real(mod(i,5)+1,real64);ir=.005d0;runon=.01d0
  c=real(mod(i,17)+1,real64)*.0005d0;q=-(rr+ir+runon)
  a=0d0;if(mod(i,3)==0)a=.2d0
  v=0d0;if(mod(i,4)==0)v=.2d0
  ro=0d0;if(mod(i,5)==0)ro=.003d0
  m=0d0;if(mod(i,7)==0)m=.001d0
  call old_evaluate(m,rr,c,ir,c,q,a,v,dt,old,runon,c,ro)
  call evaluate_b111_pond_solute_exchange(m,rr,c,ir,c,q,a,v,dt,r,runon,c,ro)
  x=[old%mass_before,old%rain_input,old%irrigation_input,old%runon_input,old%pond_concentration, &
    old%soil_transfer,old%runoff_output,old%mass_after,old%balance_residual]
  y=[r%mass_before,r%rain_input,r%irrigation_input,r%runon_input,r%pond_concentration, &
    r%soil_transfer,r%runoff_output,r%mass_after,r%balance_residual]
  if(old%status==B111_POND_SOL_OK.or.a/=0d0)then
   call require(r%status==old%status.and.all(transfer(x,[0_int64],9)==transfer(y,[0_int64],9)), &
      'previous accepted result or macropore identity changed')
   unchanged=unchanged+1
  else
   call require(old%mass_after<0d0.and.r%status==B111_POND_SOL_OK,'unrelated rejection changed')
   storage=v*r%pond_concentration
   call require(r%mass_after==storage.and.r%mass_after>=0d0,'independent algebraic storage')
   available=m+(rr+ir+runon)*c*dt
   call require(abs(r%mass_after+r%soil_transfer+r%runoff_output-available)<= &
     16d0*epsilon(1d0)*max(tiny(1d0),available),'existing conservative floating-point budget')
   corrected=corrected+1
  endif
 enddo
 call require(corrected>100.and.unchanged>10000,'case diversity')
 call evaluate_b111_pond_solute_exchange(-1d0,.05d0,.001d0,0d0,0d0,-.05d0,0d0,0d0,1d0,r)
 call require(r%status/=B111_POND_SOL_OK,'negative incoming mass still rejects')
 print *,'POND_PRESERVED_AND_CORRECTED_CASES',unchanged,corrected
 print '(A)','POND_PREVIOUS_SUCCESS_BITS_MACROPORE_AND_ANALYTIC_EMPTYING=PASS'
contains
 subroutine require(ok,label)
  logical,intent(in)::ok
  character(*),intent(in)::label
  if(.not.ok)then
   print *,label;error stop 1
  endif
 endsubroutine
endprogram
