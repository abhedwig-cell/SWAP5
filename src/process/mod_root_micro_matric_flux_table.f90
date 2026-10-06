module mod_root_micro_matric_flux_table
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private
  integer, parameter, public :: MICRO_TABLE_POINTS=430, MICRO_TABLE_OK=0, MICRO_TABLE_INVALID=1
  real(real64), parameter, public :: MICRO_DRY_HEAD=-20000.0_real64
  real(real64), parameter :: WET_HEAD=-1.023293_real64
  type, public :: micro_matric_flux_table_t
    private
    real(real64) :: m(MICRO_TABLE_POINTS)=0.0_real64, k(MICRO_TABLE_POINTS)=0.0_real64
    real(real64) :: dry_k=0.0_real64, saturated_k=0.0_real64
    logical :: ready=.false.
  end type
  public :: build_micro_matric_flux_table, evaluate_micro_matric_flux_table
contains
  subroutine build_micro_matric_flux_table(conductivity, dry_conductivity, saturated_conductivity, table, status)
    real(real64), intent(in) :: conductivity(:), dry_conductivity, saturated_conductivity
    type(micro_matric_flux_table_t), intent(inout) :: table
    integer, intent(out) :: status
    type(micro_matric_flux_table_t) :: candidate
    integer :: i
    real(real64) :: head1, head2
    status=MICRO_TABLE_INVALID
    if(size(conductivity)/=MICRO_TABLE_POINTS) return
    if(any(.not.ieee_is_finite(conductivity))) return
    if(.not.ieee_is_finite(dry_conductivity).or..not.ieee_is_finite(saturated_conductivity)) return
    if(any(conductivity<0.0_real64).or.dry_conductivity<0.0_real64.or.saturated_conductivity<0.0_real64) return
    candidate%k=conductivity
    candidate%dry_k=dry_conductivity
    candidate%saturated_k=saturated_conductivity
    head1=-10.0_real64**(real(MICRO_TABLE_POINTS,real64)/100.0_real64)
    candidate%m(MICRO_TABLE_POINTS)=0.5_real64*(dry_conductivity+conductivity(MICRO_TABLE_POINTS))*(head1-MICRO_DRY_HEAD)
    do i=MICRO_TABLE_POINTS-1,1,-1
      head2=-10.0_real64**(real(i,real64)/100.0_real64)
      candidate%m(i)=candidate%m(i+1)+0.5_real64*(conductivity(i+1)+conductivity(i))*(head2-head1)
      head1=head2
    end do
    if(any(.not.ieee_is_finite(candidate%m))) return
    candidate%ready=.true.
    table=candidate
    status=MICRO_TABLE_OK
  end subroutine

  subroutine evaluate_micro_matric_flux_table(table, head, matric_flux, conductivity, status)
    type(micro_matric_flux_table_t), intent(in) :: table
    real(real64), intent(in) :: head
    real(real64), intent(out) :: matric_flux, conductivity
    integer, intent(out) :: status
    integer :: i
    real(real64) :: loghead, fraction, first_head, span, delta
    status=MICRO_TABLE_INVALID
    matric_flux=0.0_real64
    conductivity=0.0_real64
    if(.not.table%ready.or..not.ieee_is_finite(head)) return
    first_head=-10.0_real64**(real(MICRO_TABLE_POINTS,real64)/100.0_real64)
    if(head<MICRO_DRY_HEAD) then
      ! Explicit physical dry cutoff retained from the source.
    else if(head<=first_head) then
      span=first_head-MICRO_DRY_HEAD
      delta=head-MICRO_DRY_HEAD
      fraction=delta/span
      conductivity=table%dry_k+(table%k(MICRO_TABLE_POINTS)-table%dry_k)*fraction
      matric_flux=table%dry_k*delta+0.5_real64*(table%k(MICRO_TABLE_POINTS)-table%dry_k)*delta*fraction
    else if(head>WET_HEAD) then
      matric_flux=table%m(1)+(head-WET_HEAD)*table%saturated_k
      conductivity=table%saturated_k
    else
      loghead=100.0_real64*log10(-head)
      i=int(loghead)
      if(i<1.or.i>=MICRO_TABLE_POINTS) return
      fraction=loghead-real(i,real64)
      matric_flux=fraction*table%m(i+1)+(1.0_real64-fraction)*table%m(i)
      conductivity=fraction*table%k(i+1)+(1.0_real64-fraction)*table%k(i)
    end if
    if(.not.ieee_is_finite(matric_flux).or..not.ieee_is_finite(conductivity)) return
    status=MICRO_TABLE_OK
  end subroutine
end module
