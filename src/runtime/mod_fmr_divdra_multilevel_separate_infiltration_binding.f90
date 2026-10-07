module mod_fmr_divdra_multilevel_separate_infiltration_binding
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_process_hydraulic_view, only: process_hydraulic_view_t
  use mod_drainage_spatial_distribution, only: drainage_distribution_parameters_t
  use mod_drainage_multilevel_separate_infiltration, only: drainage_multilevel_separate_infiltration_result_t, &
       distribute_multilevel_separate_infiltration_b19, DRAIN_MULTI_INF_OK
  implicit none
  private

  integer,parameter,public :: FMR_DIVDRA_MULTI_INF_OK=0
  integer,parameter,public :: FMR_DIVDRA_MULTI_INF_TARGET_ALREADY_BOUND=1
  integer,parameter,public :: FMR_DIVDRA_MULTI_INF_PROCESS_REJECTED=2
  integer,parameter,public :: FMR_DIVDRA_MULTI_INF_INVALID_RESULT=3

  type,public :: fmr_divdra_multi_inf_binding_diagnostics_t
    integer :: status=FMR_DIVDRA_MULTI_INF_OK
    integer :: process_status=DRAIN_MULTI_INF_OK
    logical :: process_evaluated=.false.
    logical :: published=.false.
    integer :: drainage_levels=0
    integer :: active_nodes=0
    real(real64),allocatable :: authoritative_scalar_transfer(:)
    type(drainage_multilevel_separate_infiltration_result_t) :: process
  end type

  public :: fmr_bind_multilevel_separate_infiltration

contains

  subroutine fmr_bind_multilevel_separate_infiltration(level_parameters,view,scalar_transfer,drain_bottom_cm, &
       surface_water_level_cm,infiltration_depth_factor,drainage_flux_by_level,diagnostics)
    type(drainage_distribution_parameters_t),intent(in)::level_parameters(:)
    type(process_hydraulic_view_t),intent(in)::view
    real(real64),intent(in)::scalar_transfer(:),drain_bottom_cm(:),surface_water_level_cm(:)
    real(real64),intent(in)::infiltration_depth_factor
    real(real64),allocatable,intent(inout)::drainage_flux_by_level(:,:)
    type(fmr_divdra_multi_inf_binding_diagnostics_t),intent(out)::diagnostics
    type(drainage_multilevel_separate_infiltration_result_t)::process_result
    integer::levels,n

    diagnostics=fmr_divdra_multi_inf_binding_diagnostics_t()
    diagnostics%authoritative_scalar_transfer=scalar_transfer
    if(allocated(drainage_flux_by_level))then
      diagnostics%status=FMR_DIVDRA_MULTI_INF_TARGET_ALREADY_BOUND
      return
    end if

    call distribute_multilevel_separate_infiltration_b19(level_parameters,view,scalar_transfer,drain_bottom_cm, &
         surface_water_level_cm,infiltration_depth_factor,process_result)
    diagnostics%process=process_result
    diagnostics%process_status=process_result%status
    diagnostics%process_evaluated=process_result%available
    if(process_result%status/=DRAIN_MULTI_INF_OK.or..not.process_result%available.or. &
         .not.allocated(process_result%drainage_flux_by_level))then
      diagnostics%status=FMR_DIVDRA_MULTI_INF_PROCESS_REJECTED
      return
    end if

    levels=size(level_parameters)
    if(levels<=1.or.size(scalar_transfer)/=levels.or.size(drain_bottom_cm)/=levels.or. &
         size(surface_water_level_cm)/=levels)then
      diagnostics%status=FMR_DIVDRA_MULTI_INF_INVALID_RESULT
      return
    end if
    n=level_parameters(1)%active_nodes
    if(n<=0.or.size(process_result%drainage_flux_by_level,1)/=levels.or. &
         size(process_result%drainage_flux_by_level,2)/=n)then
      diagnostics%status=FMR_DIVDRA_MULTI_INF_INVALID_RESULT
      return
    end if

    allocate(drainage_flux_by_level(levels,n))
    drainage_flux_by_level=process_result%drainage_flux_by_level
    diagnostics%published=.true.
    diagnostics%drainage_levels=levels
    diagnostics%active_nodes=n
  end subroutine
end module mod_fmr_divdra_multilevel_separate_infiltration_binding
