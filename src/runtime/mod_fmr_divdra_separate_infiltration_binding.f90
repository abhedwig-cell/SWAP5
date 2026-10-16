module mod_fmr_divdra_separate_infiltration_binding
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_process_hydraulic_view, only: process_hydraulic_view_t
  use mod_drainage_spatial_distribution, only: drainage_distribution_parameters_t
  use mod_drainage_b19_separate_infiltration_adapter
  implicit none
  private
  integer,parameter,public::FMR_DIVDRA_INF_SPLIT_OK=0,FMR_DIVDRA_INF_SPLIT_TARGET_ALREADY_BOUND=1
  integer,parameter,public::FMR_DIVDRA_INF_SPLIT_PROCESS_REJECTED=2
  type,public::fmr_divdra_separate_infiltration_binding_diagnostics_t
    integer::status=FMR_DIVDRA_INF_SPLIT_OK,process_status=DRAIN_B19_INF_OK
    logical::published=.false.
    real(real64),allocatable::authoritative_scalar_transfer(:)
  end type
  public::fmr_bind_separate_infiltration
contains
  subroutine fmr_bind_separate_infiltration(p,view,q,controls,target,diagnostics)
    type(drainage_distribution_parameters_t),intent(in)::p(:)
    type(process_hydraulic_view_t),intent(in)::view
    real(real64),intent(in)::q(:)
    type(drainage_b19_separate_infiltration_parameters_t),intent(in)::controls(:)
    real(real64),allocatable,intent(inout)::target(:,:)
    type(fmr_divdra_separate_infiltration_binding_diagnostics_t),intent(out)::diagnostics
    real(real64),allocatable::scratch(:,:)
    type(drainage_b19_separate_infiltration_result_t)::single
    integer::status
    diagnostics=fmr_divdra_separate_infiltration_binding_diagnostics_t()
    diagnostics%authoritative_scalar_transfer=q
    if(allocated(target))then
      diagnostics%status=FMR_DIVDRA_INF_SPLIT_TARGET_ALREADY_BOUND;return
    end if
    status=DRAIN_B19_INF_INVALID_PARAMETERS
    if(size(p)==1.and.size(q)==1.and.size(controls)==1)then
      call distribute_single_level_separate_infiltration_b19(p(1),view,q(1),controls(1),single)
      status=single%status
      if(single%available)then
        allocate(scratch(1,size(single%nodal_transfer)));scratch(1,:)=single%nodal_transfer
      end if
    else
      call distribute_multilevel_separate_infiltration_b19(p,view,q,controls,scratch,status)
    end if
    diagnostics%process_status=status
    if(status/=DRAIN_B19_INF_OK.or..not.allocated(scratch))then
      diagnostics%status=FMR_DIVDRA_INF_SPLIT_PROCESS_REJECTED;return
    end if
    call move_alloc(scratch,target);diagnostics%published=.true.
  end subroutine
end module
