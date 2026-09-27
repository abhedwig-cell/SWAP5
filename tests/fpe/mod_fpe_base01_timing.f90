module mod_fpe_base01_timing
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: iso_c_binding, only: c_int, c_double
  implicit none
  private
  integer(int64), save :: solver_ticks=0_int64
  integer(int64), save :: outer_const_ticks=0_int64
  integer(int64), save :: initial_residual_ticks=0_int64
  integer(int64), save :: jacobian_ticks=0_int64
  integer(int64), save :: linear_ticks=0_int64
  integer(int64), save :: candidate_ticks=0_int64
  integer(int64), save :: candidate_const_ticks=0_int64
  integer(int64), save :: candidate_residual_ticks=0_int64
  public :: base01_clock, base01_add_solver, base01_add_outer_constitutive
  public :: base01_add_initial_residual, base01_add_jacobian, base01_add_linear
  public :: base01_add_candidate, base01_add_candidate_constitutive, base01_add_candidate_residual
  public :: fpe_base01_timing_reset_c, fpe_base01_timing_get_c
contains
  subroutine base01_clock(t0)
    integer(int64), intent(out) :: t0
    call system_clock(t0)
  end subroutine

  subroutine add_elapsed(counter,t0)
    integer(int64), intent(inout) :: counter
    integer(int64), intent(in) :: t0
    integer(int64) :: t1
    call system_clock(t1)
    counter=counter+max(0_int64,t1-t0)
  end subroutine

  subroutine base01_add_solver(t0)
    integer(int64), intent(in) :: t0
    call add_elapsed(solver_ticks,t0)
  end subroutine
  subroutine base01_add_outer_constitutive(t0)
    integer(int64), intent(in) :: t0
    call add_elapsed(outer_const_ticks,t0)
  end subroutine
  subroutine base01_add_initial_residual(t0)
    integer(int64), intent(in) :: t0
    call add_elapsed(initial_residual_ticks,t0)
  end subroutine
  subroutine base01_add_jacobian(t0)
    integer(int64), intent(in) :: t0
    call add_elapsed(jacobian_ticks,t0)
  end subroutine
  subroutine base01_add_linear(t0)
    integer(int64), intent(in) :: t0
    call add_elapsed(linear_ticks,t0)
  end subroutine
  subroutine base01_add_candidate(t0)
    integer(int64), intent(in) :: t0
    call add_elapsed(candidate_ticks,t0)
  end subroutine
  subroutine base01_add_candidate_constitutive(t0)
    integer(int64), intent(in) :: t0
    call add_elapsed(candidate_const_ticks,t0)
  end subroutine
  subroutine base01_add_candidate_residual(t0)
    integer(int64), intent(in) :: t0
    call add_elapsed(candidate_residual_ticks,t0)
  end subroutine

  integer(c_int) function fpe_base01_timing_reset_c() bind(C,name="fpe_base01_timing_reset_c")
    solver_ticks=0_int64
    outer_const_ticks=0_int64
    initial_residual_ticks=0_int64
    jacobian_ticks=0_int64
    linear_ticks=0_int64
    candidate_ticks=0_int64
    candidate_const_ticks=0_int64
    candidate_residual_ticks=0_int64
    fpe_base01_timing_reset_c=0_c_int
  end function

  integer(c_int) function fpe_base01_timing_get_c(solver_s,outer_const_s,initial_residual_s,jacobian_s,linear_s, &
       candidate_s,candidate_const_s,candidate_residual_s) bind(C,name="fpe_base01_timing_get_c")
    real(c_double), intent(out) :: solver_s,outer_const_s,initial_residual_s,jacobian_s,linear_s
    real(c_double), intent(out) :: candidate_s,candidate_const_s,candidate_residual_s
    integer(int64) :: rate
    call system_clock(count_rate=rate)
    if(rate<=0_int64) then
      fpe_base01_timing_get_c=1_c_int
      return
    end if
    solver_s=real(solver_ticks,real64)/real(rate,real64)
    outer_const_s=real(outer_const_ticks,real64)/real(rate,real64)
    initial_residual_s=real(initial_residual_ticks,real64)/real(rate,real64)
    jacobian_s=real(jacobian_ticks,real64)/real(rate,real64)
    linear_s=real(linear_ticks,real64)/real(rate,real64)
    candidate_s=real(candidate_ticks,real64)/real(rate,real64)
    candidate_const_s=real(candidate_const_ticks,real64)/real(rate,real64)
    candidate_residual_s=real(candidate_residual_ticks,real64)/real(rate,real64)
    fpe_base01_timing_get_c=0_c_int
  end function
end module mod_fpe_base01_timing
