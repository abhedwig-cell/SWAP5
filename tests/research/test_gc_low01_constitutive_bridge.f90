program test_gc_low01_constitutive_bridge
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, &
       b110_default_mvg_provider_t, initialize_b110_default_mvg_parameters, &
       bind_b110_default_mvg_provider
  use MOD_MvG, only: gc_low01_bind_mvg, watcon, hconduc, moiscap, dhconduc, cofgen
  implicit none

  integer, parameter :: n = 4
  real(real64), parameter :: dt = 0.25_real64
  real(real64) :: raw(24,n)
  real(real64) :: heads(n), water(n), conductivity(n), capacity(n), dkdh(n)
  real(real64) :: theta_s(n), k_s(n), cap_s(n), dk_s(n), heads_s(n)
  real(real64) :: bridge_theta, bridge_k, bridge_c, bridge_d
  type(b110_default_mvg_parameters_t), target :: parameters
  type(b110_default_mvg_provider_t) :: provider
  integer :: i

  raw = 0.0_real64
  do i = 1, n
    raw(1,i) = 0.032_real64
    raw(2,i) = 0.423_real64 + 0.001_real64*real(i-1,real64)
    raw(3,i) = 4.75_real64 + 0.5_real64*real(i-1,real64)
    raw(4,i) = 0.0135_real64
    raw(5,i) = 0.365_real64
    raw(6,i) = 1.455_real64
    raw(7,i) = 1.0_real64 - 1.0_real64/raw(6,i)
    raw(8,i) = raw(4,i)
    raw(9,i) = 0.0_real64
    raw(10,i) = 10.0_real64*raw(3,i)
    raw(11,i) = 0.998_real64
    raw(12,i) = 0.99_real64*raw(3,i)
    raw(22,i) = -1.0e6_real64
    raw(23,i) = 1.0e-12_real64
  end do

  call initialize_b110_default_mvg_parameters(parameters, raw)
  call bind_b110_default_mvg_provider(provider, parameters, dt)
  call gc_low01_bind_mvg(parameters, dt)

  heads = [-100.0_real64, -5.0_real64, -1.0_real64, 0.0_real64]
  call provider%evaluate(heads, water, conductivity, capacity, dkdh)

  do i = 1, n
    bridge_theta = watcon(i,heads(i))
    bridge_k = hconduc(i,heads(i),bridge_theta,1.0_real64)
    bridge_c = moiscap(i,heads(i))
    bridge_d = dhconduc(i,heads(i),bridge_theta,bridge_c,1.0_real64)

    call require(bits_equal(bridge_theta,water(i)), 10+i)
    call require(bits_equal(bridge_k,conductivity(i)), 20+i)
    call require(bits_equal(bridge_c,capacity(i)), 30+i)
    call require(bits_equal(bridge_d,dkdh(i)), 40+i)

    write(*,'(A,I0,A,ES24.16E3,A,ES24.16E3,A,ES24.16E3,A,ES24.16E3)') &
      'GC_LOW01_CONST_NODE=',i,':THETA=',bridge_theta,':K=',bridge_k,':C=',bridge_c,':DKDH=',bridge_d
  end do

  heads_s = 0.0_real64
  call provider%evaluate(heads_s, theta_s, k_s, cap_s, dk_s)
  do i = 1, n
    call require(bits_equal(theta_s(i),cofgen(2,i)), 50+i)
    call require(bits_equal(k_s(i),cofgen(3,i)), 60+i)
    call require(bits_equal(watcon(i,0.0_real64),cofgen(2,i)), 70+i)
    call require(bits_equal(hconduc(i,0.0_real64,cofgen(2,i),1.0_real64),cofgen(3,i)), 80+i)
  end do

  call require(.not.parameters%ksatexm_extension_enabled, 91)

  print '(A)','GC_LOW01_CONST_PROVIDER_SCALAR_EQUIVALENCE=PASS'
  print '(A)','GC_LOW01_CONST_SATURATED_THETA_COFGEN2=PASS'
  print '(A)','GC_LOW01_CONST_SATURATED_K_COFGEN3=PASS'
  print '(A)','GC_LOW01_CONST_KSATEXM_DISABLED_BOUND=PASS'
  print '(A)','GC_LOW01_CONST_BRIDGE_GATE=PASS'

contains

  logical function bits_equal(a,b)
    real(real64), intent(in) :: a,b
    integer(int64) :: ia,ib
    ia=transfer(a,0_int64); ib=transfer(b,0_int64)
    bits_equal=ia==ib
  end function bits_equal

  subroutine require(condition, code)
    logical, intent(in) :: condition
    integer, intent(in) :: code
    if (.not.condition) then
      write(*,'(A,I0)') 'GC_LOW01_CONST_FAIL=',code
      error stop 1
    end if
  end subroutine require

end program test_gc_low01_constitutive_bridge
