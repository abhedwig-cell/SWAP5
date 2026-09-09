program test_fsi21_initial_hydraulic_timescale
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use MOD_grid, only: numnod, dz
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  implicit none

  integer, parameter :: nstates = 6, nattempts = 3
  real(real64), parameter :: initial_heads(nstates) = [ &
       -40.0_real64, -55.0_real64, -110.0_real64, -160.0_real64, -210.0_real64, -320.0_real64 ]
  real(real64), parameter :: attempt_dt(nattempts) = [0.25_real64, 0.125_real64, 0.0625_real64]
  real(real64) :: cofgen(24,numnod), heads(numnod), theta(numnod), conductivity(numnod)
  real(real64) :: capacity(numnod), dkdh(numnod), first_k, first_c, k0, c0, d0, lbottom, tau, lambda
  integer(int64) :: first_k_bits, first_c_bits
  type(b110_default_mvg_parameters_t), target :: hyd_parameters
  type(b110_default_mvg_provider_t) :: constitutive
  integer :: state_id, attempt_id, k

  cofgen = 0.0_real64
  do k = 1, numnod
    cofgen(1,k)=0.032_real64; cofgen(2,k)=0.423_real64; cofgen(3,k)=4.75_real64
    cofgen(4,k)=0.0135_real64; cofgen(5,k)=0.365_real64; cofgen(6,k)=1.455_real64
    cofgen(7,k)=1.0_real64-1.0_real64/cofgen(6,k); cofgen(8,k)=cofgen(4,k)
    cofgen(9,k)=0.0_real64; cofgen(10,k)=cofgen(3,k); cofgen(11,k)=0.999_real64
    cofgen(12,k)=0.99_real64*cofgen(3,k); cofgen(22,k)=-1.0e6_real64; cofgen(23,k)=1.0e-12_real64
  end do
  call initialize_b110_default_mvg_parameters(hyd_parameters, cofgen)
  lbottom = dz(numnod)
  call require(lbottom > 0.0_real64, 'positive bottom-node characteristic length')

  do state_id = 1, nstates
    heads = initial_heads(state_id)
    first_k = -1.0_real64
    first_c = -1.0_real64
    first_k_bits = -1_int64
    first_c_bits = -1_int64
    do attempt_id = 1, nattempts
      call bind_b110_default_mvg_provider(constitutive, hyd_parameters, attempt_dt(attempt_id))
      call constitutive%evaluate(heads, theta, conductivity, capacity, dkdh)
      call require(all(conductivity > 0.0_real64), 'positive conductivity')
      call require(all(capacity > 0.0_real64), 'positive capacity')
      call require(all(conductivity == conductivity(1)), 'uniform-state conductivity')
      call require(all(capacity == capacity(1)), 'uniform-state capacity')
      k0 = conductivity(numnod)
      c0 = capacity(numnod)
      if (attempt_id == 1) then
        first_k = k0
        first_c = c0
        first_k_bits = transfer(k0, 0_int64)
        first_c_bits = transfer(c0, 0_int64)
      else
        call require(transfer(k0,0_int64) == first_k_bits, 'K0 invariant to retry horizon at T0')
        call require(transfer(c0,0_int64) == first_c_bits, 'C0 invariant to retry horizon at T0')
      end if
      d0 = k0/c0
      tau = c0*lbottom*lbottom/k0
      lambda = attempt_dt(attempt_id)/tau
      call require(d0 > 0.0_real64 .and. tau > 0.0_real64 .and. lambda > 0.0_real64, 'finite positive descriptor')
      write(*,'(A,I0,A,I0,A,ES26.17E3,A,ES26.17E3,A,ES26.17E3,A,ES26.17E3,A,ES26.17E3,A,ES26.17E3,A,ES26.17E3,A,ES26.17E3)') &
           'FSI21_GATEA_ROW:STATE=', state_id, ':ATTEMPT=', attempt_id, ':H0_CM=', initial_heads(state_id), &
           ':DT_DAY=', attempt_dt(attempt_id), ':K0_CM_DAY=', k0, ':C0_PER_CM=', c0, ':D0_CM2_DAY=', d0, &
           ':L_BOTTOM_CM=', lbottom, ':TAU_DAY=', tau, ':LAMBDA=', lambda
    end do
    call require(first_k > 0.0_real64 .and. first_c > 0.0_real64, 'state descriptor captured')
  end do

  write(*,'(A)') 'FSI21_GATEA_T0_K_C_RETRY_HORIZON_INVARIANCE=PASS'
  write(*,'(A)') 'FSI21_GATEA_INITIAL_HYDRAULIC_TIMESCALE_DRIVER PASS'

contains

  subroutine require(condition, label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(A,1X,A)') 'FSI21_GATEA_FAIL', trim(label)
      error stop 1
    end if
  end subroutine require
end program test_fsi21_initial_hydraulic_timescale
