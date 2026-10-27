program test_integrated_wet_wall
 use iso_fortran_env,only:real64
 use mod_macropore_standard_rate_adapter,only:integrate_matrix_wet_wall
 implicit none
 real(real64)::h(3),z(3)=[-0.5_real64,-1.5_real64,-2.5_real64],dz(3)=1
 real(real64)::macro(1,3),wet(3),overlap(1,3)
 logical::ok
 macro=1;h=-1.25_real64-z
 call integrate_matrix_wet_wall(h,z,dz,macro,wet,overlap,ok)
 call check(ok.and.maxval(abs(wet-[0.0_real64,0.75_real64,1.0_real64]))<1e-15_real64,'hydrostatic exact areas')
 call check(all(overlap(1,:)==wet),'full macro overlap')
 macro=0.5_real64
 call integrate_matrix_wet_wall(h,z,dz,macro,wet,overlap,ok)
 call check(ok.and.overlap(1,2)==0.5_real64,'exact lower wet intersection')
 h=[1.0_real64,-1e-8_real64,1.0_real64];macro=1
 call integrate_matrix_wet_wall(h,z,dz,macro,wet,overlap,ok)
 call check(ok.and.abs(wet(2)-1)<3e-8_real64,'vanishing dry pocket is continuous')
 h(2)=0
 call integrate_matrix_wet_wall(h,z,dz,macro,wet,overlap,ok)
 call check(ok.and.wet(2)==1,'zero-pressure point has no dry wall length')
 h=-1
 call integrate_matrix_wet_wall(h,z,dz,macro,wet,overlap,ok)
 call check(ok.and.all(wet==0).and.all(overlap==0),'dry matrix')
 h=1
 call integrate_matrix_wet_wall(h,z,dz,macro,wet,overlap,ok)
 call check(ok.and.all(wet==1).and.all(overlap==1),'wet matrix')
 macro=-1
 call integrate_matrix_wet_wall(h,z,dz,macro,wet,overlap,ok)
 call check(.not.ok.and.all(wet==0).and.all(overlap==0),'invalid input atomic empty output')
 print *,'INTEGRATED_WET_WALL_PASS'
contains
 subroutine check(ok,msg)
 logical,intent(in)::ok
 character(*),intent(in)::msg
 if(.not.ok)then
 print *,msg
 error stop 1
 end if
 end subroutine
end program
