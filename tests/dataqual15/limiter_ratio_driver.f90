program limiter_ratio_driver
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_ppa_wu05a6_top_inflow_limiter
  implicit none
  type(standard_inflow_limit_request_t) :: q
  type(standard_inflow_limit_result_t) :: r
  character(len=1024) :: fixture
  real(real64) :: small
  integer :: u,nd

  call get_command_argument(1,fixture)
  open(newunit=u,file=trim(fixture),status='old',action='read')
  read(u,*) q%conservative_storage_bounds,nd
  q%num_domains=nd
  allocate(q%accepted_storage_cm(nd),q%maximum_storage_cm(nd),q%minimum_storage_cm(nd), &
    q%potential_top_vertical_cm(nd),q%potential_top_lateral_cm(nd),q%potential_interflow_sat_cm(nd), &
    q%potential_matrix_sat_cm(nd),q%potential_outflow_cm(nd),q%redistribution_capacity_cm(nd),q%top_domain_fraction(nd))
  read(u,*) q%accepted_storage_cm,q%maximum_storage_cm,q%minimum_storage_cm, &
    q%potential_top_vertical_cm,q%potential_top_lateral_cm,q%potential_interflow_sat_cm, &
    q%potential_matrix_sat_cm,q%potential_outflow_cm,q%redistribution_capacity_cm,q%top_domain_fraction
  close(u)
  if(.not.q%valid())error stop 'actual native limiter request invalid'
  call evaluate_standard_inflow_limit(q,r)
  if(.not.r%valid)error stop 'actual native limiter receipt refused'
  if(any(.not.ieee_is_finite(r%outflow_fraction)))error stop 'nonfinite actual fraction'
  if(any(r%outflow_fraction<0d0).or.any(r%outflow_fraction>1d0))error stop 'actual fraction bounds'
  if(any(r%outflow_fraction/=1d0))error stop 'actual sufficient-stock demand limited'

  ! Independent one-domain stock cases: zero demand, sufficient stock with
  ! subnormal demand, dry stock and exactly half of a representable demand.
  q%num_domains=1;q%conservative_storage_bounds=.true.
  q%accepted_storage_cm=[.25d0];q%maximum_storage_cm=[1d0];q%minimum_storage_cm=[0d0]
  q%potential_top_vertical_cm=[0d0];q%potential_top_lateral_cm=[0d0]
  q%potential_interflow_sat_cm=[0d0];q%potential_matrix_sat_cm=[0d0]
  q%redistribution_capacity_cm=[0d0];q%top_domain_fraction=[1d0]
  q%potential_outflow_cm=[0d0]
  call check(1d0)
  small=nearest(0d0,1d0)
  q%potential_outflow_cm=[small]
  call check(1d0)
  q%accepted_storage_cm=[0d0]
  call check(0d0)
  q%potential_outflow_cm=[1024d0*small];q%accepted_storage_cm=[512d0*small]
  call check(.5d0)
  q%potential_outflow_cm=[.5d0];q%accepted_storage_cm=[.25d0]
  call check(.5d0)
  q%accepted_storage_cm=[.5d0]
  call check(1d0)
  q%accepted_storage_cm=[.75d0]
  call check(1d0)
  print *, 'ACTUAL_AND_SUBNORMAL_LIMITER_RATIO_PASS'
contains
  subroutine check(expected)
    real(real64),intent(in)::expected
    call evaluate_standard_inflow_limit(q,r)
    if(.not.r%valid)error stop 'valid one-domain receipt refused'
    if(r%outflow_fraction(1)/=expected)error stop 'one-domain stock fraction'
    if(r%outflow_fraction(1)*q%potential_outflow_cm(1)>q%accepted_storage_cm(1)) &
      error stop 'outgoing amount exceeds stock'
  end subroutine
end program
