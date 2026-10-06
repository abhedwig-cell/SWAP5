module mod_fmr_micro_mvg_table_binding
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, evaluate_b110_default_mvg_conductivity
  use mod_root_micro_matric_flux_table, only: micro_matric_flux_table_t, &
       build_micro_matric_flux_table, MICRO_TABLE_POINTS, MICRO_TABLE_OK, MICRO_DRY_HEAD
  implicit none
  private
  public :: fmr_build_micro_mvg_tables, fmr_micro_horizon_map_valid
contains
  pure logical function fmr_micro_horizon_map_valid(first_node, active_nodes) result(valid)
    integer, intent(in) :: first_node(:), active_nodes
    integer :: node
    valid=.false.
    if(active_nodes<=0.or.size(first_node)/=active_nodes) return
    if(first_node(1)/=1) return
    do node=2,active_nodes
      if(first_node(node)/=first_node(node-1).and.first_node(node)/=node) return
    end do
    valid=.true.
  end function

  subroutine fmr_build_micro_mvg_tables(hydraulics, tables, ok, horizon_first_node)
    type(b110_default_mvg_parameters_t), intent(in) :: hydraulics
    type(micro_matric_flux_table_t), allocatable, intent(out) :: tables(:)
    logical, intent(out) :: ok
    integer, intent(in), optional :: horizon_first_node(:)
    real(real64) :: conductivity(MICRO_TABLE_POINTS), dry_k, saturated_k, head
    integer :: node, representative, index, status
    logical :: available
    ok=.false.
    if(hydraulics%active_nodes<=0) return
    if(present(horizon_first_node)) then
      if(.not.fmr_micro_horizon_map_valid(horizon_first_node,hydraulics%active_nodes)) return
    end if
    allocate(tables(hydraulics%active_nodes))
    do node=1,hydraulics%active_nodes
      representative=node
      if(present(horizon_first_node)) representative=horizon_first_node(node)
      if(representative<node) then
        tables(node)=tables(representative)
        cycle
      end if
      do index=1,MICRO_TABLE_POINTS
        head=-10.0_real64**(real(index,real64)/100.0_real64)
        call evaluate_b110_default_mvg_conductivity(hydraulics,representative,head,conductivity(index),available)
        if(.not.available) then
          deallocate(tables)
          return
        end if
      end do
      call evaluate_b110_default_mvg_conductivity(hydraulics,representative,MICRO_DRY_HEAD,dry_k,available)
      if(.not.available) then
        deallocate(tables)
        return
      end if
      call evaluate_b110_default_mvg_conductivity(hydraulics,representative,0.0_real64,saturated_k,available)
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
