program test_swap431_drain_topinterflow
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_process_hydraulic_view, only: process_hydraulic_view_t
  use mod_drainage_spatial_distribution, only: drainage_distribution_parameters_t
  use mod_drainage_top_interflow_distribution, only: drainage_top_interflow_diagnostics_t, &
       distribute_highest_interflow_signed_divdra, DRAIN_TOPINT_OK
  implicit none
  integer,parameter :: n=5, levels=3
  type(drainage_distribution_parameters_t) :: p(levels)
  type(process_hydraulic_view_t) :: v
  type(drainage_top_interflow_diagnostics_t) :: d
  real(real64),allocatable :: q(:,:)
  real(real64) :: s(levels)
  integer :: i
  real(real64),parameter :: tol=256.0_real64*epsilon(1.0_real64)

  do i=1,levels
    p(i)%active_nodes=n
    allocate(p(i)%dz(n),p(i)%zbotcp(n),p(i)%saturated_conductivity(n),p(i)%horizontal_anisotropy_factor(n))
    p(i)%dz=[10.0_real64,15.0_real64,20.0_real64,25.0_real64,30.0_real64]
    p(i)%zbotcp=[-10.0_real64,-25.0_real64,-45.0_real64,-70.0_real64,-100.0_real64]
    p(i)%saturated_conductivity=[1.0_real64,2.0_real64,3.0_real64,4.0_real64,5.0_real64]
    p(i)%horizontal_anisotropy_factor=[1.0_real64,1.25_real64,0.75_real64,2.0_real64,1.5_real64]
  end do
  p(1)%drain_spacing=120.0_real64
  p(2)%drain_spacing=80.0_real64
  p(3)%drain_spacing=40.0_real64
  v%active_nodes=n
  allocate(v%pressure_head(n),v%water_content(n))
  v%pressure_head=0.0_real64
  v%water_content=0.3_real64
  v%groundwater_level=-20.0_real64
  s=[0.6_real64,-0.3_real64,0.2_real64]

  call distribute_highest_interflow_signed_divdra(p,v,s,-45.0_real64,q,d)
  call require(d%status==DRAIN_TOPINT_OK.and.d%evaluated,'exact-boundary route evaluates')
  call require(d%top_interflow_active,'highest interflow active')
  call require(d%top_interflow_bottom_node==3,'physical bottom node')
  call require(all(abs([sum(q(1,:)),sum(q(2,:)),sum(q(3,:))]-s)<=tol),'per-level mass closure')
  call require(all(abs(q(1:2,1:3))<=tol),'lower levels excluded above interflow bottom')
  call require(any(abs(q(3,2:3))>tol),'highest interflow occupies upper layer')

  deallocate(q)
  s(3)=0.0_real64
  call distribute_highest_interflow_signed_divdra(p,v,s,-45.0_real64,q,d)
  call require(d%status==DRAIN_TOPINT_OK.and..not.d%top_interflow_active,'inactive highest level')
  call require(all(abs([sum(q(1,:)),sum(q(2,:)),sum(q(3,:))]-s)<=tol),'inactive highest mass closure')
  call require(any(abs(q(1:2,2))>tol),'lower levels retain original groundwater top when highest inactive')

  print '(a)','SW431_DRAIN_TOPINTERFLOW_BOUNDARY=PASS'
  print '(a)','SW431_DRAIN_TOPINTERFLOW_MASS=PASS'
  print '(a)','SW431_DRAIN_TOPINTERFLOW_INACTIVE=PASS'
  print '(a)','SW431_DRAIN_TOPINTERFLOW=PASS'
contains
  subroutine require(ok,label)
    logical,intent(in)::ok
    character(len=*),intent(in)::label
    if(.not.ok)then
      write(*,'(a,1x,a)')'SW431_TOPINTERFLOW_FAIL',trim(label)
      error stop 431
    end if
  end subroutine
end program
