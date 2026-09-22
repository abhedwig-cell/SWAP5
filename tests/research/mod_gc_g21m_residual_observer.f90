module mod_gc_g21m_residual_observer
  use, intrinsic :: iso_c_binding, only: c_double, c_int
  use, intrinsic :: iso_fortran_env, only: real64
  implicit none
  private

  logical, save :: snapshot_ready = .false.
  logical, save :: node4_terms_ready = .false.
  integer, save :: saved_n = 0
  integer, save :: saved_iteration = 0
  integer, save :: saved_backtracking = 0
  real(real64), save :: saved_residual(4) = 0.0_real64
  real(real64), save :: saved_native_sum = 0.0_real64
  real(real64), save :: saved_native_fmax = 0.0_real64
  real(real64), save :: saved_node4_terms(6) = 0.0_real64

  public :: g21m_record_residual_snapshot
  public :: gc_g21m_snapshot_c

contains

  subroutine g21m_record_residual_snapshot(residual, native_sum, native_fmax, iteration, backtracking, &
       node4_available, storage_term, sink_term, source_term, root_term, upper_flux_term, lower_flux_term)
    real(real64), intent(in) :: residual(:), native_sum, native_fmax
    integer, intent(in) :: iteration, backtracking
    logical, intent(in) :: node4_available
    real(real64), intent(in) :: storage_term, sink_term, source_term, root_term, upper_flux_term, lower_flux_term
    integer :: n

    snapshot_ready = .false.
    node4_terms_ready = .false.
    saved_n = 0
    saved_iteration = 0
    saved_backtracking = 0
    saved_residual = 0.0_real64
    saved_native_sum = 0.0_real64
    saved_native_fmax = 0.0_real64
    saved_node4_terms = 0.0_real64

    n = size(residual)
    if (n /= 4) return
    saved_n = n
    saved_iteration = iteration
    saved_backtracking = backtracking
    saved_residual = residual
    saved_native_sum = native_sum
    saved_native_fmax = native_fmax
    node4_terms_ready = node4_available
    if (node4_available) then
      saved_node4_terms = [storage_term, sink_term, source_term, root_term, upper_flux_term, lower_flux_term]
    end if
    snapshot_ready = .true.
  end subroutine g21m_record_residual_snapshot

  integer(c_int) function gc_g21m_snapshot_c(available,n,iteration,backtracking,node4_available, &
       r1,r2,r3,r4,native_sum,native_fmax,storage_term,sink_term,source_term,root_term,upper_flux_term,lower_flux_term) &
       bind(C,name="gc_g21m_snapshot_c")
    integer(c_int), intent(out) :: available,n,iteration,backtracking,node4_available
    real(c_double), intent(out) :: r1,r2,r3,r4,native_sum,native_fmax
    real(c_double), intent(out) :: storage_term,sink_term,source_term,root_term,upper_flux_term,lower_flux_term

    available=0_c_int; n=0_c_int; iteration=0_c_int; backtracking=0_c_int; node4_available=0_c_int
    r1=0.0_c_double; r2=0.0_c_double; r3=0.0_c_double; r4=0.0_c_double
    native_sum=0.0_c_double; native_fmax=0.0_c_double
    storage_term=0.0_c_double; sink_term=0.0_c_double; source_term=0.0_c_double
    root_term=0.0_c_double; upper_flux_term=0.0_c_double; lower_flux_term=0.0_c_double
    if (.not. snapshot_ready) then
      gc_g21m_snapshot_c=1_c_int
      return
    end if

    available=1_c_int
    n=int(saved_n,c_int)
    iteration=int(saved_iteration,c_int)
    backtracking=int(saved_backtracking,c_int)
    if (node4_terms_ready) node4_available=1_c_int
    r1=real(saved_residual(1),c_double); r2=real(saved_residual(2),c_double)
    r3=real(saved_residual(3),c_double); r4=real(saved_residual(4),c_double)
    native_sum=real(saved_native_sum,c_double); native_fmax=real(saved_native_fmax,c_double)
    storage_term=real(saved_node4_terms(1),c_double); sink_term=real(saved_node4_terms(2),c_double)
    source_term=real(saved_node4_terms(3),c_double); root_term=real(saved_node4_terms(4),c_double)
    upper_flux_term=real(saved_node4_terms(5),c_double); lower_flux_term=real(saved_node4_terms(6),c_double)
    gc_g21m_snapshot_c=0_c_int
  end function gc_g21m_snapshot_c

end module mod_gc_g21m_residual_observer
