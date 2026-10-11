program test_fmig431_low01a_qgwl_provider
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_fmr_legacy_qgwl_bottom_boundary_provider
  implicit none
  type(fmr_qgwl_bottom_boundary_config_t) :: c
  type(fmr_qgwl_bottom_boundary_result_t) :: r
  integer :: status
  real(real64), parameter :: tol=1.0e-12_real64

  c%swqhbot=FMR_QGWL_EXPONENTIAL
  c%cofqha=-0.133_real64; c%cofqhb=-0.01_real64; c%cofqhc=0.082_real64
  call fmr_evaluate_legacy_qgwl_bottom_boundary(c,-86.0_real64,r,status)
  call require(status==FMR_QGWL_OK .and. r%available,'exponential available')
  call close(r%qbot_cm_per_day,c%cofqha*exp(c%cofqhb*86.0_real64)+c%cofqhc,'exact exponential')
  call require(r%qbot_cm_per_day>0.0_real64,'positive qbot case')
  c%cofqhc=0.0_real64
  call fmr_evaluate_legacy_qgwl_bottom_boundary(c,-86.0_real64,r,status)
  call require(r%qbot_cm_per_day<0.0_real64,'negative qbot case')
  c%cofqha=0.0_real64
  call fmr_evaluate_legacy_qgwl_bottom_boundary(c,-86.0_real64,r,status)
  call close(r%qbot_cm_per_day,0.0_real64,'zero qbot case')

  c=fmr_qgwl_bottom_boundary_config_t(); c%swqhbot=FMR_QGWL_TABLE
  allocate(c%htab(3),c%qtab(3))
  c%htab=[-0.1_real64,-70.0_real64,-125.0_real64]
  c%qtab=[-0.35_real64,-0.05_real64,-0.01_real64]
  call fmr_evaluate_legacy_qgwl_bottom_boundary(c,-35.05_real64,r,status)
  call close(r%qbot_cm_per_day,-0.20_real64,'descending interpolation')
  call fmr_evaluate_legacy_qgwl_bottom_boundary(c,0.0_real64,r,status)
  call close(r%qbot_cm_per_day,-0.35_real64,'wet endpoint clamp')
  call fmr_evaluate_legacy_qgwl_bottom_boundary(c,-1000.0_real64,r,status)
  call close(r%qbot_cm_per_day,-0.01_real64,'dry endpoint clamp')

  c%htab=[-125.0_real64,-70.0_real64,-0.1_real64]
  c%qtab=[-0.01_real64,-0.05_real64,-0.35_real64]
  call fmr_evaluate_legacy_qgwl_bottom_boundary(c,-35.05_real64,r,status)
  call close(r%qbot_cm_per_day,-0.20_real64,'ascending identity')

  c%htab=[-125.0_real64,-70.0_real64,-70.0_real64]
  call fmr_evaluate_legacy_qgwl_bottom_boundary(c,-80.0_real64,r,status)
  call require(status==FMR_QGWL_INVALID_TABLE .and. .not.r%available,'duplicate fail closed')

  c=fmr_qgwl_bottom_boundary_config_t(); c%swqhbot=FMR_QGWL_EXPONENTIAL
  c%cofqha=101.0_real64
  call fmr_evaluate_legacy_qgwl_bottom_boundary(c,-80.0_real64,r,status)
  call require(status==FMR_QGWL_INVALID_CONFIG .and. .not.r%available,'coefficient domain fail closed')

  print '(a)', 'F-MIG431-LOW01A QGWL PROVIDER GATE PASS'
contains
  subroutine close(a,b,label)
    real(real64),intent(in)::a,b
    character(*),intent(in)::label
    if(abs(a-b)>tol) then
      print *,trim(label),a,b
      error stop 1
    end if
  end subroutine
  subroutine require(ok,label)
    logical,intent(in)::ok
    character(*),intent(in)::label
    if(.not.ok) then
      print *,trim(label)
      error stop 1
    end if
  end subroutine
end program test_fmig431_low01a_qgwl_provider
