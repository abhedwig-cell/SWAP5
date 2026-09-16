module mod_groundwater_coupling_policy
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use, intrinsic :: iso_fortran_env, only: int64, real64
  implicit none
  private

  integer, parameter, public :: GW_HEAD_POLICY_OK = 0
  integer, parameter, public :: GW_HEAD_POLICY_UNAVAILABLE = 1
  integer, parameter, public :: GW_HEAD_POLICY_INVALID_TOLERANCE = 2
  integer, parameter, public :: GW_HEAD_POLICY_INVALID_PROVENANCE = 3
  integer, parameter, public :: GW_HEAD_POLICY_INVALID_RESIDUAL = 4

  integer, parameter, public :: GW_HEAD_TOLERANCE_PROVENANCE_GOVERNED_EXTERNAL = 1

  ! This policy owns only interface head convergence. It deliberately does not
  ! own application H_app, the Richards temporal H_budget, nonlinear solver
  ! tolerances, predictor perturbations, or any mass tolerance. F-GC22 later
  ! qualifies the binding between this explicit tolerance and governed
  ! application/temporal accuracy evidence.
  type, public :: groundwater_head_convergence_policy_t
    logical :: available = .false.
    integer(int64) :: policy_id = 0_int64
    integer :: policy_version = 0
    integer :: provenance_class = 0
    integer(int64) :: provenance_id = 0_int64
    logical :: provenance_qualified = .false.
    real(real64) :: head_tolerance_m = 0.0_real64
  contains
    procedure :: valid => groundwater_head_policy_valid
    procedure :: evaluate => evaluate_groundwater_head_convergence
  end type groundwater_head_convergence_policy_t

contains

  pure logical function groundwater_head_policy_valid(self)
    class(groundwater_head_convergence_policy_t), intent(in) :: self

    groundwater_head_policy_valid = .false.
    if (.not. self%available) return
    if (self%policy_id <= 0_int64) return
    if (self%policy_version <= 0) return
    if (self%provenance_class /= GW_HEAD_TOLERANCE_PROVENANCE_GOVERNED_EXTERNAL) return
    if (self%provenance_id <= 0_int64) return
    if (.not. self%provenance_qualified) return
    if (.not. ieee_is_finite(self%head_tolerance_m)) return
    if (self%head_tolerance_m <= 0.0_real64) return
    groundwater_head_policy_valid = .true.
  end function groundwater_head_policy_valid

  pure subroutine evaluate_groundwater_head_convergence(self, head_residual_m, converged, status)
    class(groundwater_head_convergence_policy_t), intent(in) :: self
    real(real64), intent(in) :: head_residual_m
    logical, intent(out) :: converged
    integer, intent(out) :: status

    converged = .false.
    status = GW_HEAD_POLICY_UNAVAILABLE
    if (.not. self%available) return

    if (self%policy_id <= 0_int64 .or. self%policy_version <= 0 .or. &
        self%provenance_class /= GW_HEAD_TOLERANCE_PROVENANCE_GOVERNED_EXTERNAL .or. &
        self%provenance_id <= 0_int64 .or. .not. self%provenance_qualified) then
      status = GW_HEAD_POLICY_INVALID_PROVENANCE
      return
    end if

    if (.not. ieee_is_finite(self%head_tolerance_m)) then
      status = GW_HEAD_POLICY_INVALID_TOLERANCE
      return
    end if
    if (self%head_tolerance_m <= 0.0_real64) then
      status = GW_HEAD_POLICY_INVALID_TOLERANCE
      return
    end if
    if (.not. ieee_is_finite(head_residual_m)) then
      status = GW_HEAD_POLICY_INVALID_RESIDUAL
      return
    end if

    converged = abs(head_residual_m) <= self%head_tolerance_m
    status = GW_HEAD_POLICY_OK
  end subroutine evaluate_groundwater_head_convergence

end module mod_groundwater_coupling_policy
