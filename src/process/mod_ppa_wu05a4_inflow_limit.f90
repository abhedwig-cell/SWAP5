! B1.11 MACRORATE standard-domain inflow limiter, lines 209-244.
! Inputs are integrated potentials (cm); outputs are rates (cm/day).
! Groundwater-limited volume is supplied by the separately tested VOLUNDR stage.
module mod_ppa_wu05a4_inflow_limit
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private
  public :: limit_domain_inflow
contains
  pure subroutine limit_domain_inflow(storage,volume,groundwater_volume,dt,top_vertical,top_lateral, &
      internal_total,matrix_total,outgoing_total,internal_potential,matrix_potential, &
      fraction,temporary_storage,maximum_storage,top_excess,top_rate,internal_rate,matrix_rate,ok)
    real(real64), intent(in) :: storage,volume,groundwater_volume,dt,top_vertical,top_lateral
    real(real64), intent(in) :: internal_total,matrix_total,outgoing_total
    real(real64), intent(in) :: internal_potential(:),matrix_potential(:)
    real(real64), intent(out) :: fraction,temporary_storage,maximum_storage,top_excess,top_rate(2)
    real(real64), intent(out) :: internal_rate(:),matrix_rate(:)
    logical, intent(out) :: ok
    real(real64) :: incoming,excess
    ok=.false.
    fraction=0; temporary_storage=0; maximum_storage=0; top_excess=0; top_rate=0
    internal_rate=0; matrix_rate=0
    if (size(internal_potential)<1) return
    if (size(matrix_potential)/=size(internal_potential)) return
    if (size(internal_rate)/=size(internal_potential)) return
    if (size(matrix_rate)/=size(internal_potential)) return
    if (.not.all(ieee_is_finite([storage,volume,groundwater_volume,dt,top_vertical,top_lateral, &
        internal_total,matrix_total,outgoing_total]))) return
    if (.not.all(ieee_is_finite(internal_potential))) return
    if (.not.all(ieee_is_finite(matrix_potential))) return
    if (dt<=0 .or. min(storage,volume,groundwater_volume,top_vertical,top_lateral, &
        internal_total,matrix_total,outgoing_total)<0) return
    if (groundwater_volume>volume) return
    if (any(internal_potential<0) .or. any(matrix_potential<0)) return
    ! Keep supplied source-loop totals: summing again here could alter rounding.
    incoming=top_vertical+top_lateral+internal_total+matrix_total
    temporary_storage=storage+incoming-outgoing_total
    maximum_storage=volume
    if ((incoming-matrix_total)/dt<1.e-7_real64 .and. matrix_total/dt>1.e-7_real64) &
        maximum_storage=groundwater_volume
    fraction=1.0_real64
    if (temporary_storage>maximum_storage+1.e-7_real64 .and. incoming>0) then
      excess=temporary_storage-maximum_storage
      fraction=max(0.0_real64,1.0_real64-excess/incoming)
      top_excess=(1.0_real64-fraction)*(top_vertical+top_lateral)
    end if
    top_rate(1)=fraction*top_vertical/dt
    top_rate(2)=fraction*top_lateral/dt
    internal_rate=fraction*internal_potential/dt
    matrix_rate=fraction*matrix_potential/dt
    ok=.true.
  end subroutine
end module
