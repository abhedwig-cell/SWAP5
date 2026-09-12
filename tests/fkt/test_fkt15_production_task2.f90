program test_fkt15_production_task2
  use, intrinsic :: iso_fortran_env, only: int64, real64, error_unit
  use mod_a23bu_worker_execution_context, only: a23bu_worker_context_t, a23bu_initialize_worker
  use mod_b110_production_soil_water_task2, only: try_b110_production_task2
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use MOD_swap_base, only: swfrost
  use MOD_grid, only: numnod
  use MOD_MvG, only: cofgen
  use MOD_meteo, only: nraidt, epond, peva, empreva
  use MOD_irrigation, only: nird, qssdi
  use MOD_snow, only: melt
  use MOD_drain, only: qdra
  use MOD_frost, only: rfcp
  use variables, only: h, theta, hm1, thetm1, pond, pondm1, gwl, gwlm1, qtop, qbot, hbot, &
       runon, epd, reva, runots, qrot, dt, swbotb, maxit, fldecdt, pondmx, rsro, rsroexp, &
       kmean, numbit, itnumb
  implicit none

  type(a23bu_worker_context_t) :: worker, workers(8)
  type(b110_default_mvg_parameters_t), target :: hydraulic_parameters
  type(b110_default_mvg_provider_t) :: constitutive
  real(real64) :: heads(numnod), water(numnod), conductivity(numnod), capacity(numnod), dkdh(numnod)
  real(real64) :: k_flux
  real(real64) :: h_before(numnod), theta_before(numnod), pond_before, qtop_before, qbot_before
  integer, parameter :: worker_counts(4) = [1,2,4,8]
  logical :: handled
  integer :: i, icase, nw

  call configure_hydraulic_family()
  call initialize_b110_default_mvg_parameters(hydraulic_parameters, cofgen(:,1:numnod))
  call bind_b110_default_mvg_provider(constitutive, hydraulic_parameters, dt)
  heads = -75.0_real64
  call constitutive%evaluate(heads, water, conductivity, capacity, dkdh)
  k_flux = conductivity(1)
  call require(k_flux > 0.0_real64, 'positive equilibrium conductivity')

  call seed_equilibrium(water, k_flux)
  call a23bu_initialize_worker(worker, numnod, 15)
  call try_b110_production_task2(worker, handled)
  call require(handled, 'admitted route handled')
  call require(worker%soil_water_trial%typed_attempted, 'typed attempt recorded')
  call require(worker%soil_water_trial%typed_accepted, 'typed solve accepted')
  call require(.not. worker%soil_water_trial%retry_advised, 'accepted solve no retry')
  call require(worker%soil_water_trial%sensitivity_available, 'accepted qbot sensitivity available')
  call require(trim(worker%soil_water_trial%sensitivity_method) == 'same-tridag-factor', 'same-factor method')
  call require(worker%soil_water_trial%interface_sensitivity_backsolves == 1, 'exactly one tangent backsolve')
  call require(worker%diagnostics%headcalc_calls == 1, 'one hydraulic authority call')
  call require(all_bits_equal(h, heads), 'equilibrium heads bitwise unchanged')
  call require(all_bits_equal(theta, water), 'equilibrium water contents bitwise unchanged')
  call require(same_bits(qtop, -k_flux), 'accepted qtop equilibrium identity')
  call require(same_bits(qbot, -k_flux), 'accepted qbot equilibrium identity')
  call require(same_bits(pond, 0.0_real64), 'accepted pond identity')
  call require(same_bits(reva, 0.0_real64) .and. same_bits(epd, 0.0_real64), 'accepted evaporation metadata')
  call require(same_bits(runots, 0.0_real64), 'accepted runoff metadata')
  call require(.not. fldecdt, 'accepted route no dt reduction')
  write(*,'(A)') 'FKT15_ACCEPTED_TYPED_ROUTE=PASS'
  write(*,'(A)') 'FKT15_ACCEPTED_SENSITIVITY=PASS'
  write(*,'(A)') 'FKT15_SINGLE_HYDRAULIC_AUTHORITY=PASS'

  ! An unsupported configuration must fall through without touching physical state
  ! and must clear any prior trial-local sensitivity metadata.
  h_before = h; theta_before = theta; pond_before = pond; qtop_before = qtop; qbot_before = qbot
  swfrost = 1
  call try_b110_production_task2(worker, handled)
  call require(.not. handled, 'unsupported frost route not handled')
  call require(.not. worker%soil_water_trial%typed_attempted, 'unsupported route no typed attempt')
  call require(.not. worker%soil_water_trial%sensitivity_available, 'unsupported route clears stale sensitivity')
  call require(all_bits_equal(h, h_before), 'unsupported heads unchanged')
  call require(all_bits_equal(theta, theta_before), 'unsupported theta unchanged')
  call require(same_bits(pond,pond_before) .and. same_bits(qtop,qtop_before) .and. same_bits(qbot,qbot_before), &
       'unsupported scalar state unchanged')
  swfrost = 0
  write(*,'(A)') 'FKT15_UNSUPPORTED_DIRECT_FALLBACK_SEAM=PASS'
  write(*,'(A)') 'FKT15_STALE_SENSITIVITY_CLEAR=PASS'

  ! Worker-owned result capsules are exercised as 1/2/4/8 logical-worker groups.
  ! Execution is intentionally interleaved rather than a throughput benchmark: the
  ! purpose here is absence of a module-global last-result/tangent state.
  do icase = 1, 4
    nw = worker_counts(icase)
    do i = 1, nw
      call seed_equilibrium(water, k_flux)
      call a23bu_initialize_worker(workers(i), numnod, i)
      call try_b110_production_task2(workers(i), handled)
      call require(handled .and. workers(i)%soil_water_trial%typed_accepted, 'worker accepted')
      call require(workers(i)%soil_water_trial%sensitivity_available, 'worker sensitivity available')
    end do
    swfrost = 1
    call try_b110_production_task2(workers(nw), handled)
    call require(.not. handled, 'selected worker unsupported route')
    call require(.not. workers(nw)%soil_water_trial%sensitivity_available, 'selected worker cleared')
    do i = 1, nw-1
      call require(workers(i)%soil_water_trial%sensitivity_available, 'other worker capsule preserved')
    end do
    swfrost = 0
    select case (nw)
    case (1)
      write(*,'(A)') 'FKT15_WORKER_ISOLATION_1=PASS'
    case (2)
      write(*,'(A)') 'FKT15_WORKER_ISOLATION_2=PASS'
    case (4)
      write(*,'(A)') 'FKT15_WORKER_ISOLATION_4=PASS'
    case (8)
      write(*,'(A)') 'FKT15_WORKER_ISOLATION_8=PASS'
    end select
  end do
  write(*,'(A)') 'FKT15_EIGHT_WORKER_CAPSULE_ISOLATION=PASS'

  ! Deliberately impossible prescribed bottom flux with one Newton iteration.
  ! The admitted typed route must advise retry and publish neither state nor tangent.
  call seed_equilibrium(water, k_flux)
  maxit = 1
  qbot = 1.0e6_real64
  h_before = h; theta_before = theta; pond_before = pond
  call try_b110_production_task2(worker, handled)
  call require(handled, 'retry case remains typed route')
  call require(worker%soil_water_trial%typed_attempted, 'retry typed attempted')
  call require(.not. worker%soil_water_trial%typed_accepted, 'retry not accepted')
  call require(worker%soil_water_trial%retry_advised, 'retry advised')
  call require(.not. worker%soil_water_trial%sensitivity_available, 'retry no sensitivity')
  call require(fldecdt, 'retry maps to fldecdt')
  call require(all_bits_equal(h,h_before) .and. all_bits_equal(theta,theta_before), 'retry does not publish candidate arrays')
  call require(same_bits(pond,pond_before), 'retry does not publish pond')
  maxit = 12
  write(*,'(A)') 'FKT15_RETRY_FAIL_CLOSED=PASS'

  write(*,'(A)') 'FKT15_PRODUCTION_TASK2_GATE=PASS'

contains

  subroutine configure_hydraulic_family()
    integer :: k
    cofgen = 0.0_real64
    do k = 1, numnod+1
      cofgen(1,k)=0.032_real64; cofgen(2,k)=0.423_real64; cofgen(3,k)=4.75_real64
      cofgen(4,k)=0.0135_real64; cofgen(5,k)=0.365_real64; cofgen(6,k)=1.455_real64
      cofgen(7,k)=1.0_real64-1.0_real64/cofgen(6,k); cofgen(8,k)=cofgen(4,k); cofgen(9,k)=0.0_real64
      cofgen(10,k)=cofgen(3,k); cofgen(11,k)=0.999_real64; cofgen(12,k)=0.99_real64*cofgen(3,k)
      cofgen(13,k)=0.10_real64; cofgen(14,k)=1.50_real64; cofgen(15,k)=0.50_real64
      cofgen(22,k)=-1.0e6_real64; cofgen(23,k)=1.0e-12_real64
    end do
  end subroutine configure_hydraulic_family

  subroutine seed_equilibrium(water0, kval)
    real(real64), intent(in) :: water0(:), kval
    h = -75.0_real64
    theta = water0
    hm1 = h
    thetm1 = theta
    pond = 0.0_real64; pondm1 = 0.0_real64
    gwl = -2.0_real64; gwlm1 = gwl
    qtop = -kval; qbot = -kval; hbot = -100.0_real64
    nraidt = kval; nird = 0.0_real64; melt = 0.0_real64
    epond = 0.0_real64; peva = 0.0_real64; empreva = 0.0_real64
    runon = 0.0_real64; epd = 0.0_real64; reva = 0.0_real64; runots = 0.0_real64
    qrot = 0.0_real64; qdra = 0.0_real64; qssdi = 0.0_real64; rfcp = 1.0_real64
    pondmx = 10.0_real64; rsro = 0.5_real64; rsroexp = 1.0_real64
    swbotb = 2; fldecdt = .false.; numbit = 0; itnumb = 0; kmean = 1.0_real64
  end subroutine seed_equilibrium

  logical function same_bits(a,b)
    real(real64), intent(in) :: a,b
    same_bits = transfer(a,0_int64) == transfer(b,0_int64)
  end function same_bits

  logical function all_bits_equal(a,b)
    real(real64), intent(in) :: a(:),b(:)
    integer :: j
    all_bits_equal = size(a) == size(b)
    if (.not. all_bits_equal) return
    do j = 1, size(a)
      if (.not. same_bits(a(j),b(j))) then
        all_bits_equal = .false.
        return
      end if
    end do
  end function all_bits_equal

  subroutine require(condition,label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(error_unit,'(A,1X,A)') 'FKT15_FAIL', trim(label)
      error stop 1
    end if
  end subroutine require
end program test_fkt15_production_task2
