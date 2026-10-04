program test_solute_water_face_flux_reconstruction
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan
  use mod_solute_water_face_flux_reconstruction, only: reconstruct_interval_water_face_flux, &
       WATER_FACE_FLUX_OK, WATER_FACE_FLUX_INVALID, WATER_FACE_FLUX_BOUNDARY_CLOSURE
  implicit none

  call test_manufactured_flux_recovery()
  call test_boundary_closure_rejection()
  call test_mean_flux_does_not_identify_reversal_transport()
  call test_invalid_inputs()
  write(*,'(a)') 'PPA_WU05E_WATER_FACE_FLUX_RECONSTRUCTION=PASS'

contains

  subroutine test_manufactured_flux_recovery()
    real(real64) :: dz(3), theta0(3), theta1(3), source(3), expected(4), dt, residual
    real(real64), allocatable :: actual(:)
    integer :: status, i

    dz = [10.0_real64,20.0_real64,15.0_real64]
    theta0 = [0.20_real64,0.25_real64,0.30_real64]
    source = [0.03_real64,-0.02_real64,0.01_real64]
    expected = [0.8_real64,0.4_real64,-0.1_real64,0.2_real64]
    dt = 0.5_real64
    do i=1,3
      theta1(i) = theta0(i) + dt*(expected(i)-expected(i+1)+source(i))/dz(i)
    end do

    call reconstruct_interval_water_face_flux(dz,theta0,theta1,source,expected(1),expected(4),dt, &
         1.0e-12_real64,actual,residual,status)
    call require(status==WATER_FACE_FLUX_OK,'manufactured conservative profile accepted')
    call require(allocated(actual),'flux result allocated on success')
    call require(size(actual)==size(expected),'one flux per boundary/internal face')
    call require(maxval(abs(actual-expected))<=2.0e-14_real64,'manufactured face fluxes recovered')
    call require(abs(residual)<=2.0e-14_real64,'bottom closure residual is small')
  end subroutine test_manufactured_flux_recovery

  subroutine test_boundary_closure_rejection()
    real(real64) :: dz(2), theta0(2), theta1(2), source(2), residual
    real(real64), allocatable :: actual(:)
    integer :: status

    dz=[5.0_real64,10.0_real64]
    theta0=[0.2_real64,0.3_real64]
    theta1=[0.21_real64,0.29_real64]
    source=0.0_real64
    call reconstruct_interval_water_face_flux(dz,theta0,theta1,source,0.1_real64,0.5_real64,1.0_real64, &
         1.0e-12_real64,actual,residual,status)
    call require(status==WATER_FACE_FLUX_BOUNDARY_CLOSURE,'inconsistent bottom boundary rejected')
    call require(.not.allocated(actual),'rejected flux profile is not published')
    call require(abs(residual)>1.0e-12_real64,'closure residual retained for diagnostics')
  end subroutine test_boundary_closure_rejection

  subroutine test_mean_flux_does_not_identify_reversal_transport()
    real(real64), parameter :: q=1.0_real64, half_interval=0.5_real64
    real(real64), parameter :: c_left=1.0_real64, c_right=0.0_real64
    real(real64) :: signed_mean, directional_salt_transfer, mean_only_salt_transfer

    ! The two accepted half-intervals have equal and opposite water flux,
    ! hence zero signed mean and zero net water storage change at this face.
    ! Their ordered donor concentrations still produce nonzero salt transfer.
    signed_mean=(q*half_interval-q*half_interval)/(2.0_real64*half_interval)
    directional_salt_transfer=q*half_interval*c_left-q*half_interval*c_right
    mean_only_salt_transfer=signed_mean*(2.0_real64*half_interval)*c_left

    call require(abs(signed_mean)<=epsilon(1.0_real64),'reversing flux has zero signed mean')
    call require(abs(directional_salt_transfer-q*half_interval)<=epsilon(1.0_real64), &
         'ordered reversal transports salt despite zero mean water flux')
    call require(abs(mean_only_salt_transfer)<=epsilon(1.0_real64), &
         'applying only reconstructed mean loses the directional salt transfer')
  end subroutine test_mean_flux_does_not_identify_reversal_transport

  subroutine test_invalid_inputs()
    real(real64) :: dz(1), theta0(1), theta1(1), source(1), residual, nan_value
    real(real64), allocatable :: actual(:)
    integer :: status

    dz=[1.0_real64]; theta0=[0.2_real64]; theta1=[0.2_real64]; source=[0.0_real64]
    call reconstruct_interval_water_face_flux(dz,theta0,theta1,source,0.0_real64,0.0_real64,0.0_real64, &
         1.0e-12_real64,actual,residual,status)
    call require(status==WATER_FACE_FLUX_INVALID,'zero duration rejected')
    call require(.not.allocated(actual),'invalid request produces no flux profile')

    nan_value=ieee_value(0.0_real64,ieee_quiet_nan)
    call reconstruct_interval_water_face_flux(dz,theta0,theta1,source,nan_value,0.0_real64,1.0_real64, &
         1.0e-12_real64,actual,residual,status)
    call require(status==WATER_FACE_FLUX_INVALID,'nonfinite boundary rejected')
    call require(.not.allocated(actual),'nonfinite input produces no flux profile')
  end subroutine test_invalid_inputs

  subroutine require(condition,message)
    logical,intent(in)::condition
    character(len=*),intent(in)::message
    if(.not.condition)then
      write(*,'(a)') 'FAIL: '//message
      error stop 1
    end if
  end subroutine require

end program test_solute_water_face_flux_reconstruction
