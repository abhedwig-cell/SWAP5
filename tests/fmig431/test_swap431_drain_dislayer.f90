program test_swap431_drain_dislayer
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_process_hydraulic_view, only: process_hydraulic_view_t
  use mod_drainage_discharge_layer_top, only: drainage_discharge_layer_top_control_t, &
       drainage_discharge_layer_top_diagnostics_t, redistribute_discharge_layer_top, &
       DRAIN_TOP_OK, DRAIN_TOP_ABSOLUTE, DRAIN_TOP_RELATIVE, DRAIN_TOP_SOURCE_OTHER, DRAIN_TOP_SOURCE_DRAMET2
  implicit none
  real(real64) :: dz(4),row(4),scalar
  real(real64),allocatable :: out(:)
  type(process_hydraulic_view_t) :: v
  type(drainage_discharge_layer_top_control_t) :: c
  type(drainage_discharge_layer_top_diagnostics_t) :: d
  real(real64),parameter :: tol=1.0e-13_real64
  dz=[10.0_real64,10.0_real64,10.0_real64,10.0_real64]
  row=[0.1_real64,0.2_real64,0.3_real64,0.4_real64]
  scalar=1.0_real64
  v%groundwater_level=-5.0_real64

  c%active=.true.
  c%mode=DRAIN_TOP_ABSOLUTE
  c%absolute_top_level_cm=-15.0_real64
  call redistribute_discharge_layer_top(dz,scalar,c,v,row,out,d)
  call require(d%status==DRAIN_TOP_OK.and.d%top_node==2,'absolute top node')
  call require(abs(sum(out)-scalar)<tol,'absolute mass closure')
  call require(abs(out(1))<tol,'absolute truncation')
  deallocate(out)

  c%mode=DRAIN_TOP_RELATIVE
  c%source_family=DRAIN_TOP_SOURCE_OTHER
  c%top_fraction=0.5_real64
  c%source_head_difference_cm=20.0_real64
  call redistribute_discharge_layer_top(dz,scalar,c,v,row,out,d)
  call require(abs(d%resolved_top_level_cm+15.0_real64)<tol,'relative non-DRAMET2 resolver')
  deallocate(out)

  c%source_family=DRAIN_TOP_SOURCE_DRAMET2
  c%drain_bottom_cm=-30.0_real64
  c%shape=2.0_real64
  c%top_fraction=0.5_real64
  call redistribute_discharge_layer_top(dz,scalar,c,v,row,out,d)
  call require(d%status==DRAIN_TOP_OK,'relative DRAMET2 resolver')
  call require(abs(sum(out)-scalar)<tol,'relative mass closure')

  print '(a)','SW431_DRAIN_DISLAYER_ABSOLUTE=PASS'
  print '(a)','SW431_DRAIN_DISLAYER_RELATIVE=PASS'
  print '(a)','SW431_DRAIN_DISLAYER_MASS=PASS'
  print '(a)','SW431_DRAIN_DISLAYER=PASS'
contains
  subroutine require(ok,label)
    logical,intent(in)::ok
    character(len=*),intent(in)::label
    if(.not.ok)then
      write(*,'(a,1x,a)')'SW431_DISLAYER_FAIL',trim(label)
      error stop 431
    end if
  end subroutine
end program
