program test_b111_solute_sorption_decay
 use iso_fortran_env, only: real64
 use mod_b111_solute_sorption
 use mod_b111_solute_decay
 implicit none
 type(b111_sorption_result_t)::s,p
 type(b111_decay_result_t)::d
 call b111_sorption_storage_from_concentration(.25d0,1.4d0,.8d0,2d0,.7d0,3d0,s)
 call check(s%status==B111_SORP_OK,'sorption forward status')
 call b111_sorption_partition_total(.25d0,1.4d0,.8d0,2d0,.7d0,s%total_density,3d0,p)
 call check(p%status==B111_SORP_OK,'sorption inverse status')
 call near(p%concentration,3d0,5d-3,'sorption inverse concentration')
 call near(p%total_density,s%total_density,5d-3,'sorption total reconstruction')
 call b111_sorption_storage_from_concentration(.3d0,1.2d0,.5d0,1d0,1d0,4d0,s)
 call b111_sorption_partition_total(.3d0,1.2d0,.5d0,1d0,1d0,s%total_density,0d0,p)
 call near(p%concentration,4d0,1d-12,'linear branch')
 call evaluate_b111_solute_decay(.true.,20d0,.05d0,.25d0,.30d0,2d0,.01d0,.8d0,10d0,d)
 call check(d%status==B111_DECAY_OK,'decay status')
 call near(d%temperature_factor,1d0,1d-12,'decay temp ref')
 call near(d%moisture_factor,(.25d0/.30d0)**2,1d-12,'decay moisture')
 call near(d%transformation_density_rate,.01d0*.8d0*(.25d0/.30d0)**2*10d0,1d-12,'decay mass')
 call evaluate_b111_solute_decay(.false.,20d0,.05d0,.25d0,.30d0,2d0,.01d0,.8d0,10d0,d)
 call near(d%transformation_density_rate,0d0,1d-12,'temperature-off source semantics')
 call evaluate_b111_solute_decay(.true.,40d0,.05d0,.4d0,.3d0,2d0,.01d0,.8d0,10d0,d)
 call near(d%temperature_factor,exp(.05d0*15d0),1d-12,'temperature cap')
 call near(d%moisture_factor,1d0,1d-12,'moisture cap')
 print '(A)','B111_SOLUTE_SORPTION_DECAY_PASS'
contains
 subroutine near(a,b,rtol,label)
  real(real64),intent(in)::a,b,rtol;character(len=*),intent(in)::label
  call check(abs(a-b)<=rtol*max(1d0,abs(a),abs(b)),label)
 end subroutine
 subroutine check(ok,label)
  logical,intent(in)::ok;character(len=*),intent(in)::label
  if(.not.ok)then;print '(A)',trim(label)//' failed';error stop 1;end if
 end subroutine
end program
