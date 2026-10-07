program test_b111_solute_sorption_partition
 use iso_fortran_env,only:real64
 use mod_solute_mobile_salt_state
 use mod_solute_compartment_state
 use mod_b111_solute_sorption_partition
 implicit none
 type(mobile_salt_state_t)::m,mc
 type(solute_compartment_state_t)::s,sc
 type(b111_sorption_partition_receipt_t)::r
 integer::status
 real(real64)::w(2),dz(2),bd(2),kf(2),cref(2),frexp(2),before
 w=[.25d0,.3d0];dz=[10d0,12d0];bd=[1.4d0,1.3d0];kf=[.8d0,.4d0];cref=[2d0,2d0];frexp=[.7d0,1d0]
 call initialize_mobile_salt_state(dz,w,[3d0,1.5d0],m,status)
 call check(status==SOLUTE_OK,'mobile init')
 call initialize_solute_compartment_state([4d0,2d0],0d0,0d0,[0d0,0d0],s,status)
 call check(status==SOLCOMP_OK,'companion init')
 before=sum(m%mass_mg_cm2)+sum(s%sorbed_matrix_mass)
 call repartition_b111_solute_sorption(m,s,w,dz,bd,kf,cref,frexp,mc,sc,r)
 call check(r%status==B111_SORP_PARTITION_OK,'partition status')
 call near(sum(mc%mass_mg_cm2)+sum(sc%sorbed_matrix_mass),before,'combined conserved')
 call near(r%balance_residual,0d0,'receipt balance')
 call check(all(mc%mass_mg_cm2>=0d0).and.all(sc%sorbed_matrix_mass>=0d0),'nonnegative')
 call near(sum(m%mass_mg_cm2),3d0*.25d0*10d0+1.5d0*.3d0*12d0,'committed unchanged')
 print '(A)','B111_SOLUTE_SORPTION_PARTITION_PASS'
contains
 subroutine near(x,y,label)
  real(real64),intent(in)::x,y;character(len=*),intent(in)::label
  call check(abs(x-y)<=5d-10*max(1d0,abs(x),abs(y)),label)
 end subroutine
 subroutine check(ok,label)
  logical,intent(in)::ok;character(len=*),intent(in)::label
  if(.not.ok)then;print '(A)',trim(label)//' failed';error stop 1;end if
 end subroutine
end program
