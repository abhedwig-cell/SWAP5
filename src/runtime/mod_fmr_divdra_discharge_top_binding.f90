module mod_fmr_divdra_discharge_top_binding
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_process_hydraulic_view, only: process_hydraulic_view_t
  use mod_drainage_spatial_distribution, only: drainage_distribution_parameters_t
  use mod_drainage_discharge_layer_top, only: drainage_discharge_layer_top_control_t, &
       drainage_discharge_layer_top_diagnostics_t, redistribute_discharge_layer_top, DRAIN_TOP_OK
  implicit none
  private

  integer,parameter,public :: FMR_DIVDRA_TOP_OK=0
  integer,parameter,public :: FMR_DIVDRA_TOP_SHAPE_MISMATCH=1
  integer,parameter,public :: FMR_DIVDRA_TOP_PROCESS_REJECTED=2

  public :: apply_fmr_divdra_discharge_top_controls

contains

  subroutine apply_fmr_divdra_discharge_top_controls(parameters,view,scalar_transfer,controls, &
       drainage_flux_by_level,diagnostics,status)
    type(drainage_distribution_parameters_t),intent(in)::parameters(:)
    type(process_hydraulic_view_t),intent(in)::view
    real(real64),intent(in)::scalar_transfer(:)
    type(drainage_discharge_layer_top_control_t),intent(in)::controls(:)
    real(real64),intent(inout)::drainage_flux_by_level(:,:)
    type(drainage_discharge_layer_top_diagnostics_t),allocatable,intent(out)::diagnostics(:)
    integer,intent(out)::status
    real(real64),allocatable::work(:,:),row(:)
    integer::level,n

    status=FMR_DIVDRA_TOP_SHAPE_MISMATCH
    if(size(parameters)<1.or.size(scalar_transfer)/=size(parameters).or.size(controls)/=size(parameters))return
    n=parameters(1)%active_nodes
    if(n<1.or.size(drainage_flux_by_level,1)/=size(parameters).or.size(drainage_flux_by_level,2)/=n)return

    allocate(work(size(drainage_flux_by_level,1),n),diagnostics(size(parameters)))
    work=drainage_flux_by_level
    do level=1,size(parameters)
      call redistribute_discharge_layer_top(parameters(level)%dz,scalar_transfer(level),controls(level), &
           view,work(level,:),row,diagnostics(level))
      if(diagnostics(level)%status/=DRAIN_TOP_OK)then
        status=FMR_DIVDRA_TOP_PROCESS_REJECTED
        return
      end if
      work(level,:)=row
      deallocate(row)
    end do
    drainage_flux_by_level=work
    status=FMR_DIVDRA_TOP_OK
  end subroutine
end module
