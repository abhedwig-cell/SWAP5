program test_mig431_tillage_constitutive
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_tillage_constitutive_process
  implicit none

  type(tillage_vg_parameters_t) :: prior, candidate
  real(real64), allocatable :: density(:)
  real(real64) :: ratio, expected_sat, expected_ks
  integer :: next_event, previous_event, status

  call select_tillage_start_event([10.0_real64,20.0_real64,30.0_real64], 5.0_real64, &
                                   next_event, previous_event, status)
  call require(status == TILLAGE_OK .and. next_event == 1 .and. previous_event == 0, 'before first event')
  call select_tillage_start_event([10.0_real64,20.0_real64,30.0_real64], 20.0_real64, &
                                   next_event, previous_event, status)
  call require(status == TILLAGE_OK .and. next_event == 2 .and. previous_event == 1, 'exact event day')
  call select_tillage_start_event([10.0_real64,20.0_real64,30.0_real64], 25.0_real64, &
                                   next_event, previous_event, status)
  call require(status == TILLAGE_OK .and. next_event == 3 .and. previous_event == 2, 'between events')
  call select_tillage_start_event([10.0_real64,20.0_real64,30.0_real64], 35.0_real64, &
                                   next_event, previous_event, status)
  call require(status == TILLAGE_OK .and. next_event == 4 .and. previous_event == 3, 'after last event')
  call select_tillage_start_event([10.0_real64,10.0_real64], 5.0_real64, &
                                   next_event, previous_event, status)
  call require(status == TILLAGE_INVALID_EVENTS .and. next_event == 0, 'unexecutable duplicate dates fail closed')

  call apply_tillage_density_event([1400.0_real64,1300.0_real64], &
       [1000.0_real64,1100.0_real64], 0.5_real64, density, status)
  call require(status == TILLAGE_OK .and. maxval(abs(density-[1200.0_real64,1200.0_real64])) < &
       1.0e-12_real64, 'event intensity interpolates target density by horizon')
  call consolidate_tillage_density([1200.0_real64], [1400.0_real64], [0.01_real64], &
       2.0_real64, density, status)
  call require(status == TILLAGE_OK .and. abs(density(1)-(1400.0_real64-200.0_real64*exp(-0.2_real64))) < &
       1.0e-12_real64, 'consolidation uses accepted cumulative rain amount in mm')

  prior%theta_residual = 0.05_real64
  prior%theta_saturated = 0.45_real64
  prior%saturated_conductivity = 10.0_real64
  prior%alpha = 0.01_real64
  prior%lambda = 0.5_real64
  prior%n = 1.5_real64
  prior%m = 1.0_real64-1.0_real64/prior%n
  ratio = 1300.0_real64/1200.0_real64
  expected_sat = 0.45_real64*(2650.0_real64-1300.0_real64)/(2650.0_real64-1200.0_real64)
  expected_ks = 10.0_real64*(expected_sat/0.45_real64)**3*ratio**(-3)
  call transform_tillage_vg(prior,1200.0_real64,1300.0_real64,1,0.3_real64,0.2_real64, &
                            0.0_real64,candidate,status)
  call require(status == TILLAGE_OK .and. abs(candidate%theta_residual-0.05_real64*ratio) < &
       1.0e-14_real64 .and. abs(candidate%theta_saturated-expected_sat) < 1.0e-14_real64, &
       'residual and saturated water contents follow independent density oracle')
  call require(abs(candidate%saturated_conductivity-expected_ks) < 1.0e-13_real64 .and. &
       abs(candidate%alpha-0.01_real64*ratio**(-3.97_real64)) < 1.0e-14_real64, &
       'conductivity and alpha follow independent source exponents')
  call require(abs(candidate%n-prior%n) < 1.0e-14_real64 .and. &
       abs(candidate%m-(1.0_real64-1.0_real64/prior%n)) < 1.0e-14_real64, &
       'n model 1 keeps n and regenerates m')
  call transform_tillage_vg(prior,1200.0_real64,1300.0_real64,2,0.3_real64,0.2_real64, &
                            0.0_real64,candidate,status)
  call require(status == TILLAGE_OK .and. abs(candidate%n-(1.0_real64+0.5_real64*ratio**0.95_real64)) < &
       1.0e-14_real64, 'n model 2 uses source silt/clay exponent')
  call transform_tillage_vg(prior,1200.0_real64,1300.0_real64,2,0.3_real64,0.0_real64, &
                            0.0_real64,candidate,status)
  call require(status == TILLAGE_INVALID_PARAMETERS .and. abs(candidate%n-prior%n) < 1.0e-14_real64, &
       'known zero-clay defect fails closed without candidate publication')
  call transform_tillage_vg(prior,1200.0_real64,1300.0_real64,3,0.3_real64,0.2_real64, &
                            -0.001_real64,candidate,status)
  call require(status == TILLAGE_OK .and. abs(candidate%n-1.4_real64) < 1.0e-14_real64, &
       'n model 3 applies persisted matching-point slope')

  write(*,'(a)') 'F_MIG431_TILLAGE_B111_EVENT_START=PASS'
  write(*,'(a)') 'F_MIG431_TILLAGE_DENSITY_CONSOLIDATION=PASS'
  write(*,'(a)') 'F_MIG431_TILLAGE_MVG_N123=PASS'
  write(*,'(a)') 'F_MIG431_TILLAGE_ZERO_CLAY_REJECTED=PASS'

contains

  subroutine require(condition, label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(a)') 'FAIL: '//label
      error stop 1
    end if
  end subroutine require

end program test_mig431_tillage_constitutive
