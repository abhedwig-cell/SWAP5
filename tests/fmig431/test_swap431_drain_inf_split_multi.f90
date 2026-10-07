program test_swap431_drain_inf_split_multi
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_process_hydraulic_view, only: process_hydraulic_view_t
  use mod_drainage_spatial_distribution, only: drainage_distribution_parameters_t, drainage_multilevel_diagnostics_t, &
       distribute_multilevel_signed_divdra, DRAIN_DIST_OK
  use mod_drainage_b19_separate_infiltration_adapter, only: drainage_b19_separate_infiltration_parameters_t, &
       drainage_b19_separate_infiltration_result_t, distribute_single_level_separate_infiltration_b19, DRAIN_B19_INF_OK
  use mod_drainage_multilevel_separate_infiltration, only: drainage_multilevel_separate_infiltration_result_t, &
       distribute_multilevel_separate_infiltration_b19, DRAIN_MULTI_INF_OK
  use mod_fmr_divdra_multilevel_separate_infiltration_binding, only: &
       fmr_divdra_multi_inf_binding_diagnostics_t, &
       fmr_bind_multilevel_separate_infiltration, FMR_DIVDRA_MULTI_INF_OK, &
       FMR_DIVDRA_MULTI_INF_TARGET_ALREADY_BOUND
  implicit none

  integer,parameter :: n=5,nlev=3
  type(drainage_distribution_parameters_t) :: levels(nlev),effective(nlev)
  type(process_hydraulic_view_t) :: view
  type(drainage_multilevel_separate_infiltration_result_t) :: result
  type(drainage_b19_separate_infiltration_parameters_t) :: p
  type(drainage_b19_separate_infiltration_result_t) :: direct
  type(drainage_multilevel_diagnostics_t) :: ordinary_diag
  type(fmr_divdra_multi_inf_binding_diagnostics_t) :: bind_diag
  real(real64),allocatable :: ordinary(:,:),published(:,:)
  real(real64) :: scalar(nlev),bottom(nlev),water(nlev)
  real(real64),parameter :: factor=.35_real64,tol=1024._real64*epsilon(1._real64)
  integer :: i

  do i=1,nlev
    levels(i)%active_nodes=n
    allocate(levels(i)%dz(n),levels(i)%zbotcp(n),levels(i)%saturated_conductivity(n), &
         levels(i)%horizontal_anisotropy_factor(n))
    levels(i)%dz=[10._real64,15._real64,20._real64,25._real64,30._real64]
    levels(i)%zbotcp=[-10._real64,-25._real64,-45._real64,-70._real64,-100._real64]
    levels(i)%saturated_conductivity=[1._real64,2._real64,3._real64,4._real64,5._real64]
    levels(i)%horizontal_anisotropy_factor=[1._real64,1.25_real64,.75_real64,2._real64,1.5_real64]
  end do
  levels(1)%drain_spacing=120._real64
  levels(2)%drain_spacing=45._real64
  levels(3)%drain_spacing=70._real64

  view%active_nodes=n
  allocate(view%pressure_head(n),view%water_content(n))
  view%pressure_head=[-5._real64,-10._real64,-20._real64,-30._real64,-40._real64]
  view%water_content=[.30_real64,.31_real64,.32_real64,.33_real64,.34_real64]
  view%groundwater_level=-30._real64
  scalar=[.8_real64,-.55_real64,.25_real64]
  bottom=[-70._real64,-70._real64,-70._real64]
  water=[-10._real64,-8._real64,-12._real64]

  call distribute_multilevel_separate_infiltration_b19(levels,view,scalar,bottom,water,factor,result)
  call require(result%status==DRAIN_MULTI_INF_OK.and.result%available,'multilevel split available')
  call require(all(abs([sum(result%drainage_flux_by_level(1,:)),sum(result%drainage_flux_by_level(2,:)), &
       sum(result%drainage_flux_by_level(3,:))]-scalar)<=tol),'per-level mass closure')
  call require(result%fdisinf(2)>=factor.and.result%fdisinf(2)>0._real64,'negative level FDisInf resolved')
  call require(result%fdisinf(1)==1._real64.and.result%fdisinf(3)==1._real64,'positive levels keep unit factor')

  p%drain_bottom_cm=bottom(2);p%drain_level_cm=water(2);p%infiltration_depth_factor=factor
  call distribute_single_level_separate_infiltration_b19(levels(2),view,scalar(2),p,direct)
  call require(direct%status==DRAIN_B19_INF_OK.and.direct%available,'direct B19 negative row available')
  call require(all(abs(result%drainage_flux_by_level(2,:)-direct%nodal_transfer)<=tol), &
       'negative row is exact B19 reuse')

  effective=levels
  effective(2)%drain_spacing=result%fdisinf(2)*levels(2)%drain_spacing
  call distribute_multilevel_signed_divdra(effective,view,scalar,ordinary,ordinary_diag)
  call require(ordinary_diag%status==DRAIN_DIST_OK,'effective-spacing multilevel geometry available')
  call require(all(abs(result%multilevel%discharge_layer_bottom_depth- &
       ordinary_diag%discharge_layer_bottom_depth)<=tol),'FDisInf drives multilevel geometry exactly')

  call fmr_bind_multilevel_separate_infiltration(levels,view,scalar,bottom,water,factor,published,bind_diag)
  call require(bind_diag%status==FMR_DIVDRA_MULTI_INF_OK.and.bind_diag%published,'binding publishes')
  call require(all(abs(published-result%drainage_flux_by_level)<=tol),'binding exact process matrix')
  deallocate(published)
  allocate(published(nlev,n));published=77._real64
  call fmr_bind_multilevel_separate_infiltration(levels,view,scalar,bottom,water,factor,published,bind_diag)
  call require(bind_diag%status==FMR_DIVDRA_MULTI_INF_TARGET_ALREADY_BOUND,'overwrite fails closed')
  call require(all(published==77._real64),'overwrite target unchanged')

  print '(a)','SW431_DRAIN_INF_SPLIT_MULTI_FDISINF=PASS'
  print '(a)','SW431_DRAIN_INF_SPLIT_MULTI_B19_REUSE=PASS'
  print '(a)','SW431_DRAIN_INF_SPLIT_MULTI_MASS=PASS'
  print '(a)','SW431_DRAIN_INF_SPLIT_MULTI_BINDING=PASS'
  print '(a)','SW431_DRAIN_INF_SPLIT_MULTI=PASS'
contains
  subroutine require(ok,label)
    logical,intent(in)::ok
    character(len=*),intent(in)::label
    if(.not.ok)then
      write(*,'(a,1x,a)')'SW431_INF_SPLIT_MULTI_FAIL',trim(label)
      error stop 431
    end if
  end subroutine
end program
