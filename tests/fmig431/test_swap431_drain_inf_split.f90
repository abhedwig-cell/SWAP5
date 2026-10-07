program test_swap431_drain_inf_split
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_process_hydraulic_view, only: process_hydraulic_view_t
  use mod_drainage_spatial_distribution, only: drainage_distribution_parameters_t
  use mod_frost_divdra_drainage_effect, only: frost_divdra_parameters_t, frost_divdra_result_t, &
       compose_single_level_signed_frost_divdra, FROST_DIVDRA_OK
  use mod_drainage_b19_separate_infiltration_adapter, only: drainage_b19_separate_infiltration_parameters_t, &
       drainage_b19_separate_infiltration_result_t, distribute_single_level_separate_infiltration_b19, DRAIN_B19_INF_OK
  use mod_fmr_divdra_separate_infiltration_binding, only: fmr_divdra_separate_infiltration_binding_diagnostics_t, &
       fmr_bind_single_level_separate_infiltration, FMR_DIVDRA_INF_SPLIT_OK, &
       FMR_DIVDRA_INF_SPLIT_TARGET_ALREADY_BOUND, FMR_DIVDRA_INF_SPLIT_PROCESS_REJECTED
  implicit none
  integer,parameter :: n=5
  type(drainage_distribution_parameters_t) :: dist
  type(process_hydraulic_view_t) :: view
  type(drainage_b19_separate_infiltration_parameters_t) :: p
  type(drainage_b19_separate_infiltration_result_t) :: a
  type(frost_divdra_parameters_t) :: b19p
  type(frost_divdra_result_t) :: b19
  type(fmr_divdra_separate_infiltration_binding_diagnostics_t) :: bd
  real(real64),allocatable :: factor(:),sat(:),q(:,:)
  real(real64),parameter :: scalar=-0.6_real64
  real(real64),parameter :: tol=512.0_real64*epsilon(1.0_real64)

  dist%active_nodes=n
  allocate(dist%dz(n),dist%zbotcp(n),dist%saturated_conductivity(n),dist%horizontal_anisotropy_factor(n))
  dist%dz=[10._real64,15._real64,20._real64,25._real64,30._real64]
  dist%zbotcp=[-10._real64,-25._real64,-45._real64,-70._real64,-100._real64]
  dist%saturated_conductivity=[1._real64,2._real64,3._real64,4._real64,5._real64]
  dist%horizontal_anisotropy_factor=[1._real64,1.25_real64,.75_real64,2._real64,1.5_real64]
  dist%drain_spacing=80._real64
  view%active_nodes=n
  allocate(view%pressure_head(n),view%water_content(n))
  view%pressure_head=[-5._real64,-10._real64,-20._real64,-30._real64,-40._real64]
  view%water_content=[.30_real64,.31_real64,.32_real64,.33_real64,.34_real64]
  view%groundwater_level=-30._real64
  view%ponding_depth=0._real64

  p%drain_bottom_cm=-70._real64
  p%drain_level_cm=-10._real64
  p%infiltration_depth_factor=.5_real64
  call distribute_single_level_separate_infiltration_b19(dist,view,scalar,p,a)
  call require(a%status==DRAIN_B19_INF_OK.and.a%available,'ordinary B19 adapter available')
  call require(abs(sum(a%nodal_transfer)-scalar)<=tol,'adapter mass closure')

  b19p%distribution=dist
  b19p%drain_bottom_cm=p%drain_bottom_cm
  b19p%separate_infiltration=.true.
  b19p%surface_water_level_cm=p%drain_level_cm
  b19p%infiltration_depth_factor=p%infiltration_depth_factor
  allocate(factor(n),sat(n));factor=1._real64;sat=view%water_content
  call compose_single_level_signed_frost_divdra(b19p,view,factor,-1,0._real64,view%water_content,sat, &
       scalar,0._real64,b19)
  call require(b19%status==FROST_DIVDRA_OK.and.b19%available,'direct B19 neutral invocation')
  call require(all(abs(a%nodal_transfer-b19%final_nodal_sink)<=tol),'adapter exactly reuses B19 partition')

  call fmr_bind_single_level_separate_infiltration(dist,view,scalar,p%drain_bottom_cm,p%drain_level_cm, &
       p%infiltration_depth_factor,q,bd)
  call require(bd%status==FMR_DIVDRA_INF_SPLIT_OK.and.bd%published,'runtime binding publication')
  call require(all(abs(q(1,:)-a%nodal_transfer)<=tol),'binding exact adapter row')
  deallocate(q)

  allocate(q(1,n));q=77._real64
  call fmr_bind_single_level_separate_infiltration(dist,view,scalar,p%drain_bottom_cm,p%drain_level_cm, &
       p%infiltration_depth_factor,q,bd)
  call require(bd%status==FMR_DIVDRA_INF_SPLIT_TARGET_ALREADY_BOUND,'overwrite guard')
  call require(all(abs(q-77._real64)<=tol),'overwrite target unchanged')
  deallocate(q)

  call fmr_bind_single_level_separate_infiltration(dist,view,abs(scalar),p%drain_bottom_cm,p%drain_level_cm, &
       p%infiltration_depth_factor,q,bd)
  call require(bd%status==FMR_DIVDRA_INF_SPLIT_PROCESS_REJECTED,'positive transfer rejected')

  print '(a)','SW431_DRAIN_INF_SPLIT_B19_REUSE=PASS'
  print '(a)','SW431_DRAIN_INF_SPLIT_MASS=PASS'
  print '(a)','SW431_DRAIN_INF_SPLIT_BINDING=PASS'
  print '(a)','SW431_DRAIN_INF_SPLIT_FAIL_CLOSED=PASS'
  print '(a)','SW431_DRAIN_INF_SPLIT=PASS'
contains
  subroutine require(ok,label)
    logical,intent(in)::ok
    character(len=*),intent(in)::label
    if(.not.ok)then
      write(*,'(a,1x,a)')'SW431_INF_SPLIT_FAIL',trim(label)
      error stop 431
    end if
  end subroutine
end program
