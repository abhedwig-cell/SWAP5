program test_ftab02a_generated_mvg_table_state
  use, intrinsic :: iso_fortran_env, only: error_unit, int64, real64
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_b110_generated_mvg_table_state, only: b110_generated_mvg_table_state_t, &
       initialize_b110_generated_mvg_table_state, evaluate_b110_generated_mvg_table_state, &
       F_TAB02_STATE_OK, F_TAB02_STATE_UNSUPPORTED_HENPR, F_TAB02_STATE_UNSUPPORTED_KSATEXM
  implicit none

  integer, parameter :: N=3, NH=12
  real(real64) :: cofgen(24,N), bad(24,N)
  real(real64) :: heads(N), theta_a(N), k_a(N), c_a(N), dk(N)
  real(real64) :: theta_t(N), k_t(N), c_t(N)
  real(real64) :: theta_t2(N), k_t2(N), c_t2(N)
  real(real64), parameter :: probes(NH) = [ &
       -1.0e7_real64, -1.0e6_real64, -1.0e5_real64, -1.0e4_real64, &
       -1.0e3_real64, -1.0e2_real64, -1.0e1_real64, -1.0_real64, &
       -1.0e-1_real64, -1.0e-2_real64, -1.0e-3_real64, -1.0e-5_real64 ]
  type(b110_default_mvg_parameters_t), target :: p, p_bad, p_ext
  type(b110_default_mvg_provider_t) :: analytic
  type(b110_generated_mvg_table_state_t) :: state, state2, bad_state
  real(real64) :: theta_err, c_err, logk_err
  integer :: i, j, status

  cofgen = 0.0_real64
  call set_node(1, 0.020_real64, 0.420_real64, 100.0_real64, 0.030_real64, 0.50_real64, 1.80_real64)
  call set_node(2, 0.050_real64, 0.450_real64,  30.0_real64, 0.015_real64, 0.50_real64, 1.50_real64)
  call set_node(3, 0.080_real64, 0.500_real64,   5.0_real64, 0.008_real64, 0.50_real64, 1.30_real64)

  call initialize_b110_default_mvg_parameters(p, cofgen)
  call bind_b110_default_mvg_provider(analytic, p, 1.0e-6_real64)

  call initialize_b110_generated_mvg_table_state(state, p, status)
  if (status /= F_TAB02_STATE_OK) write(error_unit,'(a,i0)') 'F_TAB02_A_INIT_STATUS=', status
  call require(status == F_TAB02_STATE_OK, 'generated state init')
  call require(state%ready(), 'generated state ready')
  call require(state%node_count() == N, 'generated node count')
  call require(state%estimated_bytes() > 0_int64, 'generated state byte estimate')

  call initialize_b110_generated_mvg_table_state(state2, p, status)
  call require(status == F_TAB02_STATE_OK, 'second generated state init')

  theta_err = 0.0_real64
  c_err = 0.0_real64
  logk_err = 0.0_real64
  do j = 1, NH
    heads = probes(j)
    call analytic%evaluate(heads, theta_a, k_a, c_a, dk)
    call evaluate_b110_generated_mvg_table_state(state, heads, theta_t, k_t, c_t, status)
    if (status /= F_TAB02_STATE_OK) write(error_unit,'(a,i0,1x,a,es24.16,1x,a,i0)') &
         'F_TAB02_A_EVAL_FAIL_PROBE=', j, 'h=', probes(j), 'status=', status
    call require(status == F_TAB02_STATE_OK, 'table state evaluate')
    call evaluate_b110_generated_mvg_table_state(state2, heads, theta_t2, k_t2, c_t2, status)
    call require(status == F_TAB02_STATE_OK, 'second table state evaluate')
    call require(all(theta_t == theta_t2) .and. all(k_t == k_t2) .and. all(c_t == c_t2), &
         'deterministic duplicate state')
    theta_err = max(theta_err, maxval(abs(theta_t-theta_a)))
    c_err = max(c_err, maxval(abs(c_t-c_a)))
    do i = 1, N
      logk_err = max(logk_err, abs(log10(k_t(i))-log10(k_a(i))))
    end do
  end do

  call require(theta_err <= 1.0e-4_real64, 'theta qualification')
  call require(c_err <= 1.0e-4_real64, 'capacity qualification')
  call require(logk_err <= 5.0e-4_real64, 'conductivity qualification')

  bad = cofgen
  bad(9,2) = -10.0_real64
  call initialize_b110_default_mvg_parameters(p_bad, bad)
  call initialize_b110_generated_mvg_table_state(bad_state, p_bad, status)
  call require(status == F_TAB02_STATE_UNSUPPORTED_HENPR, 'H_ENPR fail closed')

  call initialize_b110_default_mvg_parameters(p_ext, cofgen, enable_ksatexm_extension=.true.)
  call initialize_b110_generated_mvg_table_state(bad_state, p_ext, status)
  call require(status == F_TAB02_STATE_UNSUPPORTED_KSATEXM, 'KSATEXM fail closed')

  write(*,'(a,es24.16)') 'F_TAB02_A_THETA_MAX_ABS=', theta_err
  write(*,'(a,es24.16)') 'F_TAB02_A_CAPACITY_MAX_ABS=', c_err
  write(*,'(a,es24.16)') 'F_TAB02_A_LOG10K_MAX_ABS=', logk_err
  write(*,'(a,i0)') 'F_TAB02_A_STATE_BYTES=', state%estimated_bytes()
  write(*,'(a)') 'F_TAB02_A_DETERMINISTIC_GENERATION=PASS'
  write(*,'(a)') 'F_TAB02_A_HENPR_FAIL_CLOSED=PASS'
  write(*,'(a)') 'F_TAB02_A_KSATEXM_FAIL_CLOSED=PASS'
  write(*,'(a)') 'F-TAB02-A GENERATED MVG TABLE STATE GATE PASS'

contains

  subroutine set_node(node, theta_r, theta_s, ksat, alpha, lambda, npar)
    integer, intent(in) :: node
    real(real64), intent(in) :: theta_r, theta_s, ksat, alpha, lambda, npar
    cofgen(1,node)=theta_r
    cofgen(2,node)=theta_s
    cofgen(3,node)=ksat
    cofgen(4,node)=alpha
    cofgen(5,node)=lambda
    cofgen(6,node)=npar
    cofgen(7,node)=1.0_real64-1.0_real64/npar
    cofgen(8,node)=alpha
    cofgen(9,node)=0.0_real64
    cofgen(10,node)=ksat
    cofgen(11,node)=0.999_real64
    cofgen(12,node)=0.99_real64*ksat
  end subroutine set_node

  subroutine require(condition, label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(error_unit,'(a,1x,a)') 'F_TAB02_A_GATE_FAIL', trim(label)
      error stop 1
    end if
  end subroutine require
end program test_ftab02a_generated_mvg_table_state
