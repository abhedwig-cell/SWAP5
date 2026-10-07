module mod_fmr_divdra_top_interflow_binding
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_process_hydraulic_view, only: process_hydraulic_view_t
  use mod_drainage_spatial_distribution, only: drainage_distribution_parameters_t
  use mod_drainage_top_interflow_distribution, only: drainage_top_interflow_diagnostics_t, &
       distribute_highest_interflow_signed_divdra, DRAIN_TOPINT_OK
  implicit none
  private

  integer,parameter,public :: FMR_DIVDRA_TOPINT_OK=0
  integer,parameter,public :: FMR_DIVDRA_TOPINT_TARGET_ALREADY_BOUND=1
  integer,parameter,public :: FMR_DIVDRA_TOPINT_PROCESS_REJECTED=2
  integer,parameter,public :: FMR_DIVDRA_TOPINT_INVALID_RESULT=3

  type,public :: fmr_divdra_top_interflow_binding_diagnostics_t
    integer :: status=FMR_DIVDRA_TOPINT_OK
    integer :: process_status=DRAIN_TOPINT_OK
    logical :: process_evaluated=.false.
    logical :: published=.false.
    integer :: drainage_levels=0
    integer :: active_nodes=0
    real(real64),allocatable :: authoritative_scalar_transfer(:)
    type(drainage_top_interflow_diagnostics_t) :: process
  end type

  public :: fmr_bind_highest_interflow_signed_divdra

contains

  subroutine fmr_bind_highest_interflow_signed_divdra(parameters,view,scalar_transfer,top_drain_bottom_cm, &
       drainage_flux_by_level,diagnostics)
    type(drainage_distribution_parameters_t),intent(in)::parameters(:)
    type(process_hydraulic_view_t),intent(in)::view
    real(real64),intent(in)::scalar_transfer(:),top_drain_bottom_cm
    real(real64),allocatable,intent(inout)::drainage_flux_by_level(:,:)
    type(fmr_divdra_top_interflow_binding_diagnostics_t),intent(out)::diagnostics
    real(real64),allocatable::process_flux(:,:)
    type(drainage_top_interflow_diagnostics_t)::process_diag
    integer::levels,n

    diagnostics=fmr_divdra_top_interflow_binding_diagnostics_t()
    diagnostics%authoritative_scalar_transfer=scalar_transfer
    if(allocated(drainage_flux_by_level))then
      diagnostics%status=FMR_DIVDRA_TOPINT_TARGET_ALREADY_BOUND
      return
    end if
    call distribute_highest_interflow_signed_divdra(parameters,view,scalar_transfer,top_drain_bottom_cm, &
         process_flux,process_diag)
    diagnostics%process=process_diag
    diagnostics%process_status=process_diag%status
    diagnostics%process_evaluated=process_diag%evaluated
    if(process_diag%status/=DRAIN_TOPINT_OK)then
      diagnostics%status=FMR_DIVDRA_TOPINT_PROCESS_REJECTED
      return
    end if
    levels=size(parameters)
    if(levels<1.or.size(scalar_transfer)/=levels.or..not.allocated(process_flux))then
      diagnostics%status=FMR_DIVDRA_TOPINT_INVALID_RESULT
      return
    end if
    n=parameters(1)%active_nodes
    if(n<1.or.size(process_flux,1)/=levels.or.size(process_flux,2)/=n)then
      diagnostics%status=FMR_DIVDRA_TOPINT_INVALID_RESULT
      return
    end if
    allocate(drainage_flux_by_level(levels,n))
    drainage_flux_by_level=process_flux
    diagnostics%published=.true.
    diagnostics%drainage_levels=levels
    diagnostics%active_nodes=n
  end subroutine
end module
