module mod_gc_low01_trial_transaction
  use, intrinsic :: iso_fortran_env, only: int64, real64
  implicit none
  private

  integer, parameter, public :: GC_LOW01_BRANCH_BELOW_BOTTOM_NODE = 3
  character(len=*), parameter, public :: GC_LOW01_QBOT_ROUTE_MODE5_MATERIALIZED = &
       'mode5-explicit-materialization'

  type, public :: gc_low01_candidate_t
     logical :: available = .false.
     real(real64) :: requested_hphreatic_cm = 0.0_real64
     real(real64) :: effective_hphreatic_cm = 0.0_real64
     integer :: branch_id = 0
     integer :: active_nodes = 0
     logical :: fllowgwl_equivalent = .false.
     real(real64) :: hbot_cm = 0.0_real64
     real(real64) :: qbot_cm_per_day = 0.0_real64
     character(len=48) :: qbot_materialization_route = 'not-run'
     logical :: derived_profile_gwl_available = .false.
     real(real64) :: derived_profile_gwl_cm = 0.0_real64
     real(real64) :: integrated_mass_residual_cm = 0.0_real64
     integer :: nonlinear_iterations = 0
     integer :: linear_solves = 0
     integer :: alternative_solver_calls = 0
     logical :: retry_advised = .false.
     real(real64), allocatable :: pressure_head_cm(:)
     real(real64), allocatable :: water_content(:)
     real(real64) :: ponding_depth_cm = 0.0_real64
     real(real64) :: solver_groundwater_level_compat_cm = 0.0_real64
  end type gc_low01_candidate_t

  type, public :: gc_low01_accepted_state_t
     integer(int64) :: revision = 0_int64
     real(real64) :: accepted_interface_mass_cm = 0.0_real64
     real(real64), allocatable :: pressure_head_cm(:)
     real(real64), allocatable :: water_content(:)
     real(real64) :: ponding_depth_cm = 0.0_real64
     real(real64) :: solver_groundwater_level_compat_cm = 0.0_real64
  end type gc_low01_accepted_state_t

  public :: gc_low01_initialize_accepted
  public :: gc_low01_build_below_profile_candidate
  public :: gc_low01_reject_candidate
  public :: gc_low01_accept_candidate

contains

  subroutine gc_low01_initialize_accepted(accepted, pressure_head_cm, water_content, ponding_depth_cm, groundwater_level_cm)
    type(gc_low01_accepted_state_t), intent(out) :: accepted
    real(real64), intent(in) :: pressure_head_cm(:), water_content(:)
    real(real64), intent(in) :: ponding_depth_cm, groundwater_level_cm

    if (size(pressure_head_cm) <= 0 .or. size(water_content) /= size(pressure_head_cm)) &
         error stop 'LOW01 transaction: invalid accepted state shape'
    accepted%revision = 0_int64
    accepted%accepted_interface_mass_cm = 0.0_real64
    allocate(accepted%pressure_head_cm(size(pressure_head_cm)), accepted%water_content(size(water_content)))
    accepted%pressure_head_cm = pressure_head_cm
    accepted%water_content = water_content
    accepted%ponding_depth_cm = ponding_depth_cm
    accepted%solver_groundwater_level_compat_cm = groundwater_level_cm
  end subroutine gc_low01_initialize_accepted

  subroutine gc_low01_build_below_profile_candidate(candidate, requested_hphreatic_cm, bottom_face_cm, &
                                                     qbot_cm_per_day, integrated_mass_residual_cm, &
                                                     pressure_head_cm, water_content, ponding_depth_cm, &
                                                     solver_groundwater_level_compat_cm, nonlinear_iterations, &
                                                     linear_solves, alternative_solver_calls, retry_advised)
    type(gc_low01_candidate_t), intent(out) :: candidate
    real(real64), intent(in) :: requested_hphreatic_cm, bottom_face_cm
    real(real64), intent(in) :: qbot_cm_per_day, integrated_mass_residual_cm
    real(real64), intent(in) :: pressure_head_cm(:), water_content(:)
    real(real64), intent(in) :: ponding_depth_cm, solver_groundwater_level_compat_cm
    integer, intent(in) :: nonlinear_iterations, linear_solves, alternative_solver_calls
    logical, intent(in) :: retry_advised

    if (requested_hphreatic_cm >= bottom_face_cm) &
         error stop 'LOW01 transaction: below-profile candidate requires H_phreatic below bottom face'
    if (size(pressure_head_cm) <= 0 .or. size(water_content) /= size(pressure_head_cm)) &
         error stop 'LOW01 transaction: invalid candidate state shape'

    candidate%available = .true.
    candidate%requested_hphreatic_cm = requested_hphreatic_cm
    candidate%effective_hphreatic_cm = requested_hphreatic_cm
    candidate%branch_id = GC_LOW01_BRANCH_BELOW_BOTTOM_NODE
    candidate%active_nodes = size(pressure_head_cm)
    candidate%fllowgwl_equivalent = .true.
    candidate%hbot_cm = requested_hphreatic_cm - bottom_face_cm
    candidate%qbot_cm_per_day = qbot_cm_per_day
    candidate%qbot_materialization_route = GC_LOW01_QBOT_ROUTE_MODE5_MATERIALIZED
    ! The focused mode-5 solve does not execute legacy SoilWater task-3 calcgwl().
    ! Keep the solver compatibility field available without pretending it is
    ! source-equivalent derived-profile groundwater-level authority.
    candidate%derived_profile_gwl_available = .false.
    candidate%derived_profile_gwl_cm = 0.0_real64
    candidate%integrated_mass_residual_cm = integrated_mass_residual_cm
    candidate%nonlinear_iterations = nonlinear_iterations
    candidate%linear_solves = linear_solves
    candidate%alternative_solver_calls = alternative_solver_calls
    candidate%retry_advised = retry_advised
    allocate(candidate%pressure_head_cm(size(pressure_head_cm)), candidate%water_content(size(water_content)))
    candidate%pressure_head_cm = pressure_head_cm
    candidate%water_content = water_content
    candidate%ponding_depth_cm = ponding_depth_cm
    candidate%solver_groundwater_level_compat_cm = solver_groundwater_level_compat_cm
  end subroutine gc_low01_build_below_profile_candidate

  subroutine gc_low01_reject_candidate(candidate)
    type(gc_low01_candidate_t), intent(inout) :: candidate
    candidate = gc_low01_candidate_t()
  end subroutine gc_low01_reject_candidate

  subroutine gc_low01_accept_candidate(accepted, candidate, step_duration_day)
    type(gc_low01_accepted_state_t), intent(inout) :: accepted
    type(gc_low01_candidate_t), intent(inout) :: candidate
    real(real64), intent(in) :: step_duration_day

    if (.not. candidate%available) error stop 'LOW01 transaction: no candidate to accept'
    if (step_duration_day <= 0.0_real64) error stop 'LOW01 transaction: invalid step duration'
    if (.not. allocated(candidate%pressure_head_cm) .or. .not. allocated(candidate%water_content)) &
         error stop 'LOW01 transaction: candidate state not allocated'

    if (allocated(accepted%pressure_head_cm)) deallocate(accepted%pressure_head_cm)
    if (allocated(accepted%water_content)) deallocate(accepted%water_content)
    allocate(accepted%pressure_head_cm(size(candidate%pressure_head_cm)), &
             accepted%water_content(size(candidate%water_content)))
    accepted%pressure_head_cm = candidate%pressure_head_cm
    accepted%water_content = candidate%water_content
    accepted%ponding_depth_cm = candidate%ponding_depth_cm
    accepted%solver_groundwater_level_compat_cm = candidate%solver_groundwater_level_compat_cm
    accepted%revision = accepted%revision + 1_int64
    accepted%accepted_interface_mass_cm = accepted%accepted_interface_mass_cm + &
         candidate%qbot_cm_per_day * step_duration_day

    call gc_low01_reject_candidate(candidate)
  end subroutine gc_low01_accept_candidate

end module mod_gc_low01_trial_transaction
