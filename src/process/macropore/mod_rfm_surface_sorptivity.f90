module mod_rfm_surface_sorptivity
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_process_hydraulic_view, only: process_hydraulic_view_t, validate_process_hydraulic_view
  use mod_soil_water_solver_contract, only: constitutive_hydraulics_provider_t, &
       CONSTITUTIVE_DEMAND_WATER_CONTENT, CONSTITUTIVE_DEMAND_CONDUCTIVITY
  implicit none
  private

  public :: evaluate_rfm_surface_sorptivity

contains

  subroutine evaluate_rfm_surface_sorptivity(view, constitutive, panels, sorptivity, ok)
    type(process_hydraulic_view_t), intent(in) :: view
    class(constitutive_hydraulics_provider_t), intent(in) :: constitutive
    integer, intent(in) :: panels
    real(real64), intent(out) :: sorptivity
    logical, intent(out) :: ok
    real(real64), allocatable :: head(:), theta(:), conductivity(:), capacity(:), dkdh(:)
    real(real64) :: h_initial, theta_initial, theta_s, dh, h_mid, integrand, integral
    logical :: view_ok
    integer :: i, n

    sorptivity = 0.0_real64
    ok = .false.
    call validate_process_hydraulic_view(view,view_ok)
    if (.not. view_ok .or. panels <= 0) return

    n = view%active_nodes
    h_initial = view%pressure_head(1)
    theta_initial = view%water_content(1)
    if (.not. ieee_is_finite(h_initial) .or. .not. ieee_is_finite(theta_initial)) return

    if (h_initial >= 0.0_real64) then
      sorptivity = 0.0_real64
      ok = .true.
      return
    end if

    allocate(head(n),theta(n),conductivity(n),capacity(n),dkdh(n))
    head = view%pressure_head
    head(1) = 0.0_real64
    call constitutive%evaluate_demand(head, &
         CONSTITUTIVE_DEMAND_WATER_CONTENT+CONSTITUTIVE_DEMAND_CONDUCTIVITY, &
         theta,conductivity,capacity,dkdh)
    theta_s = theta(1)
    if (.not. ieee_is_finite(theta_s) .or. theta_s < theta_initial) return

    dh = -h_initial/real(panels,real64)
    integral = 0.0_real64
    do i=1,panels
      h_mid = h_initial+(real(i,real64)-0.5_real64)*dh
      head = view%pressure_head
      head(1) = h_mid
      call constitutive%evaluate_demand(head, &
           CONSTITUTIVE_DEMAND_WATER_CONTENT+CONSTITUTIVE_DEMAND_CONDUCTIVITY, &
           theta,conductivity,capacity,dkdh)
      if (.not. ieee_is_finite(theta(1)) .or. .not. ieee_is_finite(conductivity(1))) return
      if (conductivity(1) < 0.0_real64) return
      integrand = (theta_s+theta(1)-2.0_real64*theta_initial)*conductivity(1)
      integral = integral+max(0.0_real64,integrand)*dh
    end do

    sorptivity = sqrt(max(0.0_real64,integral))
    if (.not. ieee_is_finite(sorptivity)) then
      sorptivity = 0.0_real64
      return
    end if
    ok = .true.
  end subroutine evaluate_rfm_surface_sorptivity

end module mod_rfm_surface_sorptivity
