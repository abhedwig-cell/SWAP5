module mod_rfm_preferential_router
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_rfm_unponded_surface_composition, only: rfm_unponded_surface_composition_result_t, &
       RFM_SURFACE_COMPOSITION_AVAILABLE
  implicit none
  private

  integer, parameter, public :: RFM_PREF_ROUTER_NOT_RUN = 0
  integer, parameter, public :: RFM_PREF_ROUTER_AVAILABLE = 1
  integer, parameter, public :: RFM_PREF_ROUTER_INVALID = 2

  type, public :: rfm_preferential_routing_request_t
    real(real64) :: f_mb = -1.0_real64
    real(real64) :: connectivity_p = -1.0_real64
    real(real64) :: z_ah_cm = -1.0_real64
    real(real64) :: z_ic_cm = -1.0_real64
    real(real64), allocatable :: endpoint_depth_cm(:)
  contains
    procedure, public :: valid => routing_request_valid
  end type rfm_preferential_routing_request_t

  type, public :: rfm_preferential_routing_result_t
    integer :: status = RFM_PREF_ROUTER_NOT_RUN
    real(real64) :: activation_fraction = 0.0_real64
    real(real64) :: mb_amount = 0.0_real64
    real(real64) :: ic_amount = 0.0_real64
    real(real64), allocatable :: endpoint_weight(:)
    real(real64), allocatable :: endpoint_amount(:)
    real(real64) :: endpoint_weight_residual = 0.0_real64
    real(real64) :: mass_residual = 0.0_real64
  end type rfm_preferential_routing_result_t

  public :: route_rfm_preferential_supply

contains

  pure logical function routing_request_valid(self) result(ok)
    class(rfm_preferential_routing_request_t), intent(in) :: self
    integer :: i

    ok = ieee_is_finite(self%f_mb) .and. self%f_mb >= 0.0_real64 .and. self%f_mb <= 1.0_real64 .and. &
         ieee_is_finite(self%connectivity_p) .and. self%connectivity_p > 0.0_real64 .and. &
         ieee_is_finite(self%z_ah_cm) .and. self%z_ah_cm >= 0.0_real64 .and. &
         ieee_is_finite(self%z_ic_cm) .and. self%z_ic_cm > self%z_ah_cm
    if (.not. ok) return

    ok = allocated(self%endpoint_depth_cm)
    if (.not. ok) return
    ok = size(self%endpoint_depth_cm) > 0
    if (.not. ok) return
    ok = all(ieee_is_finite(self%endpoint_depth_cm)) .and. all(self%endpoint_depth_cm > 0.0_real64)
    if (.not. ok) return
    do i = 2, size(self%endpoint_depth_cm)
      if (self%endpoint_depth_cm(i) <= self%endpoint_depth_cm(i-1)) then
        ok = .false.
        return
      end if
    end do
    ok = self%endpoint_depth_cm(size(self%endpoint_depth_cm)) >= self%z_ic_cm
  end function routing_request_valid

  pure subroutine route_rfm_preferential_supply(surface_receipt,request,tolerance,result)
    type(rfm_unponded_surface_composition_result_t), intent(in) :: surface_receipt
    type(rfm_preferential_routing_request_t), intent(in) :: request
    real(real64), intent(in) :: tolerance
    type(rfm_preferential_routing_result_t), intent(out) :: result

    real(real64) :: preferential, effective, activation, previous_survival
    real(real64) :: survival, loss, raw_total
    integer :: i,n

    result = rfm_preferential_routing_result_t()

    if (.not.ieee_is_finite(tolerance) .or. tolerance < 0.0_real64) then
      result%status = RFM_PREF_ROUTER_INVALID
      return
    end if
    if (surface_receipt%status /= RFM_SURFACE_COMPOSITION_AVAILABLE) then
      result%status = RFM_PREF_ROUTER_INVALID
      return
    end if
    if (.not.request%valid()) then
      result%status = RFM_PREF_ROUTER_INVALID
      return
    end if

    effective = surface_receipt%effective_supply_cm_per_day
    preferential = surface_receipt%preferential_supply_cm_per_day
    if (.not.ieee_is_finite(effective) .or. .not.ieee_is_finite(preferential)) then
      result%status = RFM_PREF_ROUTER_INVALID
      return
    end if
    if (effective < 0.0_real64 .or. preferential < 0.0_real64 .or. &
        preferential > effective + tolerance) then
      result%status = RFM_PREF_ROUTER_INVALID
      return
    end if

    n = size(request%endpoint_depth_cm)
    allocate(result%endpoint_weight(n),result%endpoint_amount(n))
    result%endpoint_weight = 0.0_real64
    result%endpoint_amount = 0.0_real64

    if (preferential <= tolerance) then
      result%status = RFM_PREF_ROUTER_AVAILABLE
      return
    end if
    if (effective <= 0.0_real64) then
      result%status = RFM_PREF_ROUTER_INVALID
      return
    end if

    activation = preferential/effective
    if (.not.ieee_is_finite(activation) .or. activation <= 0.0_real64 .or. activation > 1.0_real64+tolerance) then
      result%status = RFM_PREF_ROUTER_INVALID
      return
    end if
    activation = min(1.0_real64,activation)
    result%activation_fraction = activation

    previous_survival = activation
    raw_total = 0.0_real64
    do i = 1,n
      survival = active_survival(request%endpoint_depth_cm(i),activation,request%z_ah_cm, &
           request%z_ic_cm,request%connectivity_p)
      loss = max(0.0_real64,previous_survival-survival)
      result%endpoint_weight(i) = loss
      raw_total = raw_total + loss
      previous_survival = survival
    end do

    if (abs(raw_total-activation) > tolerance) then
      result = rfm_preferential_routing_result_t(status=RFM_PREF_ROUTER_INVALID)
      return
    end if

    result%endpoint_weight = result%endpoint_weight/activation
    result%endpoint_weight_residual = sum(result%endpoint_weight)-1.0_real64

    result%mb_amount = request%f_mb*preferential
    result%ic_amount = preferential-result%mb_amount
    result%endpoint_amount = result%ic_amount*result%endpoint_weight
    result%mass_residual = preferential-result%mb_amount-sum(result%endpoint_amount)

    if (any(result%endpoint_weight < -tolerance) .or. any(result%endpoint_amount < -tolerance)) then
      result = rfm_preferential_routing_result_t(status=RFM_PREF_ROUTER_INVALID)
      return
    end if
    if (abs(result%endpoint_weight_residual) > tolerance .or. abs(result%mass_residual) > tolerance) then
      result = rfm_preferential_routing_result_t(status=RFM_PREF_ROUTER_INVALID)
      return
    end if

    result%status = RFM_PREF_ROUTER_AVAILABLE
  end subroutine route_rfm_preferential_supply

  pure real(real64) function active_survival(depth,activation,z_ah,z_ic,p) result(value)
    real(real64), intent(in) :: depth,activation,z_ah,z_ic,p
    real(real64) :: connectivity,x

    if (depth <= z_ah) then
      connectivity = 1.0_real64
    else if (depth >= z_ic) then
      connectivity = 0.0_real64
    else
      x = (depth-z_ah)/(z_ic-z_ah)
      connectivity = 1.0_real64-x**p
    end if
    value = max(0.0_real64,activation-(1.0_real64-connectivity))
  end function active_survival

end module mod_rfm_preferential_router
