program test_fsi35_task2_dispatch_equivalence
  use, intrinsic :: iso_fortran_env, only: int64, real64, error_unit
  use mod_a23bu_worker_execution_context, only: a23bu_worker_context_t, a23bu_initialize_worker
  use MOD_SoilWater, only: soilwater
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use MOD_grid, only: numnod
  use MOD_MvG, only: cofgen
  use MOD_meteo, only: nraidt, epond, peva, empreva
  use MOD_irrigation, only: nird, qssdi
  use MOD_snow, only: melt
  use MOD_drain, only: qdra
  use MOD_frost, only: rfcp
  use variables, only: h, theta, hm1, thetm1, pond, pondm1, gwl, gwlm1, qtop, qbot, hbot, &
       runon, epd, reva, runots, qrot, dt, swbotb, fldecdt, pondmx, rsro, rsroexp, &
       kmean, numbit, itnumb
  implicit none

  type(a23bu_worker_context_t) :: worker
  type(b110_default_mvg_parameters_t), target :: hydraulic_parameters
  type(b110_default_mvg_provider_t) :: constitutive
  real(real64) :: heads(numnod), water(numnod), conductivity(numnod), capacity(numnod), dkdh(numnod)
  real(real64) :: standalone_h(numnod), standalone_theta(numnod)
  real(real64) :: standalone_pond, standalone_gwl, standalone_qtop, standalone_qbot
  real(real64) :: standalone_reva, standalone_epd, standalone_runots
  real(real64) :: k_flux

  call configure_hydraulic_family()
  call initialize_b110_default_mvg_parameters(hydraulic_parameters, cofgen(:,1:numnod))
  call bind_b110_default_mvg_provider(constitutive, hydraulic_parameters, dt)
  heads = -75.0_real64
  call constitutive%evaluate(heads, water, conductivity, capacity, dkdh)
  k_flux = conductivity(1)
  call require(k_flux > 0.0_real64, 'positive equilibrium conductivity')

  call seed_equilibrium(water, k_flux)
  call soilwater(2)
  call require(.not. fldecdt, 'standalone accepted without retry')
  standalone_h = h
  standalone_theta = theta
  standalone_pond = pond
  standalone_gwl = gwl
  standalone_qtop = qtop
  standalone_qbot = qbot
  standalone_reva = reva
  standalone_epd = epd
  standalone_runots = runots

  call seed_equilibrium(water, k_flux)
  call a23bu_initialize_worker(worker, numnod, 35)
  call soilwater(2, worker)
  call require(worker%soil_water_trial%typed_attempted, 'worker typed attempt')
  call require(worker%soil_water_trial%typed_accepted, 'worker typed accepted')
  call require(.not. worker%soil_water_trial%retry_advised, 'worker accepted without retry')
  call require(worker%diagnostics%headcalc_calls == 1, 'worker one hydraulic authority call')

  call require(all_bits_equal(h, standalone_h), 'pressure head standalone worker identity')
  call require(all_bits_equal(theta, standalone_theta), 'water content standalone worker identity')
  call require(same_bits(pond, standalone_pond), 'pond standalone worker identity')
  call require(same_bits(gwl, standalone_gwl), 'groundwater level standalone worker identity')
  call require(same_bits(qtop, standalone_qtop), 'top flux standalone worker identity')
  call require(same_bits(qbot, standalone_qbot), 'bottom flux standalone worker identity')
  call require(same_bits(reva, standalone_reva), 'bare evaporation standalone worker identity')
  call require(same_bits(epd, standalone_epd), 'pond evaporation standalone worker identity')
  call require(same_bits(runots, standalone_runots), 'runoff standalone worker identity')
  call require(all_bits_equal(h, heads), 'equilibrium heads preserved')
  call require(all_bits_equal(theta, water), 'equilibrium theta preserved')

  write(*,'(A)') 'FSI35_STANDALONE_WORKER_TASK2_EQUIVALENCE=PASS'
  write(*,'(A)') 'FSI35_STANDALONE_USES_COMMON_SOLVER_SERVICE=PASS'

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
      write(error_unit,'(A,1X,A)') 'FSI35_FAIL', trim(label)
      error stop 1
    end if
  end subroutine require
end program test_fsi35_task2_dispatch_equivalence
