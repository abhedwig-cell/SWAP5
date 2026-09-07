program test_fsi10_source_sink_provider
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_soil_water_solver_contract, only: source_sink_provider_t
  use mod_b110_source_sink_provider, only: b110_source_sink_provider_t, bind_b110_source_sink_provider
  implicit none

  integer, parameter :: n = 4, levels = 3
  type(b110_source_sink_provider_t), target :: provider
  real(real64), target :: qdra(levels,n), qssdi(n), qrot(n)
  real(real64) :: h(n), theta(n), source(n), sink(n), expected_sink(n)
  class(source_sink_provider_t), pointer :: base
  integer :: i, level

  do i = 1, n
     qdra(1,i) = 1.0e-4_real64*real(i,real64)
     qdra(2,i) = -2.5e-5_real64*real(i+1,real64)
     qdra(3,i) = 7.5e-6_real64*real(2*i+1,real64)
     qssdi(i) = 3.0e-5_real64*real(i,real64)
     qrot(i) = 0.0_real64
     h(i) = -10.0_real64*real(i,real64)
     theta(i) = 0.20_real64 + 0.01_real64*real(i,real64)
  end do

  call bind_b110_source_sink_provider(provider, qdra, qssdi, qrot)
  base => provider
  call base%evaluate(h, theta, source, sink)

  expected_sink = 0.0_real64
  do level = 1, levels
     expected_sink = expected_sink + qdra(level,:)
  end do

  do i = 1, n
     if (transfer(source(i),0_int64) /= transfer(qssdi(i),0_int64)) error stop 'F-SI10 source mapping mismatch'
     if (transfer(sink(i),0_int64) /= transfer(expected_sink(i),0_int64)) error stop 'F-SI10 drainage sink mapping mismatch'
  end do

  qdra(2,3) = qdra(2,3) + 1.25e-6_real64
  qssdi(4) = qssdi(4) - 2.0e-6_real64
  call base%evaluate(h, theta, source, sink)
  expected_sink = 0.0_real64
  do level = 1, levels
     expected_sink = expected_sink + qdra(level,:)
  end do
  do i = 1, n
     if (transfer(source(i),0_int64) /= transfer(qssdi(i),0_int64)) error stop 'F-SI10 rebound source mismatch'
     if (transfer(sink(i),0_int64) /= transfer(expected_sink(i),0_int64)) error stop 'F-SI10 rebound sink mismatch'
  end do

  print *, 'F-SI10_SOURCE_SINK_MAPPING PASS'
end program test_fsi10_source_sink_provider
