program test_swap431_frost_divdra_multi
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_process_hydraulic_view, only: process_hydraulic_view_t
  use mod_drainage_spatial_distribution, only: drainage_distribution_parameters_t, &
       drainage_multilevel_diagnostics_t, distribute_multilevel_signed_divdra, DRAIN_DIST_OK
  use mod_frost_drainage_effect, only: frost_drainage_result_t, compose_legacy_normal_frost_drainage, FROST_DRAIN_OK
  use mod_frost_low_air_drainage_effect, only: frost_low_air_drainage_result_t, compose_legacy_bracketed_frost_drainage
  implicit none
  integer,parameter :: n=4,levels=2
  type(drainage_distribution_parameters_t) :: p(levels)
  type(process_hydraulic_view_t) :: view
  type(drainage_multilevel_diagnostics_t) :: md
  type(frost_drainage_result_t) :: normal
  type(frost_low_air_drainage_result_t) :: low
  real(real64),allocatable :: proposal(:,:),final(:,:)
  real(real64) :: scalar(levels),temperature(n),theta(n),sat(n),factor(n),dz(n),z(n),distance(n),drain_depth(levels)
  real(real64),parameter :: tol=512.0_real64*epsilon(1.0_real64)
  integer :: i

  dz=1.0_real64
  z=[-.5_real64,-1.5_real64,-2.5_real64,-3.5_real64]
  distance=1.0_real64
  do i=1,levels
    p(i)%active_nodes=n
    allocate(p(i)%dz(n),p(i)%zbotcp(n),p(i)%saturated_conductivity(n),p(i)%horizontal_anisotropy_factor(n))
    p(i)%dz=dz
    p(i)%zbotcp=[-1._real64,-2._real64,-3._real64,-4._real64]
    p(i)%saturated_conductivity=[1._real64,1.5_real64,2._real64,2.5_real64]
    p(i)%horizontal_anisotropy_factor=1._real64
  end do
  p(1)%drain_spacing=8._real64
  p(2)%drain_spacing=4._real64
  view%active_nodes=n
  allocate(view%pressure_head(n),view%water_content(n))
  view%pressure_head=0._real64
  view%water_content=.25_real64
  view%groundwater_level=-.5_real64
  scalar=[.04_real64,-.02_real64]

  call distribute_multilevel_signed_divdra(p,view,scalar,proposal,md)
  call require(md%status==DRAIN_DIST_OK.and.md%evaluated,'multilevel proposal available')
  call require(all(abs([sum(proposal(1,:)),sum(proposal(2,:))]-scalar)<=tol),'proposal per-level mass')

  allocate(final(levels,n))
  temperature=[-1._real64,-1._real64,1._real64,1._real64]
  theta=.20_real64
  sat=.45_real64
  factor=[.3_real64,.6_real64,1._real64,1._real64]
  call compose_legacy_normal_frost_drainage(.true.,temperature,-2._real64,theta,sat,dz,factor,proposal,final,normal)
  call require(normal%status==FROST_DRAIN_OK.and.normal%available,'normal frost accepts multilevel matrix')
  call require(all(abs(final-proposal*spread(factor,1,levels))<=tol),'normal frost nodewise factor composition')
  call require(all(abs(normal%level_rate-[sum(final(1,:)),sum(final(2,:))])<=tol),'normal per-level accounting')
  call require(abs(normal%total_rate-sum(final))<=tol,'normal total single owner')

  theta=.5_real64
  sat=.5_real64
  temperature=[-4._real64,-4._real64,1._real64,1._real64]
  factor=[.01_real64,.01_real64,1._real64,1._real64]
  drain_depth=[-1._real64,-3._real64]
  call compose_legacy_bracketed_frost_drainage(temperature,-4._real64,0._real64,-2._real64,theta,sat,dz,factor,z, &
       distance,drain_depth,proposal,.01_real64,final,low)
  call require(low%available.and.low%low_air_branch,'low-air frost accepts multilevel matrix')
  call require(size(low%blocked_level)==levels,'low-air per-level blocking vector')
  call require(all(abs(low%drainage%level_rate-[sum(final(1,:)),sum(final(2,:))])<=tol),'low-air per-level accounting')
  call require(abs(low%drainage%total_rate-sum(final))<=tol,'low-air total single owner')

  print '(a)','SW431_FROST_DIV_MULTI_PROPOSAL=PASS'
  print '(a)','SW431_FROST_DIV_MULTI_NORMAL=PASS'
  print '(a)','SW431_FROST_DIV_MULTI_LOW_AIR=PASS'
  print '(a)','SW431_FROST_DIV_MULTI=PASS'
contains
  subroutine require(ok,label)
    logical,intent(in)::ok
    character(len=*),intent(in)::label
    if(.not.ok)then
      write(*,'(a,1x,a)')'SW431_FROST_DIV_MULTI_FAIL',trim(label)
      error stop 431
    end if
  end subroutine
end program
