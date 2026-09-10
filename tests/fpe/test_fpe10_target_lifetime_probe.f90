program test_fpe10_target_lifetime_probe
  use, intrinsic :: iso_fortran_env, only: real64
  implicit none

  type :: forcing_t
    real(real64), allocatable :: values(:)
  end type forcing_t

  type :: model_t
    real(real64), pointer :: view(:) => null()
  end type model_t

  type(forcing_t) :: registry(1)
  type(model_t) :: model
  real(real64) :: checksum

  allocate(registry(1)%values(4))
  registry(1)%values = [1.0_real64, 2.0_real64, 3.0_real64, 4.0_real64]

  call outer_runtime(registry, model, checksum)
  if (abs(checksum - 10.0_real64) > 0.0_real64) error stop 'FPE10 target lifetime checksum mismatch'
  if (associated(model%view)) error stop 'FPE10 target lifetime view escaped outer runtime'
  if (any(registry(1)%values /= [1.0_real64, 2.0_real64, 3.0_real64, 4.0_real64])) &
       error stop 'FPE10 immutable target mutated'

  print *, 'FPE10_TARGET_LIFETIME_NESTED_VIEW=PASS'
  print *, 'FPE10_TARGET_LIFETIME_EXPLICIT_RELEASE=PASS'
  print *, 'FPE10_TARGET_LIFETIME_IMMUTABLE_TARGET=PASS'
  print *, 'FPE10_TARGET_LIFETIME_PROBE PASS'

contains

  subroutine outer_runtime(registry_arg, model_arg, value)
    type(forcing_t), target, intent(in) :: registry_arg(:)
    type(model_t), intent(inout) :: model_arg
    real(real64), intent(out) :: value

    call prepare_interval(model_arg, registry_arg(1))
    call nested_kernel_use(model_arg, value)
    call release_interval(model_arg)
  end subroutine outer_runtime

  subroutine prepare_interval(model_arg, forcing_arg)
    type(model_t), intent(inout) :: model_arg
    type(forcing_t), target, intent(in) :: forcing_arg

    if (.not. allocated(forcing_arg%values)) error stop 'FPE10 forcing values unavailable'
    model_arg%view => forcing_arg%values
  end subroutine prepare_interval

  subroutine nested_kernel_use(model_arg, value)
    type(model_t), intent(in) :: model_arg
    real(real64), intent(out) :: value

    if (.not. associated(model_arg%view)) error stop 'FPE10 nested view not associated'
    value = sum(model_arg%view)
  end subroutine nested_kernel_use

  subroutine release_interval(model_arg)
    type(model_t), intent(inout) :: model_arg
    nullify(model_arg%view)
  end subroutine release_interval

end program test_fpe10_target_lifetime_probe
