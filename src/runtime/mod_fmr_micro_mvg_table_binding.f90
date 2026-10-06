module mod_fmr_micro_mvg_table_binding
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, evaluate_b110_default_mvg_conductivity
  use mod_root_micro_matric_flux_table, only: micro_matric_flux_table_t, &
       build_micro_matric_flux_table, MICRO_TABLE_POINTS, MICRO_TABLE_OK, MICRO_DRY_HEAD
  implicit none
  private
  public :: fmr_build_micro_mvg_tables
contains
  subroutine fmr_build_micro_mvg_tables(hydraulics, tables, ok)
    type(b110_default_mvg_parameters_t), intent(in) :: hydraulics
    type(micro_matric_flux_table_t), allocatable, intent(out) :: tables(:)
    logical, intent(out) :: ok
    real(real64) :: conductivity(MICRO_TABLE_POINTS), dry_k, saturated_k, head
    integer :: node, index, status
    logical :: available
    ok=.false.
    if(hydraulics%active_nodes<=0) return
    allocate(tables(hydraulics%active_nodes))
    do node=1,hydraulics%active_nodes
      do index=1,MICRO_TABLE_POINTS
        head=-10.0_real64**(real(index,real64)/100.0_real64)
        call evaluate_b110_default_mvg_conductivity(hydraulics,node,head,conductivity(index),available)
        if(.not.available) then
          deallocate(tables)
          return
        end if
      end do
      call evaluate_b110_default_mvg_conductivity(hydraulics,node,MICRO_DRY_HEAD,dry_k,available)
      if(.not.available) then
        deallocate(tables)
        return
      end if
      call evaluate_b110_default_mvg_conductivity(hydraulics,node,0.0_real64,saturated_k,available)
      if(.not.available) then
        deallocate(tables)
        return
      end if
      call build_micro_matric_flux_table(conductivity,dry_k,saturated_k,tables(node),status)
      if(status/=MICRO_TABLE_OK) then
        deallocate(tables)
        return
      end if
    end do
    ok=.true.
  end subroutine
end module
