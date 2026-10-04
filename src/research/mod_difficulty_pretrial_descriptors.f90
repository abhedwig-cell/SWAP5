module mod_difficulty_pretrial_descriptors
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_soil_water_solver_contract, only: soil_water_solve_request_t
  implicit none
  private

  type, public :: difficulty_pretrial_descriptors_t
    logical :: available = .false.
    integer :: active_nodes = 0
    real(real64) :: h_min=0, h_max=0
    real(real64) :: theta_min=0, theta_max=0
    real(real64) :: k_min=0, k_max=0
    real(real64) :: capacity_min=0, capacity_max=0
    real(real64) :: abs_dkdh_max=0
    real(real64) :: grad_h_max=0, grad_theta_max=0, grad_logk_max=0
    integer :: grad_h_location=0, grad_theta_location=0, grad_logk_location=0
    real(real64) :: groundwater_level=0
    real(real64) :: ponding_depth=0
    logical :: top_flux_ratio_available=.false.
    real(real64) :: abs_top_flux_over_surface_k=0
  end type

  public :: evaluate_difficulty_pretrial_descriptors

contains
  subroutine evaluate_difficulty_pretrial_descriptors(request,d)
    type(soil_water_solve_request_t),intent(in)::request
    type(difficulty_pretrial_descriptors_t),intent(out)::d
    real(real64),allocatable::theta(:),k(:),c(:),dk(:)
    real(real64)::dist,g
    integer::n,i
    d=difficulty_pretrial_descriptors_t()
    n=request%base_state%active_nodes
    if(n<=0 .or. .not.associated(request%evaluation%constitutive)) return
    if(.not.allocated(request%base_state%pressure_head)) return
    allocate(theta(n),k(n),c(n),dk(n))
    call request%evaluation%constitutive%evaluate(request%base_state%pressure_head,theta,k,c,dk)
    d%active_nodes=n; d%available=.true.
    d%h_min=minval(request%base_state%pressure_head); d%h_max=maxval(request%base_state%pressure_head)
    d%theta_min=minval(theta); d%theta_max=maxval(theta)
    d%k_min=minval(k); d%k_max=maxval(k); d%capacity_min=minval(c); d%capacity_max=maxval(c)
    d%abs_dkdh_max=maxval(abs(dk)); d%groundwater_level=request%base_state%groundwater_level
    d%ponding_depth=request%base_state%ponding_depth
    do i=1,n-1
      dist=1.0_real64
      if(associated(request%parameters)) then
        if(allocated(request%parameters%node_distance)) dist=max(abs(request%parameters%node_distance(i)),tiny(1.0_real64))
      end if
      g=abs(request%base_state%pressure_head(i+1)-request%base_state%pressure_head(i))/dist
      if(g>d%grad_h_max) then; d%grad_h_max=g; d%grad_h_location=i; end if
      g=abs(theta(i+1)-theta(i))/dist
      if(g>d%grad_theta_max) then; d%grad_theta_max=g; d%grad_theta_location=i; end if
      if(k(i)>0 .and. k(i+1)>0) then
        g=abs(log(k(i+1))-log(k(i)))/dist
        if(g>d%grad_logk_max) then; d%grad_logk_max=g; d%grad_logk_location=i; end if
      end if
    end do
    if(k(1)>tiny(1.0_real64)) then
      d%top_flux_ratio_available=.true.
      d%abs_top_flux_over_surface_k=abs(request%boundary%top_flux)/k(1)
    end if
  end subroutine
end module mod_difficulty_pretrial_descriptors
