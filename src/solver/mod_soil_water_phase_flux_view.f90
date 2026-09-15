module mod_soil_water_phase_flux_view
  use, intrinsic :: iso_fortran_env, only: real64
  implicit none
  private

  integer, parameter, public :: SW_FACE_FLUX_SIGN_UNSPECIFIED = 0
  integer, parameter, public :: SW_FACE_FLUX_POSITIVE_UPWARD = 1

  ! Candidate/trial result only.  This type is deliberately separate from the
  ! persistent hydraulic state: a caller may commit, discard or recompute the
  ! interval without changing the column checkpoint.
  type, public :: soil_water_phase_flux_view_t
     integer :: active_nodes = 0
     integer :: face_count = 0
     integer :: sign_convention = SW_FACE_FLUX_SIGN_UNSPECIFIED
     logical :: candidate_interval = .false.
     logical :: liquid_flux_available = .false.
     logical :: liquid_transport_available = .false.
     logical :: continuity_residual_available = .false.
     logical :: vapor_phase_modelled = .false.
     logical :: vapor_flux_available = .false.
     logical :: vapor_transport_available = .false.
     logical :: full_physical_phase_coverage = .false.
     real(real64) :: step_duration_day = 0.0_real64
     real(real64) :: bottom_flux_consistency_residual_cm_day = 0.0_real64
     real(real64) :: mass_balance_residual_cm_day = 0.0_real64
     real(real64), allocatable :: liquid_face_flux_cm_day(:)
     real(real64), allocatable :: liquid_face_transport_cm(:)
     real(real64), allocatable :: continuity_residual_cm_day(:)
     character(len=48) :: route = 'not-available'
  end type soil_water_phase_flux_view_t

  public :: reset_soil_water_phase_flux_view
  public :: validate_soil_water_phase_flux_view

contains

  subroutine reset_soil_water_phase_flux_view(view)
    type(soil_water_phase_flux_view_t), intent(inout) :: view

    if (allocated(view%liquid_face_flux_cm_day)) deallocate(view%liquid_face_flux_cm_day)
    if (allocated(view%liquid_face_transport_cm)) deallocate(view%liquid_face_transport_cm)
    if (allocated(view%continuity_residual_cm_day)) deallocate(view%continuity_residual_cm_day)
    view%active_nodes = 0
    view%face_count = 0
    view%sign_convention = SW_FACE_FLUX_SIGN_UNSPECIFIED
    view%candidate_interval = .false.
    view%liquid_flux_available = .false.
    view%liquid_transport_available = .false.
    view%continuity_residual_available = .false.
    view%vapor_phase_modelled = .false.
    view%vapor_flux_available = .false.
    view%vapor_transport_available = .false.
    view%full_physical_phase_coverage = .false.
    view%step_duration_day = 0.0_real64
    view%bottom_flux_consistency_residual_cm_day = 0.0_real64
    view%mass_balance_residual_cm_day = 0.0_real64
    view%route = 'not-available'
  end subroutine reset_soil_water_phase_flux_view

  subroutine validate_soil_water_phase_flux_view(view, ok)
    type(soil_water_phase_flux_view_t), intent(in) :: view
    logical, intent(out) :: ok
    integer :: n

    ok = .false.
    n = view%active_nodes
    if (n <= 0) return
    if (view%face_count /= n + 1) return
    if (view%sign_convention /= SW_FACE_FLUX_POSITIVE_UPWARD) return
    if (.not. view%candidate_interval) return
    if (view%step_duration_day <= 0.0_real64) return
    if (.not. view%liquid_flux_available) return
    if (.not. view%liquid_transport_available) return
    if (.not. view%continuity_residual_available) return
    if (.not. allocated(view%liquid_face_flux_cm_day)) return
    if (.not. allocated(view%liquid_face_transport_cm)) return
    if (.not. allocated(view%continuity_residual_cm_day)) return
    if (size(view%liquid_face_flux_cm_day) /= n + 1) return
    if (size(view%liquid_face_transport_cm) /= n + 1) return
    if (size(view%continuity_residual_cm_day) /= n) return

    ! EB-I03 does not invent a zero vapour flux.  Until a producer actually
    ! models and publishes vapour transport, full physical phase coverage must
    ! remain false.
    if (view%vapor_phase_modelled) return
    if (view%vapor_flux_available) return
    if (view%vapor_transport_available) return
    if (view%full_physical_phase_coverage) return

    ok = .true.
  end subroutine validate_soil_water_phase_flux_view

end module mod_soil_water_phase_flux_view
