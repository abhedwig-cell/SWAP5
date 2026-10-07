program test_swap431_dislayer
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_drainage_discharge_layer_transform
  implicit none
  real(real64)::dz(4),q(4),top
  type(discharge_layer_diagnostics_t)::d
  integer::st
  dz=[1._real64,1._real64,1._real64,1._real64]
  q=[.1_real64,.2_real64,.3_real64,.4_real64]
  call apply_discharge_layer_top(dz,-1.5_real64,1._real64,q,d)
  call req(d%status==DISLAYER_OK.and.d%top_node==2,'absolute top')
  call req(q(1)==0._real64.and.abs(sum(q)-1._real64)<1e-14_real64,'absolute closure')
  call req(abs(q(2)-.125_real64)<1e-14_real64.and.abs(q(3)-.375_real64)<1e-14_real64.and.abs(q(4)-.5_real64)<1e-14_real64,'absolute redistribution')

  call derive_dynamic_discharge_layer_top(3,.25_real64,-1._real64,-3._real64,1._real64,1._real64,top,st)
  call req(st==DISLAYER_OK.and.abs(top+1.75_real64)<1e-14_real64,'dramet3 dynamic top')
  call derive_dynamic_discharge_layer_top(2,.5_real64,-1._real64,-3._real64,.5_real64,0._real64,top,st)
  call req(st==DISLAYER_OK.and.abs(top-(-1._real64))<1e-14_real64,'dramet2 dynamic top')

  q=[1.e-10_real64,1.e-10_real64,0._real64,0._real64]
  call apply_discharge_layer_top(dz,-1.5_real64,.02_real64,q,d)
  call req(d%small_retained_fallback.and.abs(sum(q)-.02_real64)<1e-14_real64,'small retained fallback')

  print '(A)','SW431_DRAIN_DISLAYER_ABSOLUTE=PASS'
  print '(A)','SW431_DRAIN_DISLAYER_DYNAMIC=PASS'
  print '(A)','SW431_DRAIN_DISLAYER_MASS=PASS'
contains
  subroutine req(ok,label)
    logical,intent(in)::ok
    character(len=*),intent(in)::label
    if(.not.ok)then;write(*,'(A,1X,A)')'DISLAYER_FAIL',trim(label);error stop 84;end if
  end subroutine
end program
