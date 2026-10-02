module mod_top03_constitutive_cut_probe
 use,intrinsic::iso_fortran_env,only:real64
 use mod_b110_default_mvg_provider,only:b110_default_mvg_parameters_t,evaluate_b110_default_mvg_conductivity
 implicit none
 contains
 subroutine top03_measure_cut(p)
 type(b110_default_mvg_parameters_t),intent(in)::p
 real(real64)::c(size(p%cofgen,1)),s,hcut,theta_cut,delta,klo,khi,jump
 logical::ok1,ok2
 integer::j
 c=p%cofgen(:,1);s=1.0_real64-1e-6_real64
 if(c(9)<=-0.01_real64)error stop 'cut probe only near-zero entry branch'
 theta_cut=c(1)+c(25)*s
 if(theta_cut<=c(26))then
 hcut=-(s**(-1.0_real64/c(7))-1.0_real64)**(1.0_real64/c(6))/c(4)
 else
 hcut=-0.01_real64+(theta_cut-c(26))/c(27)
 end if
 do j=4,9
 delta=10.0_real64**(-j)
 call evaluate_b110_default_mvg_conductivity(p,1,hcut-delta,klo,ok1)
 call evaluate_b110_default_mvg_conductivity(p,1,hcut+delta,khi,ok2)
 if(.not.ok1.or..not.ok2)error stop 'cut oracle failed'
 jump=khi-klo
 if(jump<0.17_real64.or.jump>0.19_real64)error stop 'expected nonvanishing fixture K jump'
 if(abs(khi-c(3))>1e-14_real64)error stop 'cut saturated side mismatch'
 write(*,'(a,7(a,es24.16))')'CUT_ORACLE',',',hcut,',',delta,',',klo,',',khi,',',jump,',',jump/(2.0_real64*delta),',',jump/c(3)
 end do
 end subroutine
end module
