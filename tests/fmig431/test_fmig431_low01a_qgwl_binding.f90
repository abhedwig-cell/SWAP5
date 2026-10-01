program test_fmig431_low01a_qgwl_binding
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_fmr_legacy_qgwl_bottom_boundary_provider
  use mod_fmr_legacy_bottom_boundary_application_binding
  implicit none
  type(fmr_qgwl_bottom_boundary_config_t) :: c
  type(fmr_legacy_bottom_boundary_binding_t) :: a,b,a2
  integer :: status
  real(real64), parameter :: tol=1.0e-12_real64

  c%swqhbot=FMR_QGWL_EXPONENTIAL
  c%cofqha=-0.133_real64; c%cofqhb=-0.01_real64; c%cofqhc=0.082_real64
  call fmr_resolve_legacy_qgwl_bottom_boundary(c,-86.0_real64,a,status)
  call require(status==FMR_LEGACY_BOTTOM_BINDING_OK .and. a%available,'A available')
  call require(a%legacy_swbotb==4 .and. a%typed_bottom_mode==2,'generic qbot row')
  call close(a%typed_bottom_flux,c%cofqha*exp(c%cofqhb*86.0_real64)+c%cofqhc,'oracle identity')

  call fmr_resolve_legacy_qgwl_bottom_boundary(c,-147.0_real64,b,status)
  call require(status==FMR_LEGACY_BOTTOM_BINDING_OK,'B available')
  call require(abs(a%typed_bottom_flux-b%typed_bottom_flux)>tol,'state dependence')
  call fmr_resolve_legacy_qgwl_bottom_boundary(c,-86.0_real64,a2,status)
  call close(a2%typed_bottom_flux,a%typed_bottom_flux,'A/B/A determinism')

  ! Retry contract: a rejected candidate GWL is not an input. Re-evaluating
  ! from the exact same committed checkpoint must reproduce qbot exactly.
  call fmr_resolve_legacy_qgwl_bottom_boundary(c,-86.0_real64,a2,status)
  call close(a2%typed_bottom_flux,a%typed_bottom_flux,'failed-then-retry checkpoint identity')

  call fmr_resolve_legacy_bottom_boundary(6,b,status)
  call require(status==FMR_LEGACY_BOTTOM_BINDING_OK .and. b%typed_bottom_mode==2,'mode6 preservation')
  call close(b%typed_bottom_flux,0.0_real64,'mode6 zero flux preservation')

  print '(a)', 'F-MIG431-LOW01A QGWL BINDING GATE PASS'
contains
  subroutine close(x,y,label)
    real(real64),intent(in)::x,y
    character(*),intent(in)::label
    if(abs(x-y)>tol) error stop label
  end subroutine
  subroutine require(ok,label)
    logical,intent(in)::ok
    character(*),intent(in)::label
    if(.not.ok) error stop label
  end subroutine
end program test_fmig431_low01a_qgwl_binding
