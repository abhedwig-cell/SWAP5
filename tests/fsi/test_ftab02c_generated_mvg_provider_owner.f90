program test_ftab02c_generated_mvg_provider_owner
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_soil_water_solver_contract, only: constitutive_hydraulics_provider_t
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, &
       initialize_b110_default_mvg_parameters
  use mod_b110_generated_mvg_provider_owner, only: b110_generated_mvg_provider_owner_t, &
       F_TAB02_OWNER_OK, F_TAB02_OWNER_INACTIVE, F_TAB02_OWNER_STATE_FAILED
  implicit none

  type(b110_default_mvg_parameters_t) :: parameters, unsupported
  type(b110_generated_mvg_provider_owner_t), target :: owner
  class(constitutive_hydraulics_provider_t), pointer :: provider
  real(real64), allocatable :: cofgen(:,:), h(:), theta(:), k(:), c(:), dk(:)
  integer :: n, i, iu, ios, status
  character(len=512) :: path
  character(len=16) :: soil
  real(real64) :: ores, osat, alpha, npar, ksat, lexp

  if (command_argument_count() /= 1) error stop 'usage: test_ftab02c FIXTURE'
  call get_command_argument(1,path)
  open(newunit=iu,file=trim(path),status='old',action='read',iostat=ios)
  if (ios /= 0) error stop 'cannot open F-TAB02 fixture'
  read(iu,*,iostat=ios) n
  if (ios /= 0 .or. n <= 0) error stop 'invalid F-TAB02 fixture header'
  allocate(cofgen(24,n)); cofgen=0.0_real64
  do i=1,n
    read(iu,*,iostat=ios) soil,ores,osat,alpha,npar,ksat,lexp
    if (ios /= 0) error stop 'invalid F-TAB02 fixture row'
    cofgen(1,i)=ores
    cofgen(2,i)=osat
    cofgen(3,i)=ksat
    cofgen(4,i)=alpha
    cofgen(5,i)=lexp
    cofgen(6,i)=npar
    cofgen(7,i)=1.0_real64-1.0_real64/npar
    cofgen(8,i)=alpha
    cofgen(9,i)=0.0_real64
    cofgen(10,i)=ksat
    cofgen(11,i)=0.999_real64
    cofgen(12,i)=0.99_real64*ksat
  end do
  close(iu)

  call initialize_b110_default_mvg_parameters(parameters,cofgen)
  allocate(h(n),theta(n),k(n),c(n),dk(n))
  h=-100.0_real64

  ! Default route remains analytical: generated state is absent until the
  ! explicit generated-provider selection is true.
  call owner%configure(.false.,101_int64,parameters,status)
  call require(status == F_TAB02_OWNER_INACTIVE, 'default selection inactive')
  call require(.not. owner%active(), 'default selection owns no generated state')
  call require(owner%generation_count() == 0, 'default selection generation count')
  call owner%provider_pointer(provider,status)
  call require(.not. associated(provider) .and. status == F_TAB02_OWNER_INACTIVE, &
       'inactive selection exposes no provider')

  call owner%configure(.true.,101_int64,parameters,status)
  call require(status == F_TAB02_OWNER_OK .and. owner%active(), 'generated selection configure')
  call require(owner%bound_parameter_set_id() == 101_int64, 'parameter authority id')
  call require(owner%generation_count() == 1, 'first generation')

  ! Reconfiguration of the same immutable parameter authority is the
  ! transaction/retry pattern and must not regenerate table state.
  do i=1,5
    call owner%configure(.true.,101_int64,parameters,status)
    call require(status == F_TAB02_OWNER_OK, 'same-authority configure')
  end do
  call require(owner%generation_count() == 1, 'same-authority state reused')

  call owner%bind_step(4.0e-2_real64,status)
  call require(status == F_TAB02_OWNER_OK, 'first step bind')
  call owner%provider_pointer(provider,status)
  call require(associated(provider) .and. status == F_TAB02_OWNER_OK, 'selected provider available')
  call provider%evaluate(h,theta,k,c,dk)
  call require(all(ieee_is_finite(theta)) .and. all(ieee_is_finite(k)) .and. &
       all(ieee_is_finite(c)) .and. all(k > 0.0_real64), 'selected provider finite evaluation')

  call owner%bind_step(2.0e-2_real64,status)
  call require(status == F_TAB02_OWNER_OK, 'step rebind')
  call require(owner%generation_count() == 1, 'step rebind does not regenerate')

  ! A new typed parameter authority invalidates the previous immutable table.
  call owner%configure(.true.,102_int64,parameters,status)
  call require(status == F_TAB02_OWNER_OK, 'new parameter authority configure')
  call require(owner%generation_count() == 2, 'new authority regenerates once')
  call owner%provider_pointer(provider,status)
  call require(.not. associated(provider) .and. status == F_TAB02_OWNER_INACTIVE, &
       'new state requires explicit step bind')
  call owner%bind_step(4.0e-2_real64,status)
  call require(status == F_TAB02_OWNER_OK, 'new authority step bind')

  ! Unsupported generated-provider physics must fail closed. There is no
  ! analytical fallback inside the generated owner after explicit selection.
  cofgen(9,1)=-5.0_real64
  call initialize_b110_default_mvg_parameters(unsupported,cofgen)
  call owner%configure(.true.,103_int64,unsupported,status)
  call require(status == F_TAB02_OWNER_STATE_FAILED, 'unsupported H_ENPR fails closed')
  call require(.not. owner%active(), 'failed generated selection inactive')
  call owner%provider_pointer(provider,status)
  call require(.not. associated(provider), 'failed generated selection has no fallback provider')
  call require(owner%generation_count() == 2, 'failed generation not counted')

  call owner%configure(.false.,104_int64,parameters,status)
  call require(status == F_TAB02_OWNER_INACTIVE .and. .not. owner%active(), 'explicit deselection')
  call owner%close()
  call require(owner%generation_count() == 0, 'owner close resets lifecycle')

  write(*,'(a,i0)') 'F_TAB02_C_STARING_ROWS=',n
  write(*,'(a)') 'F_TAB02_C_DEFAULT_ANALYTICAL_SELECTION=PASS'
  write(*,'(a)') 'F_TAB02_C_EXPLICIT_GENERATED_SELECTION=PASS'
  write(*,'(a)') 'F_TAB02_C_SAME_AUTHORITY_REUSE=PASS'
  write(*,'(a)') 'F_TAB02_C_STEP_REBIND_NO_REGENERATION=PASS'
  write(*,'(a)') 'F_TAB02_C_PARAMETER_AUTHORITY_INVALIDATION=PASS'
  write(*,'(a)') 'F_TAB02_C_UNSUPPORTED_FAIL_CLOSED_NO_FALLBACK=PASS'
  write(*,'(a)') 'F-TAB02-C GENERATED PROVIDER OWNER GATE PASS'

contains

  subroutine require(condition,label)
    logical,intent(in)::condition
    character(len=*),intent(in)::label
    if(.not.condition) then
      write(*,'(a,1x,a)') 'F_TAB02_C_GATE_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require

end program test_ftab02c_generated_mvg_provider_owner
