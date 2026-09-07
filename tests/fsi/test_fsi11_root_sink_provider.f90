program test_fsi11_root_sink_provider
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_soil_water_solver_contract, only: root_sink_provider_t
  use mod_b110_root_sink_provider, only: b110_root_sink_provider_t, bind_b110_root_sink_provider
  implicit none

  integer, parameter :: n = 4
  type(b110_root_sink_provider_t), target :: provider
  class(root_sink_provider_t), pointer :: base
  real(real64), target :: qrot(n)
  real(real64) :: h(n), theta(n), root_sink(n)
  real(real64) :: storage, drainage, source, root_value, legacy_order, folded_order
  integer :: i

  do i = 1, n
     qrot(i) = 1.0e-5_real64*real(2*i-1,real64)
     h(i) = -10.0_real64*real(i,real64)
     theta(i) = 0.20_real64 + 0.01_real64*real(i,real64)
  end do

  call bind_b110_root_sink_provider(provider, qrot)
  base => provider
  call base%evaluate(h, theta, root_sink)
  do i = 1, n
     if (transfer(root_sink(i),0_int64) /= transfer(qrot(i),0_int64)) &
          error stop 'F-SI11 root-sink mapping mismatch'
  end do

  qrot(3) = qrot(3) + 1.25e-6_real64
  call base%evaluate(h, theta, root_sink)
  if (transfer(root_sink(3),0_int64) /= transfer(qrot(3),0_int64)) &
       error stop 'F-SI11 rebound root-sink mismatch'

  ! Sentinel proving that folding root extraction into the drainage sink is not
  ! algebraically safe for exact-reference arithmetic. Legacy HeadCalc orders the
  ! operations as storage + sink - source + root_sink.
  storage = 1.0e16_real64
  drainage = -1.0e16_real64
  source = 1.0_real64
  root_value = 1.0_real64
  legacy_order = storage + drainage - source + root_value
  folded_order = storage + (drainage + root_value) - source
  if (transfer(legacy_order,0_int64) == transfer(folded_order,0_int64)) &
       error stop 'F-SI11 arithmetic-order sentinel failed to distinguish folded root sink'
  if (transfer(legacy_order,0_int64) /= transfer(0.0_real64,0_int64)) &
       error stop 'F-SI11 unexpected legacy arithmetic sentinel result'

  print *, 'F-SI11_ROOT_SINK_MAPPING PASS'
  print *, 'F-SI11_ARITHMETIC_ORDER_SENTINEL PASS'
end program test_fsi11_root_sink_provider
