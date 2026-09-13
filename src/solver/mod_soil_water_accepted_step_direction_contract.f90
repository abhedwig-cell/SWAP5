module mod_soil_water_accepted_step_direction_contract
  use, intrinsic :: iso_fortran_env, only: real64
  implicit none
  private

  integer, parameter, public :: SW_STEP_DIRECTION_NOT_RUN = 0
  integer, parameter, public :: SW_STEP_DIRECTION_AVAILABLE = 1
  integer, parameter, public :: SW_STEP_DIRECTION_UNAVAILABLE = 2
  integer, parameter, public :: SW_STEP_DIRECTION_FAILED = 3

  integer, parameter, public :: SW_STEP_CONTROL_NONE = 0
  integer, parameter, public :: SW_STEP_CONTROL_BOTTOM_FLUX = 2
  integer, parameter, public :: SW_STEP_CONTROL_BOTTOM_HEAD = 5

  ! One scalar directional derivative through exactly one accepted physical
  ! soil-water step.  F-KT owns trajectory composition across accepted steps.
  ! These arrays are numerical scratch inputs/outputs, not persistent column
  ! state and never participate in physical acceptance or mass accounting.
  type, public :: soil_water_accepted_step_direction_request_t
     logical :: requested = .false.
     integer :: control_coordinate = SW_STEP_CONTROL_NONE
     real(real64), allocatable :: incoming_pressure_head(:)
     real(real64), allocatable :: incoming_water_content(:)
     real(real64) :: incoming_ponding_depth = 0.0_real64
     real(real64) :: direct_control_derivative = 0.0_real64
  end type soil_water_accepted_step_direction_request_t

  type, public :: soil_water_accepted_step_direction_result_t
     integer :: status = SW_STEP_DIRECTION_NOT_RUN
     logical :: available = .false.
     logical :: fixed_smooth_route = .false.
     integer :: control_coordinate = SW_STEP_CONTROL_NONE
     character(len=48) :: method = 'not-run'
     character(len=64) :: route = 'not-run'
     real(real64), allocatable :: outgoing_pressure_head(:)
     real(real64), allocatable :: outgoing_water_content(:)
     real(real64) :: outgoing_ponding_depth = 0.0_real64
     real(real64) :: top_flux_derivative = 0.0_real64
     real(real64) :: bottom_flux_derivative = 0.0_real64
     integer :: additional_tridiagonal_backsolves = 0
     integer :: additional_jacobian_builds = 0
     integer :: additional_full_nonlinear_solves = 0
  end type soil_water_accepted_step_direction_result_t

end module mod_soil_water_accepted_step_direction_contract
