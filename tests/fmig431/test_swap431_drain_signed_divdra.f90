program test_swap431_drain_signed_divdra
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_process_hydraulic_view, only: process_hydraulic_view_t
  use mod_drainage_spatial_distribution, only: drainage_distribution_parameters_t, drainage_node_transfer_t, &
       drainage_distribution_diagnostics_t, distribute_single_level_positive_divdra, distribute_single_level_signed_divdra, &
       DRAIN_DIST_OK, DRAIN_DIST_TRANSFER_BELOW_ADMITTED_MAGNITUDE
  use mod_fmr_divdra_runtime_binding, only: fmr_divdra_binding_diagnostics_t, &
       fmr_bind_single_level_positive_divdra, fmr_bind_single_level_signed_divdra, &
       FMR_DIVDRA_BIND_OK, FMR_DIVDRA_BIND_PROCESS_REJECTED, FMR_DIVDRA_BIND_TARGET_ALREADY_BOUND
  implicit none
  integer, parameter :: n=5
  type(drainage_distribution_parameters_t) :: p
  type(process_hydraulic_view_t) :: h
  type(drainage_node_transfer_t) :: pos, neg
  type(drainage_distribution_diagnostics_t) :: pd, nd
  type(fmr_divdra_binding_diagnostics_t) :: bd
  real(real64), allocatable :: q(:,:)
  real(real64), parameter :: scalar=0.75_real64
  real(real64), parameter :: tol=128.0_real64*epsilon(1.0_real64)

  p%active_nodes=n
  allocate(p%dz(n),p%zbotcp(n),p%saturated_conductivity(n),p%horizontal_anisotropy_factor(n))
  p%dz=[10._real64,15._real64,20._real64,25._real64,30._real64]
  p%zbotcp=[-10._real64,-25._real64,-45._real64,-70._real64,-100._real64]
  p%saturated_conductivity=[1._real64,2._real64,3._real64,4._real64,5._real64]
  p%horizontal_anisotropy_factor=[1._real64,1.25_real64,.75_real64,2._real64,1.5_real64]
  p%drain_spacing=80._real64
  h%active_nodes=n
  allocate(h%pressure_head(n),h%water_content(n))
  h%pressure_head=[-5._real64,-10._real64,-20._real64,-30._real64,-40._real64]
  h%water_content=[.30_real64,.31_real64,.32_real64,.33_real64,.34_real64]
  h%groundwater_level=-30._real64

  call distribute_single_level_positive_divdra(p,h,scalar,pos,pd)
  call require(pd%status==DRAIN_DIST_OK,'positive preservation provider')
  call distribute_single_level_signed_divdra(p,h,-scalar,neg,nd)
  call require(nd%status==DRAIN_DIST_OK,'negative signed provider')
  call require(all(abs(neg%soil_to_drain_rate+pos%soil_to_drain_rate)<=tol),'signed partition exact sign mirror')
  call require(abs(sum(neg%soil_to_drain_rate)+scalar)<=tol,'negative scalar mass closure')

  call fmr_bind_single_level_signed_divdra(p,h,-scalar,q,bd)
  call require(bd%status==FMR_DIVDRA_BIND_OK .and. bd%published,'signed binding publication')
  call require(size(q,1)==1 .and. size(q,2)==n,'signed binding shape')
  call require(all(abs(q(1,:)-neg%soil_to_drain_rate)<=tol),'signed binding exact row')
  deallocate(q)

  call fmr_bind_single_level_positive_divdra(p,h,-scalar,q,bd)
  call require(bd%status==FMR_DIVDRA_BIND_PROCESS_REJECTED,'legacy positive API still rejects negative')
  call require(.not.allocated(q),'legacy negative rejection publishes nothing')

  call fmr_bind_single_level_signed_divdra(p,h,-1.0e-10_real64,q,bd)
  call require(bd%status==FMR_DIVDRA_BIND_PROCESS_REJECTED,'signed small magnitude fails closed')
  call require(bd%process_status==DRAIN_DIST_TRANSFER_BELOW_ADMITTED_MAGNITUDE,'signed small status propagated')
  call require(.not.allocated(q),'small rejection publishes nothing')

  allocate(q(1,n)); q=99._real64
  call fmr_bind_single_level_signed_divdra(p,h,-scalar,q,bd)
  call require(bd%status==FMR_DIVDRA_BIND_TARGET_ALREADY_BOUND,'signed overwrite guard')
  call require(all(q==99._real64),'signed overwrite leaves target unchanged')

  print '(a)','SW431_DRAIN_SIGNED_POSITIVE_PRESERVATION=PASS'
  print '(a)','SW431_DRAIN_SIGNED_NEGATIVE_MASS=PASS'
  print '(a)','SW431_DRAIN_SIGNED_BINDING=PASS'
  print '(a)','SW431_DRAIN_SIGNED_FAIL_CLOSED=PASS'
  print '(a)','SW431_DRAIN_SIGNED_DIVDRA=PASS'
contains
  subroutine require(ok,label)
    logical,intent(in)::ok
    character(len=*),intent(in)::label
    if(.not.ok)then
      write(*,'(a,1x,a)')'SW431_DRAIN_SIGNED_FAIL',trim(label)
      error stop 431
    end if
  end subroutine
end program
