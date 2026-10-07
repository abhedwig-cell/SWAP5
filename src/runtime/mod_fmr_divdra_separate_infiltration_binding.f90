module mod_fmr_divdra_separate_infiltration_binding
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_process_hydraulic_view, only: process_hydraulic_view_t
  use mod_drainage_spatial_distribution, only: drainage_distribution_parameters_t
  use mod_drainage_separate_infiltration_distribution, only: drainage_separate_infiltration_diagnostics_t, &
       distribute_single_level_separate_infiltration, DRAIN_INF_SPLIT_OK
  implicit none
  private

  integer,parameter,public :: FMR_DIVDRA_INF_SPLIT_OK=0
  integer,parameter,public :: FMR_DIVDRA_INF_SPLIT_TARGET_ALREADY_BOUND=1
  integer,parameter,public :: FMR_DIVDRA_INF_SPLIT_PROCESS_REJECTED=2
  integer,parameter,public :: FMR_DIVDRA_INF_SPLIT_INVALID_RESULT=3

  type,public :: fmr_divdra_separate_infiltration_binding_diagnostics_t
    integer :: status=FMR_DIVDRA_INF_SPLIT_OK
    integer :: process_status=DRAIN_INF_SPLIT_OK
    logical :: process_evaluated=.false.
    logical :: published=.false.
    integer :: active_nodes=0
    real(real64) :: authoritative_scalar_transfer=0.0_real64
    type(drainage_separate_infiltration_diagnostics_t) :: process
  end type

  public :: fmr_bind_single_level_separate_infiltration

contains

  subroutine fmr_bind_single_level_separate_infiltration(parameters,view,scalar_transfer,drain_bottom_cm, &
       surface_water_level_cm,infiltration_depth_factor,drainage_flux_by_level,diagnostics)
    type(drainage_distribution_parameters_t),intent(in)::parameters
    type(process_hydraulic_view_t),intent(in)::view
    real(real64),intent(in)::scalar_transfer,drain_bottom_cm,surface_water_level_cm,infiltration_depth_factor
    real(real64),allocatable,intent(inout)::drainage_flux_by_level(:,:)
    type(fmr_divdra_separate_infiltration_binding_diagnostics_t),intent(out)::diagnostics
    real(real64),allocatable::nodal(:)
    type(drainage_separate_infiltration_diagnostics_t)::process_diag
    integer::n

    diagnostics=fmr_divdra_separate_infiltration_binding_diagnostics_t()
    diagnostics%authoritative_scalar_transfer=scalar_transfer
    if(allocated(drainage_flux_by_level))then
      diagnostics%status=FMR_DIVDRA_INF_SPLIT_TARGET_ALREADY_BOUND
      return
    end if
    call distribute_single_level_separate_infiltration(parameters,view,scalar_transfer,drain_bottom_cm, &
         surface_water_level_cm,infiltration_depth_factor,nodal,process_diag)
    diagnostics%process=process_diag
    diagnostics%process_status=process_diag%status
    diagnostics%process_evaluated=process_diag%evaluated
    if(process_diag%status/=DRAIN_INF_SPLIT_OK.or..not.allocated(nodal))then
      diagnostics%status=FMR_DIVDRA_INF_SPLIT_PROCESS_REJECTED
      return
    end if
    n=parameters%active_nodes
    if(n<1.or.size(nodal)/=n)then
      diagnostics%status=FMR_DIVDRA_INF_SPLIT_INVALID_RESULT
      return
    end if
    allocate(drainage_flux_by_level(1,n))
    drainage_flux_by_level(1,:)=nodal
    diagnostics%published=.true.
    diagnostics%active_nodes=n
  end subroutine
end module
