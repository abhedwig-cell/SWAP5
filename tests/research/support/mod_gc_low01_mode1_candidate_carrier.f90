module mod_gc_low01_mode1_candidate_carrier
  use, intrinsic :: iso_fortran_env, only: real64
  implicit none
  private

  integer, parameter, public :: LOW01_BRANCH_ABOVE_OR_AT_TOP = 1
  integer, parameter, public :: LOW01_BRANCH_INSIDE_PROFILE = 2
  integer, parameter, public :: LOW01_BRANCH_BELOW_PROFILE = 3
  real(real64), parameter, public :: LOW01_NODE_SNAP_TOL_CM = 1.0e-4_real64

  type, public :: low01_mode1_candidate_t
    real(real64) :: requested_h_phreatic_cm = 0.0_real64
    real(real64) :: effective_h_phreatic_cm = 0.0_real64
    real(real64) :: raw_legacy_groundwater_level_cm = 0.0_real64
    logical :: derived_profile_gwl_available = .false.
    real(real64) :: derived_profile_gwl_cm = 0.0_real64
    real(real64) :: bottom_face_cm = 0.0_real64
    integer :: branch = 0
    integer :: active_richards_nodes = 0
    logical :: fllowgwl = .false.
    real(real64) :: qbot_cm_per_day = 0.0_real64
    real(real64) :: storage_change_cm = 0.0_real64
    real(real64), allocatable :: pressure_head_cm(:)
    real(real64), allocatable :: water_content(:)
  end type low01_mode1_candidate_t

  public :: classify_low01_h_phreatic
  public :: materialize_low01_mode1_candidate
  public :: low01_branch_name

contains

  subroutine classify_low01_h_phreatic(z, dz, requested, branch, active_nodes, effective, bottom_face, hbot)
    real(real64), intent(in) :: z(:), dz(:), requested
    integer, intent(out) :: branch, active_nodes
    real(real64), intent(out) :: effective, bottom_face, hbot
    integer :: n

    n = size(z)
    if (n <= 0 .or. size(dz) /= n) error stop 'LOW01 carrier: invalid geometry'
    if (any(dz <= 0.0_real64)) error stop 'LOW01 carrier: nonpositive dz'

    bottom_face = z(n) - 0.5_real64*dz(n)
    effective = requested
    hbot = 0.0_real64

    if (requested >= z(1) - LOW01_NODE_SNAP_TOL_CM) then
      branch = LOW01_BRANCH_ABOVE_OR_AT_TOP
      active_nodes = 0
      return
    end if

    if (requested <= bottom_face) then
      branch = LOW01_BRANCH_BELOW_PROFILE
      active_nodes = n
      hbot = requested - bottom_face
      return
    end if

    branch = LOW01_BRANCH_INSIDE_PROFILE
    active_nodes = 0
    do while (active_nodes < n)
      if (.not. (z(active_nodes+1) > effective)) exit
      active_nodes = active_nodes + 1
    end do

    if (active_nodes > 0) then
      if ((z(active_nodes) - effective) < LOW01_NODE_SNAP_TOL_CM) then
        effective = z(active_nodes)
        active_nodes = active_nodes - 1
      end if
    end if

    if (active_nodes <= 0 .or. active_nodes > n) &
      error stop 'LOW01 carrier: invalid inside-profile active domain'
  end subroutine classify_low01_h_phreatic

  subroutine materialize_low01_mode1_candidate(z, dz, requested, raw_legacy_gwl, raw_fllowgwl, qbot, &
                                                storage_change, pressure_head, water_content, candidate)
    real(real64), intent(in) :: z(:), dz(:), requested, raw_legacy_gwl, qbot, storage_change
    logical, intent(in) :: raw_fllowgwl
    real(real64), intent(in) :: pressure_head(:), water_content(:)
    type(low01_mode1_candidate_t), intent(out) :: candidate
    real(real64) :: hbot
    integer :: branch, nn

    if (size(pressure_head) /= size(z) .or. size(water_content) /= size(z)) &
      error stop 'LOW01 carrier: candidate array shape mismatch'

    call classify_low01_h_phreatic(z, dz, requested, branch, nn, candidate%effective_h_phreatic_cm, &
                                   candidate%bottom_face_cm, hbot)

    candidate%requested_h_phreatic_cm = requested
    candidate%raw_legacy_groundwater_level_cm = raw_legacy_gwl
    candidate%derived_profile_gwl_available = .false.
    candidate%derived_profile_gwl_cm = 0.0_real64
    candidate%branch = branch
    candidate%active_richards_nodes = nn
    candidate%fllowgwl = (branch == LOW01_BRANCH_BELOW_PROFILE)
    if (raw_fllowgwl .neqv. candidate%fllowgwl) then
      ! Raw legacy state remains provenance. A disagreement is an observable
      ! branch-contract error rather than something this carrier silently fixes.
      error stop 'LOW01 carrier: raw branch diagnostic disagrees with typed branch'
    end if
    candidate%qbot_cm_per_day = qbot
    candidate%storage_change_cm = storage_change
    allocate(candidate%pressure_head_cm(size(z)), candidate%water_content(size(z)))
    candidate%pressure_head_cm = pressure_head
    candidate%water_content = water_content
  end subroutine materialize_low01_mode1_candidate

  pure function low01_branch_name(branch) result(name)
    integer, intent(in) :: branch
    character(len=16) :: name
    select case(branch)
    case(LOW01_BRANCH_ABOVE_OR_AT_TOP)
      name = 'ABOVE_OR_AT_TOP'
    case(LOW01_BRANCH_INSIDE_PROFILE)
      name = 'INSIDE_PROFILE  '
    case(LOW01_BRANCH_BELOW_PROFILE)
      name = 'BELOW_PROFILE   '
    case default
      name = 'INVALID         '
    end select
  end function low01_branch_name

end module mod_gc_low01_mode1_candidate_carrier
