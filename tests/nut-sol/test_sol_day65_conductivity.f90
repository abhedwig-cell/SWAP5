program test_sol_day65_conductivity
 use iso_fortran_env,only:real64
 use mod_b110_default_mvg_provider
 implicit none
 type(b110_default_mvg_parameters_t),target::legacy,continuous
 type(b110_default_mvg_provider_t)::old_provider,new_provider
 real(real64)::cof(24,2),h(2),theta(2),k(2),cap(2),dk(2),newtheta(2),newk(2),newcap(2),newdk(2)
 real(real64)::cutoff(2),below(2),above(2),smoothbelow(2),smoothabove(2)
 integer::i,j
 ! Exact two-layer coefficients in the retained day65 original SWP fixture.
 cof=0d0;cof(1,:)=[.032d0,.04d0];cof(2,:)=[.423d0,.45d0]
 cof(3,:)=[10d0,2d0];cof(4,:)=[.0135d0,.02d0];cof(5,:)=[.365d0,.4d0];cof(6,:)=[1.455d0,1.6d0]
 cof(7,:)=1d0-1d0/cof(6,:)
 call initialize_b110_default_mvg_parameters(legacy,cof)
 continuous=legacy;continuous%continuous_saturation_conductivity=.true.
 call bind_b110_default_mvg_provider(old_provider,legacy,1d-3)
 call bind_b110_default_mvg_provider(new_provider,continuous,1d-3)
 do i=1,2
  cutoff(i)=-(( (1d0-1d-6)**(-1d0/cof(7,i))-1d0)**(1d0/cof(6,i)))/cof(4,i)
 end do
 do j=1,2
  h=cutoff+merge(-1d-8,1d-8,j==1)
  call old_provider%evaluate(h,theta,k,cap,dk)
  call new_provider%evaluate(h,newtheta,newk,newcap,newdk)
  if(any(newtheta/=theta).or.any(newcap/=cap))error stop 'retention or capacity changed'
  if(j==1)then
   below=k;smoothbelow=newk
  else
   above=k;smoothabove=newk
  end if
 end do
 do i=1,2
  if(above(i)/=cof(3,i))error stop 'legacy early saturated branch not reproduced'
  if((above(i)-below(i))/cof(3,i)<.01d0)error stop 'missing material legacy conductivity jump'
  if(abs(smoothabove(i)-smoothbelow(i))/cof(3,i)>1d-6)error stop 'continuous candidate still jumps'
  if(smoothabove(i)<smoothbelow(i))error stop 'nonmonotone candidate'
  write(*,'(A,I0,5(1X,ES25.17E3))')'CUTOFF_LAYER ',i,cutoff(i),below(i),above(i),smoothbelow(i),smoothabove(i)
 end do
 h=-75d0;call old_provider%evaluate(h,theta,k,cap,dk);call new_provider%evaluate(h,newtheta,newk,newcap,newdk)
 if(any(k/=newk).or.any(theta/=newtheta))error stop 'dry domain drift'
 h=0d0;call new_provider%evaluate(h,newtheta,newk,newcap,newdk)
 if(any(newk/=cof(3,:)).or.any(newtheta/=cof(2,:)))error stop 'saturated endpoint drift'
 print *, 'SOL_DAY65_REAL_CONDUCTIVITY_CUTOFF_AND_CONTINUOUS_CURVE_PASS'
end program
